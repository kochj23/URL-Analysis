//
//  NetworkInterceptor.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//
//  Custom URLProtocol for intercepting and timing network requests
//

import Foundation

/// Custom URLProtocol that intercepts all network requests to capture timing data
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

        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // Start timing
        state.dnsStart = Date()

        // Create and start data task
        dataTask = session.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
    }

}

// MARK: - URLSessionTaskDelegate

extension NetworkInterceptor: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            // Complete the request state
            requestState?.responseEnd = Date()

            if let resource = requestState?.toResource() {
                Task { @MainActor in
                    NetworkInterceptor.sharedMonitor?.addResource(resource)
                }
            }

            client?.urlProtocolDidFinishLoading(self)
        }
    }
}

// MARK: - URLSessionDataDelegate

extension NetworkInterceptor: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        requestState?.dnsEnd = Date()
        requestState?.connectStart = Date()
        requestState?.connectEnd = Date()
        requestState?.responseStart = Date()

        // Extract response information
        if let httpResponse = response as? HTTPURLResponse {
            requestState?.statusCode = httpResponse.statusCode
            requestState?.responseHeaders = httpResponse.allHeaderFields.reduce(into: [:]) { result, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    result[key] = value
                }
            }
        }

        requestState?.mimeType = response.mimeType

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        requestState?.responseSize = Int64(receivedData.count)
        requestState?.responseBody = receivedData

        client?.urlProtocol(self, didLoad: data)
    }
}
