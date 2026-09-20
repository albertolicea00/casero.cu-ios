import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var settings: AppSettings
    @StateObject private var viewModel: SettingsViewModel

    init(client: CaseroClient, settings: AppSettings) {
        self.settings = settings
        _viewModel = StateObject(wrappedValue: SettingsViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                sessionSection
                cacheSection
                exportSection
                aboutSection
            }
            .navigationTitle("Settings")
            .task { await viewModel.refreshCacheSummary() }
            .sheet(item: $viewModel.exportedFile) { file in
                ShareSheet(items: [file.url])
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            Toggle("Remember credentials", isOn: $settings.rememberCredentials)
            Text("Stored in the iOS Keychain, used only for silent session recovery.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Sign out", role: .destructive) {
                Task { await appState.signOutCompletely() }
            }
        }
    }

    private var sessionSection: some View {
        Section("Session") {
            Toggle("Auto re-authenticate on expiry", isOn: $settings.autoReauth)
                .disabled(!settings.rememberCredentials)
            Text("Detected lazily: only when a real request comes back as expired, never by polling in the background. If off (or no credentials saved), a banner asks you to sign in again.")
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
            Text(viewModel.cacheSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Clear cache", role: .destructive) {
                Task { await viewModel.clearCache() }
            }
        }
    }

    private var exportSection: some View {
        Section("Export") {
            DatePicker("From", selection: $viewModel.exportFrom, displayedComponents: .date)
            DatePicker("To", selection: $viewModel.exportTo, displayedComponents: .date)
            Picker("Format", selection: $viewModel.exportFormat) {
                ForEach(ExportService.Format.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            if viewModel.exportFormat == .pdf {
                Toggle("Include photos", isOn: $viewModel.includePhotosInPDF)
            }
            Text("Built from the guests already cached on this device — reload the Guests tab first to include recent data.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                Task { await viewModel.export() }
            } label: {
                if viewModel.isExporting {
                    ProgressView()
                } else {
                    Text("Export")
                }
            }
            .disabled(viewModel.isExporting)
            if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(.red).font(.caption)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            NavigationLink("Manual") { ManualView() }
            NavigationLink("Disclaimer") { DisclaimerView() }
            NavigationLink("Developer & official links") { DeveloperInfoView() }
        }
    }
}

private struct ManualView: View {
    var body: some View {
        ScrollView {
            Text(
                """
                SMS: report a guest over your carrier network when the portal is unreachable. \
                iOS requires you to confirm sending the message yourself.

                Register: look up a guest by passport (foreign) or carné (Cuban companion), \
                add them with check-in/check-out dates, then submit — you can batch several \
                people into one submission.

                Guests: shows active and past stays. Pull to refresh or tap the reload icon; \
                data is cached on-device so you can still browse it offline.

                Settings: manage your session, cache, exports, and this manual.
                """
            )
            .padding()
        }
        .navigationTitle("Manual")
    }
}

private struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            Text(
                """
                CASERO for iOS is an unofficial, independent client for the CASERO web portal \
                (casero.rem.cu) and the official USSD/SMS reporting codes. It is not affiliated \
                with, endorsed by, or produced by CIDP-MININT or any Cuban government agency.

                Use at your own risk. The developer is not responsible for reporting delays, \
                data loss, or portal outages beyond this app's control.
                """
            )
            .padding()
        }
        .navigationTitle("Disclaimer")
    }
}

private struct DeveloperInfoView: View {
    var body: some View {
        Form {
            Section("Official channels") {
                Link("CASERO web portal", destination: URL(string: "https://casero.rem.cu/")!)
            }
            Section("This app") {
                Text("Unofficial iOS client. Source and issue tracker are linked from the project README.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Developer info")
    }
}
