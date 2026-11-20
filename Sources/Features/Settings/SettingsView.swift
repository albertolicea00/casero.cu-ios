import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var settings: AppSettings
    @StateObject private var viewModel: SettingsViewModel

    init(client: CaseroClient, settings: AppSettings) {
        self.settings = settings
        _viewModel = StateObject(wrappedValue: SettingsViewModel(client: client, settings: settings))
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                Section("Communication channels") {
                    NavigationLink("Manage phones and emails") {
                        PortalPageView(path: "ViasComunicacion", title: "Communication channels")
                    }
                    Text("Changes are saved directly through the official portal form.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                sessionSection
                guestRangeSection
                cacheSection
                exportSection
                aboutSection
            }
            .navigationTitle("Settings")
            .task { await viewModel.refreshCacheSummary() }
            .onChange(of: settings.saveImages) { enabled in
                if !enabled { Task { await PhotoCache.shared.clear() } }
            }
            .sheet(item: $viewModel.exportedFile, onDismiss: viewModel.removeExport) { file in
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
            if !settings.rememberCredentials {
                Text("Enable Remember credentials at sign-in to recover expired sessions automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Auto re-authenticate on expiry", isOn: $settings.autoReauth)
                .disabled(!settings.rememberCredentials)
            Text(
                "Detected lazily: only when a real request comes back as expired, never by polling in the background. If off (or no credentials saved), a banner asks you to sign in again."
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
            Text(viewModel.cacheSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Clear cache", role: .destructive) {
                Task {
                    await viewModel.clearCache()
                    appState.hasCachedGuests = false
                }
            }
        }
    }

    private var guestRangeSection: some View {
        Section("Guests") {
            Picker("Default date range", selection: $settings.defaultGuestRangeDays) {
                ForEach([30, 60, 90, 180, 365], id: \.self) { days in
                    Text(LocalizedStringKey("\(days) days")).tag(days)
                }
            }
            Text(
                "This range is used by default when loading guests. Choose a longer range in the calendar filter when needed."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
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
                } else {
                    Text("Export")
                }
            }
            .disabled(viewModel.isExporting)
            if let message = viewModel.noticeMessage { Text(message).foregroundStyle(.secondary).font(.caption) }
            if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(.red).font(.caption)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            NavigationLink("Manual") { ManualView() }
            NavigationLink("Disclaimer") { DisclaimerView() }
            NavigationLink("Privacy") { PrivacyView() }
            NavigationLink("Developer & official links") { DeveloperInfoView() }
        }
    }
}

private struct ManualView: View {
    var body: some View {
        ScrollView {
            Text("Manual instructions")
                .padding()
        }
        .navigationTitle("Manual")
    }
}

private struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            Text("App disclaimer")
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

private struct PrivacyView: View {
    var body: some View {
        ScrollView { Text("Privacy details").padding() }
            .navigationTitle("Privacy")
    }
}
