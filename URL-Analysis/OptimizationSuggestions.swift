//
//  OptimizationSuggestions.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI

/// Optimization suggestion with impact and difficulty
struct OptimizationSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let impact: Impact
    let difficulty: Difficulty
    let category: Category
    let affectedResources: [ResourceDetail]
    let estimatedSavings: String?
    let currentState: String  // Current metrics
    let targetState: String?  // What it should be

    struct ResourceDetail {
        let url: String
        let size: Int64
        let type: NetworkResource.ResourceType
        let duration: TimeInterval
        let specificIssue: String?  // Specific problem with this resource
    }

    enum Impact: String, CaseIterable {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .blue
            }
        }

        var weight: Int {
            switch self {
            case .critical: return 4
            case .high: return 3
            case .medium: return 2
            case .low: return 1
            }
        }
    }

    enum Difficulty: String, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"

        var color: Color {
            switch self {
            case .easy: return .green
            case .medium: return .orange
            case .hard: return .red
            }
        }
    }

    enum Category: String, CaseIterable {
        case compression = "Compression"
        case images = "Images"
        case caching = "Caching"
        case renderBlocking = "Render Blocking"
        case javascript = "JavaScript"
        case css = "CSS"
        case fonts = "Fonts"
        case thirdParty = "Third-Party"
    }
}

/// Analyzes resources and generates optimization suggestions
@MainActor
class OptimizationAnalyzer: ObservableObject {
    @Published var suggestions: [OptimizationSuggestion] = []

    func analyze(monitor: NetworkMonitor) {
        suggestions.removeAll()

        analyzeCompression(monitor)
        analyzeImages(monitor)
        analyzeCaching(monitor)
        analyzeRenderBlocking(monitor)
        analyzeJavaScript(monitor)
        analyzeCSS(monitor)
        analyzeFonts(monitor)
        analyzeConnections(monitor)

        // Sort by impact (critical first) then by difficulty (easy first)
        suggestions.sort { (lhs, rhs) in
            if lhs.impact.weight != rhs.impact.weight {
                return lhs.impact.weight > rhs.impact.weight
            }
            return lhs.difficulty.rawValue < rhs.difficulty.rawValue
        }
    }

    private func analyzeCompression(_ monitor: NetworkMonitor) {
        // Find text resources without compression
        let textTypes: Set<NetworkResource.ResourceType> = [.script, .stylesheet, .document, .xhr]
        let uncompressed = monitor.resources.filter { resource in
            textTypes.contains(resource.resourceType) &&
            resource.responseSize > 1024 &&  // > 1 KB
            !hasCompressionHeader(resource)
        }

        if !uncompressed.isEmpty {
            let totalSize = uncompressed.reduce(0) { $0 + $1.responseSize }
            let estimatedSavings = Int64(Double(totalSize) * 0.7)  // ~70% compression

            // Group by type for better reporting
            let byType = Dictionary(grouping: uncompressed, by: { $0.resourceType })
            var typeBreakdown = byType.map { type, resources in
                "\(resources.count) \(type.rawValue)"
            }.joined(separator: ", ")

            let resourceDetails = uncompressed.map { resource -> OptimizationSuggestion.ResourceDetail in
                return OptimizationSuggestion.ResourceDetail(
                    url: resource.url,
                    size: resource.responseSize,
                    type: resource.resourceType,
                    duration: resource.totalDuration,
                    specificIssue: "Missing Content-Encoding header (gzip/brotli)"
                )
            }

            suggestions.append(OptimizationSuggestion(
                title: "Enable Gzip/Brotli Compression",
                description: "\(uncompressed.count) text-based resources (\(typeBreakdown)) totaling \(formatSize(totalSize)) are served without compression. Text files typically compress 60-80%.",
                impact: totalSize > 1_048_576 ? .critical : .high,
                difficulty: .easy,
                category: .compression,
                affectedResources: resourceDetails,
                estimatedSavings: "Current size: \(formatSize(totalSize)). With compression: ~\(formatSize(totalSize - estimatedSavings)) (saves \(formatSize(estimatedSavings)) or \(Int(Double(estimatedSavings) / Double(totalSize) * 100))%)",
                currentState: "\(uncompressed.count) uncompressed files, \(formatSize(totalSize)) total",
                targetState: "Enable gzip (compression level 6) or brotli (level 4) on server"
            ))
        }
    }

