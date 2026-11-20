import MessageUI
import SwiftUI

/// Carrier SMS reports remain accessible without a portal account or mobile data.
struct SMSHelpView: View {
    @StateObject private var model = SMSReportViewModel()
    @State private var isInfoPresented = false
    let onOpenSettings: () -> Void

    init(onOpenSettings: @escaping () -> Void = {}) {
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Report by SMS") {
                    Picker("Operation", selection: $model.kind) {
                        ForEach(SMSReportViewModel.Kind.allCases) { kind in
                            Text(LocalizedStringKey(kind.rawValue)).tag(kind)
                        }
                    }
                    if model.kind == .confirmation {
                        TextField("Confirmation code without HC", text: $model.confirmationCode)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        Text(
                            "Check the name and nationality in the service reply before confirming. Requests expire after six hours; start a new report if that time has passed."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    } else {
                        TextField("Guest passport", text: $model.passport)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        if model.kind == .companion {
                            TextField("Companion identity number", text: $model.companionIdentity)
                                .keyboardType(.numberPad)
                            Toggle("The main guest's registration is confirmed", isOn: $model.mainGuestIsRegistered)
                        }
                        TextField("Stay days", text: $model.days).keyboardType(.numberPad)
                    }
                    if let validation = model.validationMessage {
                        Text(validation).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let preview = model.preview {
                    Section("Message preview") {
                        LabeledContent("Destination", value: USSDSMSReporter.smsDestination)
                        Text(preview).font(.body.monospaced()).textSelection(.enabled)
                    }
                }
                Section {
                    Button {
                        model.prepare()
                    } label: {
                        Label("Review and send SMS", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(model.preview == nil || !MessageComposeView.canSendText)
                    if !MessageComposeView.canSendText {
                        Label(
                            "This device cannot send SMS. Use the preview on your registered phone.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                    } else {
                        Text("You’ll review the prepared message in Messages before sending.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let result = model.resultMessage {
                    Section("Last result") { Text(result) }
                }
                Section("After sending") {
                    Text(
                        "Each guest and companion requires a separate report. The first reply supplies a confirmation code. Send HC followed by that code to 7344, then wait for the registration code that confirms the report."
                    )
                    Text(
                        "Sending an SMS does not by itself confirm registration. iOS requires you to review and send each message in Messages."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("SMS reports")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isInfoPresented = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("SMS report information")
                }
            }
            .onChange(of: model.passport) { _ in model.mainGuestIsRegistered = false }
            .sheet(item: $model.preparedMessage) { message in
                MessageComposeView(recipients: [USSDSMSReporter.smsDestination], body: message.body) { result in
                    model.finished(result, kind: message.kind)
                }
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: $isInfoPresented) {
                SMSReportInfoSheet(onOpenSettings: onOpenSettings)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct SMSReportInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onOpenSettings: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Before the first report") {
                    Text(
                        "Use the phone number associated with your host account. Call 18808 to request association and wait for confirmation before reporting."
                    )
                    if let url = USSDSMSReporter.dialURL(for: USSDSMSReporter.associationPhone) {
                        Link(destination: url) {
                            Label("Call 18808", systemImage: "phone.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Text("SMS does not require internet, but needs cellular service. Carrier charges may apply.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Instructions and portal") {
                    Text(
                        "If you already have an account, associate or update your phone from Settings > Communication channels, or use the official portal."
                    )
                    .font(.subheadline)
                    Button {
                        dismiss()
                        onOpenSettings()
                    } label: {
                        Label("Manage phone in Settings", systemImage: "gearshape")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    NavigationLink {
                        PortalPageView(path: "", title: "Official portal")
                    } label: {
                        Label("Open official portal", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Link(destination: USSDSMSReporter.instructionsURL) {
                        Label("SMS procedure reference", systemImage: "book")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("SMS report information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
