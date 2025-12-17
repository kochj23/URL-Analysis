//
//  WebVitals.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI

/// Core Web Vitals metrics (Google's user experience metrics)
struct WebVitals: Codable {
    let lcp: Metric  // Largest Contentful Paint
    let cls: Metric  // Cumulative Layout Shift
    let fid: Metric  // First Input Delay
    let captureTime: Date

    struct Metric: Codable {
        let value: String
        let rawValue: Double
        let score: Int
        let rating: Rating

        enum Rating: String, Codable {
            case good
            case needsImprovement
            case poor

            var color: Color {
                switch self {
                case .good: return .green
                case .needsImprovement: return .orange
                case .poor: return .red
                }
            }

            var emoji: String {
                switch self {
                case .good: return "✅"
                case .needsImprovement: return "⚠️"
                case .poor: return "❌"
                }
            }
        }
    }

    /// Create WebVitals from JavaScript data
    static func from(data: [String: Any]) -> WebVitals? {
        guard let lcpValue = data["lcp"] as? Double,
              let clsValue = data["cls"] as? Double,
              let fidValue = data["fid"] as? Double else {
            return nil
        }

        return WebVitals(
            lcp: createLCPMetric(lcpValue),
            cls: createCLSMetric(clsValue),
            fid: createFIDMetric(fidValue),
            captureTime: Date()
        )
    }

    private static func createLCPMetric(_ value: Double) -> Metric {
        // LCP thresholds: Good < 2.5s, Needs Improvement < 4.0s, Poor >= 4.0s
        let rating: Metric.Rating
        let score: Int

        if value < 2500 {
            rating = .good
            score = max(75, 100 - Int(value / 100))
        } else if value < 4000 {
            rating = .needsImprovement
            score = max(50, 75 - Int((value - 2500) / 60))
        } else {
            rating = .poor
            score = max(0, 50 - Int((value - 4000) / 200))
        }

        let displayValue = value < 1000 ? String(format: "%.0f ms", value) : String(format: "%.2f s", value / 1000)

        return Metric(value: displayValue, rawValue: value, score: score, rating: rating)
    }

    private static func createCLSMetric(_ value: Double) -> Metric {
        // CLS thresholds: Good < 0.1, Needs Improvement < 0.25, Poor >= 0.25
        let rating: Metric.Rating
        let score: Int

        if value < 0.1 {
            rating = .good
            score = max(75, 100 - Int(value * 250))
        } else if value < 0.25 {
            rating = .needsImprovement
            score = max(50, 75 - Int((value - 0.1) * 167))
        } else {
            rating = .poor
            score = max(0, 50 - Int((value - 0.25) * 100))
        }

        return Metric(value: String(format: "%.3f", value), rawValue: value, score: score, rating: rating)
    }

    private static func createFIDMetric(_ value: Double) -> Metric {
        // FID thresholds: Good < 100ms, Needs Improvement < 300ms, Poor >= 300ms
        let rating: Metric.Rating
        let score: Int

        if value < 100 {
            rating = .good
            score = max(75, 100 - Int(value / 4))
        } else if value < 300 {
            rating = .needsImprovement
            score = max(50, 75 - Int((value - 100) / 8))
        } else {
            rating = .poor
            score = max(0, 50 - Int((value - 300) / 20))
        }

        return Metric(value: String(format: "%.0f ms", value), rawValue: value, score: score, rating: rating)
    }
}
