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
        NavigationStack {
            Form {
                Section {
                    Text("Sign in to the guest portal")
                        .foregroundStyle(.secondary)
                    TextField("Username", text: $viewModel.user)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                    Toggle("Remember credentials", isOn: $settings.rememberCredentials)
                }

                if let message = viewModel.validationMessage {
                    Section { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
                if let message = viewModel.errorMessage {
                    Section { Text(message).foregroundStyle(.red).font(.footnote) }
                }

                Section {
                    Button {
                        Task {
                            if await viewModel.submit() {
                                appState.sessionExpiredBanner = false
                                appState.isSignedIn = true
                            }
                        }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Sign in in app")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSubmit)

                    NavigationLink {
                        PortalPageView(path: "", title: "Official portal")
                    } label: {
                        Text("Open official portal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Sign in in app")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
