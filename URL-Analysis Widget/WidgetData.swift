//
//  WidgetData.swift
//  URL-Analysis Widget
//
//  Data models for widget display
//  Created by Jordan Koch on 2026-02-04
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

// MARK: - Widget Data Models

/// Data shared between the main app and widget via App Group
struct WidgetAnalysisData: Codable {
    let lastUpdated: Date
    let recentAnalyses: [WidgetAnalysisEntry]
    let backendStatus: BackendStatus
    let statistics: AnalysisStatistics

    struct BackendStatus: Codable {
        let isAvailable: Bool
        let activeBackend: String?
        let lastChecked: Date
    }

    struct AnalysisStatistics: Codable {
        let totalAnalyses: Int
        let averageScore: Double
        let todayCount: Int
        let weekCount: Int
    }

    static var placeholder: WidgetAnalysisData {
        WidgetAnalysisData(
            lastUpdated: Date(),
            recentAnalyses: [
                WidgetAnalysisEntry.placeholder,
                WidgetAnalysisEntry(
                    id: UUID(),
                    url: "https://apple.com",
                    domain: "apple.com",
                    timestamp: Date().addingTimeInterval(-3600),
                    overallScore: 92,
                    lcpValue: "1.2s",
                    fidValue: "45ms",
                    clsValue: "0.05",
                    loadTime: 1.8,
                    requestCount: 42,
                    totalSize: 1_200_000
                ),
                WidgetAnalysisEntry(
                    id: UUID(),
                    url: "https://github.com",
                    domain: "github.com",
                    timestamp: Date().addingTimeInterval(-7200),
                    overallScore: 78,
                    lcpValue: "2.1s",
                    fidValue: "85ms",
                    clsValue: "0.12",
                    loadTime: 2.5,
                    requestCount: 68,
                    totalSize: 2_500_000
                )
            ],
            backendStatus: BackendStatus(
                isAvailable: true,
                activeBackend: "Ollama",
                lastChecked: Date()
            ),
            statistics: AnalysisStatistics(
                totalAnalyses: 150,
                averageScore: 75.5,
                todayCount: 5,
                weekCount: 32
            )
        )
    }
}

/// Individual analysis entry for widget display
struct WidgetAnalysisEntry: Codable, Identifiable {
    let id: UUID
    let url: String
    let domain: String
    let timestamp: Date
    let overallScore: Int?
    let lcpValue: String?
    let fidValue: String?
    let clsValue: String?
    let loadTime: TimeInterval
    let requestCount: Int
    let totalSize: Int64

    var scoreColor: ScoreRating {
        guard let score = overallScore else { return .unknown }
        if score >= 75 { return .good }
        if score >= 50 { return .needsImprovement }
        return .poor
    }

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var formattedLoadTime: String {
        if loadTime < 1 {
            return String(format: "%.0fms", loadTime * 1000)
        } else {
            return String(format: "%.1fs", loadTime)
        }
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    static var placeholder: WidgetAnalysisEntry {
        WidgetAnalysisEntry(
            id: UUID(),
            url: "https://example.com",
            domain: "example.com",
            timestamp: Date(),
            overallScore: 85,
            lcpValue: "1.5s",
            fidValue: "50ms",
            clsValue: "0.08",
            loadTime: 2.3,
            requestCount: 55,
            totalSize: 1_500_000
        )
    }
}

// MARK: - Score Rating

enum ScoreRating: String, Codable {
    case good
    case needsImprovement
    case poor
    case unknown

    var label: String {
        switch self {
        case .good: return "Good"
        case .needsImprovement: return "Needs Work"
        case .poor: return "Poor"
        case .unknown: return "N/A"
        }
    }

    var symbol: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .needsImprovement: return "exclamationmark.triangle.fill"
        case .poor: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Web Vitals Display

struct WebVitalsDisplay {
    let lcp: VitalMetric
    let fid: VitalMetric
    let cls: VitalMetric

    struct VitalMetric {
        let name: String
        let value: String
        let rating: ScoreRating

        static func lcp(value: String?) -> VitalMetric {
            guard let value = value else {
                return VitalMetric(name: "LCP", value: "--", rating: .unknown)
            }

            // Parse value to determine rating
            let numericValue: Double
            if value.hasSuffix("ms") {
                numericValue = Double(value.replacingOccurrences(of: "ms", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
            } else if value.hasSuffix("s") {
                numericValue = (Double(value.replacingOccurrences(of: "s", with: "").trimmingCharacters(in: .whitespaces)) ?? 0) * 1000
            } else {
                numericValue = Double(value) ?? 0
            }

            let rating: ScoreRating
            if numericValue < 2500 {
                rating = .good
            } else if numericValue < 4000 {
                rating = .needsImprovement
            } else {
                rating = .poor
            }

            return VitalMetric(name: "LCP", value: value, rating: rating)
        }

        static func fid(value: String?) -> VitalMetric {
            guard let value = value else {
                return VitalMetric(name: "FID", value: "--", rating: .unknown)
            }

            let numericValue = Double(value.replacingOccurrences(of: "ms", with: "").trimmingCharacters(in: .whitespaces)) ?? 0

            let rating: ScoreRating
            if numericValue < 100 {
                rating = .good
            } else if numericValue < 300 {
                rating = .needsImprovement
            } else {
                rating = .poor
            }

            return VitalMetric(name: "FID", value: value, rating: rating)
        }

        static func cls(value: String?) -> VitalMetric {
            guard let value = value else {
                return VitalMetric(name: "CLS", value: "--", rating: .unknown)
            }

            let numericValue = Double(value) ?? 0

            let rating: ScoreRating
            if numericValue < 0.1 {
                rating = .good
            } else if numericValue < 0.25 {
                rating = .needsImprovement
            } else {
                rating = .poor
            }

            return VitalMetric(name: "CLS", value: value, rating: rating)
        }
    }

    init(entry: WidgetAnalysisEntry) {
        self.lcp = VitalMetric.lcp(value: entry.lcpValue)
        self.fid = VitalMetric.fid(value: entry.fidValue)
        self.cls = VitalMetric.cls(value: entry.clsValue)
    }
}

// MARK: - Timeline Entry

struct URLAnalysisTimelineEntry: TimelineEntry {
    let date: Date
    let data: WidgetAnalysisData
    let configuration: ConfigurationAppIntent?

    static var placeholder: URLAnalysisTimelineEntry {
        URLAnalysisTimelineEntry(
            date: Date(),
            data: .placeholder,
            configuration: nil
        )
    }
}

// MARK: - Configuration Intent (for interactive widgets)

import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "URL Analysis Widget"
    static var description = IntentDescription("Shows recent URL analysis results and performance metrics.")

    @Parameter(title: "Show Backend Status", default: true)
    var showBackendStatus: Bool

    @Parameter(title: "Show Web Vitals", default: true)
    var showWebVitals: Bool
}

// MARK: - Quick Analyze Intent

struct QuickAnalyzeIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Analyze"
    static var description = IntentDescription("Opens URL Analysis to analyze a new URL.")

    func perform() async throws -> some IntentResult {
        // This will open the main app
        return .result()
    }

    static var openAppWhenRun: Bool = true
}
