import MessageUI
import XCTest

@testable import CaseroCu

final class SMSFormatTests: XCTestCase {
    func testForeignGuestUsesPrefixPassportAndStayDays() throws {
        XCTAssertEqual(try USSDSMSReporter.reportBody(passport: " test0001 ", days: "05"), "HCTEST0001 5")
    }

    func testCompanionUsesMainPassportIdentityAndDays() throws {
        XCTAssertEqual(
            try USSDSMSReporter.reportBody(passport: "TEST0001", days: "5", companionIdentity: "00000000000"),
            "HCTEST0001 00000000000 5")
    }

    func testConfirmationUsesHCAndCode() throws {
        XCTAssertEqual(try USSDSMSReporter.confirmationBody(code: "2568"), "HC2568")
        XCTAssertThrowsError(try USSDSMSReporter.confirmationBody(code: "HC2568"))
        XCTAssertThrowsError(try USSDSMSReporter.confirmationBody(code: ""))
    }

    func testInvalidFieldsCannotProduceReport() {
        for days in ["0", "-1", "1.5", "abc", "", "٥"] {
            XCTAssertThrowsError(try USSDSMSReporter.reportBody(passport: "TEST0001", days: days))
        }
        for passport in ["", "TEST 0001", "TEST\n0001", "PÄSS", "TEST*0001"] {
            XCTAssertThrowsError(try USSDSMSReporter.reportBody(passport: passport, days: "5"))
        }
        XCTAssertThrowsError(try USSDSMSReporter.reportBody(passport: "TEST0001", days: "5", companionIdentity: "123"))
        XCTAssertThrowsError(try USSDSMSReporter.reportBody(passport: String(repeating: "T", count: 160), days: "5"))
    }
}

@MainActor
final class SMSFlowTests: XCTestCase {
    func testMainGuestMustBeRegisteredBeforeCompanion() {
        let model = SMSReportViewModel()
        model.kind = .companion
        model.passport = "TEST0001"
        model.days = "5"
        model.companionIdentity = "00000000000"
        XCTAssertNil(model.preview)
        model.mainGuestIsRegistered = true
        XCTAssertEqual(model.preview, "HCTEST0001 00000000000 5")
    }

    func testSendingRequestPreparesConfirmationWithoutClaimingRegistration() throws {
        let model = SMSReportViewModel()
        model.passport = "TEST0001"
        model.days = "5"
        model.prepare(kind: .guest)
        let message = try XCTUnwrap(model.preparedMessage)
        XCTAssertEqual(message.body, "HCTEST0001 5")
        model.finished(.sent, kind: message.kind)
        XCTAssertNil(model.preparedMessage)
        XCTAssertEqual(model.kind, .confirmation)
        XCTAssertNotNil(model.resultMessage)
        XCTAssertNil(model.preview)
        model.confirmationCode = "2568"
        XCTAssertEqual(model.preview, "HC2568")
    }

    func testCancellingDoesNotAdvanceToConfirmationOrLoseInputs() {
        let model = SMSReportViewModel()
        model.passport = "TEST0001"
        model.prepare(kind: .guest)
        model.finished(.cancelled, kind: .guest)
        XCTAssertEqual(model.kind, .guest)
        XCTAssertEqual(model.passport, "TEST0001")
        XCTAssertNotNil(model.resultMessage)
    }

    func testPreparedMessageIsAnImmutableSnapshot() throws {
        let model = SMSReportViewModel()
        model.passport = "TEST0001"
        model.prepare(kind: .guest)
        let message = try XCTUnwrap(model.preparedMessage)
        model.passport = "TEST0002"
        model.days = "7"
        XCTAssertEqual(message.body, "HCTEST0001 1")
    }
}
