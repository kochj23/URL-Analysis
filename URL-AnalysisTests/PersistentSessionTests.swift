//
//  PersistentSessionTests.swift
//  URL-AnalysisTests
//
//  Unit tests for PersistentSession, SessionMetadata, and SessionIndex
//  Created by Jordan Koch on 2026-05-01
//

import XCTest
@testable import URL_Analysis

final class PersistentSessionTests: XCTestCase {

    // MARK: - Domain Extraction

    func testDomainFromValidURL() {
        let session = makeSession(url: "https://www.example.com/path")
        XCTAssertEqual(session.domain, "www.example.com")
    }

    func testDomainFromURLWithPort() {
        let session = makeSession(url: "https://localhost:8080/api")
        XCTAssertEqual(session.domain, "localhost")
    }

    func testDomainFromInvalidURL() {
        let session = makeSession(url: "not a url")
        // Falls back to the raw url string
        XCTAssertEqual(session.domain, "not a url")
    }

    // MARK: - Performance Rating

    func testPerformanceRatingGood() {
        let session = makeSession(overallScore: 80)
        XCTAssertEqual(session.performanceRating, "Good")
    }

    func testPerformanceRatingNeedsImprovement() {
        let session = makeSession(overallScore: 60)
        XCTAssertEqual(session.performanceRating, "Needs Improvement")
    }

    func testPerformanceRatingPoor() {
        let session = makeSession(overallScore: 30)
        XCTAssertEqual(session.performanceRating, "Poor")
    }

    func testPerformanceRatingNil() {
        let session = makeSession(overallScore: nil)
        XCTAssertEqual(session.performanceRating, "N/A")
    }

    func testPerformanceRatingBoundary75() {
        let session = makeSession(overallScore: 75)
        XCTAssertEqual(session.performanceRating, "Good")
    }

    func testPerformanceRatingBoundary50() {
        let session = makeSession(overallScore: 50)
        XCTAssertEqual(session.performanceRating, "Needs Improvement")
    }

    // MARK: - Formatted Timestamp

    func testFormattedTimestampNonEmpty() {
        let session = makeSession()
        XCTAssertFalse(session.formattedTimestamp.isEmpty)
    }

    // MARK: - Codable Round-Trip

    func testPersistentSessionCodable() throws {
        let session = makeSession(
            url: "https://example.com",
            overallScore: 85,
            tags: ["fast", "mobile"]
        )
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(PersistentSession.self, from: data)

        XCTAssertEqual(decoded.url, session.url)
        XCTAssertEqual(decoded.overallScore, session.overallScore)
        XCTAssertEqual(decoded.tags, session.tags)
        XCTAssertEqual(decoded.resourceCount, session.resourceCount)
        XCTAssertEqual(decoded.totalSize, session.totalSize)
    }

    // MARK: - SessionMetadata

    func testSessionMetadataFromSession() {
        let session = makeSession(
            url: "https://test.com",
            overallScore: 72
        )
        let metadata = SessionMetadata(from: session)
        XCTAssertEqual(metadata.id, session.id)
        XCTAssertEqual(metadata.url, session.url)
        XCTAssertEqual(metadata.score, session.overallScore)
        XCTAssertEqual(metadata.totalSize, session.totalSize)
        XCTAssertEqual(metadata.requestCount, session.requestCount)
    }

    // MARK: - SessionIndex

    func testSessionIndexAddAndSort() {
        var index = SessionIndex(sessions: [])
        let older = makeSessionMetadata(timestamp: Date(timeIntervalSinceNow: -3600))
        let newer = makeSessionMetadata(timestamp: Date())

        index.add(older)
        index.add(newer)

        XCTAssertEqual(index.sessions.count, 2)
        // Newest first
        XCTAssertTrue(index.sessions[0].timestamp >= index.sessions[1].timestamp)
    }

    func testSessionIndexRemove() {
        var index = SessionIndex(sessions: [])
        let meta = makeSessionMetadata()
        index.add(meta)
        XCTAssertEqual(index.sessions.count, 1)

        index.remove(id: meta.id)
        XCTAssertEqual(index.sessions.count, 0)
    }

    func testSessionIndexRemoveNonExistent() {
        var index = SessionIndex(sessions: [])
        let meta = makeSessionMetadata()
        index.add(meta)
        index.remove(id: UUID())  // Remove non-existent
        XCTAssertEqual(index.sessions.count, 1)
    }

    // MARK: - Helpers

    private func makeSession(
        url: String = "https://example.com",
        overallScore: Double? = 80,
        tags: [String] = []
    ) -> PersistentSession {
        PersistentSession(
            url: url,
            timestamp: Date(),
            deviceProfile: nil,
            resourceCount: 25,
            resourceData: "[]",
            lcpValue: "1.50 s",
            clsValue: "0.050",
            fidValue: "50 ms",
            overallScore: overallScore,
            budgetViolations: [],
            optimizationCount: 3,
            thirdPartyCount: 5,
            duration: 2.5,
            totalSize: 1_500_000,
            requestCount: 25,
            tags: tags,
            notes: "",
            screenshots: []
        )
    }

    private func makeSessionMetadata(timestamp: Date = Date()) -> SessionMetadata {
        let session = PersistentSession(
            url: "https://example.com",
            timestamp: timestamp,
            deviceProfile: nil,
            resourceCount: 10,
            resourceData: "[]",
            lcpValue: nil, clsValue: nil, fidValue: nil,
            overallScore: 70,
            budgetViolations: [],
            optimizationCount: 0,
            thirdPartyCount: 0,
            duration: 1.0,
            totalSize: 100_000,
            requestCount: 10,
            tags: [],
            notes: "",
            screenshots: []
        )
        return SessionMetadata(from: session)
    }
}
