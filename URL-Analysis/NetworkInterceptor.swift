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
        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        // Create request state
        let state = NetworkRequestState(
            url: url.absoluteString,
            method: request.httpMethod ?? "GET"
        )
        state.requestHeaders = request.allHTTPHeaderFields ?? [:]
        state.requestBody = request.httpBody
        state.requestSize = Int64(request.httpBody?.count ?? 0)
        self.requestState = state

        // Mark request as handled
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        NetworkInterceptor.setProperty(true, forKey: NetworkInterceptor.requestStateKey, in: mutableRequest)

        // Create session configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300

        // FIX: Use completion handler instead of delegate to avoid retain cycle
        // URLSession with delegate creates: self → dataTask → session → delegate (self) ♻️
        let session = URLSession(configuration: config)

        // Start timing
        state.dnsStart = Date()

        // Create data task with completion handler (breaks retain cycle)
        dataTask = session.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }

            // Handle response
            if let response = response {
                self.requestState?.dnsEnd = Date()
                self.requestState?.connectStart = Date()
                self.requestState?.connectEnd = Date()
                self.requestState?.responseStart = Date()

                if let httpResponse = response as? HTTPURLResponse {
                    self.requestState?.statusCode = httpResponse.statusCode
                    self.requestState?.responseHeaders = httpResponse.allHeaderFields.reduce(into: [:]) { result, pair in
                        if let key = pair.key as? String, let value = pair.value as? String {
                            result[key] = value
                        }
                    }
                }

                self.requestState?.mimeType = response.mimeType
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            }

            // Handle data
            if let data = data {
                self.receivedData = data
                self.requestState?.responseSize = Int64(data.count)
                self.requestState?.responseBody = data
                self.client?.urlProtocol(self, didLoad: data)
            }

            // Complete the request
            self.requestState?.responseEnd = Date()

            if let resource = self.requestState?.toResource() {
                Task { @MainActor in
                    NetworkInterceptor.sharedMonitor?.addResource(resource)
                }
            }

            self.client?.urlProtocolDidFinishLoading(self)
        }

        dataTask?.resume()
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
