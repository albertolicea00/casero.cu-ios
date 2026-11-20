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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Operation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Operation", selection: $model.kind) {
                            Text("Guest").tag(SMSReportViewModel.Kind.guest)
                            Text("Companion").tag(SMSReportViewModel.Kind.companion)
                            Text("Confirm").tag(SMSReportViewModel.Kind.confirmation)
                        }
                        .pickerStyle(.segmented)
                    }

                    inputCard

                    if let preview = model.preview {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message preview").font(.headline)
                            LabeledContent("Destination", value: USSDSMSReporter.smsDestination)
                            Text(preview).font(.body.monospaced()).textSelection(.enabled)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        model.prepare()
                    } label: {
                        Text("Send SMS")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.preview == nil || !MessageComposeView.canSendText)

                    if !MessageComposeView.canSendText {
                        Label(
                            "This device cannot send SMS. Use the preview on your registered phone.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Text("You’ll review the prepared message in Messages before sending.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    if let result = model.resultMessage {
                        Text(result)
                            .font(.subheadline)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("After sending").font(.headline)
                        Text(
                            "Each guest and companion requires a separate report. The first reply supplies a confirmation code. Send HC followed by that code to 7344, then wait for the registration code that confirms the report."
                        )
                        Text(
                            "Sending an SMS does not by itself confirm registration. iOS requires you to review and send each message in Messages."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
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

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.kind == .confirmation {
                TextField("Confirmation code without HC", text: $model.confirmationCode)
                    .textContentType(.oneTimeCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Text(
                    "Check the name and nationality in the service reply before confirming. Requests expire after six hours; start a new report if that time has passed."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                TextField("Guest passport", text: $model.passport)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                if model.kind == .companion {
                    TextField("Companion identity number", text: $model.companionIdentity)
                        .keyboardType(.numberPad)
                    Toggle("The main guest's registration is confirmed", isOn: $model.mainGuestIsRegistered)
                }
                TextField("Stay days", text: $model.days)
                    .keyboardType(.numberPad)
            }
            if let validation = model.validationMessage {
                Text(validation).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SMSReportInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onOpenSettings: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Before the first report").font(.headline)
                        Text(
                            "Use the phone number associated with your host account. Call 18808 to request association and wait for confirmation before reporting."
                        )
                        Text("SMS does not require internet, but needs cellular service. Carrier charges may apply.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("How to report by SMS")
                            .font(.headline)
                        instructionStep(
                            number: "1",
                            title: "Associate your host phone",
                            description:
                                "Call 18808 from the phone associated with your host account and wait for confirmation. If you already have an account, manage the phone in Settings or on the official portal."
                        )
                        instructionStep(
                            number: "2",
                            title: "Prepare the first message",
                            description:
                                "For a guest, enter the passport and stay days. For a companion, enter the main guest's passport and the companion's identity number; the main guest must already be registered. The app prepares the HC message for 7344. Review it in Messages and send it."
                        )
                        instructionStep(
                            number: "3",
                            title: "Check the reply and confirm",
                            description:
                                "Wait for the service reply. Verify the guest's name and nationality, then select Confirm, enter the received confirmation code without HC, and send the prepared confirmation message to 7344."
                        )
                        instructionStep(
                            number: "4",
                            title: "Wait for the registration code",
                            description:
                                "The report is complete only after the service returns a final registration code. Each person needs a separate exchange. Confirmation requests expire after six hours; start a new report if one expires."
                        )
                        Text(
                            "Guest: HC<PASSPORT> <STAY_DAYS>\nCompanion: HC<MAIN_PASSPORT> <ID_NUMBER> <STAY_DAYS>\nConfirm: HC<CONFIRMATION_CODE>"
                        )
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    if let url = USSDSMSReporter.dialURL(for: USSDSMSReporter.associationPhone) {
                        HStack {
                            Spacer()
                            Link(destination: url) {
                                Label("Call 18808", systemImage: "phone.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            Spacer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions and portal").font(.headline)
                        Text(
                            "If you already have an account, associate or update your phone from Settings > Communication channels, or use the official portal."
                        )
                        .font(.subheadline)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    Button {
                        dismiss()
                        onOpenSettings()
                    } label: {
                        HStack {
                            Label("Manage phone in Settings", systemImage: "gearshape")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PortalPageView(path: "", title: "Official portal")
                    } label: {
                        HStack {
                            Spacer()
                            Label("Open official portal", systemImage: "safari")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)

                    Link(destination: USSDSMSReporter.instructionsURL) {
                        HStack {
                            Spacer()
                            Label("SMS procedure reference", systemImage: "book")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
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

    private func instructionStep(number: String, title: LocalizedStringKey, description: LocalizedStringKey)
        -> some View
    {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Color(uiColor: .tertiarySystemFill), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
