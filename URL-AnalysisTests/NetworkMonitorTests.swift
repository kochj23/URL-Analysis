//
//  NetworkMonitorTests.swift
//  URL-AnalysisTests
//
//  Unit tests for NetworkMonitor, ResourceFilter, and ResourceTimings
//  Created by Jordan Koch on 2026-05-01
//

import XCTest
@testable import URL_Analysis

final class NetworkMonitorTests: XCTestCase {

    // MARK: - ResourceTimings

    func testResourceTimingsTotal() {
        let timings = ResourceTimings(
            blocked: 0.01,
            dns: 0.05,
            connect: 0.03,
            ssl: 0.02,
            send: 0.001,
            wait: 0.1,
            receive: 0.05
        )
        let expected = 0.01 + 0.05 + 0.03 + 0.02 + 0.001 + 0.1 + 0.05
        XCTAssertEqual(timings.total, expected, accuracy: 0.0001)
    }

    func testResourceTimingsAllZero() {
        let timings = ResourceTimings(
            blocked: 0, dns: 0, connect: 0, ssl: 0,
            send: 0, wait: 0, receive: 0
        )
        XCTAssertEqual(timings.total, 0)
    }

    // MARK: - NetworkResource

    func testNetworkResourceDomain() {
        let resource = makeResource(url: "https://example.com/path/file.js")
        XCTAssertEqual(resource.domain, "example.com")
    }

    func testNetworkResourceDomainEmpty() {
        let resource = makeResource(url: "not-a-url")
        XCTAssertEqual(resource.domain, "")
    }

    func testNetworkResourceTotalDuration() {
        let timings = ResourceTimings(
            blocked: 0.01, dns: 0.02, connect: 0.03,
            ssl: 0.04, send: 0.05, wait: 0.06, receive: 0.07
        )
        let resource = makeResource(timings: timings)
        XCTAssertEqual(resource.totalDuration, timings.total)
    }

    // MARK: - ResourceFilter

    func testFilterMatchesAllTypes() {
        var filter = ResourceFilter()
        let resource = makeResource(resourceType: .script)
        XCTAssertTrue(filter.matches(resource))
    }

    func testFilterExcludesType() {
        var filter = ResourceFilter()
        filter.types = [.image, .stylesheet]
        let resource = makeResource(resourceType: .script)
        XCTAssertFalse(filter.matches(resource))
    }

    func testFilterByDomain() {
        var filter = ResourceFilter()
        filter.domains = Set(["example.com"])
        let matched = makeResource(url: "https://example.com/app.js")
        let excluded = makeResource(url: "https://other.com/app.js")
        XCTAssertTrue(filter.matches(matched))
        XCTAssertFalse(filter.matches(excluded))
    }

    func testFilterByMinSize() {
        var filter = ResourceFilter()
        filter.minSize = 1000
        let small = makeResource(responseSize: 500)
        let big = makeResource(responseSize: 2000)
        XCTAssertFalse(filter.matches(small))
        XCTAssertTrue(filter.matches(big))
    }

    func testFilterByMaxSize() {
        var filter = ResourceFilter()
        filter.maxSize = 1000
        let small = makeResource(responseSize: 500)
        let big = makeResource(responseSize: 2000)
        XCTAssertTrue(filter.matches(small))
        XCTAssertFalse(filter.matches(big))
    }

    func testFilterBySearchText() {
        var filter = ResourceFilter()
        filter.searchText = "analytics"
        let matched = makeResource(url: "https://example.com/analytics.js")
        let excluded = makeResource(url: "https://example.com/app.js")
        XCTAssertTrue(filter.matches(matched))
        XCTAssertFalse(filter.matches(excluded))
    }

    func testFilterSearchTextCaseInsensitive() {
        var filter = ResourceFilter()
        filter.searchText = "ANALYTICS"
        let resource = makeResource(url: "https://example.com/analytics.js")
        XCTAssertTrue(filter.matches(resource))
    }

    func testFilterEmptyDomainSetMatchesAll() {
        var filter = ResourceFilter()
        filter.domains = []
        let resource = makeResource(url: "https://any-domain.com/file.js")
        XCTAssertTrue(filter.matches(resource))
    }

    func testFilterByDuration() {
        var filter = ResourceFilter()
        filter.minDuration = 0.5
        filter.maxDuration = 2.0

        let timingsFast = ResourceTimings(blocked: 0, dns: 0, connect: 0, ssl: 0, send: 0, wait: 0.1, receive: 0.1)
        let timingsMid = ResourceTimings(blocked: 0, dns: 0, connect: 0, ssl: 0, send: 0, wait: 0.5, receive: 0.5)
        let timingsSlow = ResourceTimings(blocked: 0, dns: 0, connect: 0, ssl: 0, send: 0, wait: 2.0, receive: 1.0)

        XCTAssertFalse(filter.matches(makeResource(timings: timingsFast)))
        XCTAssertTrue(filter.matches(makeResource(timings: timingsMid)))
        XCTAssertFalse(filter.matches(makeResource(timings: timingsSlow)))
    }

    // MARK: - NetworkThrottle

    func testNoThrottleUnlimited() {
        XCTAssertEqual(NetworkThrottle.none.downloadSpeed, 0)
        XCTAssertEqual(NetworkThrottle.none.latency, 0)
    }

