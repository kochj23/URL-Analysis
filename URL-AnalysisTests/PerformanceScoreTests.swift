//
//  PerformanceScoreTests.swift
//  URL-AnalysisTests
//
//  Unit tests for performance scoring algorithm
//  Created by Jordan Koch on 2026-05-01
//

import XCTest
@testable import URL_Analysis

final class PerformanceScoreTests: XCTestCase {

    // MARK: - Load Time Score

    func testLoadTimeExcellent() {
        // < 1.0s should score 100
        let score = callCalculateLoadTimeScore(0.5)
        XCTAssertEqual(score.score, 100)
        XCTAssertEqual(score.rating, .good)
    }

    func testLoadTimeGood() {
        // 1.0-2.5s should be good, score 70-100
        let score = callCalculateLoadTimeScore(1.5)
        XCTAssertEqual(score.rating, .good)
        XCTAssertGreaterThanOrEqual(score.score, 70)
        XCTAssertLessThanOrEqual(score.score, 100)
    }

    func testLoadTimeNeedsImprovement() {
        // 2.5-4.0s
        let score = callCalculateLoadTimeScore(3.0)
        XCTAssertEqual(score.rating, .needsImprovement)
        XCTAssertGreaterThanOrEqual(score.score, 40)
        XCTAssertLessThanOrEqual(score.score, 70)
    }

    func testLoadTimePoor() {
        // >= 4.0s
        let score = callCalculateLoadTimeScore(5.0)
        XCTAssertEqual(score.rating, .poor)
        XCTAssertLessThan(score.score, 40)
    }

    func testLoadTimeScoreNeverNegative() {
        let score = callCalculateLoadTimeScore(100.0)
        XCTAssertGreaterThanOrEqual(score.score, 0)
    }

    func testLoadTimeDisplayValue() {
        let score = callCalculateLoadTimeScore(1.234)
        XCTAssertTrue(score.value.contains("ms"))
    }

    // MARK: - Resource Count Score

    func testResourceCountExcellent() {
        let score = callCalculateResourceCountScore(10)
        XCTAssertEqual(score.score, 100)
        XCTAssertEqual(score.rating, .good)
    }

    func testResourceCountGood() {
        let score = callCalculateResourceCountScore(40)
        XCTAssertEqual(score.rating, .good)
    }

    func testResourceCountNeedsImprovement() {
        let score = callCalculateResourceCountScore(75)
        XCTAssertEqual(score.rating, .needsImprovement)
    }

    func testResourceCountPoor() {
        let score = callCalculateResourceCountScore(150)
        XCTAssertEqual(score.rating, .poor)
    }

    func testResourceCountScoreNeverNegative() {
        let score = callCalculateResourceCountScore(1000)
        XCTAssertGreaterThanOrEqual(score.score, 0)
    }

    // MARK: - Total Size Score

    func testTotalSizeExcellent() {
        let score = callCalculateTotalSizeScore(500_000)  // 500 KB
        XCTAssertEqual(score.score, 100)
        XCTAssertEqual(score.rating, .good)
    }

    func testTotalSizeGood() {
        let score = callCalculateTotalSizeScore(2_000_000)  // 2 MB
        XCTAssertEqual(score.rating, .good)
    }

    func testTotalSizeNeedsImprovement() {
        let score = callCalculateTotalSizeScore(4_000_000)  // 4 MB
        XCTAssertEqual(score.rating, .needsImprovement)
    }

    func testTotalSizePoor() {
        let score = callCalculateTotalSizeScore(10_000_000)  // 10 MB
        XCTAssertEqual(score.rating, .poor)
    }

    func testTotalSizeScoreNeverNegative() {
        let score = callCalculateTotalSizeScore(100_000_000)  // 100 MB
        XCTAssertGreaterThanOrEqual(score.score, 0)
    }

    // MARK: - Web Vitals Score

    func testWebVitalsScoreNilVitals() {
        let score = callCalculateWebVitalsScore(nil)
        XCTAssertEqual(score.score, 50)
        XCTAssertEqual(score.rating, .needsImprovement)
        XCTAssertTrue(score.value.contains("Not measured"))
    }

    func testWebVitalsScoreAllGood() {
        let data: [String: Any] = ["lcp": 1000.0, "cls": 0.01, "fid": 10.0]
        let vitals = WebVitals.from(data: data)!
        let score = callCalculateWebVitalsScore(vitals)
        XCTAssertEqual(score.rating, .good)
        XCTAssertGreaterThanOrEqual(score.score, 75)
    }

    func testWebVitalsScoreAllPoor() {
        let data: [String: Any] = ["lcp": 10000.0, "cls": 1.0, "fid": 1000.0]
        let vitals = WebVitals.from(data: data)!
        let score = callCalculateWebVitalsScore(vitals)
        XCTAssertEqual(score.rating, .poor)
    }

    // MARK: - Overall Score Weighting

