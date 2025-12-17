//
//  NetworkMonitor.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// Represents a network resource with detailed timing information
struct NetworkResource: Identifiable, Codable {
    let id: UUID
    let url: String
    let method: String
    let statusCode: Int
    let mimeType: String?
    let resourceType: ResourceType

    // Timing information (HAR-compatible)
    let startTime: Date
    let timings: ResourceTimings

    // Sizes
    let requestSize: Int64
    let responseSize: Int64

    // Headers
    let requestHeaders: [String: String]
    let responseHeaders: [String: String]

    // Request/Response data
    let requestBody: Data?
    let responseBody: Data?

    enum ResourceType: String, Codable, CaseIterable {
        case document = "Document"
        case stylesheet = "Stylesheet"
        case script = "Script"
        case image = "Image"
        case font = "Font"
        case xhr = "XHR"
        case fetch = "Fetch"
        case websocket = "WebSocket"
        case media = "Media"
        case other = "Other"
    }

    var totalDuration: TimeInterval {
        return timings.total
    }

    var domain: String {
        guard let url = URL(string: url) else { return "" }
        return url.host ?? ""
    }
}

/// HAR-compatible timing structure
struct ResourceTimings: Codable {
    let blocked: TimeInterval  // Time spent in queue
    let dns: TimeInterval      // DNS resolution time
    let connect: TimeInterval  // TCP connection time
    let ssl: TimeInterval      // SSL/TLS negotiation time
    let send: TimeInterval     // Time to send request
    let wait: TimeInterval     // TTFB - Time To First Byte
    let receive: TimeInterval  // Time to download response

    var total: TimeInterval {
        return blocked + dns + connect + ssl + send + wait + receive
    }
}

/// Filter options for waterfall view
struct ResourceFilter {
    var types: Set<NetworkResource.ResourceType> = Set(NetworkResource.ResourceType.allCases)
    var domains: Set<String> = []
    var minSize: Int64 = 0
    var maxSize: Int64 = .max
    var minDuration: TimeInterval = 0
    var maxDuration: TimeInterval = .infinity
    var searchText: String = ""

    func matches(_ resource: NetworkResource) -> Bool {
        // Type filter
        guard types.contains(resource.resourceType) else { return false }

        // Domain filter
        if !domains.isEmpty && !domains.contains(resource.domain) {
            return false
        }

        // Size filter
        if resource.responseSize < minSize || resource.responseSize > maxSize {
            return false
        }

        // Duration filter
        if resource.totalDuration < minDuration || resource.totalDuration > maxDuration {
            return false
        }

        // Search text
        if !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            return resource.url.lowercased().contains(lowercased)
        }

        return true
    }
}

/// Network throttling presets
enum NetworkThrottle: String, CaseIterable {
    case none = "No Throttling"
    case slow3G = "Slow 3G (400 Kbps)"
    case fast3G = "Fast 3G (1.6 Mbps)"
    case slow4G = "Slow 4G (3 Mbps)"
    case fast4G = "Fast 4G (10 Mbps)"
    case custom = "Custom"

    var downloadSpeed: Int64 {
        switch self {
        case .none: return 0  // Unlimited
        case .slow3G: return 50_000  // 400 Kbps / 8
        case .fast3G: return 200_000  // 1.6 Mbps / 8
        case .slow4G: return 375_000  // 3 Mbps / 8
        case .fast4G: return 1_250_000  // 10 Mbps / 8
        case .custom: return 0
        }
    }

    var uploadSpeed: Int64 {
        return downloadSpeed / 2  // Upload typically slower
    }

    var latency: TimeInterval {
        switch self {
        case .none: return 0
        case .slow3G: return 0.4
        case .fast3G: return 0.2
        case .slow4G: return 0.15
        case .fast4G: return 0.05
        case .custom: return 0
        }
    }
}

/// Main network monitoring class
@MainActor
class NetworkMonitor: ObservableObject {
    @Published var resources: [NetworkResource] = []
    @Published var filter = ResourceFilter()
    @Published var throttle: NetworkThrottle = .none
    @Published var isLoading = false
    @Published var sessionStartTime: Date?
    @Published var webVitals: WebVitals?
    @Published var performanceScore: PerformanceScore?

    private var activeRequests: [UUID: NetworkRequestState] = [:]

    var filteredResources: [NetworkResource] {
        return resources.filter { filter.matches($0) }
    }

    var totalSize: Int64 {
        return resources.reduce(0) { $0 + $1.responseSize }
    }

    var totalDuration: TimeInterval {
        guard let first = resources.first, let last = resources.last else { return 0 }
        return last.startTime.timeIntervalSince(first.startTime) + last.totalDuration
    }

    var domains: Set<String> {
        return Set(resources.map { $0.domain })
    }

    func startNewSession() {
        resources.removeAll()
        activeRequests.removeAll()
        sessionStartTime = Date()
        isLoading = true
    }

    func addResource(_ resource: NetworkResource) {
        resources.append(resource)
        updatePerformanceScore()
    }

    func updateWebVitals(_ vitals: WebVitals) {
        webVitals = vitals
        updatePerformanceScore()
    }

    private func updatePerformanceScore() {
        // Only calculate if we have resources
        if !resources.isEmpty {
            performanceScore = PerformanceScore.calculate(from: self, webVitals: webVitals)
        }
    }

    func clearResources() {
        resources.removeAll()
        activeRequests.removeAll()
        sessionStartTime = nil
        isLoading = false
        webVitals = nil
        performanceScore = nil
    }

