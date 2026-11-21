import MessageUI
import SwiftUI

/// Carrier SMS reports remain accessible without a portal account or mobile data.
struct SMSHelpView: View {
    @StateObject private var model = SMSReportViewModel()
    @State private var isInfoPresented = false
    @State private var selectedReportKind = SMSReportViewModel.Kind.guest
    let onOpenSettings: () -> Void

    init(onOpenSettings: @escaping () -> Void = {}) {
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tap Preview SMS to open the prepared message in Messages. Review it and tap Send to confirm sending.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Operation", selection: $selectedReportKind) {
                            Text("Guest").tag(SMSReportViewModel.Kind.guest)
                            Text("Companion").tag(SMSReportViewModel.Kind.companion)
                        }
                        .onChange(of: selectedReportKind) { kind in
                            model.kind = kind
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    reportInputCard
                    sendSMSButton(for: selectedReportKind)

                    Divider()
                        .padding(.vertical, 6)

                    confirmationSection

                    if !MessageComposeView.canSendText {
                        Label(
                            "This device cannot send SMS. Use the preview on your registered phone.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let result = model.resultMessage {
                        Text(result)
                            .font(.subheadline)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }

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

    private var reportInputCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(spacing: 0) {
                TextField("Guest passport", text: $model.passport)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.vertical, 12)
                if selectedReportKind == .companion {
                    Divider()
                    TextField("Companion identity number", text: $model.companionIdentity)
                        .keyboardType(.numberPad)
                        .padding(.vertical, 12)
                    Divider()
                    Toggle("The main guest's registration is confirmed", isOn: $model.mainGuestIsRegistered)
                        .padding(.vertical, 12)
                }
                Divider()
                TextField("Stay days", text: $model.days)
                    .keyboardType(.numberPad)
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            if let validation = model.validationMessage(for: selectedReportKind) {
                Label(validation, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var confirmationInputCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(spacing: 0) {
                TextField("Confirmation code without HC", text: $model.confirmationCode)
                    .textContentType(.oneTimeCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            if let validation = model.validationMessage(for: .confirmation) {
                Label(validation, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var confirmationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Confirm received code")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(
                    "Check the name and nationality in the service reply before confirming. Requests expire after six hours; start a new report if that time has passed."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            confirmationInputCard
            sendSMSButton(for: .confirmation)
        }
    }

    private func sendSMSButton(for kind: SMSReportViewModel.Kind) -> some View {
        VStack(spacing: 8) {
            Button {
                model.prepare(kind: kind)
            } label: {
                Text("Preview SMS")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SMSPreviewButtonStyle())
            .disabled(model.preview(for: kind) == nil || !MessageComposeView.canSendText)

            if model.preview(for: kind) == nil {
                Label("Fill in the fields above to send the SMS.", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SMSPreviewButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(
                Color.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.55),
                in: RoundedRectangle(cornerRadius: 14)
            )
    }
}

private struct SMSReportInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onOpenSettings: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    infoHeading("Before the first report")
                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            "Use the phone number associated with your host account. Request phone association and wait for confirmation before reporting."
                        )
                        if let url = USSDSMSReporter.dialURL(for: USSDSMSReporter.associationPhone) {
                            Divider()
                            Link(destination: url) {
                                HStack {
                                    Label("Call 18808", systemImage: "phone.fill")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Divider()
                        }
                        Text("SMS does not require internet, but needs cellular service. Carrier charges may apply.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    infoHeading("After sending")
                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            "Each guest and companion needs a separate report. Check the reply's name and nationality, then send the confirmation code when prompted."
                        )
                        Divider()
                        Text(
                            "The report is complete only after the service returns a final registration code. Confirmation requests expire after six hours; start a new report if one expires."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    infoHeading("How to report by SMS")
                    VStack(alignment: .leading, spacing: 14) {
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
                        Divider()
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

                    infoHeading("Instructions and portal")
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            "If you already have an account, associate or update your phone from Settings > Communication channels, or use the official portal."
                        )
                        .font(.subheadline)
                        Divider()
                        Button {
                            dismiss()
                            onOpenSettings()
                        } label: {
                            HStack {
                                Label("Manage phone in Settings", systemImage: "gearshape")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    Link(destination: CaseroClient.baseURL) {
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

    private func infoHeading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }
}