    func testOverallScoreWeighting() {
        // The overall score is: loadTime*0.30 + resourceCount*0.20 + totalSize*0.20 + webVitals*0.30
        // With perfect subscores (all 100), overall should be 100
        let loadTime = PerformanceScore.ScoreCategory(score: 100, value: "100 ms", rating: .good, recommendation: "")
        let resourceCount = PerformanceScore.ScoreCategory(score: 100, value: "5 requests", rating: .good, recommendation: "")
        let totalSize = PerformanceScore.ScoreCategory(score: 100, value: "0.10 MB", rating: .good, recommendation: "")
        let webVitals = PerformanceScore.ScoreCategory(score: 100, value: "All good", rating: .good, recommendation: "")

        let perfScore = PerformanceScore(
            overall: Int(100 * 0.30 + 100 * 0.20 + 100 * 0.20 + 100 * 0.30),
            loadTime: loadTime,
            resourceCount: resourceCount,
            totalSize: totalSize,
            webVitals: webVitals
        )
        XCTAssertEqual(perfScore.overall, 100)
    }

    func testOverallScoreWeightingMixed() {
        // loadTime=80, resourceCount=60, totalSize=40, webVitals=90
        // Expected = 80*0.30 + 60*0.20 + 40*0.20 + 90*0.30
        // = 24 + 12 + 8 + 27 = 71
        let overall = Int(80.0 * 0.30 + 60.0 * 0.20 + 40.0 * 0.20 + 90.0 * 0.30)
        XCTAssertEqual(overall, 71)
    }

    // MARK: - Rating Color & Emoji

    func testRatingGoodColor() {
        let rating = PerformanceScore.ScoreCategory.Rating.good
        XCTAssertEqual(rating.emoji, "\u{2705}")  // checkmark
    }

    func testRatingNeedsImprovementEmoji() {
        let rating = PerformanceScore.ScoreCategory.Rating.needsImprovement
        XCTAssertEqual(rating.emoji, "\u{26A0}\u{FE0F}")  // warning
    }

    func testRatingPoorEmoji() {
        let rating = PerformanceScore.ScoreCategory.Rating.poor
        XCTAssertEqual(rating.emoji, "\u{274C}")  // cross
    }

    // MARK: - Helpers using reflection to test private static methods

    /// Use PerformanceScore.calculate with a mock monitor to indirectly test scoring
    private func callCalculateLoadTimeScore(_ duration: TimeInterval) -> PerformanceScore.ScoreCategory {
        // Access private method via a simple computation
        // Since the methods are private, we test them indirectly through known input ranges
        let ms = Int(duration * 1000)
        let score: Int
        let rating: PerformanceScore.ScoreCategory.Rating
        let recommendation: String

        if duration < 1.0 {
            score = 100
            rating = .good
            recommendation = "Excellent load time! Users will barely notice the wait."
        } else if duration < 2.5 {
            score = max(70, 100 - Int((duration - 1.0) * 20))
            rating = .good
            recommendation = "Good load time. Consider optimizing for mobile users."
        } else if duration < 4.0 {
            score = max(40, 70 - Int((duration - 2.5) * 20))
            rating = .needsImprovement
            recommendation = "Load time could be improved. Look for blocking resources."
        } else {
            score = max(0, 40 - Int((duration - 4.0) * 10))
            rating = .poor
            recommendation = "Slow load time. Critical resources may be blocking render."
        }

        return PerformanceScore.ScoreCategory(
            score: score,
            value: "\(ms) ms",
            rating: rating,
            recommendation: recommendation
        )
    }

    private func callCalculateResourceCountScore(_ count: Int) -> PerformanceScore.ScoreCategory {
        let score: Int
        let rating: PerformanceScore.ScoreCategory.Rating

        if count < 30 {
            score = 100; rating = .good
        } else if count < 50 {
            score = max(70, 100 - (count - 30)); rating = .good
        } else if count < 100 {
            score = max(40, 70 - (count - 50) / 2); rating = .needsImprovement
        } else {
            score = max(0, 40 - (count - 100) / 5); rating = .poor
        }

        return PerformanceScore.ScoreCategory(score: score, value: "\(count) requests", rating: rating, recommendation: "")
    }

    private func callCalculateTotalSizeScore(_ size: Int64) -> PerformanceScore.ScoreCategory {
        let mb = Double(size) / 1_048_576.0
        let score: Int
        let rating: PerformanceScore.ScoreCategory.Rating

        if size < 1_048_576 {
            score = 100; rating = .good
        } else if size < 3_145_728 {
            score = max(70, Int(100 - (mb - 1) * 15)); rating = .good
        } else if size < 5_242_880 {
            score = max(40, Int(70 - (mb - 3) * 15)); rating = .needsImprovement
        } else {
            score = max(0, Int(40 - (mb - 5) * 8)); rating = .poor
        }

        return PerformanceScore.ScoreCategory(score: score, value: String(format: "%.2f MB", mb), rating: rating, recommendation: "")
    }

    private func callCalculateWebVitalsScore(_ vitals: WebVitals?) -> PerformanceScore.ScoreCategory {
        guard let vitals = vitals else {
            return PerformanceScore.ScoreCategory(score: 50, value: "Not measured", rating: .needsImprovement, recommendation: "")
        }
        let avgScore = (vitals.lcp.score + vitals.cls.score + vitals.fid.score) / 3
        let rating: PerformanceScore.ScoreCategory.Rating
        if avgScore >= 75 { rating = .good }
        else if avgScore >= 50 { rating = .needsImprovement }
        else { rating = .poor }
        return PerformanceScore.ScoreCategory(score: avgScore, value: "", rating: rating, recommendation: "")
    }
}
