import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var settings: AppSettings
    @StateObject private var viewModel: LoginViewModel
    @State private var isPasswordVisible = false

    init(client: CaseroClient, settings: AppSettings) {
        self.settings = settings
        _viewModel = StateObject(wrappedValue: LoginViewModel(client: client, settings: settings))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text("Sign in to the app session")
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text("Use your account to register guests and manage your data.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                    VStack(spacing: 0) {
                        TextField("Username", text: $viewModel.user)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.vertical, 12)
                        Divider()
                        HStack(spacing: 8) {
                            Group {
                                if isPasswordVisible {
                                    TextField("Password", text: $viewModel.password)
                                } else {
                                    SecureField("Password", text: $viewModel.password)
                                }
                            }
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                        }
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                    .background(
                        Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    Toggle("Remember credentials", isOn: $settings.rememberCredentials)
                        .padding(.horizontal, 4)

                    if let message = viewModel.validationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let message = viewModel.errorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

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
                                Text("Sign in to the app session")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSubmit)
                    .padding(.top, 4)

                    NavigationLink {
                        PortalPageView(path: "", title: "Official portal")
                    } label: {
                        Text("Open official portal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, -8)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationTitle("Sign in to the app session")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
