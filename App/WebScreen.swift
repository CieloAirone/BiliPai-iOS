import SwiftUI
import WebKit

struct WebScreen: View {
    let url: URL
    let title: String
    var body: some View { Browser(url: url).navigationTitle(title).navigationBarTitleDisplayMode(.inline) }
}
struct Browser: UIViewRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration(); config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // Use an ephemeral web store; only explicitly imported API cookies persist in Keychain.
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.allowsBackForwardNavigationGestures = true; view.navigationDelegate = context.coordinator
        Task { @MainActor in
            for cookie in HTTPCookieStorage.shared.cookies ?? [] { await view.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) }
            view.load(URLRequest(url: url))
        }
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, ["https","http","about"].contains(url.scheme ?? "") else { decisionHandler(.cancel); return }
            decisionHandler(.allow)
        }
    }
}
