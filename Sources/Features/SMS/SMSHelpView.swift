import MessageUI
import SwiftUI

/// SMS/USSD reporting tab. Offline fallback for when the portal is unreachable.
struct SMSHelpView: View {
    @State private var passport = ""
    @State private var isComposing = false
    @State private var composeResult: MessageComposeResult?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("This channel does not need internet — it uses your carrier's SMS/USSD network.", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("How it works") {
                    Text(
                        """
                        1. Enter the guest's passport or identity number below.
                        2. Tap "Prepare message" to open a pre-filled SMS to the reporting \
                        short number.
                        3. Review the message and tap Send — iOS never sends SMS silently, \
                        you must confirm it yourself.
                        4. USSD codes containing `*` or `#` cannot be auto-dialed by iOS; \
                        if shown, dial them manually from the Phone app.
                        """
                    )
                    .font(.subheadline)
                }

                Section("Report a guest") {
                    TextField("Passport / identity number", text: $passport)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    if !MessageComposeView.canSendText {
                        Label("This device can't send SMS.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else {
                        Button("Prepare message") {
                            isComposing = true
                        }
                        .disabled(passport.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if let composeResult {
                    Section {
                        Text(resultText(composeResult))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("The exact SMS/USSD report format used by CIDP-MININT is not yet confirmed in this app. The message below is a placeholder — verify it against the official channel before relying on it.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .navigationTitle("SMS / USSD")
            .sheet(isPresented: $isComposing) {
                MessageComposeView(
                    recipients: [USSDSMSReporter.smsDestination],
                    body: USSDSMSReporter.reportBody(passport: passport.trimmingCharacters(in: .whitespaces)),
                    onFinish: { result in
                        composeResult = result
                        isComposing = false
                    },
                )
            }
        }
    }

    private func resultText(_ result: MessageComposeResult) -> String {
        switch result {
        case .sent: return "Message sent."
        case .cancelled: return "Message cancelled."
        case .failed: return "Message failed to send."
        @unknown default: return "Unknown result."
        }
    }
}
