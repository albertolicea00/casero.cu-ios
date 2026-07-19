import Foundation

@MainActor
final class LoginViewModel: ObservableObject {

    @Published var user = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client: CaseroClient

    init(client: CaseroClient) {
        self.client = client
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
        do {
            try await client.login(user: user.trimmingCharacters(in: .whitespaces), password: password)
            return true
        } catch {
            errorMessage = (error as? PortalError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}