    func exportHAR(to url: URL) {
        let har = generateHAR()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(har)
            try data.write(to: url)
        } catch {
            print("Failed to export HAR: \(error)")
        }
    }

    private func generateHAR() -> HARFile {
        return HARFile(
            log: HARLog(
                version: "1.2",
                creator: HARCreator(name: "URL Analysis", version: "1.0.0"),
                pages: [
                    HARPage(
                        startedDateTime: sessionStartTime ?? Date(),
                        id: "page_1",
                        title: "Network Analysis",
                        pageTimings: HARPageTimings(
                            onContentLoad: totalDuration,
                            onLoad: totalDuration
                        )
                    )
                ],
                entries: resources.map { resource in
                    HAREntry(
                        startedDateTime: resource.startTime,
                        time: resource.totalDuration * 1000,  // Convert to ms
                        request: HARRequest(
                            method: resource.method,
                            url: resource.url,
                            httpVersion: "HTTP/1.1",
                            headers: resource.requestHeaders.map { HARHeader(name: $0.key, value: $0.value) },
                            queryString: [],
                            headersSize: resource.requestSize,
                            bodySize: resource.requestSize
                        ),
                        response: HARResponse(
                            status: resource.statusCode,
                            statusText: HTTPURLResponse.localizedString(forStatusCode: resource.statusCode),
                            httpVersion: "HTTP/1.1",
                            headers: resource.responseHeaders.map { HARHeader(name: $0.key, value: $0.value) },
                            content: HARContent(
                                size: resource.responseSize,
                                mimeType: resource.mimeType ?? "application/octet-stream"
                            ),
                            redirectURL: "",
                            headersSize: -1,
                            bodySize: resource.responseSize
                        ),
                        cache: HARCache(),
                        timings: HARTimings(
                            blocked: resource.timings.blocked * 1000,
                            dns: resource.timings.dns * 1000,
                            connect: resource.timings.connect * 1000,
                            ssl: resource.timings.ssl * 1000,
                            send: resource.timings.send * 1000,
                            wait: resource.timings.wait * 1000,
                            receive: resource.timings.receive * 1000
                        ),
                        pageref: "page_1"
                    )
                }
            )
        )
    }
}

// MARK: - Internal Request State Tracking

class NetworkRequestState {
    let id: UUID
    let url: String
    let method: String
    var startTime: Date
    var requestHeaders: [String: String] = [:]
    var requestBody: Data?
    var requestSize: Int64 = 0

    var dnsStart: Date?
    var dnsEnd: Date?
    var connectStart: Date?
    var connectEnd: Date?
    var sslStart: Date?
    var sslEnd: Date?
    var requestSentStart: Date?
    var requestSentEnd: Date?
    var responseStart: Date?
    var responseEnd: Date?

    var statusCode: Int = 0
    var responseHeaders: [String: String] = [:]
    var responseBody: Data?
    var responseSize: Int64 = 0
    var mimeType: String?

    init(id: UUID = UUID(), url: String, method: String) {
        self.id = id
        self.url = url
        self.method = method
        self.startTime = Date()
    }

    func toResource() -> NetworkResource? {
        guard let responseEnd = responseEnd else { return nil }

        let timings = ResourceTimings(
            blocked: dnsStart?.timeIntervalSince(startTime) ?? 0,
            dns: (dnsEnd?.timeIntervalSince(dnsStart ?? startTime)) ?? 0,
            connect: (connectEnd?.timeIntervalSince(connectStart ?? startTime)) ?? 0,
            ssl: (sslEnd?.timeIntervalSince(sslStart ?? startTime)) ?? 0,
            send: (requestSentEnd?.timeIntervalSince(requestSentStart ?? startTime)) ?? 0.001,
            wait: (responseStart?.timeIntervalSince(requestSentEnd ?? startTime)) ?? 0.001,
            receive: responseEnd.timeIntervalSince(responseStart ?? startTime)
        )

        return NetworkResource(
            id: id,
            url: url,
            method: method,
            statusCode: statusCode,
            mimeType: mimeType,
            resourceType: determineResourceType(),
            startTime: startTime,
            timings: timings,
            requestSize: requestSize,
            responseSize: responseSize,
            requestHeaders: requestHeaders,
            responseHeaders: responseHeaders,
            requestBody: requestBody,
            responseBody: responseBody
        )
    }

    private func determineResourceType() -> NetworkResource.ResourceType {
        guard let mimeType = mimeType?.lowercased() else {
            // Fallback to URL extension
            let urlStr = url.lowercased()
            if urlStr.hasSuffix(".js") { return .script }
            if urlStr.hasSuffix(".css") { return .stylesheet }
            if urlStr.hasSuffix(".png") || urlStr.hasSuffix(".jpg") || urlStr.hasSuffix(".gif") || urlStr.hasSuffix(".webp") {
                return .image
            }
            return .other
        }

        if mimeType.contains("html") { return .document }
        if mimeType.contains("css") { return .stylesheet }
        if mimeType.contains("javascript") || mimeType.contains("ecmascript") { return .script }
        if mimeType.contains("image") { return .image }
        if mimeType.contains("font") || mimeType.contains("woff") { return .font }
        if mimeType.contains("json") || mimeType.contains("xml") { return .xhr }
        if mimeType.contains("video") || mimeType.contains("audio") { return .media }

        return .other
    }
}
