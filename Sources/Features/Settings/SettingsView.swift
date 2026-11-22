import SwiftUI

struct SettingsView: View {
    /// Screens other tabs can open directly inside Settings.
    enum Destination: Hashable {
        case cubatramiteGuide
    }

    @EnvironmentObject private var appState: AppState
    @Binding private var path: [Destination]
    private let client: CaseroClient
    @ObservedObject private var settings: AppSettings
    @StateObject private var viewModel: SettingsViewModel
    @State private var isExportFormPresented = false
    @State private var isLoginPresented = false
    @State private var isChannelsPresented = false
    @State private var isProfilePresented = false

    init(client: CaseroClient, settings: AppSettings, path: Binding<[Destination]> = .constant([])) {
        self.client = client
        _path = path
        self.settings = settings
        _viewModel = StateObject(wrappedValue: SettingsViewModel(client: client, settings: settings))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                accountSection
                sessionSection
                cacheSection
                guestSection
                aboutSection
                versionFooter
            }
            .navigationTitle("Settings")
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .cubatramiteGuide: CubatramiteGuideView()
                }
            }
            .task { await viewModel.refreshCacheSummary() }
            .onChange(of: settings.saveImages) { enabled in
                if !enabled { Task { await PhotoCache.shared.clear() } }
            }
            .onChange(of: appState.isSignedIn) { signedIn in
                if signedIn { isLoginPresented = false }
            }
            .sheet(isPresented: $isProfilePresented) {
                PortalProfileSheet(client: client)
            }
            .sheet(isPresented: $isChannelsPresented) {
                CommunicationChannelsSheet(client: client)
            }
            .sheet(isPresented: $isExportFormPresented) {
                ExportFormSheet(viewModel: viewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            Button {
                isProfilePresented = true
            } label: {
                Label("Portal Profile Account", systemImage: "person.crop.circle")
            }
            Button {
                isChannelsPresented = true
            } label: {
                Label("Communication channels", systemImage: "envelope")
            }
            Toggle("Remember credentials", isOn: $settings.rememberCredentials)
            Text("Stored only on this device in the iOS Keychain, used to restore the app session.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if appState.isSignedIn {
                Button("Sign out of the app session", role: .destructive) {
                    Task { await appState.signOutCompletely() }
                }
            } else {
                Button {
                    isLoginPresented = true
                } label: {
                    Label("Sign in to the app session", systemImage: "person.crop.circle.badge.plus")
                }
            }
        }
        .sheet(isPresented: $isLoginPresented) {
            LoginView(client: client, settings: settings)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var sessionSection: some View {
        Section("Session") {
            if !settings.rememberCredentials {
                Text("Enable Remember credentials at sign-in to recover expired sessions automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Auto re-authenticate on expiry", isOn: $settings.autoReauth)
                .disabled(!settings.rememberCredentials)
            Text(
                "Signs in with your saved credentials when the app opens and when a request comes back as expired. iOS asks for Face ID, Touch ID or your passcode each time; without a device passcode it stays off. If it fails, a banner asks you to sign in."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var cacheSection: some View {
        Section("Cache") {
            Picker("Keep guest data for", selection: $settings.cacheTTL) {
                ForEach(AppSettings.CacheTTL.allCases) { ttl in
                    Text(ttl.label).tag(ttl)
                }
            }
            Toggle("Save guest photos", isOn: $settings.saveImages)
            Button(role: .destructive) {
                Task {
                    await viewModel.clearCache()
                    appState.hasCachedGuests = false
                }
            } label: {
                Label {
                    Text("Clear cache")
                } icon: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
            Text(viewModel.cacheSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var guestSection: some View {
        Section("Guests") {
            Picker("Default date range", selection: $settings.defaultGuestRangeDays) {
                ForEach([7, 15, 30, 60, 90, 180, 365], id: \.self) { days in
                    Text(LocalizedStringKey("\(days) days")).tag(days)
                }
            }
            Button {
                isExportFormPresented = true
            } label: {
                Label("Export guest data", systemImage: "square.and.arrow.up")
            }
            Text(
                "This range is used by default when loading guests. Choose a longer range in the calendar filter when needed."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("Disclaimer")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                }
                .font(.subheadline.weight(.semibold))
                Text("App disclaimer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            NavigationLink("App User Manual") { ManualView() }
            NavigationLink("Official Portal Help") { PortalHelpView() }
            NavigationLink("Cubatramite source", value: Destination.cubatramiteGuide)
            NavigationLink("Privacy Policy & Terms") { PrivacyView() }
            Link(destination: URL(string: "https://github.com/albertolicea00/casero.cu-ios")!) {
                Label("Open source project", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Link(destination: URL(string: "https://casero.rem.cu/")!) {
                Label("CASERO web portal", systemImage: "safari")
            }
        }
    }

    private var versionFooter: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return Section {
            VStack(spacing: 4) {
                Text("Version \(version) (\(build))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("by @albertolicea00", destination: URL(string: "https://github.com/albertolicea00")!)
                    .font(.caption)
                    .tint(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
        }
    }
}

private struct ExportFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Date range") {
                    DatePicker("From", selection: $viewModel.exportFrom, displayedComponents: .date)
                    DatePicker("To", selection: $viewModel.exportTo, displayedComponents: .date)
                }
                Section("Format") {
                    Picker("Format", selection: $viewModel.exportFormat) {
                        ForEach(ExportService.Format.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    if viewModel.exportFormat == .pdf {
                        Toggle("Include photos", isOn: $viewModel.includePhotosInPDF)
                    }
                }
                Section {
                    Text(viewModel.cacheSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(
                        "Built from the guests already cached on this device — reload the Guests tab first to include recent data."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Button {
                        Task { await viewModel.export() }
                    } label: {
                        if viewModel.isExporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create export")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isExporting)
                    if let message = viewModel.noticeMessage {
                        Text(message).foregroundStyle(.secondary).font(.caption)
                    }
                    if let message = viewModel.errorMessage {
                        Text(message).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $viewModel.exportedFile, onDismiss: viewModel.removeExport) { file in
            ShareSheet(items: [file.url])
        }
    }
}

private struct ManualView: View {
    var body: some View {
        ScrollView {
            Text("Manual instructions")
                .padding()
        }
        .navigationTitle("App User Manual")
    }
}

private struct PrivacyView: View {
    var body: some View {
        ScrollView { Text("Privacy details").padding() }
            .navigationTitle("Privacy Policy & Terms")
    }
}