    private func analyzeImages(_ monitor: NetworkMonitor) {
        let images = monitor.resources.filter { $0.resourceType == .image }

        // Large images
        let largeImages = images.filter { $0.responseSize > 500_000 }  // > 500 KB
        if !largeImages.isEmpty {
            let totalSize = largeImages.reduce(0) { $0 + $1.responseSize }
            let avgSize = totalSize / Int64(largeImages.count)
            let largestImage = largeImages.max(by: { $0.responseSize < $1.responseSize })!

            let resourceDetails = largeImages.map { resource -> OptimizationSuggestion.ResourceDetail in
                let fileExtension = URL(string: resource.url)?.pathExtension.uppercased() ?? "Unknown"
                let sizeStr = self.formatSize(resource.responseSize)
                return OptimizationSuggestion.ResourceDetail(
                    url: resource.url,
                    size: resource.responseSize,
                    type: resource.resourceType,
                    duration: resource.totalDuration,
                    specificIssue: "\(sizeStr) \(fileExtension) image - Convert to WebP and resize appropriately"
                )
            }

            suggestions.append(OptimizationSuggestion(
                title: "Optimize Large Images",
                description: "\(largeImages.count) images exceed 500 KB each. Largest is \(formatSize(largestImage.responseSize)). Modern formats (WebP, AVIF) and proper sizing can dramatically reduce file size while maintaining quality.",
                impact: .high,
                difficulty: .medium,
                category: .images,
                affectedResources: resourceDetails,
                estimatedSavings: "Current total: \(formatSize(totalSize)) across \(largeImages.count) images (avg \(formatSize(avgSize))). Target with WebP: ~\(formatSize(totalSize / 5)) (80% reduction). Potential savings: \(formatSize(totalSize - totalSize / 5))",
                currentState: "\(largeImages.count) images > 500 KB, totaling \(formatSize(totalSize))",
                targetState: "Convert to WebP, resize to actual display dimensions, use srcset for responsive images"
            ))
        }

        // Many images (could lazy load)
        if images.count > 20 {
            let totalImages = images.count
            let aboveFold = 5  // Estimate
            let belowFold = totalImages - aboveFold
            let belowFoldSize = images.suffix(belowFold).reduce(0) { $0 + $1.responseSize }

            let resourceDetails = images.map { resource -> OptimizationSuggestion.ResourceDetail in
                let sizeStr = self.formatSize(resource.responseSize)
                return OptimizationSuggestion.ResourceDetail(
                    url: resource.url,
                    size: resource.responseSize,
                    type: resource.resourceType,
                    duration: resource.totalDuration,
                    specificIssue: "\(sizeStr) - Candidate for lazy loading with loading=\"lazy\" attribute"
                )
            }

            suggestions.append(OptimizationSuggestion(
                title: "Implement Image Lazy Loading",
                description: "\(images.count) images loaded eagerly. Approximately \(belowFold) images (~\(Int(Double(belowFold) / Double(totalImages) * 100))%) are likely below the fold and could be lazy-loaded to improve initial page load.",
                impact: .medium,
                difficulty: .easy,
                category: .images,
                affectedResources: resourceDetails,
                estimatedSavings: "Defer \(formatSize(belowFoldSize)) of images (\(belowFold) images) from initial load. Add loading=\"lazy\" attribute to <img> tags. Initial load could be \(formatSize(belowFoldSize)) smaller.",
                currentState: "\(images.count) images loaded immediately, \(formatSize(images.reduce(0) { $0 + $1.responseSize })) total",
                targetState: "Lazy load images below fold using loading=\"lazy\" or IntersectionObserver API"
            ))
        }
    }

