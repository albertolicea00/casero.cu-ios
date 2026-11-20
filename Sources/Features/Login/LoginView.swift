import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var settings: AppSettings
    @StateObject private var viewModel: LoginViewModel

    init(client: CaseroClient, settings: AppSettings) {
        self.settings = settings
        _viewModel = StateObject(wrappedValue: LoginViewModel(client: client, settings: settings))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Casero")
                    .font(.largeTitle.bold())
                Text("Sign in to the guest portal")
                    .foregroundStyle(.secondary)

                TextField("Username", text: $viewModel.user)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)

                Toggle("Remember credentials", isOn: $settings.rememberCredentials)
                if let message = viewModel.validationMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                if let message = viewModel.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Button {
                    Task {
                        if await viewModel.submit() {
                            appState.sessionExpiredBanner = false
                            appState.isSignedIn = true
                        }
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Sign in").frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmit)
            }
            .padding(24)
        }
    }
}
