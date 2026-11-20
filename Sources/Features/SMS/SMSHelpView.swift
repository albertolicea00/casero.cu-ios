import MessageUI
import SwiftUI

/// Carrier SMS reports remain accessible without a portal account or mobile data.
struct SMSHelpView: View {
    @StateObject private var model = SMSReportViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Before the first report") {
                    Text(
                        "Use the phone number associated with your host account. Call 18808 to request association and wait for confirmation before reporting."
                    )
                    if let url = USSDSMSReporter.dialURL(for: USSDSMSReporter.associationPhone) {
                        Link("Call 18808", destination: url)
                    }
                    Text("SMS does not require internet, but needs cellular service. Carrier charges may apply.")
                        .font(.caption).foregroundStyle(.secondary)
                }
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
                        if MessageComposeView.canSendText {
                            Button("Prepare SMS") { model.prepare() }
                        } else {
                            Label(
                                "This device cannot send SMS. Use the preview on your registered phone.",
                                systemImage: "exclamationmark.triangle"
                            )
                            .font(.caption)
                        }
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
                Section("Instructions and portal") {
                    Link("SMS procedure reference", destination: USSDSMSReporter.instructionsURL)
                    NavigationLink("Open official portal") {
                        PortalPageView(path: "", title: "Official portal")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("SMS reports")
            .onChange(of: model.passport) { _ in model.mainGuestIsRegistered = false }
            .sheet(item: $model.preparedMessage) { message in
                MessageComposeView(recipients: [USSDSMSReporter.smsDestination], body: message.body) { result in
                    model.finished(result, kind: message.kind)
                }
                .interactiveDismissDisabled()
            }
        }
    }
}
