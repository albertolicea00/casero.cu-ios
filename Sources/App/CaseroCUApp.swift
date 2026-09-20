import SwiftUI

@main
struct CaseroCUApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

/// Process-wide state: the portal client, session status, and shared services.
@MainActor
final class AppState: ObservableObject {
    @Published var isSignedIn = false
    /// Set once a lazily-detected session expiry could not be silently recovered.
    /// Drives the "session lost, tap to sign in" banner instead of an immediate bounce.
    @Published var sessionExpiredBanner = false

    let client = CaseroClient()
    let settings = AppSettings()
    let connectivity = ConnectivityMonitor()

    /// Called by any feature view model that catches `PortalError.sessionExpired`.
    /// Lazy by design: no background polling, this only reacts to a real failed call.
    func reportSessionExpired() async {
        if settings.autoReauth,
           settings.rememberCredentials,
           let user = KeychainStore.get(.username),
           let password = KeychainStore.get(.password) {
            do {
                try await client.login(user: user, password: password)
                sessionExpiredBanner = false
                return
            } catch {
                // Fall through to the banner — silent retry failed.
            }
        }
        sessionExpiredBanner = true
    }

    func signOutCompletely() async {
        await client.signOut()
        isSignedIn = false
        sessionExpiredBanner = false
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.isSignedIn {
            MainTabView(client: appState.client)
        } else {
            LoginView(client: appState.client, settings: appState.settings)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    let client: CaseroClient

    var body: some View {
        VStack(spacing: 0) {
            if appState.sessionExpiredBanner {
                SessionExpiredBanner()
            }
            ConnectivityBanner(connectivity: appState.connectivity)

            TabView {
                SMSHelpView()
                    .tabItem { Label("SMS", systemImage: "message.fill") }

                RegisterGuestView(client: client)
                    .tabItem { Label("Register", systemImage: "person.badge.plus") }

                GuestsView(client: client, settings: appState.settings)
                    .tabItem { Label("Guests", systemImage: "person.2.fill") }

                SettingsView(client: client, settings: appState.settings)
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
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
        .background(Color.orange)
        .foregroundStyle(.white)
    }
}

private struct ConnectivityBanner: View {
    @ObservedObject var connectivity: ConnectivityMonitor

    var body: some View {
        Group {
            if !connectivity.isConnected {
                Label("No internet connection. The portal is only reachable from inside Cuba.", systemImage: "wifi.slash")
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.red)
                    .foregroundStyle(.white)
            }
        }
    }
}
