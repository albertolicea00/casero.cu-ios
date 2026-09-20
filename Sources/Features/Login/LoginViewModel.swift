import Foundation

@MainActor
final class LoginViewModel: ObservableObject {

    @Published var user = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client: CaseroClient
    private let settings: AppSettings

    init(client: CaseroClient, settings: AppSettings) {
        self.client = client
        self.settings = settings
        if settings.rememberCredentials, let savedUser = KeychainStore.get(.username) {
            user = savedUser
        }
    }

    var canSubmit: Bool {
        !user.isEmpty && password.count >= 8 && !isLoading
    }

    /// Returns `true` on a successful sign-in.
    func submit() async -> Bool {
        guard canSubmit else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let trimmedUser = user.trimmingCharacters(in: .whitespaces)
        do {
            try await client.login(user: trimmedUser, password: password)
            if settings.rememberCredentials {
                KeychainStore.set(trimmedUser, for: .username)
                KeychainStore.set(password, for: .password)
            }
            return true
        } catch {
            errorMessage = (error as? PortalError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}