    func testSlow3GValues() {
        XCTAssertEqual(NetworkThrottle.slow3G.downloadSpeed, 50_000)
        XCTAssertEqual(NetworkThrottle.slow3G.latency, 0.4)
    }

    func testUploadSpeedIsHalfDownload() {
        for throttle in NetworkThrottle.allCases {
            XCTAssertEqual(throttle.uploadSpeed, throttle.downloadSpeed / 2,
                           "\(throttle) upload speed should be half download speed")
        }
    }

    // MARK: - NetworkRequestState

    func testDetermineResourceTypeByMime() {
        let state = NetworkRequestState(url: "https://example.com/file", method: "GET")
        state.mimeType = "text/html"
        state.responseEnd = Date()
        let resource = state.toResource()
        XCTAssertEqual(resource?.resourceType, .document)
    }

    func testDetermineResourceTypeByMimeCSS() {
        let state = NetworkRequestState(url: "https://example.com/file", method: "GET")
        state.mimeType = "text/css"
        state.responseEnd = Date()
        let resource = state.toResource()
        XCTAssertEqual(resource?.resourceType, .stylesheet)
    }

    func testDetermineResourceTypeByMimeJS() {
        let state = NetworkRequestState(url: "https://example.com/file", method: "GET")
        state.mimeType = "application/javascript"
        state.responseEnd = Date()
        let resource = state.toResource()
        XCTAssertEqual(resource?.resourceType, .script)
    }

    func testDetermineResourceTypeByMimeImage() {
        let state = NetworkRequestState(url: "https://example.com/file", method: "GET")
        state.mimeType = "image/png"
        state.responseEnd = Date()
        let resource = state.toResource()
        XCTAssertEqual(resource?.resourceType, .image)
    }

    func testDetermineResourceTypeByMimeFont() {
        let state = NetworkRequestState(url: "https://example.com/file", method: "GET")
        state.mimeType = "font/woff2"
        state.responseEnd = Date()
        let resource = state.toResource()
        XCTAssertEqual(resource?.resourceType, .font)
    }

    func testDetermineResourceTypeByURLExtension() {
        let state = NetworkRequestState(url: "https://example.com/script.js", method: "GET")
        state.responseEnd = Date()
        let resource = state.toResource()
        XCTAssertEqual(resource?.resourceType, .script)
    }

    func testDetermineResourceTypeByURLExtensionCSS() {
        let state = NetworkRequestState(url: "https://example.com/style.css", method: "GET")
        state.responseEnd = Date()
        let resource = state.toResource()
        XCTAssertEqual(resource?.resourceType, .stylesheet)
    }

    func testDetermineResourceTypeByURLExtensionImage() {
        let state = NetworkRequestState(url: "https://example.com/photo.webp", method: "GET")
        state.responseEnd = Date()
        let resource = state.toResource()
        XCTAssertEqual(resource?.resourceType, .image)
    }

    func testRequestStateReturnsNilWithoutResponseEnd() {
        let state = NetworkRequestState(url: "https://example.com/file", method: "GET")
        state.mimeType = "text/html"
        // responseEnd never set
        XCTAssertNil(state.toResource())
    }

    // MARK: - HAR Format

    func testHARTimingsCodable() throws {
        let timings = HARTimings(blocked: 10, dns: 20, connect: 30, ssl: 40, send: 5, wait: 100, receive: 50)
        let data = try JSONEncoder().encode(timings)
        let decoded = try JSONDecoder().decode(HARTimings.self, from: data)
        XCTAssertEqual(decoded.blocked, 10)
        XCTAssertEqual(decoded.dns, 20)
        XCTAssertEqual(decoded.wait, 100)
    }

    func testHARFileCodable() throws {
        let har = HARFile(log: HARLog(
            version: "1.2",
            creator: HARCreator(name: "URL Analysis", version: "1.0.0"),
            pages: [],
            entries: []
        ))
        let data = try JSONEncoder().encode(har)
        let decoded = try JSONDecoder().decode(HARFile.self, from: data)
        XCTAssertEqual(decoded.log.version, "1.2")
        XCTAssertEqual(decoded.log.creator.name, "URL Analysis")
    }

    // MARK: - Helpers

    private func makeResource(
        url: String = "https://example.com/file",
        method: String = "GET",
        statusCode: Int = 200,
        mimeType: String? = "text/html",
        resourceType: NetworkResource.ResourceType = .document,
        timings: ResourceTimings? = nil,
        responseSize: Int64 = 1024,
        requestHeaders: [String: String] = [:],
        responseHeaders: [String: String] = [:]
    ) -> NetworkResource {
        let defaultTimings = timings ?? ResourceTimings(
            blocked: 0.01, dns: 0.02, connect: 0.03,
            ssl: 0.02, send: 0.001, wait: 0.05, receive: 0.01
        )
        return NetworkResource(
            id: UUID(),
            url: url,
            method: method,
            statusCode: statusCode,
            mimeType: mimeType,
            resourceType: resourceType,
            startTime: Date(),
            timings: defaultTimings,
            requestSize: 256,
            responseSize: responseSize,
            requestHeaders: requestHeaders,
            responseHeaders: responseHeaders,
            requestBody: nil,
            responseBody: nil
        )
    }
}
