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
        isSignedIn = false
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
    private enum Tab: Hashable {
        case sms
        case register
        case guests
        case settings
    }

    @EnvironmentObject private var appState: AppState
    @State private var selection: Tab = .sms
    @State private var isRegisterLoginPresented = false
    let client: CaseroClient

    var body: some View {
        VStack(spacing: 0) {
            if appState.isSigningOut { ProgressView("Signing out of the app session…").padding() }
            if appState.sessionExpiredBanner {
                SessionExpiredBanner(onSignIn: { isRegisterLoginPresented = true })
            }
            ConnectivityBanner(connectivity: appState.connectivity)
            if !appState.isSignedIn && !appState.sessionExpiredBanner
                && [.register, .guests, .settings].contains(selection)
            {
                SignInBanner(onSignIn: { isRegisterLoginPresented = true })
            }

            TabView(selection: $selection) {
                SMSHelpView {
                    selection = .settings
                }
                .tabItem { Label("SMS", systemImage: "message.fill") }
                .tag(Tab.sms)

                AuthGate(
                    isActive: selection == .register,
                    onSignIn: { isRegisterLoginPresented = true }
                ) { RegisterGuestView(client: client) }
                .tabItem { Label("Register", systemImage: "person.badge.plus") }
                .tag(Tab.register)

                GuestsView(client: client, settings: appState.settings)
                    .tabItem { Label("Guests", systemImage: "person.2.fill") }
                    .tag(Tab.guests)

                SettingsView(client: client, settings: appState.settings)
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(Tab.settings)
            }
        }
        .sheet(isPresented: $isRegisterLoginPresented) {
            LoginView(client: client, settings: appState.settings)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: selection) { tab in
            if tab == .register && !appState.isSignedIn {
                isRegisterLoginPresented = true
            }
        }
        .onChange(of: appState.isSignedIn) { signedIn in
            if signedIn { isRegisterLoginPresented = false }
        }
    }
}

/// Keeps registration locked until the login sheet succeeds; SMS remains
/// available without a portal account.
private struct AuthGate<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    let isActive: Bool
    let onSignIn: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        if appState.isSignedIn {
            content()
        } else {
            NavigationStack {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.key")
                        .font(.system(size: 38))
                        .foregroundStyle(.tertiary)
                    Text("Sign in to the app session")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("Use your portal account to look up and report guests.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(action: onSignIn) {
                        Label("Sign in to the app session", systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Register")
            }
            .onAppear {
                if isActive { onSignIn() }
            }
        }
    }
}

private struct SessionExpiredBanner: View {
    let onSignIn: () -> Void

    var body: some View {
        Button(action: onSignIn) {
            Label("App session expired. Tap to sign in again.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(8)
        }
        .frame(minHeight: 44)
        .background(Color.orange.opacity(0.2))
        .foregroundStyle(.primary)
    }
}

private struct SignInBanner: View {
    let onSignIn: () -> Void

    var body: some View {
        Button(action: onSignIn) {
            Label("Sign in to the app session", systemImage: "person.crop.circle.badge.plus")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(8)
        }
        .frame(minHeight: 44)
        .background(Color.yellow.opacity(0.25))
        .foregroundStyle(.primary)
    }
}

private struct ConnectivityBanner: View {
    @ObservedObject var connectivity: ConnectivityMonitor

    var body: some View {
        Group {
            if !connectivity.isConnected {
                Label(
                    "No internet connection. Check your Wi-Fi or mobile data.", systemImage: "wifi.slash"
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
