//
//  WebView.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI
import WebKit

/// SwiftUI wrapper for WKWebView with network monitoring
struct WebView: NSViewRepresentable {
    @Binding var url: String
    @ObservedObject var networkMonitor: NetworkMonitor

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Enable developer extras for debugging
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Set the shared monitor for NetworkInterceptor
        NetworkInterceptor.sharedMonitor = networkMonitor

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only load if URL changed and is valid
        if let requestURL = URL(string: url), webView.url?.absoluteString != url {
            let request = URLRequest(url: requestURL)
            webView.load(request)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView

        init(parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                parent.networkMonitor.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                parent.networkMonitor.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                parent.networkMonitor.isLoading = false
            }
            print("Navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                parent.networkMonitor.isLoading = false
            }
            print("Provisional navigation failed: \(error.localizedDescription)")
        }
    }
}
