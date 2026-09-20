import SwiftUI

/// Thin wrapper around `UIActivityViewController`, used to hand an exported
/// file (CSV/PDF) to Mail, Files, AirDrop, etc.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
