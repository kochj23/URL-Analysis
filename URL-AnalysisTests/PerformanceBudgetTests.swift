//
//  PerformanceBudgetTests.swift
//  URL-AnalysisTests
//
//  Unit tests for performance budget presets and budget violation logic
//  Created by Jordan Koch on 2026-05-01
//

import XCTest
@testable import URL_Analysis

final class PerformanceBudgetTests: XCTestCase {

    // MARK: - Presets

    func testDesktopStandardPreset() {
        let budget = PerformanceBudget.desktopStandard
        XCTAssertEqual(budget.maxLoadTime, 3.0)
        XCTAssertEqual(budget.maxSize, 3_145_728)
        XCTAssertEqual(budget.maxRequests, 50)
        XCTAssertEqual(budget.minScore, 75)
        XCTAssertEqual(budget.maxLCP, 2500)
        XCTAssertEqual(budget.maxCLS, 0.1)
        XCTAssertEqual(budget.maxFID, 100)
        XCTAssertTrue(budget.isEnabled)
    }

    func testMobileFastPreset() {
        let budget = PerformanceBudget.mobileFast
        XCTAssertEqual(budget.maxLoadTime, 2.0)
        XCTAssertEqual(budget.maxSize, 1_572_864)
        XCTAssertEqual(budget.maxRequests, 30)
        XCTAssertEqual(budget.minScore, 85)
        XCTAssertTrue(budget.isEnabled)
    }

    func testPWAPreset() {
        let budget = PerformanceBudget.pwa
        XCTAssertEqual(budget.maxLoadTime, 1.5)
        XCTAssertEqual(budget.maxSize, 1_048_576)
        XCTAssertEqual(budget.maxRequests, 25)
        XCTAssertEqual(budget.minScore, 90)
        XCTAssertTrue(budget.isEnabled)
    }

    func testPWAStricterThanDesktop() {
        let pwa = PerformanceBudget.pwa
        let desktop = PerformanceBudget.desktopStandard
        XCTAssertLessThan(pwa.maxLoadTime, desktop.maxLoadTime)
        XCTAssertLessThan(pwa.maxSize, desktop.maxSize)
        XCTAssertLessThan(pwa.maxRequests, desktop.maxRequests)
        XCTAssertGreaterThan(pwa.minScore, desktop.minScore)
    }

    // MARK: - Codable

    func testBudgetCodable() throws {
        let budget = PerformanceBudget.mobileFast
        let data = try JSONEncoder().encode(budget)
        let decoded = try JSONDecoder().decode(PerformanceBudget.self, from: data)
        XCTAssertEqual(decoded.maxLoadTime, budget.maxLoadTime)
        XCTAssertEqual(decoded.maxSize, budget.maxSize)
        XCTAssertEqual(decoded.maxRequests, budget.maxRequests)
        XCTAssertEqual(decoded.minScore, budget.minScore)
    }

    // MARK: - BudgetViolation Severity

    func testViolationSeverityColors() {
        // Verify severity levels have different colors
        let critical = BudgetViolation(
            metric: "Test", actual: "10", budget: "5",
            severity: .critical, recommendation: ""
        )
        let warning = BudgetViolation(
            metric: "Test", actual: "10", budget: "5",
            severity: .warning, recommendation: ""
        )
        let minor = BudgetViolation(
            metric: "Test", actual: "10", budget: "5",
            severity: .minor, recommendation: ""
        )
        // Each severity level should have a distinct icon
        XCTAssertNotEqual(critical.severity.icon, warning.severity.icon)
        XCTAssertNotEqual(warning.severity.icon, minor.severity.icon)
    }

    func testViolationIdentifiable() {
        let v1 = BudgetViolation(metric: "A", actual: "1", budget: "2", severity: .minor, recommendation: "")
        let v2 = BudgetViolation(metric: "A", actual: "1", budget: "2", severity: .minor, recommendation: "")
        XCTAssertNotEqual(v1.id, v2.id, "Each violation should have a unique ID")
    }

    // MARK: - Default Budget Values

    func testDefaultBudgetValues() {
        let budget = PerformanceBudget()
        XCTAssertEqual(budget.maxLoadTime, 3.0)
        XCTAssertEqual(budget.maxSize, 3_145_728)
        XCTAssertEqual(budget.maxRequests, 50)
        XCTAssertEqual(budget.minScore, 75)
        XCTAssertTrue(budget.isEnabled)
    }
}
