//
//  CLIOutputFormatter.swift
//  URL Analysis
//
//  Output formatters for CLI mode (JSON, CSV, summary)
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// CLI output formatting utilities
struct CLIOutputFormatter {

    // MARK: - Output Structures

    struct CLIOutput: Codable {
        let url: String
        let timestamp: String
        let metrics: Metrics
        let webVitals: WebVitalsOutput?
        let budgetViolations: [BudgetViolationOutput]?
        let resources: [ResourceOutput]

        struct Metrics: Codable {
            let loadTime: Double
            let totalSize: Int64
            let requestCount: Int
            let performanceScore: Double?
        }

        struct WebVitalsOutput: Codable {
            let lcp: String
            let cls: String
            let fid: String
            let lcpScore: Double
            let clsScore: Double
            let fidScore: Double
        }

        struct BudgetViolationOutput: Codable {
            let metric: String
            let actual: String
            let budget: String
            let severity: String
        }

        struct ResourceOutput: Codable {
            let url: String
            let type: String
            let size: Int64
            let duration: Double
            let status: Int
        }
    }

    // MARK: - JSON Format

    static func formatJSON(_ result: HeadlessAnalyzer.AnalysisResult, budgetViolations: [BudgetViolation]? = nil) throws -> Data {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: result.timestamp)

        let output = CLIOutput(
            url: result.url,
            timestamp: timestamp,
            metrics: CLIOutput.Metrics(
                loadTime: result.loadTime,
                totalSize: result.totalSize,
                requestCount: result.requestCount,
                performanceScore: result.performanceScore?.overall
            ),
            webVitals: result.webVitals.map { vitals in
                CLIOutput.WebVitalsOutput(
                    lcp: vitals.lcp.value,
                    cls: vitals.cls.value,
                    fid: vitals.fid.value,
                    lcpScore: vitals.lcp.score,
                    clsScore: vitals.cls.score,
                    fidScore: vitals.fid.score
                )
            },
            budgetViolations: budgetViolations?.map { violation in
                CLIOutput.BudgetViolationOutput(
                    metric: violation.metric,
                    actual: violation.actualValue,
                    budget: violation.budgetValue,
                    severity: violation.severity.rawValue
                )
            },
            resources: result.resources.map { resource in
                CLIOutput.ResourceOutput(
                    url: resource.url,
                    type: resource.resourceType.rawValue,
                    size: resource.responseSize,
                    duration: resource.totalDuration,
                    status: resource.statusCode
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(output)
    }

    // MARK: - CSV Format

    static func formatCSV(_ result: HeadlessAnalyzer.AnalysisResult) -> Data {
        var csv = "URL,Type,Size,Duration,Status\n"

        for resource in result.resources {
            let escapedURL = resource.url.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(escapedURL)\",\(resource.resourceType.rawValue),\(resource.responseSize),\(resource.totalDuration),\(resource.statusCode)\n"
        }

        return csv.data(using: .utf8) ?? Data()
    }

    // MARK: - Summary Format

    static func formatSummary(_ result: HeadlessAnalyzer.AnalysisResult, budgetViolations: [BudgetViolation]? = nil) -> Data {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var summary = """
        ═══════════════════════════════════════════════════════
        URL ANALYSIS SUMMARY
        ═══════════════════════════════════════════════════════

        URL:        \(result.url)
        Date:       \(formatter.string(from: result.timestamp))
        Device:     \(result.deviceProfile?.name ?? "Desktop")

        ═══════════════════════════════════════════════════════
        PERFORMANCE METRICS
        ═══════════════════════════════════════════════════════

        Load Time:          \(String(format: "%.2f", result.loadTime)) seconds
        Total Size:         \(formatBytes(result.totalSize))
        Total Requests:     \(result.requestCount)
        Performance Score:  \(result.performanceScore?.overall.map { String(format: "%.0f/100", $0) } ?? "N/A")

        """

        // Web Vitals
        if let vitals = result.webVitals {
            summary += """
            ═══════════════════════════════════════════════════════
            CORE WEB VITALS
            ═══════════════════════════════════════════════════════

            LCP (Largest Contentful Paint):  \(vitals.lcp.value) - \(vitals.lcp.rating.label)
            CLS (Cumulative Layout Shift):   \(vitals.cls.value) - \(vitals.cls.rating.label)
            FID (First Input Delay):         \(vitals.fid.value) - \(vitals.fid.rating.label)

            """
        }

        // Budget violations
        if let violations = budgetViolations, !violations.isEmpty {
            summary += """
            ═══════════════════════════════════════════════════════
            BUDGET VIOLATIONS (\(violations.count))
            ═══════════════════════════════════════════════════════

            """

            for violation in violations {
                summary += "  \(violation.severity.icon) \(violation.metric): \(violation.actualValue) (budget: \(violation.budgetValue))\n"
            }

            summary += "\n"
        }

        // Resource breakdown
        let groupedResources = Dictionary(grouping: result.resources) { $0.resourceType }

        summary += """
        ═══════════════════════════════════════════════════════
        RESOURCE BREAKDOWN
        ═══════════════════════════════════════════════════════

        """

        for type in ResourceType.allCases {
            if let resources = groupedResources[type], !resources.isEmpty {
                let totalSize = resources.reduce(0) { $0 + $1.responseSize }
                summary += "  \(type.rawValue.capitalized): \(resources.count) (\(formatBytes(totalSize)))\n"
            }
        }

        summary += """

        ═══════════════════════════════════════════════════════

        """

        return summary.data(using: .utf8) ?? Data()
    }

    // MARK: - HAR Format

    static func formatHAR(_ result: HeadlessAnalyzer.AnalysisResult) throws -> Data {
        // Create minimal HAR structure
        let harLog = HARLog(
            version: "1.2",
            creator: HARCreator(name: "URL Analysis CLI", version: "1.3.0"),
            pages: [
                HARPage(
                    startedDateTime: ISO8601DateFormatter().string(from: result.timestamp),
                    id: "page_1",
                    title: result.url,
                    pageTimings: HARPageTimings(onLoad: result.loadTime * 1000)
                )
            ],
            entries: result.resources.map { resource in
                HAREntry(
                    startedDateTime: ISO8601DateFormatter().string(from: resource.startTime),
                    time: resource.totalDuration * 1000,
                    request: HARRequest(
                        method: resource.method,
                        url: resource.url,
                        headers: resource.requestHeaders.map { HARHeader(name: $0.key, value: $0.value) },
                        bodySize: resource.requestSize
                    ),
                    response: HARResponse(
                        status: resource.statusCode,
                        statusText: "OK",
                        headers: resource.responseHeaders.map { HARHeader(name: $0.key, value: $0.value) },
                        bodySize: resource.responseSize,
                        content: HARContent(
                            size: resource.responseSize,
                            mimeType: resource.mimeType ?? "application/octet-stream"
                        )
                    ),
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

        let harFile = HARFile(log: harLog)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(harFile)
    }

    // MARK: - Helper Functions

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Budget Violation Helper

extension BudgetViolation {
    var icon: String {
        switch severity {
        case .critical: return "❌"
        case .warning: return "⚠️"
        case .minor: return "ℹ️"
        }
    }
}
