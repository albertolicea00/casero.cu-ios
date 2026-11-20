import SwiftUI
import WebKit

/// Uses the actual portal form where its JSON contract has not been verified.
/// The web session is ephemeral and receives only this host's session cookies.
struct PortalPageView: View {
    let path: String
    let title: LocalizedStringKey
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var reloadID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            if isLoading { ProgressView().padding().accessibilityLabel("Loading") }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding()
                Button("Retry") {
                    self.errorMessage = nil
                    isLoading = true
                    reloadID = UUID()
                }
            }
            PortalWebView(path: path, errorMessage: $errorMessage, isLoading: $isLoading)
                .id(reloadID)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PortalWebView: UIViewRepresentable {
    let path: String
    @Binding var errorMessage: String?
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        let cookies = HTTPCookieStorage.shared.cookies(for: CaseroClient.baseURL) ?? []
        Task { @MainActor [weak webView] in
            guard let webView else { return }
            for cookie in cookies { await configuration.websiteDataStore.httpCookieStore.setCookie(cookie) }
            guard CertificatePinner.isBundled else {
                errorMessage = PortalError.certificateNotBundled.localizedDescription
                isLoading = false
                return
            }
            webView.load(URLRequest(url: CaseroClient.baseURL.appendingPathComponent(path)))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: PortalWebView
        init(parent: PortalWebView) { self.parent = parent }

        func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let url = navigationAction.request.url
            let allowed = url?.scheme == "https" && url?.host?.lowercased() == "casero.rem.cu"
            decisionHandler(allowed ? .allow : .cancel)
        }

        func webView(
            _ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            let result = CertificatePinner.evaluate(challenge)
            completionHandler(result.0, result.1)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { parent.isLoading = false }

        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
        ) {
            fail(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }

        private func fail(_ error: Error) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            parent.isLoading = false
            parent.errorMessage = PortalError.transportError(for: error).localizedDescription
        }
    }
}
