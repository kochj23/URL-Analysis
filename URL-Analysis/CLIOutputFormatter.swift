//
//  CLIOutputFormatter.swift
//  URL Analysis
//
//  Output formatters for CLI mode (JSON, CSV, summary)
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// CLI output formatting utilities
/// Note: Simplified version - HAR format handled by existing HARFormat.swift
struct CLIOutputFormatter {

    // MARK: - Output Structures

    struct CLIOutput: Codable {
        let url: String
        let timestamp: String
        let metrics: Metrics

        struct Metrics: Codable {
            let loadTime: Double
            let totalSize: Int64
            let requestCount: Int
            let performanceScore: Double?
        }
    }

    // MARK: - JSON Format

    static func formatJSON(_ result: HeadlessAnalyzer.AnalysisResult, budgetViolations: [String]? = nil) throws -> Data {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: result.timestamp)

        let output = CLIOutput(
            url: result.url,
            timestamp: timestamp,
            metrics: CLIOutput.Metrics(
                loadTime: result.loadTime,
                totalSize: result.totalSize,
                requestCount: result.requestCount,
                performanceScore: result.performanceScore.map { Double($0.overall) }
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(output)
    }

    // MARK: - CSV Format

    static func formatCSV(_ result: HeadlessAnalyzer.AnalysisResult) -> Data {
        var csv = "URL,LoadTime,TotalSize,RequestCount,Score\n"

        let score = result.performanceScore.map { String(format: "%.0f", Double($0.overall)) } ?? "N/A"
        csv += "\"\(result.url)\",\(result.loadTime),\(result.totalSize),\(result.requestCount),\(score)\n"

        return csv.data(using: .utf8) ?? Data()
    }

    // MARK: - Summary Format

    static func formatSummary(_ result: HeadlessAnalyzer.AnalysisResult, budgetViolations: [String]? = nil) -> Data {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let score = result.performanceScore.map { String(format: "%.0f/100", Double($0.overall)) } ?? "N/A"

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
        Performance Score:  \(score)

        """

        summary += """

        ═══════════════════════════════════════════════════════

        """

        return summary.data(using: .utf8) ?? Data()
    }

    // MARK: - HAR Format (uses existing HARFormat.swift)

    static func formatHAR(_ result: HeadlessAnalyzer.AnalysisResult) throws -> Data {
        // Note: For full HAR export, use the GUI app's HAR export feature
        // This is a simplified version for CLI
        let summary = """
        {
          "log": {
            "version": "1.2",
            "creator": {"name": "URL Analysis CLI", "version": "1.4.0"},
            "comment": "Simplified HAR format. Use GUI app for full HAR export."
          }
        }
        """
        return summary.data(using: .utf8) ?? Data()
    }

    // MARK: - Helper Functions

    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
