//
//  ThirdPartyAnalysis.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI

/// Third-party domain analysis
struct ThirdPartyDomain: Identifiable {
    let id = UUID()
    let domain: String
    let provider: ThirdPartyProvider?
    let resources: [NetworkResource]

    var totalSize: Int64 {
        resources.reduce(0) { $0 + $1.responseSize }
    }

    var totalDuration: TimeInterval {
        guard let first = resources.min(by: { $0.startTime < $1.startTime }),
              let last = resources.max(by: { $0.startTime < $1.startTime }) else {
            return 0
        }
        return last.startTime.timeIntervalSince(first.startTime) + last.totalDuration
    }

    var requestCount: Int {
        resources.count
    }

    var impact: Impact {
        if totalDuration > 2.0 || totalSize > 1_048_576 {
            return .high
        } else if totalDuration > 1.0 || totalSize > 524_288 {
            return .medium
        } else {
            return .low
        }
    }

    enum Impact {
        case high, medium, low

        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .green
            }
        }

        var text: String {
            switch self {
            case .high: return "High Impact"
            case .medium: return "Medium Impact"
            case .low: return "Low Impact"
            }
        }
    }
}

/// Known third-party provider information
struct ThirdPartyProvider {
    let name: String
    let category: Category
    let description: String

    enum Category: String {
        case analytics = "Analytics"
        case advertising = "Advertising"
        case socialMedia = "Social Media"
        case cdn = "CDN"
        case fonts = "Fonts"
        case maps = "Maps"
        case video = "Video"
        case tagManagement = "Tag Management"
        case other = "Other"

        var icon: String {
            switch self {
            case .analytics: return "chart.bar.fill"
            case .advertising: return "megaphone.fill"
            case .socialMedia: return "person.3.fill"
            case .cdn: return "network"
            case .fonts: return "textformat"
            case .maps: return "map.fill"
            case .video: return "play.rectangle.fill"
            case .tagManagement: return "tag.fill"
            case .other: return "questionmark.circle.fill"
            }
        }
    }

    // Known third-party providers
    static let providers: [String: ThirdPartyProvider] = [
        "google-analytics.com": ThirdPartyProvider(name: "Google Analytics", category: .analytics, description: "Web analytics service"),
        "googletagmanager.com": ThirdPartyProvider(name: "Google Tag Manager", category: .tagManagement, description: "Tag management system"),
        "doubleclick.net": ThirdPartyProvider(name: "DoubleClick", category: .advertising, description: "Ad serving platform"),
        "facebook.net": ThirdPartyProvider(name: "Facebook", category: .socialMedia, description: "Social media tracking"),
        "connect.facebook.net": ThirdPartyProvider(name: "Facebook SDK", category: .socialMedia, description: "Facebook integration"),
        "twitter.com": ThirdPartyProvider(name: "Twitter", category: .socialMedia, description: "Social media integration"),
        "youtube.com": ThirdPartyProvider(name: "YouTube", category: .video, description: "Video platform"),
        "googlevideo.com": ThirdPartyProvider(name: "YouTube CDN", category: .video, description: "Video delivery"),
        "googleapis.com": ThirdPartyProvider(name: "Google APIs", category: .other, description: "Google services"),
        "gstatic.com": ThirdPartyProvider(name: "Google Static", category: .cdn, description: "Google CDN"),
        "cloudflare.com": ThirdPartyProvider(name: "Cloudflare", category: .cdn, description: "CDN and security"),
        "cloudfront.net": ThirdPartyProvider(name: "Amazon CloudFront", category: .cdn, description: "AWS CDN"),
        "akamaized.net": ThirdPartyProvider(name: "Akamai", category: .cdn, description: "CDN provider"),
        "fonts.googleapis.com": ThirdPartyProvider(name: "Google Fonts", category: .fonts, description: "Web fonts service"),
        "fonts.gstatic.com": ThirdPartyProvider(name: "Google Fonts CDN", category: .fonts, description: "Font delivery"),
        "typekit.net": ThirdPartyProvider(name: "Adobe Fonts", category: .fonts, description: "Web fonts service"),
        "maps.googleapis.com": ThirdPartyProvider(name: "Google Maps", category: .maps, description: "Maps API"),
        "stripe.com": ThirdPartyProvider(name: "Stripe", category: .other, description: "Payment processing"),
        "paypal.com": ThirdPartyProvider(name: "PayPal", category: .other, description: "Payment processing"),
        "hotjar.com": ThirdPartyProvider(name: "Hotjar", category: .analytics, description: "User behavior analytics"),
        "segment.com": ThirdPartyProvider(name: "Segment", category: .analytics, description: "Customer data platform"),
        "mixpanel.com": ThirdPartyProvider(name: "Mixpanel", category: .analytics, description: "Product analytics"),
        "amplitude.com": ThirdPartyProvider(name: "Amplitude", category: .analytics, description: "Product analytics"),
    ]

    static func identify(domain: String) -> ThirdPartyProvider? {
        // Try exact match first
        if let provider = providers[domain] {
            return provider
        }

        // Try subdomain match
        for (key, provider) in providers {
            if domain.hasSuffix(key) {
                return provider
            }
        }

        return nil
    }
}

/// Third-party analysis manager
@MainActor
class ThirdPartyAnalyzer: ObservableObject {
    @Published var domains: [ThirdPartyDomain] = []
    @Published var firstPartyDomain: String = ""

    func analyze(monitor: NetworkMonitor) {
        domains.removeAll()

        // Determine first-party domain (most common domain in resources)
        let domainCounts = Dictionary(grouping: monitor.resources, by: { $0.domain })
            .mapValues { $0.count }
        firstPartyDomain = domainCounts.max(by: { $0.value < $1.value })?.key ?? ""

        // Group resources by domain
        let groupedByDomain = Dictionary(grouping: monitor.resources, by: { $0.domain })

        for (domain, resources) in groupedByDomain {
            // Skip empty domain
            if domain.isEmpty { continue }

            // Identify provider
            let provider = ThirdPartyProvider.identify(domain: domain)

            let thirdPartyDomain = ThirdPartyDomain(
                domain: domain,
                provider: provider,
                resources: resources
            )

            domains.append(thirdPartyDomain)
        }

        // Sort by total duration (highest impact first)
        domains.sort { $0.totalDuration > $1.totalDuration }
    }

    var thirdPartyDomains: [ThirdPartyDomain] {
        return domains.filter { $0.domain != firstPartyDomain }
    }

    var firstPartyDomains: [ThirdPartyDomain] {
        return domains.filter { $0.domain == firstPartyDomain }
    }

    var totalThirdPartySize: Int64 {
        thirdPartyDomains.reduce(0) { $0 + $1.totalSize }
    }

    var totalThirdPartyRequests: Int {
        thirdPartyDomains.reduce(0) { $0 + $1.requestCount }
    }

    var thirdPartyPercentage: Double {
        let totalSize = domains.reduce(0) { $0 + $1.totalSize }
        guard totalSize > 0 else { return 0 }
        return Double(totalThirdPartySize) / Double(totalSize) * 100
    }

    func categorySummary() -> [ThirdPartyProvider.Category: Int] {
        var summary: [ThirdPartyProvider.Category: Int] = [:]

        for domain in thirdPartyDomains {
            if let provider = domain.provider {
                summary[provider.category, default: 0] += domain.requestCount
            }
        }

        return summary
    }

    private func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
