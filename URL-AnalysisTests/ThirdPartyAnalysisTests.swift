//
//  ThirdPartyAnalysisTests.swift
//  URL-AnalysisTests
//
//  Unit tests for third-party provider identification and analysis
//  Created by Jordan Koch on 2026-05-01
//

import XCTest
@testable import URL_Analysis

final class ThirdPartyAnalysisTests: XCTestCase {

    // MARK: - Provider Identification

    func testIdentifyGoogleAnalytics() {
        let provider = ThirdPartyProvider.identify(domain: "google-analytics.com")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.name, "Google Analytics")
        XCTAssertEqual(provider?.category, .analytics)
    }

    func testIdentifyCloudflare() {
        let provider = ThirdPartyProvider.identify(domain: "cloudflare.com")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.name, "Cloudflare")
        XCTAssertEqual(provider?.category, .cdn)
    }

    func testIdentifyGoogleFonts() {
        let provider = ThirdPartyProvider.identify(domain: "fonts.googleapis.com")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.name, "Google Fonts")
        XCTAssertEqual(provider?.category, .fonts)
    }

    func testIdentifyFacebook() {
        let provider = ThirdPartyProvider.identify(domain: "connect.facebook.net")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.category, .socialMedia)
    }

    func testIdentifyStripe() {
        let provider = ThirdPartyProvider.identify(domain: "stripe.com")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.name, "Stripe")
    }

    func testIdentifyYouTube() {
        let provider = ThirdPartyProvider.identify(domain: "youtube.com")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.category, .video)
    }

    func testIdentifyGoogleMaps() {
        let provider = ThirdPartyProvider.identify(domain: "maps.googleapis.com")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.category, .maps)
    }

    func testIdentifySubdomain() {
        // "www.google-analytics.com" should match via suffix
        let provider = ThirdPartyProvider.identify(domain: "www.google-analytics.com")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.name, "Google Analytics")
    }

    func testIdentifyUnknownDomain() {
        let provider = ThirdPartyProvider.identify(domain: "my-custom-api.example.com")
        XCTAssertNil(provider)
    }

    func testIdentifyGoogleTagManager() {
        let provider = ThirdPartyProvider.identify(domain: "googletagmanager.com")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.category, .tagManagement)
    }

    // MARK: - ThirdPartyDomain Impact

    func testHighImpactByDuration() {
        let resources = [makeResource(totalDuration: 2.5)]
        let domain = ThirdPartyDomain(domain: "slow.com", provider: nil, resources: resources)
        XCTAssertEqual(domain.impact, .high)
    }

    func testHighImpactBySize() {
        let resources = [makeResource(responseSize: 2_000_000)]  // 2 MB
        let domain = ThirdPartyDomain(domain: "heavy.com", provider: nil, resources: resources)
        XCTAssertEqual(domain.impact, .high)
    }

    func testMediumImpact() {
        let resources = [makeResource(totalDuration: 1.5, responseSize: 600_000)]
        let domain = ThirdPartyDomain(domain: "medium.com", provider: nil, resources: resources)
        XCTAssertEqual(domain.impact, .medium)
    }

    func testLowImpact() {
        let resources = [makeResource(totalDuration: 0.2, responseSize: 10_000)]
        let domain = ThirdPartyDomain(domain: "fast.com", provider: nil, resources: resources)
        XCTAssertEqual(domain.impact, .low)
    }

    func testDomainTotalSize() {
        let resources = [
            makeResource(responseSize: 1000),
            makeResource(responseSize: 2000),
            makeResource(responseSize: 3000)
        ]
        let domain = ThirdPartyDomain(domain: "example.com", provider: nil, resources: resources)
        XCTAssertEqual(domain.totalSize, 6000)
    }

    func testDomainRequestCount() {
        let resources = [
            makeResource(), makeResource(), makeResource()
        ]
        let domain = ThirdPartyDomain(domain: "example.com", provider: nil, resources: resources)
        XCTAssertEqual(domain.requestCount, 3)
    }

    // MARK: - Category Icons

    func testCategoryIcons() {
        XCTAssertEqual(ThirdPartyProvider.Category.analytics.icon, "chart.bar.fill")
        XCTAssertEqual(ThirdPartyProvider.Category.cdn.icon, "network")
        XCTAssertEqual(ThirdPartyProvider.Category.fonts.icon, "textformat")
        XCTAssertEqual(ThirdPartyProvider.Category.maps.icon, "map.fill")
    }

    // MARK: - All Known Providers Covered

    func testAllKnownProvidersHaveCategories() {
        for (domain, provider) in ThirdPartyProvider.providers {
            XCTAssertFalse(provider.name.isEmpty, "\(domain) has empty name")
            XCTAssertFalse(provider.description.isEmpty, "\(domain) has empty description")
        }
    }

    // MARK: - Helpers

    private func makeResource(
        totalDuration: TimeInterval = 0.1,
        responseSize: Int64 = 1024
    ) -> NetworkResource {
        let timings = ResourceTimings(
            blocked: 0, dns: 0, connect: 0, ssl: 0,
            send: 0, wait: totalDuration * 0.8, receive: totalDuration * 0.2
        )
        return NetworkResource(
            id: UUID(),
            url: "https://example.com/file",
            method: "GET",
            statusCode: 200,
            mimeType: "text/html",
            resourceType: .document,
            startTime: Date(),
            timings: timings,
            requestSize: 256,
            responseSize: responseSize,
            requestHeaders: [:],
            responseHeaders: [:],
            requestBody: nil,
            responseBody: nil
        )
    }
}
