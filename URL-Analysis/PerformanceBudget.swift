//
//  PerformanceBudget.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI

/// Performance budget configuration
struct PerformanceBudget: Codable {
    var maxLoadTime: TimeInterval = 3.0  // seconds
    var maxSize: Int64 = 3_145_728  // 3 MB
    var maxRequests: Int = 50
    var minScore: Int = 75
    var maxLCP: TimeInterval = 2500  // ms
    var maxCLS: Double = 0.1
    var maxFID: TimeInterval = 100  // ms
    var isEnabled: Bool = true

    // Preset budgets
    static let mobileFast = PerformanceBudget(
        maxLoadTime: 2.0,
        maxSize: 1_572_864,  // 1.5 MB
        maxRequests: 30,
        minScore: 85,
        maxLCP: 2000,
        maxCLS: 0.05,
        maxFID: 80,
        isEnabled: true
    )

    static let desktopStandard = PerformanceBudget(
        maxLoadTime: 3.0,
        maxSize: 3_145_728,  // 3 MB
        maxRequests: 50,
        minScore: 75,
        maxLCP: 2500,
        maxCLS: 0.1,
        maxFID: 100,
        isEnabled: true
    )

    static let pwa = PerformanceBudget(
        maxLoadTime: 1.5,
        maxSize: 1_048_576,  // 1 MB
        maxRequests: 25,
        minScore: 90,
        maxLCP: 1800,
        maxCLS: 0.05,
        maxFID: 50,
        isEnabled: true
    )
}

/// Budget violation tracking
struct BudgetViolation: Identifiable {
    let id = UUID()
    let metric: String
    let actual: String
    let budget: String
    let severity: Severity
    let recommendation: String

    enum Severity {
        case critical  // > 50% over budget
        case warning   // 10-50% over budget
        case minor     // < 10% over budget

        var color: Color {
            switch self {
            case .critical: return .red
            case .warning: return .orange
            case .minor: return .yellow
            }
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.octagon.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .minor: return "exclamationmark.circle.fill"
            }
        }
    }
}

/// Budget manager with violation detection
@MainActor
class BudgetManager: ObservableObject {
    @Published var budget = PerformanceBudget()
    @Published var violations: [BudgetViolation] = []

    /// Check if current performance meets budget
    func checkBudget(monitor: NetworkMonitor) {
        violations.removeAll()

        guard budget.isEnabled else { return }

        // Check load time
        if monitor.totalDuration > budget.maxLoadTime {
            let overBy = monitor.totalDuration / budget.maxLoadTime
            let severity: BudgetViolation.Severity = overBy > 1.5 ? .critical : (overBy > 1.1 ? .warning : .minor)

            violations.append(BudgetViolation(
                metric: "Load Time",
                actual: formatDuration(monitor.totalDuration),
                budget: formatDuration(budget.maxLoadTime),
                severity: severity,
                recommendation: "Optimize render-blocking resources and reduce server response time."
            ))
        }

        // Check total size
        if monitor.totalSize > budget.maxSize {
            let overBy = Double(monitor.totalSize) / Double(budget.maxSize)
            let severity: BudgetViolation.Severity = overBy > 1.5 ? .critical : (overBy > 1.1 ? .warning : .minor)

            violations.append(BudgetViolation(
                metric: "Total Size",
                actual: formatSize(monitor.totalSize),
                budget: formatSize(budget.maxSize),
                severity: severity,
                recommendation: "Optimize images, enable compression, and remove unused resources."
            ))
        }

        // Check request count
        if monitor.resources.count > budget.maxRequests {
            let overBy = Double(monitor.resources.count) / Double(budget.maxRequests)
            let severity: BudgetViolation.Severity = overBy > 1.5 ? .critical : (overBy > 1.1 ? .warning : .minor)

            violations.append(BudgetViolation(
                metric: "Request Count",
                actual: "\(monitor.resources.count) requests",
                budget: "\(budget.maxRequests) requests",
                severity: severity,
                recommendation: "Bundle JavaScript/CSS files and use image sprites or lazy loading."
            ))
        }

        // Check performance score
        if let score = monitor.performanceScore, score.overall < budget.minScore {
            let underBy = Double(budget.minScore - score.overall) / Double(budget.minScore)
            let severity: BudgetViolation.Severity = underBy > 0.3 ? .critical : (underBy > 0.1 ? .warning : .minor)

            violations.append(BudgetViolation(
                metric: "Performance Score",
                actual: "\(score.overall)",
                budget: "≥ \(budget.minScore)",
                severity: severity,
                recommendation: "Review individual category scores and follow recommendations."
            ))
        }

        // Check Web Vitals
        if let vitals = monitor.webVitals {
            // Check LCP
            if vitals.lcp.rawValue > budget.maxLCP {
                let overBy = vitals.lcp.rawValue / budget.maxLCP
                let severity: BudgetViolation.Severity = overBy > 1.5 ? .critical : (overBy > 1.1 ? .warning : .minor)

                violations.append(BudgetViolation(
                    metric: "LCP (Largest Contentful Paint)",
                    actual: vitals.lcp.value,
                    budget: formatDuration(budget.maxLCP / 1000),
                    severity: severity,
                    recommendation: "Optimize largest image or text block. Use CDN and image optimization."
                ))
            }

            // Check CLS
            if vitals.cls.rawValue > budget.maxCLS {
                let overBy = vitals.cls.rawValue / budget.maxCLS
                let severity: BudgetViolation.Severity = overBy > 1.5 ? .critical : (overBy > 1.1 ? .warning : .minor)

                violations.append(BudgetViolation(
                    metric: "CLS (Cumulative Layout Shift)",
                    actual: vitals.cls.value,
                    budget: String(format: "≤ %.2f", budget.maxCLS),
                    severity: severity,
                    recommendation: "Reserve space for ads/images. Avoid inserting content above viewport."
                ))
            }

            // Check FID
            if vitals.fid.rawValue > budget.maxFID {
                let overBy = vitals.fid.rawValue / budget.maxFID
                let severity: BudgetViolation.Severity = overBy > 1.5 ? .critical : (overBy > 1.1 ? .warning : .minor)

                violations.append(BudgetViolation(
                    metric: "FID (First Input Delay)",
                    actual: vitals.fid.value,
                    budget: formatDuration(budget.maxFID / 1000),
                    severity: severity,
                    recommendation: "Reduce JavaScript execution time. Break up long tasks."
                ))
            }
        }
    }

    var hasCriticalViolations: Bool {
        violations.contains { $0.severity == .critical }
    }

    var hasWarnings: Bool {
        violations.contains { $0.severity == .warning || $0.severity == .minor }
    }

    var summaryText: String {
        if violations.isEmpty {
            return "✅ All budgets met"
        }

        let critical = violations.filter { $0.severity == .critical }.count
        let warnings = violations.filter { $0.severity == .warning }.count
        let minor = violations.filter { $0.severity == .minor }.count

        var parts: [String] = []
        if critical > 0 { parts.append("\(critical) critical") }
        if warnings > 0 { parts.append("\(warnings) warnings") }
        if minor > 0 { parts.append("\(minor) minor") }

        return "⚠️ " + parts.joined(separator: ", ")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }

    private func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
