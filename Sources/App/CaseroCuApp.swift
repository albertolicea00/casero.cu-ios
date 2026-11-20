import SwiftUI

@main
struct CaseroCuApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(\.calendar, PortalDates.calendar)
                .environment(\.timeZone, PortalDates.timeZone)
        }
    }
}

/// Process-wide state: the portal client, session status, and shared services.
@MainActor
final class AppState: ObservableObject {
    @Published var isSignedIn = false
    @Published var hasCachedGuests = false
    @Published var isSigningOut = false
    /// Set once a lazily-detected session expiry could not be silently recovered.
    /// Drives the "session lost, tap to sign in" banner instead of an immediate bounce.
    @Published var sessionExpiredBanner = false

    let client = CaseroClient()
    let settings = AppSettings()
    let connectivity = ConnectivityMonitor()

    private var recoveryTask: Task<Bool, Never>?

    init() {
        client.recoverSession = { [weak self] in
            await self?.recoverSession() ?? false
        }
    }

    private func recoverSession() async -> Bool {
        if let recoveryTask { return await recoveryTask.value }
        guard settings.autoReauth, settings.rememberCredentials,
            let user = KeychainStore.get(.username),
            let password = KeychainStore.get(.password)
        else { return false }
        let task = Task { () -> Bool in
            do {
                try await client.login(user: user, password: password)
                try Task.checkCancellation()
                return true
            } catch { return false }
        }
        recoveryTask = task
        let recovered = await task.value
        recoveryTask = nil
        return recovered
    }

    func restoreLocalData() async {
        guard let snapshot = await GuestCache.shared.load() else {
            hasCachedGuests = false
            return
        }
        if await GuestCache.shared.isStale(snapshot, ttl: settings.cacheTTL.interval) {
            await GuestCache.shared.clear()
            await PhotoCache.shared.clear()
            hasCachedGuests = false
        } else {
            hasCachedGuests = !snapshot.guests.isEmpty
        }
    }

    /// Called by any feature view model that catches `PortalError.sessionExpired`.
    /// Lazy by design: no background polling, this only reacts to a real failed call.
    func reportSessionExpired() async {
        sessionExpiredBanner = true
    }

    func signOutCompletely() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        hasCachedGuests = false
        recoveryTask?.cancel()
        recoveryTask = nil
        isSignedIn = false
        await client.signOut()
        await GuestCache.shared.clear()
        await PhotoCache.shared.clear()
        KeychainStore.clearAll()
        sessionExpiredBanner = false
    }
}

/// Registration requires login; local settings and retained guests work offline.
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        MainTabView(client: appState.client)
            .disabled(appState.isSigningOut)
            .task { await appState.restoreLocalData() }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    let client: CaseroClient

    var body: some View {
        VStack(spacing: 0) {
            if appState.isSigningOut { ProgressView("Signing out…").padding() }
            if appState.sessionExpiredBanner {
                SessionExpiredBanner()
            }
            ConnectivityBanner(connectivity: appState.connectivity)

            TabView {
                SMSHelpView()
                    .tabItem { Label("SMS", systemImage: "message.fill") }

                AuthGate(client: client) {
                    RegisterGuestView(client: client)
                }
                .tabItem { Label("Register", systemImage: "person.badge.plus") }

                Group {
                    if appState.isSignedIn || appState.hasCachedGuests {
                        GuestsView(client: client, settings: appState.settings)
                    } else {
                        LoginView(client: client, settings: appState.settings)
                    }
                }
                .tabItem { Label("Guests", systemImage: "person.2.fill") }

                SettingsView(client: client, settings: appState.settings)
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
        }
    }
}

/// Shows `LoginView` in place of any portal-backed tab's content until the
/// user signs in, instead of blocking the whole app (SMS reporting needs no
/// account).
private struct AuthGate<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    let client: CaseroClient
    @ViewBuilder let content: () -> Content

    var body: some View {
        if appState.isSignedIn {
            content()
        } else {
            LoginView(client: client, settings: appState.settings)
        }
    }
}

private struct SessionExpiredBanner: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button {
            appState.isSignedIn = false
        } label: {
            Label("Session lost. Tap to sign in.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(8)
        }
        .frame(minHeight: 44)
        .background(Color.orange.opacity(0.2))
        .foregroundStyle(.primary)
    }
}

private struct ConnectivityBanner: View {
    @ObservedObject var connectivity: ConnectivityMonitor

    var body: some View {
        Group {
            if !connectivity.isConnected {
                Label(
                    "No internet connection. The portal is only reachable from inside Cuba.", systemImage: "wifi.slash"
                )
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.red.opacity(0.15))
                .foregroundStyle(.primary)
            }
        }
    }
}
