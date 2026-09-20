import Network
import Foundation

/// Tracks whether the device currently has internet connectivity, for the
/// connectivity banner. SMS/USSD reporting doesn't need this — it only needs
/// `MessageComposeView.canSendText` / cellular dialing, checked separately.
@MainActor
final class ConnectivityMonitor: ObservableObject {

    @Published private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.caserocu.ios.connectivity")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
