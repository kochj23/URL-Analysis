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

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: WebView
        var lastLoadedURL: String = ""

        init(parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                parent.networkMonitor.startNewSession()
                parent.networkMonitor.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            lastLoadedURL = webView.url?.absoluteString ?? ""
            Task { @MainActor in
                parent.networkMonitor.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                parent.networkMonitor.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                parent.networkMonitor.isLoading = false
            }
        }

        // WKScriptMessageHandler - receives messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "performanceMonitor" else { return }
            guard let dataArray = message.body as? [[String: Any]] else { return }

            Task { @MainActor in
                processPerformanceData(dataArray)
            }
        }

        @MainActor
        private func processPerformanceData(_ dataArray: [[String: Any]]) {
            for data in dataArray {
                guard let urlString = data["url"] as? String else { continue }

                // Skip data URLs and already processed resources
                if urlString.hasPrefix("data:") { continue }

                // Check if we already have this resource
                if parent.networkMonitor.resources.contains(where: { $0.url == urlString }) {
                    continue
                }

                // Extract timing data
                let startTime = data["startTime"] as? Double ?? 0
                let duration = data["duration"] as? Double ?? 0
                let transferSize = data["transferSize"] as? Int64 ?? 0
                let domainLookupStart = data["domainLookupStart"] as? Double ?? 0
                let domainLookupEnd = data["domainLookupEnd"] as? Double ?? 0
                let connectStart = data["connectStart"] as? Double ?? 0
                let connectEnd = data["connectEnd"] as? Double ?? 0
                let secureConnectionStart = data["secureConnectionStart"] as? Double ?? 0
                let requestStart = data["requestStart"] as? Double ?? 0
                let responseStart = data["responseStart"] as? Double ?? 0
                let responseEnd = data["responseEnd"] as? Double ?? 0
                let fetchStart = data["fetchStart"] as? Double ?? 0
                let initiatorType = data["initiatorType"] as? String ?? "other"

                // Calculate timing phases (convert ms to seconds)
                let dns = (domainLookupEnd - domainLookupStart) / 1000.0
                let connect = (connectEnd - connectStart) / 1000.0
                let ssl = secureConnectionStart > 0 ? (connectEnd - secureConnectionStart) / 1000.0 : 0
                let wait = (responseStart - requestStart) / 1000.0
                let receive = (responseEnd - responseStart) / 1000.0
                let blocked = (domainLookupStart - fetchStart) / 1000.0

                let timings = ResourceTimings(
                    blocked: max(0, blocked),
                    dns: max(0, dns),
                    connect: max(0, connect),
                    ssl: max(0, ssl),
                    send: 0.001,  // Not available in Resource Timing API
                    wait: max(0, wait),
                    receive: max(0, receive)
                )

                // Determine resource type from initiator
                let resourceType = mapInitiatorToResourceType(initiatorType, url: urlString)

                // Create network resource
                let resource = NetworkResource(
                    id: UUID(),
                    url: urlString,
                    method: "GET",  // Resource Timing API doesn't expose method
                    statusCode: 200,  // Assume success (API doesn't expose status)
                    mimeType: nil,
                    resourceType: resourceType,
                    startTime: parent.networkMonitor.sessionStartTime ?? Date(),
                    timings: timings,
                    requestSize: 0,  // Not available
                    responseSize: transferSize,
                    requestHeaders: [:],  // Not available in Resource Timing API
                    responseHeaders: [:],  // Not available
                    requestBody: nil,
                    responseBody: nil
                )

                parent.networkMonitor.addResource(resource)
            }
        }

        private func mapInitiatorToResourceType(_ initiator: String, url: String) -> NetworkResource.ResourceType {
            let urlLower = url.lowercased()

            switch initiator {
            case "navigation", "link":
                return .document
            case "script":
                return .script
            case "css":
                return .stylesheet
            case "img":
                return .image
            case "xmlhttprequest", "fetch":
                return .xhr
            default:
                // Fallback to URL extension
                if urlLower.hasSuffix(".js") { return .script }
                if urlLower.hasSuffix(".css") { return .stylesheet }
                if urlLower.hasSuffix(".png") || urlLower.hasSuffix(".jpg") || urlLower.hasSuffix(".jpeg") ||
                   urlLower.hasSuffix(".gif") || urlLower.hasSuffix(".webp") || urlLower.hasSuffix(".svg") {
                    return .image
                }
                if urlLower.hasSuffix(".woff") || urlLower.hasSuffix(".woff2") || urlLower.hasSuffix(".ttf") {
                    return .font
                }
                if urlLower.hasSuffix(".mp4") || urlLower.hasSuffix(".webm") || urlLower.hasSuffix(".mp3") {
                    return .media
                }
                return .other
            }
        }
    }

    // JavaScript to monitor network performance using Resource Timing API
    static let performanceMonitorScript = """
    (function() {
        function captureResources() {
            try {
                const resources = performance.getEntriesByType('resource');
                const data = resources.map(r => ({
                    url: r.name,
                    startTime: r.startTime,
                    duration: r.duration,
                    initiatorType: r.initiatorType,
                    transferSize: r.transferSize || 0,
                    encodedBodySize: r.encodedBodySize || 0,
                    decodedBodySize: r.decodedBodySize || 0,
                    domainLookupStart: r.domainLookupStart || 0,
                    domainLookupEnd: r.domainLookupEnd || 0,
                    connectStart: r.connectStart || 0,
                    connectEnd: r.connectEnd || 0,
                    secureConnectionStart: r.secureConnectionStart || 0,
                    requestStart: r.requestStart || 0,
                    responseStart: r.responseStart || 0,
                    responseEnd: r.responseEnd || 0,
                    fetchStart: r.fetchStart || 0
                }));

                if (data.length > 0) {
                    window.webkit.messageHandlers.performanceMonitor.postMessage(data);
                }
            } catch (error) {
                // Silent fail
            }
        }

        // Capture resources after page load
        window.addEventListener('load', function() {
            setTimeout(captureResources, 1000);  // Wait 1 second for all resources
            setTimeout(captureResources, 3000);  // Capture again after 3 seconds for late-loading resources
        });

        // Also capture on demand
        setInterval(captureResources, 5000);  // Update every 5 seconds

        // Initial capture (for already loaded pages)
        if (document.readyState === 'complete') {
            setTimeout(captureResources, 500);
        }
    })();
    """

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Enable developer extras for debugging
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Add message handler for performance data
        config.userContentController.add(context.coordinator, name: "performanceMonitor")

        // Inject JavaScript to capture network timing
        let script = WKUserScript(
            source: Self.performanceMonitorScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Set the shared monitor for NetworkInterceptor
        NetworkInterceptor.sharedMonitor = networkMonitor

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only load if URL changed and hasn't been loaded yet
        // Check against coordinator's lastLoadedURL to prevent reload loops
        if let requestURL = URL(string: url),
           url != context.coordinator.lastLoadedURL,
           !context.coordinator.parent.networkMonitor.isLoading {
            context.coordinator.lastLoadedURL = url
            let request = URLRequest(url: requestURL)
            webView.load(request)
        }
    }
}
