//
//  PerformanceScore.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI

/// Performance score breakdown and overall rating
struct PerformanceScore {
    let overall: Int  // 0-100
    let loadTime: ScoreCategory
    let resourceCount: ScoreCategory
    let totalSize: ScoreCategory
    let webVitals: ScoreCategory

    struct ScoreCategory {
        let score: Int  // 0-100
        let value: String
        let rating: Rating
        let recommendation: String

        enum Rating {
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

    /// Calculate performance score from network monitor data
    @MainActor
    static func calculate(from monitor: NetworkMonitor, webVitals: WebVitals?) -> PerformanceScore {
        let loadTimeScore = calculateLoadTimeScore(monitor.totalDuration)
        let resourceCountScore = calculateResourceCountScore(monitor.resources.count)
        let totalSizeScore = calculateTotalSizeScore(monitor.totalSize)
        let webVitalsScore = calculateWebVitalsScore(webVitals)

        // Weighted average: 30% load time, 20% resources, 20% size, 30% web vitals
        let overall = Int(
            Double(loadTimeScore.score) * 0.30 +
            Double(resourceCountScore.score) * 0.20 +
            Double(totalSizeScore.score) * 0.20 +
            Double(webVitalsScore.score) * 0.30
        )

        return PerformanceScore(
            overall: overall,
            loadTime: loadTimeScore,
            resourceCount: resourceCountScore,
            totalSize: totalSizeScore,
            webVitals: webVitalsScore
        )
    }

    private static func calculateLoadTimeScore(_ duration: TimeInterval) -> ScoreCategory {
        let ms = Int(duration * 1000)
        let score: Int
        let rating: ScoreCategory.Rating
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

        return ScoreCategory(
            score: score,
            value: "\(ms) ms",
            rating: rating,
            recommendation: recommendation
        )
    }

    private static func calculateResourceCountScore(_ count: Int) -> ScoreCategory {
        let score: Int
        let rating: ScoreCategory.Rating
        let recommendation: String

        if count < 30 {
            score = 100
            rating = .good
            recommendation = "Excellent! Low resource count improves load performance."
        } else if count < 50 {
            score = max(70, 100 - (count - 30))
            rating = .good
            recommendation = "Good resource count. Consider combining similar resources."
        } else if count < 100 {
            score = max(40, 70 - (count - 50) / 2)
            rating = .needsImprovement
            recommendation = "Many resources. Consider bundling JS/CSS and using image sprites."
        } else {
            score = max(0, 40 - (count - 100) / 5)
            rating = .poor
            recommendation = "Too many resources. Implement aggressive bundling and lazy loading."
        }

        return ScoreCategory(
            score: score,
            value: "\(count) requests",
            rating: rating,
            recommendation: recommendation
        )
    }

    private static func calculateTotalSizeScore(_ size: Int64) -> ScoreCategory {
        let mb = Double(size) / 1_048_576.0
        let score: Int
        let rating: ScoreCategory.Rating
        let recommendation: String

        if size < 1_048_576 {  // < 1 MB
            score = 100
            rating = .good
            recommendation = "Excellent! Small page size loads quickly on all connections."
        } else if size < 3_145_728 {  // < 3 MB
            score = max(70, Int(100 - (mb - 1) * 15))
            rating = .good
            recommendation = "Good size. Consider image optimization and compression."
        } else if size < 5_242_880 {  // < 5 MB
            score = max(40, Int(70 - (mb - 3) * 15))
            rating = .needsImprovement
            recommendation = "Page is heavy. Optimize images, use WebP, enable gzip/brotli."
        } else {
            score = max(0, Int(40 - (mb - 5) * 8))
            rating = .poor
            recommendation = "Page is too large. Implement lazy loading and modern image formats."
        }

        return ScoreCategory(
            score: score,
            value: String(format: "%.2f MB", mb),
            rating: rating,
            recommendation: recommendation
        )
    }

    private static func calculateWebVitalsScore(_ webVitals: WebVitals?) -> ScoreCategory {
        guard let vitals = webVitals else {
            return ScoreCategory(
                score: 50,
                value: "Not measured",
                rating: .needsImprovement,
                recommendation: "Web Vitals data not available yet."
            )
        }

        // Score based on all three metrics
        let lcpScore = vitals.lcp.score
        let clsScore = vitals.cls.score
        let fidScore = vitals.fid.score

        let avgScore = (lcpScore + clsScore + fidScore) / 3

        let rating: ScoreCategory.Rating
        if avgScore >= 75 {
            rating = .good
        } else if avgScore >= 50 {
            rating = .needsImprovement
        } else {
            rating = .poor
        }

        let recommendations = [
            vitals.lcp.rating != .good ? "Improve LCP: optimize images and server response" : nil,
            vitals.cls.rating != .good ? "Fix CLS: reserve space for dynamic content" : nil,
            vitals.fid.rating != .good ? "Reduce FID: minimize JavaScript execution" : nil
        ].compactMap { $0 }

        return ScoreCategory(
            score: avgScore,
            value: "LCP: \(vitals.lcp.value), CLS: \(vitals.cls.value), FID: \(vitals.fid.value)",
            rating: rating,
            recommendation: recommendations.isEmpty ? "All Core Web Vitals are good!" : recommendations.joined(separator: ". ")
        )
    }
}
