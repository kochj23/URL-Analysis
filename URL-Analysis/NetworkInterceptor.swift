//
//  NetworkInterceptor.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//
//  NOTE: This URLProtocol approach does NOT work with WKWebView.
//  WKWebView uses its own networking stack and bypasses URLProtocol.
//  Network monitoring is now handled via JavaScript Resource Timing API in WebView.swift.
//  This file is kept for reference and potential future use with URLSession-based networking.
//

import Foundation

/// Custom URLProtocol that intercepts all network requests to capture timing data
/// WARNING: Not used by WKWebView - see note above
class NetworkInterceptor: URLProtocol {
    private static let requestStateKey = "URLAnalysisRequestState"
    private var dataTask: URLSessionDataTask?
    private var receivedData = Data()
    private var requestState: NetworkRequestState?

    // Shared monitor instance (set by NetworkMonitor)
    static weak var sharedMonitor: NetworkMonitor?

    override class func canInit(with request: URLRequest) -> Bool {
        // Only intercept HTTP/HTTPS requests
        guard let scheme = request.url?.scheme else { return false }
        guard scheme == "http" || scheme == "https" else { return false }

        // Don't intercept requests we've already handled
        guard property(forKey: requestStateKey, in: request) == nil else { return false }

        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // This URLProtocol is not used with WKWebView
        // WKWebView has its own networking stack
        // Network monitoring is handled via JavaScript Performance API
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
    }

}

// MARK: - Memory Safety Notes
//
// This implementation uses completion handlers instead of URLSession delegates
// to prevent retain cycles. The pattern [weak self] in the completion handler
// ensures that NetworkInterceptor instances can be deallocated properly.
//
// Previous implementation had: self → dataTask → session → delegate (self) ♻️
// Current implementation breaks the cycle by removing the delegate reference.
