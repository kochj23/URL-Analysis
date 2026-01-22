//
//  LighthouseModels.swift
//  URL Analysis
//
//  Data models for Google Lighthouse results
//  Created by Jordan Koch on 2026-01-22
//

import Foundation
import SwiftUI

// MARK: - Lighthouse Category Enum

enum LighthouseCategory: String, CaseIterable, Identifiable {
    case performance
    case accessibility
    case bestPractices = "best-practices"
    case seo
    case pwa

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .performance: return "Performance"
        case .accessibility: return "Accessibility"
        case .bestPractices: return "Best Practices"
        case .seo: return "SEO"
        case .pwa: return "PWA"
        }
    }

    var icon: String {
        switch self {
        case .performance: return "speedometer"
        case .accessibility: return "hand.raised.fill"
        case .bestPractices: return "checkmark.seal.fill"
        case .seo: return "magnifyingglass.circle.fill"
        case .pwa: return "app.badge.fill"
        }
    }

    var color: Color {
        switch self {
        case .performance: return AdaptiveColors.accentBlue
        case .accessibility: return AdaptiveColors.accentGreen
        case .bestPractices: return AdaptiveColors.purple
        case .seo: return AdaptiveColors.orange
        case .pwa: return AdaptiveColors.cyan
        }
    }
}

// MARK: - Lighthouse Result

struct LighthouseResult: Codable {
    let fetchTime: String
    let finalUrl: String?
    let lighthouseVersion: String
    let userAgent: String?
    let categories: Categories
    let audits: [String: Audit]?

    struct Categories: Codable {
        let performance: CategoryScore?
        let accessibility: CategoryScore?
        let bestPractices: CategoryScore?
        let seo: CategoryScore?
        let pwa: CategoryScore?

        enum CodingKeys: String, CodingKey {
            case performance
            case accessibility
            case bestPractices = "best-practices"
            case seo
            case pwa
        }
    }

    struct CategoryScore: Codable {
        let id: String
        let title: String
        let score: Double?  // 0.0 - 1.0
        let description: String?
        let manualDescription: String?
    }

    struct Audit: Codable {
        let id: String
        let title: String
        let description: String?
        let score: Double?  // 0.0 - 1.0
        let scoreDisplayMode: String?
        let displayValue: String?
        let numericValue: Double?
        let numericUnit: String?
        let explanation: String?
    }

    /// Get score for category (0-100)
    func score(for category: LighthouseCategory) -> Double? {
        let score: Double?
        switch category {
        case .performance:
            score = categories.performance?.score
        case .accessibility:
            score = categories.accessibility?.score
        case .bestPractices:
            score = categories.bestPractices?.score
        case .seo:
            score = categories.seo?.score
        case .pwa:
            score = categories.pwa?.score
        }

        return score.map { $0 * 100 }  // Convert to percentage
    }

    /// Get rating color for score
    static func color(for score: Double?) -> Color {
        guard let score = score else { return .gray }

        if score >= 90 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    /// Get rating label for score
    static func rating(for score: Double?) -> String {
        guard let score = score else { return "N/A" }

        if score >= 90 { return "Good" }
        if score >= 50 { return "Needs Improvement" }
        return "Poor"
    }

    /// Get formatted date
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: fetchTime) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return fetchTime
    }
}

// MARK: - Lighthouse Score Summary

struct LighthouseScoreSummary {
    let category: LighthouseCategory
    let score: Double?  // 0-100
    let rating: String
    let color: Color

    init(category: LighthouseCategory, result: LighthouseResult) {
        self.category = category
        self.score = result.score(for: category)
        self.rating = LighthouseResult.rating(for: score)
        self.color = LighthouseResult.color(for: score)
    }
}
