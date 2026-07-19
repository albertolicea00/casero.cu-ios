import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: LoginViewModel

    init(client: CaseroClient) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(client: client))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Casero")
                .font(.largeTitle.bold())
            Text("Sign in to the guest portal")
                .foregroundStyle(.secondary)

            TextField("Username", text: $viewModel.user)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            if let message = viewModel.errorMessage {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button {
                Task {
                    if await viewModel.submit() {
                        appState.isSignedIn = true
                    }
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("Sign in").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmit)
        }
        .padding(24)
    }
}
