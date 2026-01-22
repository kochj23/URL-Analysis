//
//  HeadlessAnalyzer.swift
//  URL Analysis
//
//  Headless web page analyzer for CLI and automation
//  Created by Jordan Koch on 2026-01-22
//

import Foundation
import WebKit

/// Headless analyzer for command-line and automation use
@MainActor
class HeadlessAnalyzer {
    private var webView: WKWebView?
    private var monitor: NetworkMonitor?
    private var continuation: CheckedContinuation<AnalysisResult, Error>?

    /// Result structure for headless analysis
    struct AnalysisResult: Codable {
        let url: String
        let timestamp: Date
        let resources: [NetworkResource]
        let webVitals: WebVitals?
        let performanceScore: PerformanceScore?
        let loadTime: TimeInterval
        let totalSize: Int64
        let requestCount: Int
        let deviceProfile: DeviceProfile?
    }

    enum AnalysisError: Error, LocalizedError {
        case timeout
        case invalidURL
        case loadFailed(String)

        var errorDescription: String? {
            switch self {
            case .timeout:
                return "Analysis timed out"
            case .invalidURL:
                return "Invalid URL provided"
            case .loadFailed(let msg):
                return "Load failed: \(msg)"
            }
        }
    }

    /// Analyze a URL in headless mode
    func analyze(
        url: String,
        device: DeviceProfile? = nil,
        timeout: TimeInterval = 30
    ) async throws -> AnalysisResult {
        guard let requestURL = URL(string: url), !url.isEmpty else {
            throw AnalysisError.invalidURL
        }

        // Setup network monitor
        monitor = NetworkMonitor()

        // Setup WKWebView configuration
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Create coordinator for message handling
        let coordinator = Coordinator(monitor: monitor!)
        config.userContentController.add(coordinator, name: "performanceMonitor")
        config.userContentController.add(coordinator, name: "webVitals")

        // Inject performance monitoring scripts
        let perfScript = WKUserScript(
            source: WebView.performanceMonitorScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(perfScript)

        let vitalsScript = WKUserScript(
            source: WebView.webVitalsScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(vitalsScript)

        // Create WebView
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = coordinator
        coordinator.webView = webView

        // Apply device emulation if specified
        if let device = device {
            webView?.customUserAgent = device.userAgent
        }

        // Start analysis with timeout
        return try await withTimeout(timeout) {
            try await performAnalysis(url: requestURL, coordinator: coordinator)
        }
    }

    private func performAnalysis(url: URL, coordinator: Coordinator) async throws -> AnalysisResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            coordinator.continuation = continuation

            // Load URL
            let request = URLRequest(url: url)
            webView?.load(request)

            // Monitor will call continuation when complete
        }
    }

    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Main operation
            group.addTask {
                try await operation()
            }

            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw AnalysisError.timeout
            }

            // Return first to complete
            let result = try await group.next()!

            // Cancel remaining tasks
            group.cancelAll()

            return result
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let monitor: NetworkMonitor
        weak var webView: WKWebView?
        var continuation: CheckedContinuation<AnalysisResult, Error>?
        var loadStartTime: Date?
        var lastResourceCount = 0
        var stableCheckTimer: Timer?

        init(monitor: NetworkMonitor) {
            self.monitor = monitor
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            loadStartTime = Date()
            monitor.startNewSession()
            monitor.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Wait for resources to stabilize (no new resources for 2 seconds)
            stableCheckTimer?.invalidate()
            checkForCompletion()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            continuation?.resume(throwing: AnalysisError.loadFailed(error.localizedDescription))
            continuation = nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            Task { @MainActor in
                if message.name == "performanceMonitor" {
                    handlePerformanceData(message.body)
                } else if message.name == "webVitals" {
                    handleWebVitalsData(message.body)
                }

                // Check if analysis is complete
                checkForCompletion()
            }
        }

        private func handlePerformanceData(_ body: Any) {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
                  let resources = try? JSONDecoder().decode([WebResourceTiming].self, from: jsonData) else {
                return
            }

            for timing in resources {
                let resource = NetworkResource.from(timing)
                if !monitor.resources.contains(where: { $0.url == resource.url }) {
                    monitor.addResource(resource)
                }
            }
        }

        private func handleWebVitalsData(_ body: Any) {
            guard let dict = body as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                  let webVitals = try? JSONDecoder().decode(WebVitals.self, from: jsonData) else {
                return
            }

            monitor.updateWebVitals(webVitals)
        }

        @objc private func checkForCompletion() {
            let currentCount = monitor.resources.count

            // Wait for resources to stabilize
            if currentCount == lastResourceCount && currentCount > 0 {
                // Stable for 2 seconds - complete analysis
                completeAnalysis()
            } else {
                // Resources still changing - check again in 2s
                lastResourceCount = currentCount
                stableCheckTimer?.invalidate()
                stableCheckTimer = Timer.scheduledTimer(
                    timeInterval: 2.0,
                    target: self,
                    selector: #selector(checkForCompletion),
                    userInfo: nil,
                    repeats: false
                )
            }
        }

        private func completeAnalysis() {
            guard let continuation = continuation else { return }
            self.continuation = nil

            monitor.isLoading = false

            let result = AnalysisResult(
                url: webView?.url?.absoluteString ?? "",
                timestamp: Date(),
                resources: monitor.resources,
                webVitals: monitor.webVitals,
                performanceScore: monitor.performanceScore,
                loadTime: monitor.totalDuration,
                totalSize: monitor.totalSize,
                requestCount: monitor.resources.count,
                deviceProfile: nil
            )

            continuation.resume(returning: result)
        }
    }
}

/// Web resource timing from JavaScript (for decoding)
struct WebResourceTiming: Codable {
    let name: String
    let startTime: Double
    let duration: Double
    let initiatorType: String
    let transferSize: Double
    let encodedBodySize: Double
    let decodedBodySize: Double
    let domainLookupStart: Double
    let domainLookupEnd: Double
    let connectStart: Double
    let connectEnd: Double
    let secureConnectionStart: Double
    let requestStart: Double
    let responseStart: Double
    let responseEnd: Double
    let fetchStart: Double
}

extension NetworkResource {
    /// Create NetworkResource from JavaScript Resource Timing
    static func from(_ timing: WebResourceTiming) -> NetworkResource {
        let timings = ResourceTimings(
            blocked: timing.fetchStart,
            dns: max(timing.domainLookupEnd - timing.domainLookupStart, 0) / 1000.0,
            connect: max(timing.connectEnd - timing.connectStart, 0) / 1000.0,
            ssl: timing.secureConnectionStart > 0 ? max(timing.connectEnd - timing.secureConnectionStart, 0) / 1000.0 : 0,
            send: max(timing.requestStart - timing.connectEnd, 0) / 1000.0,
            wait: max(timing.responseStart - timing.requestStart, 0) / 1000.0,
            receive: max(timing.responseEnd - timing.responseStart, 0) / 1000.0
        )

        return NetworkResource(
            url: timing.name,
            method: "GET",
            statusCode: 200,
            mimeType: nil,
            resourceType: ResourceType.from(initiatorType: timing.initiatorType),
            startTime: Date(timeIntervalSinceNow: -timing.duration / 1000.0),
            timings: timings,
            requestSize: 0,
            responseSize: Int64(timing.transferSize),
            requestHeaders: [:],
            responseHeaders: [:],
            requestBody: nil,
            responseBody: nil
        )
    }
}
