import Foundation
import MessageUI

@MainActor
final class SMSReportViewModel: ObservableObject {
    enum Kind: String, CaseIterable, Identifiable {
        case guest = "Foreign guest"
        case companion = "Cuban companion"
        case confirmation = "Confirm received code"
        var id: String { rawValue }
    }

    struct PreparedMessage: Identifiable {
        let id = UUID()
        let body: String
        let kind: Kind
    }

    @Published var kind: Kind = .guest
    @Published var passport = ""
    @Published var companionIdentity = ""
    @Published var days = "1"
    @Published var confirmationCode = ""
    @Published var mainGuestIsRegistered = false
    @Published var preparedMessage: PreparedMessage?
    @Published private(set) var resultMessage: String?

    var preview: String? { try? messageBody() }

    var validationMessage: String? {
        do {
            _ = try messageBody()
            return nil
        } catch { return error.localizedDescription }
    }

    private func messageBody() throws -> String {
        switch kind {
        case .guest:
            return try USSDSMSReporter.reportBody(passport: passport, days: days)
        case .companion:
            let body = try USSDSMSReporter.reportBody(
                passport: passport, days: days, companionIdentity: companionIdentity)
            guard mainGuestIsRegistered else {
                throw PortalError.rejected(
                    String(localized: "Confirm the main guest's registration before reporting a companion."))
            }
            return body
        case .confirmation:
            return try USSDSMSReporter.confirmationBody(code: confirmationCode)
        }
    }

    func prepare() {
        guard let preview else { return }
        resultMessage = nil
        preparedMessage = PreparedMessage(body: preview, kind: kind)
    }

    func finished(_ result: MessageComposeResult, kind sentKind: Kind) {
        preparedMessage = nil
        switch result {
        case .sent:
            if sentKind == .confirmation {
                resultMessage = String(
                    localized:
                        "Confirmation SMS sent. The report is complete only when the service returns a registration code."
                )
            } else {
                resultMessage = String(
                    localized:
                        "Request SMS sent. Wait for the reply, check the name and nationality, then enter the received confirmation code."
                )
                kind = .confirmation
                confirmationCode = ""
            }
        case .cancelled:
            resultMessage = String(localized: "Message cancelled. No report was confirmed.")
        case .failed:
            resultMessage = String(localized: "Message could not be sent. Check cellular service and try again.")
        @unknown default:
            resultMessage = String(localized: "The SMS result is unknown. Check Messages before retrying.")
        }
    }

}