    private func analyzeCaching(_ monitor: NetworkMonitor) {
        // Resources without cache headers
        let uncached = monitor.resources.filter { resource in
            !hasCacheHeaders(resource) && resource.resourceType != .document
        }

        if !uncached.isEmpty {
            let totalSize = uncached.reduce(0) { $0 + $1.responseSize }
            let byType = Dictionary(grouping: uncached, by: { $0.resourceType })

            var typeBreakdown = byType.map { type, resources in
                let typeSize = resources.reduce(0) { $0 + $1.responseSize }
                return "\(resources.count) \(type.rawValue) (\(formatSize(typeSize)))"
            }.joined(separator: ", ")

            let resourceDetails = uncached.map { resource -> OptimizationSuggestion.ResourceDetail in
                return OptimizationSuggestion.ResourceDetail(
                    url: resource.url,
                    size: resource.responseSize,
                    type: resource.resourceType,
                    duration: resource.totalDuration,
                    specificIssue: "No Cache-Control, Expires, or ETag headers - will be re-downloaded on every visit"
                )
            }

            suggestions.append(OptimizationSuggestion(
                title: "Add Cache Headers",
                description: "\(uncached.count) static resources (\(typeBreakdown)) totaling \(formatSize(totalSize)) lack cache headers. Every repeat visitor re-downloads these files unnecessarily.",
                impact: .medium,
                difficulty: .easy,
                category: .caching,
                affectedResources: resourceDetails,
                estimatedSavings: "Repeat visitors currently re-download \(formatSize(totalSize)) unnecessarily. With proper caching: 0 bytes on repeat visits. Cache-Control: max-age=31536000 for static assets could save \(uncached.count) requests (\(formatSize(totalSize))) per repeat visit.",
                currentState: "\(uncached.count) resources without caching, \(formatSize(totalSize)) re-downloaded per visit",
                targetState: "Add Cache-Control: max-age=31536000 for CSS/JS/images, with versioned URLs for cache busting"
            ))
        }
    }

