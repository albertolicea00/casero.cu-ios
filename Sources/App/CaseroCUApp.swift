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

/// Process-wide state: the portal client and whether we hold a session.
@MainActor
final class AppState: ObservableObject {
    @Published var isSignedIn = false
    let client = CaseroClient()
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.isSignedIn {
            GuestsView(client: appState.client)
        } else {
            LoginView(client: appState.client)
        }
    }
}
