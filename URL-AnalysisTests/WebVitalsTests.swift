//
//  WebVitalsTests.swift
//  URL-AnalysisTests
//
//  Unit tests for Core Web Vitals metric scoring
//  Created by Jordan Koch on 2026-05-01
//

import XCTest
@testable import URL_Analysis

final class WebVitalsTests: XCTestCase {

    // MARK: - LCP (Largest Contentful Paint)

    func testLCPGoodScore() {
        let data: [String: Any] = ["lcp": 1000.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.lcp.rating, .good)
        XCTAssertGreaterThanOrEqual(vitals!.lcp.score, 75)
    }

    func testLCPNeedsImprovementScore() {
        let data: [String: Any] = ["lcp": 3000.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.lcp.rating, .needsImprovement)
        XCTAssertGreaterThanOrEqual(vitals!.lcp.score, 50)
        XCTAssertLessThan(vitals!.lcp.score, 75)
    }

    func testLCPPoorScore() {
        let data: [String: Any] = ["lcp": 5000.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.lcp.rating, .poor)
        XCTAssertLessThan(vitals!.lcp.score, 50)
    }

    func testLCPBoundaryGoodNeedsImprovement() {
        // Exactly at 2500ms boundary
        let data: [String: Any] = ["lcp": 2500.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.lcp.rating, .needsImprovement)
    }

    func testLCPBoundaryNeedsImprovementPoor() {
        // Exactly at 4000ms boundary
        let data: [String: Any] = ["lcp": 4000.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.lcp.rating, .poor)
    }

    func testLCPZeroValue() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.lcp.rating, .good)
        XCTAssertEqual(vitals!.lcp.score, 100)
    }

    func testLCPExtremelyHighValue() {
        let data: [String: Any] = ["lcp": 20000.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.lcp.rating, .poor)
        XCTAssertGreaterThanOrEqual(vitals!.lcp.score, 0)
    }

    func testLCPDisplayValueMilliseconds() {
        let data: [String: Any] = ["lcp": 500.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertTrue(vitals!.lcp.value.contains("ms"))
    }

    func testLCPDisplayValueSeconds() {
        let data: [String: Any] = ["lcp": 2000.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertTrue(vitals!.lcp.value.contains("s"))
    }

    // MARK: - CLS (Cumulative Layout Shift)

    func testCLSGoodScore() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.05, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.cls.rating, .good)
        XCTAssertGreaterThanOrEqual(vitals!.cls.score, 75)
    }

    func testCLSNeedsImprovementScore() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.15, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.cls.rating, .needsImprovement)
    }

    func testCLSPoorScore() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.5, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.cls.rating, .poor)
    }

    func testCLSZeroValuePerfect() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.cls.rating, .good)
        XCTAssertEqual(vitals!.cls.score, 100)
    }

    func testCLSBoundary() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.1, "fid": 0.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.cls.rating, .needsImprovement)
    }

    // MARK: - FID (First Input Delay)

    func testFIDGoodScore() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.0, "fid": 50.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.fid.rating, .good)
        XCTAssertGreaterThanOrEqual(vitals!.fid.score, 75)
    }

    func testFIDNeedsImprovementScore() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.0, "fid": 200.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.fid.rating, .needsImprovement)
    }

    func testFIDPoorScore() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.0, "fid": 500.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.fid.rating, .poor)
    }

    func testFIDBoundary() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.0, "fid": 100.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.fid.rating, .needsImprovement)
    }

    // MARK: - Input Validation

    func testNilFromMissingFields() {
        let data: [String: Any] = ["lcp": 1000.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNil(vitals)
    }

    func testNilFromEmptyDictionary() {
        let data: [String: Any] = [:]
        let vitals = WebVitals.from(data: data)
        XCTAssertNil(vitals)
    }

    func testNilFromWrongTypes() {
        let data: [String: Any] = ["lcp": "fast", "cls": "low", "fid": "good"]
        let vitals = WebVitals.from(data: data)
        XCTAssertNil(vitals)
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let data: [String: Any] = ["lcp": 1500.0, "cls": 0.05, "fid": 50.0]
        let vitals = WebVitals.from(data: data)!

        let encoder = JSONEncoder()
        let encoded = try encoder.encode(vitals)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WebVitals.self, from: encoded)

        XCTAssertEqual(decoded.lcp.rawValue, vitals.lcp.rawValue)
        XCTAssertEqual(decoded.cls.rawValue, vitals.cls.rawValue)
        XCTAssertEqual(decoded.fid.rawValue, vitals.fid.rawValue)
        XCTAssertEqual(decoded.lcp.score, vitals.lcp.score)
        XCTAssertEqual(decoded.cls.score, vitals.cls.score)
        XCTAssertEqual(decoded.fid.score, vitals.fid.score)
    }

    // MARK: - Score Clamping

    func testScoreNeverNegative() {
        let data: [String: Any] = ["lcp": 100000.0, "cls": 10.0, "fid": 10000.0]
        let vitals = WebVitals.from(data: data)!
        XCTAssertGreaterThanOrEqual(vitals.lcp.score, 0)
        XCTAssertGreaterThanOrEqual(vitals.cls.score, 0)
        XCTAssertGreaterThanOrEqual(vitals.fid.score, 0)
    }

    func testScoreNeverExceeds100() {
        let data: [String: Any] = ["lcp": 0.0, "cls": 0.0, "fid": 0.0]
        let vitals = WebVitals.from(data: data)!
        XCTAssertLessThanOrEqual(vitals.lcp.score, 100)
        XCTAssertLessThanOrEqual(vitals.cls.score, 100)
        XCTAssertLessThanOrEqual(vitals.fid.score, 100)
    }
}
