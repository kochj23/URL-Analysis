//
//  RequestBlockingTests.swift
//  URL-AnalysisTests
//
//  Unit tests for blocking rules and content rule generation
//  Created by Jordan Koch on 2026-05-01
//

import XCTest
@testable import URL_Analysis

final class RequestBlockingTests: XCTestCase {

    // MARK: - Predefined Profiles

    func testAdsAndTrackersProfile() {
        let rules = BlockingRules.adsAndTrackers
        XCTAssertTrue(rules.isEnabled)
        XCTAssertTrue(rules.blockedDomains.contains("doubleclick.net"))
        XCTAssertTrue(rules.blockedDomains.contains("google-analytics.com"))
        XCTAssertTrue(rules.blockedDomains.contains("googletagmanager.com"))
        XCTAssertTrue(rules.blockedDomains.contains("facebook.net"))
        XCTAssertTrue(rules.blockedTypes.isEmpty)
    }

    func testImagesOnlyProfile() {
        let rules = BlockingRules.imagesOnly
        XCTAssertTrue(rules.isEnabled)
        XCTAssertTrue(rules.blockedDomains.isEmpty)
        XCTAssertTrue(rules.blockedTypes.contains(.image))
        XCTAssertEqual(rules.blockedTypes.count, 1)
    }

    func testScriptsOnlyProfile() {
        let rules = BlockingRules.scriptsOnly
        XCTAssertTrue(rules.isEnabled)
        XCTAssertTrue(rules.blockedDomains.isEmpty)
        XCTAssertTrue(rules.blockedTypes.contains(.script))
        XCTAssertEqual(rules.blockedTypes.count, 1)
    }

    // MARK: - Default State

    func testDefaultRulesDisabled() {
        let rules = BlockingRules()
        XCTAssertFalse(rules.isEnabled)
        XCTAssertTrue(rules.blockedDomains.isEmpty)
        XCTAssertTrue(rules.blockedTypes.isEmpty)
    }

    // MARK: - Codable

    func testBlockingRulesCodable() throws {
        var rules = BlockingRules()
        rules.blockedDomains = Set(["ads.example.com", "tracker.example.com"])
        rules.blockedTypes = Set([.script, .image])
        rules.isEnabled = true

        let data = try JSONEncoder().encode(rules)
        let decoded = try JSONDecoder().decode(BlockingRules.self, from: data)

        XCTAssertEqual(decoded.blockedDomains, rules.blockedDomains)
        XCTAssertEqual(decoded.blockedTypes, rules.blockedTypes)
        XCTAssertEqual(decoded.isEnabled, rules.isEnabled)
    }

    // MARK: - Content Rule Generation (SSRF Prevention)

    func testGeneratedRulesContainBlockAction() {
        var rules = BlockingRules()
        rules.blockedDomains = Set(["evil.com"])
        rules.isEnabled = true
        let json = rules.generateContentRules()
        XCTAssertTrue(json.contains("block"))
    }

    func testEmptyRulesProduceValidJSON() {
        var rules = BlockingRules()
        rules.isEnabled = true
        let json = rules.generateContentRules()
        // Should be valid JSON even with no domains/types
        let data = json.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(parsed)
    }

    // MARK: - Ads & Trackers Coverage

    func testAdsProfileBlocksCommonTrackers() {
        let rules = BlockingRules.adsAndTrackers
        let expectedDomains = [
            "doubleclick.net", "googleadservices.com", "google-analytics.com",
            "googletagmanager.com", "facebook.net", "connect.facebook.net",
            "googlesyndication.com", "adservice.google.com"
        ]
        for domain in expectedDomains {
            XCTAssertTrue(rules.blockedDomains.contains(domain),
                          "Ads profile should block \(domain)")
        }
    }
}