    private func analyzeRenderBlocking(_ monitor: NetworkMonitor) {
        // CSS and JS in the head typically blocks rendering
        let blockingScripts = monitor.resources.filter { resource in
            resource.resourceType == .script &&
            resource.startTime.timeIntervalSince(monitor.sessionStartTime ?? Date()) < 1.0
        }

        let blockingCSS = monitor.resources.filter { resource in
            resource.resourceType == .stylesheet &&
            resource.startTime.timeIntervalSince(monitor.sessionStartTime ?? Date()) < 1.0
        }

        if !blockingScripts.isEmpty {
            let totalDuration = blockingScripts.reduce(0) { $0 + $1.totalDuration }
            let totalSize = blockingScripts.reduce(0) { $0 + $1.responseSize }
            let longestScript = blockingScripts.max(by: { $0.totalDuration < $1.totalDuration })!

            let resourceDetails = blockingScripts.map { resource -> OptimizationSuggestion.ResourceDetail in
                let fileName = URL(string: resource.url)?.lastPathComponent ?? "unknown"
                let sizeStr = self.formatSize(resource.responseSize)
                let durationStr = self.formatDuration(resource.totalDuration)
                return OptimizationSuggestion.ResourceDetail(
                    url: resource.url,
                    size: resource.responseSize,
                    type: resource.resourceType,
                    duration: resource.totalDuration,
                    specificIssue: "\(fileName): \(sizeStr), \(durationStr) download - Add async or defer attribute"
                )
            }

            suggestions.append(OptimizationSuggestion(
                title: "Defer Non-Critical JavaScript",
                description: "\(blockingScripts.count) JavaScript files (\(formatSize(totalSize))) loaded in first 1 second block HTML parsing and rendering. Each script must download and execute before page can render. Longest blocker: \(formatDuration(longestScript.totalDuration)).",
                impact: .high,
                difficulty: .medium,
                category: .renderBlocking,
                affectedResources: resourceDetails,
                estimatedSavings: "Blocking time: \(formatDuration(totalDuration)) total. Using async/defer could improve First Contentful Paint by \(formatDuration(totalDuration * 0.7)). Initial render could start \(formatDuration(totalDuration)) sooner. Add <script async> for non-critical or <script defer> for execution-order-dependent scripts.",
                currentState: "\(blockingScripts.count) render-blocking scripts, \(formatDuration(totalDuration)) blocking time, \(formatSize(totalSize)) must load before render",
                targetState: "Add async attribute for analytics/ads, defer for app logic, inline critical scripts"
            ))
        }

        if blockingCSS.count > 3 {
            let totalSize = blockingCSS.reduce(0) { $0 + $1.responseSize }
            let totalDuration = blockingCSS.reduce(0) { $0 + $1.totalDuration }

            let resourceDetails = blockingCSS.map { resource -> OptimizationSuggestion.ResourceDetail in
                let fileName = URL(string: resource.url)?.lastPathComponent ?? "unknown"
                let sizeStr = self.formatSize(resource.responseSize)
                let durationStr = self.formatDuration(resource.totalDuration)
                return OptimizationSuggestion.ResourceDetail(
                    url: resource.url,
                    size: resource.responseSize,
                    type: resource.resourceType,
                    duration: resource.totalDuration,
                    specificIssue: "\(fileName): \(sizeStr), \(durationStr) - Consider inlining critical CSS"
                )
            }

            suggestions.append(OptimizationSuggestion(
                title: "Reduce Render-Blocking CSS",
                description: "\(blockingCSS.count) CSS files (\(formatSize(totalSize))) block rendering in the critical path. Browser must download and parse all CSS before rendering page. Total blocking time: \(formatDuration(totalDuration)).",
                impact: .high,
                difficulty: .hard,
                category: .renderBlocking,
                affectedResources: resourceDetails,
                estimatedSavings: "Current: All \(formatSize(totalSize)) of CSS blocks rendering for \(formatDuration(totalDuration)). Inline ~10-15 KB of critical CSS, load rest with <link rel=\"preload\"> or media queries. Could improve First Paint by \(formatDuration(totalDuration * 0.6)) and reduce blocking CSS to ~10 KB.",
                currentState: "\(blockingCSS.count) render-blocking stylesheets, \(formatSize(totalSize)) total, \(formatDuration(totalDuration)) blocking time",
                targetState: "Inline critical CSS (~10 KB), async load non-critical with rel=\"preload\" as=\"style\""
            ))
        }
    }

    private func analyzeJavaScript(_ monitor: NetworkMonitor) {
        let scripts = monitor.resources.filter { $0.resourceType == .script }
        let totalJSSize = scripts.reduce(0) { $0 + $1.responseSize }

        if totalJSSize > 1_048_576 {  // > 1 MB
            let largestScripts = scripts.sorted(by: { $0.responseSize > $1.responseSize }).prefix(5)
            let top5Size = largestScripts.reduce(0) { $0 + $1.responseSize }

            let resourceDetails = scripts.map { resource -> OptimizationSuggestion.ResourceDetail in
                let fileName = URL(string: resource.url)?.lastPathComponent ?? "unknown"
                let percent = Int(Double(resource.responseSize) / Double(totalJSSize) * 100)
                let sizeStr = self.formatSize(resource.responseSize)
                return OptimizationSuggestion.ResourceDetail(
                    url: resource.url,
                    size: resource.responseSize,
                    type: resource.resourceType,
                    duration: resource.totalDuration,
                    specificIssue: "\(fileName): \(sizeStr) (\(percent)% of total) - Consider code splitting, tree shaking"
                )
            }

            suggestions.append(OptimizationSuggestion(
                title: "Reduce JavaScript Bundle Size",
                description: "\(scripts.count) JavaScript files totaling \(formatSize(totalJSSize)). Top 5 largest scripts account for \(formatSize(top5Size)) (\(Int(Double(top5Size) / Double(totalJSSize) * 100))%). Excessive JavaScript increases parse/compile time and delays interactivity.",
                impact: .high,
                difficulty: .medium,
                category: .javascript,
                affectedResources: resourceDetails,
                estimatedSavings: "Current: \(formatSize(totalJSSize)) JavaScript (\(scripts.count) files). Target: < 500 KB total. Use code splitting, tree shaking, remove unused libraries. Webpack Bundle Analyzer can identify unused code. Potential savings: ~\(formatSize(totalJSSize - 524_288)) (reduce by 50-70%).",
                currentState: "\(scripts.count) JS files, \(formatSize(totalJSSize)) total (target: < 500 KB)",
                targetState: "Code split by route, tree shake unused code, dynamic imports, remove duplicate dependencies"
            ))
        }
    }

