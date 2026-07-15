import SwiftUI
import WebKit

/// Port of Android CloudFlareActivity — presents WKWebView until challenge cookies appear.
struct CloudflareBrowserView: View {
    let challengeURL: URL
    var onResolved: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            CloudflareWebView(url: challengeURL, onResolved: onResolved)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Cloudflare")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel"), action: onCancel)
                    }
                }
        }
    }
}

struct CloudflareWebView: UIViewRepresentable {
    let url: URL
    var onResolved: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResolved: onResolved) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onResolved: () -> Void
        private var settled = false

        init(onResolved: @escaping () -> Void) {
            self.onResolved = onResolved
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Heuristic: title no longer "Just a moment" / challenge cleared
            let title = webView.title?.lowercased() ?? ""
            if !title.contains("just a moment") && !title.contains("attention required") && !settled {
                settled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.onResolved()
                }
            }
        }
    }
}
