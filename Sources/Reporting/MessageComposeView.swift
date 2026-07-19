import MessageUI
import SwiftUI

/// SwiftUI wrapper around `MFMessageComposeViewController`. iOS requires the user
/// to tap Send; the app only pre-fills recipient and body.
struct MessageComposeView: UIViewControllerRepresentable {

    let recipients: [String]
    let body: String
    var onFinish: (MessageComposeResult) -> Void = { _ in }

    static var canSendText: Bool { MFMessageComposeViewController.canSendText() }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let onFinish: (MessageComposeResult) -> Void

        init(onFinish: @escaping (MessageComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult,
        ) {
            controller.dismiss(animated: true)
            onFinish(result)
        }
    }
}