    private func analyzeCSS(_ monitor: NetworkMonitor) {
        let stylesheets = monitor.resources.filter { $0.resourceType == .stylesheet }
        let totalCSSSize = stylesheets.reduce(0) { $0 + $1.responseSize }

        if totalCSSSize > 204_800 {  // > 200 KB
            let largestCSS = stylesheets.max(by: { $0.responseSize < $1.responseSize })!

            let resourceDetails = stylesheets.map { resource -> OptimizationSuggestion.ResourceDetail in
                let fileName = URL(string: resource.url)?.lastPathComponent ?? "unknown"
                let percent = Int(Double(resource.responseSize) / Double(totalCSSSize) * 100)
                let sizeStr = self.formatSize(resource.responseSize)
                return OptimizationSuggestion.ResourceDetail(
                    url: resource.url,
                    size: resource.responseSize,
                    type: resource.resourceType,
                    duration: resource.totalDuration,
                    specificIssue: "\(fileName): \(sizeStr) (\(percent)% of total) - Remove unused rules with PurgeCSS or UnCSS"
                )
            }

            suggestions.append(OptimizationSuggestion(
                title: "Reduce CSS Bundle Size",
                description: "\(stylesheets.count) CSS files totaling \(formatSize(totalCSSSize)). Largest file: \(formatSize(largestCSS.responseSize)). Most sites only use 10-30% of their CSS rules. Tools like PurgeCSS can remove unused styles.",
                impact: .medium,
                difficulty: .medium,
                category: .css,
                affectedResources: resourceDetails,
                estimatedSavings: "Current: \(formatSize(totalCSSSize)) CSS (\(stylesheets.count) files). Target: < 100 KB total. Remove unused rules (typically 70-80% unused), combine files, minify. Use PurgeCSS, UnCSS, or CSS coverage tools. Potential savings: ~\(formatSize(Int64(Double(totalCSSSize) * 0.7))) (70% reduction).",
                currentState: "\(stylesheets.count) CSS files, \(formatSize(totalCSSSize)) total (target: < 100 KB)",
                targetState: "Remove unused CSS rules, combine files, minify, consider utility-first CSS frameworks"
            ))
        }
    }

