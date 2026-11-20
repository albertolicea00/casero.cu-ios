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

    var validationMessage: String? {
        guard !password.isEmpty else { return nil }
        let pattern = #"^(?=.*[A-Z])(?=.*\W)(?=.*[0-9])(?=.*[a-z]).*$"#
        guard (8...100).contains(password.count), password.range(of: pattern, options: .regularExpression) != nil else {
            return String(localized: "Use 8–100 characters with uppercase, lowercase, a number, and a symbol.")
        }
        return nil
    }

    var canSubmit: Bool {
        !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (8...100).contains(password.count)
            && validationMessage == nil && !isLoading
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
            await GuestCache.shared.clear()
            await PhotoCache.shared.clear()
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