    private func analyzeFonts(_ monitor: NetworkMonitor) {
        let fonts = monitor.resources.filter { $0.resourceType == .font }

        if fonts.count > 4 {
            let totalSize = fonts.reduce(0) { $0 + $1.responseSize }
            let avgSize = totalSize / Int64(fonts.count)

            let resourceDetails = fonts.map { resource -> OptimizationSuggestion.ResourceDetail in
                let fileName = URL(string: resource.url)?.lastPathComponent ?? "unknown"
                let format = URL(string: resource.url)?.pathExtension.uppercased() ?? "Unknown"
                let sizeStr = self.formatSize(resource.responseSize)
                let durationStr = self.formatDuration(resource.totalDuration)
                return OptimizationSuggestion.ResourceDetail(
                    url: resource.url,
                    size: resource.responseSize,
                    type: resource.resourceType,
                    duration: resource.totalDuration,
                    specificIssue: "\(fileName): \(sizeStr) \(format) - Each font family/weight adds \(durationStr) load time"
                )
            }

            suggestions.append(OptimizationSuggestion(
                title: "Reduce Font Variants",
                description: "\(fonts.count) font files loaded, totaling \(formatSize(totalSize)) (avg \(formatSize(avgSize)) per font). Each font weight/style is a separate file. Most sites only need 2-3 weights (Regular 400, Medium 500, Bold 700).",
                impact: .medium,
                difficulty: .easy,
                category: .fonts,
                affectedResources: resourceDetails,
                estimatedSavings: "Current: \(fonts.count) fonts, \(formatSize(totalSize)) total. Target: 2-3 fonts max. Removing \(fonts.count - 3) fonts saves ~\(formatSize(avgSize * Int64(fonts.count - 3))) (estimated \(fonts.count - 3) × \(formatSize(avgSize))). Use font-display: swap for better perceived performance.",
                currentState: "\(fonts.count) font files, \(formatSize(totalSize)) total",
                targetState: "Keep only essential weights (Regular, Bold), use font-display: swap, subset fonts for languages needed"
            ))
        }
    }

    private func analyzeConnections(_ monitor: NetworkMonitor) {
        let domainGroups = Dictionary(grouping: monitor.resources, by: { $0.domain })
        let domains = Set(domainGroups.keys)

        if domains.count > 10 {
            // Calculate per-domain stats
            let domainStats = domainGroups.map { domain, resources -> (domain: String, count: Int, size: Int64, duration: TimeInterval) in
                let totalSize = resources.reduce(0) { $0 + $1.responseSize }
                let maxDuration = resources.map { $0.totalDuration }.max() ?? 0
                return (domain, resources.count, totalSize, maxDuration)
            }.sorted(by: { $0.count > $1.count })

            let resourceDetails = domainStats.map { stat -> OptimizationSuggestion.ResourceDetail in
                let sizeStr = self.formatSize(stat.size)
                return OptimizationSuggestion.ResourceDetail(
                    url: stat.domain,
                    size: stat.size,
                    type: .other,
                    duration: stat.duration,
                    specificIssue: "\(stat.count) requests, \(sizeStr) - Each domain requires DNS + TCP + SSL (~300ms overhead)"
                )
            }

            let estimatedConnectionOverhead = TimeInterval(domains.count) * 0.3  // 300ms per domain
            let top5Domains = domainStats.prefix(5).map { $0.domain }.joined(separator: ", ")

            suggestions.append(OptimizationSuggestion(
                title: "Reduce Third-Party Domains",
                description: "\(domains.count) unique domains detected. Each requires separate DNS lookup, TCP connection, and SSL handshake (~300ms each). Top 5 chattiest domains: \(top5Domains). Connection overhead: ~\(formatDuration(estimatedConnectionOverhead)).",
                impact: .medium,
                difficulty: .hard,
                category: .thirdParty,
                affectedResources: resourceDetails,
                estimatedSavings: "Connection overhead: ~\(formatDuration(estimatedConnectionOverhead)) total (\(domains.count) domains × ~300ms). Reducing to < 10 domains saves ~\(formatDuration(TimeInterval(domains.count - 10) * 0.3)). Combine resources on fewer domains, remove unnecessary third-parties, use resource hints (dns-prefetch, preconnect) for critical domains.",
                currentState: "\(domains.count) unique domains, ~\(formatDuration(estimatedConnectionOverhead)) connection overhead",
                targetState: "Reduce to < 10 domains, self-host critical resources, use dns-prefetch for remaining third-parties"
            ))
        }
    }

    private func hasCompressionHeader(_ resource: NetworkResource) -> Bool {
        return resource.responseHeaders.keys.contains { key in
            key.lowercased() == "content-encoding"
        }
    }

    private func hasCacheHeaders(_ resource: NetworkResource) -> Bool {
        return resource.responseHeaders.keys.contains { key in
            let lowercased = key.lowercased()
            return lowercased == "cache-control" || lowercased == "expires" || lowercased == "etag"
        }
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
