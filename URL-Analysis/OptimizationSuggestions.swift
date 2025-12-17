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
    let affectedResources: [String]  // URLs of affected resources
    let estimatedSavings: String?

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

            suggestions.append(OptimizationSuggestion(
                title: "Enable Gzip/Brotli Compression",
                description: "\(uncompressed.count) text resources are served uncompressed. Enabling compression could reduce transfer size significantly.",
                impact: totalSize > 1_048_576 ? .critical : .high,
                difficulty: .easy,
                category: .compression,
                affectedResources: uncompressed.map { $0.url },
                estimatedSavings: "Potential savings: \(formatSize(estimatedSavings))"
            ))
        }
    }

    private func analyzeImages(_ monitor: NetworkMonitor) {
        let images = monitor.resources.filter { $0.resourceType == .image }

        // Large images
        let largeImages = images.filter { $0.responseSize > 500_000 }  // > 500 KB
        if !largeImages.isEmpty {
            let totalSize = largeImages.reduce(0) { $0 + $1.responseSize }

            suggestions.append(OptimizationSuggestion(
                title: "Optimize Large Images",
                description: "\(largeImages.count) images are larger than 500 KB. Consider using WebP format, proper sizing, and compression.",
                impact: .high,
                difficulty: .medium,
                category: .images,
                affectedResources: largeImages.map { $0.url },
                estimatedSavings: "Current total: \(formatSize(totalSize)). WebP could save 80%+."
            ))
        }

        // Many images (could lazy load)
        if images.count > 20 {
            suggestions.append(OptimizationSuggestion(
                title: "Implement Image Lazy Loading",
                description: "\(images.count) images loaded. Use lazy loading for off-screen images to improve initial load time.",
                impact: .medium,
                difficulty: .easy,
                category: .images,
                affectedResources: images.map { $0.url },
                estimatedSavings: "Could defer loading of ~\(images.count - 5) images."
            ))
        }
    }

    private func analyzeCaching(_ monitor: NetworkMonitor) {
        // Resources without cache headers
        let uncached = monitor.resources.filter { resource in
            !hasCacheHeaders(resource) && resource.resourceType != .document
        }

        if !uncached.isEmpty {
            suggestions.append(OptimizationSuggestion(
                title: "Add Cache Headers",
                description: "\(uncached.count) resources lack proper cache headers. Static assets should have long cache times.",
                impact: .medium,
                difficulty: .easy,
                category: .caching,
                affectedResources: uncached.map { $0.url },
                estimatedSavings: "Repeat visitors could load \(uncached.count) fewer resources."
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
            suggestions.append(OptimizationSuggestion(
                title: "Defer Non-Critical JavaScript",
                description: "\(blockingScripts.count) JavaScript files loaded early may block rendering. Use async/defer attributes.",
                impact: .high,
                difficulty: .medium,
                category: .renderBlocking,
                affectedResources: blockingScripts.map { $0.url },
                estimatedSavings: "Could improve First Paint by \(formatDuration(blockingScripts.reduce(0) { $0 + $1.totalDuration }))"
            ))
        }

        if blockingCSS.count > 3 {
            suggestions.append(OptimizationSuggestion(
                title: "Reduce Render-Blocking CSS",
                description: "\(blockingCSS.count) CSS files block rendering. Inline critical CSS and defer non-critical styles.",
                impact: .high,
                difficulty: .hard,
                category: .renderBlocking,
                affectedResources: blockingCSS.map { $0.url },
                estimatedSavings: "Could improve First Paint by inlining critical CSS."
            ))
        }
    }

    private func analyzeJavaScript(_ monitor: NetworkMonitor) {
        let scripts = monitor.resources.filter { $0.resourceType == .script }
        let totalJSSize = scripts.reduce(0) { $0 + $1.responseSize }

        if totalJSSize > 1_048_576 {  // > 1 MB
            suggestions.append(OptimizationSuggestion(
                title: "Reduce JavaScript Size",
                description: "Total JavaScript size is \(formatSize(totalJSSize)). Consider code splitting, tree shaking, and removing unused libraries.",
                impact: .high,
                difficulty: .medium,
                category: .javascript,
                affectedResources: scripts.map { $0.url },
                estimatedSavings: "Target: < 500 KB total JavaScript"
            ))
        }
    }

    private func analyzeCSS(_ monitor: NetworkMonitor) {
        let stylesheets = monitor.resources.filter { $0.resourceType == .stylesheet }
        let totalCSSSize = stylesheets.reduce(0) { $0 + $1.responseSize }

        if totalCSSSize > 204_800 {  // > 200 KB
            suggestions.append(OptimizationSuggestion(
                title: "Reduce CSS Size",
                description: "Total CSS size is \(formatSize(totalCSSSize)). Remove unused styles and consider critical CSS inlining.",
                impact: .medium,
                difficulty: .medium,
                category: .css,
                affectedResources: stylesheets.map { $0.url },
                estimatedSavings: "Target: < 100 KB total CSS"
            ))
        }
    }

    private func analyzeFonts(_ monitor: NetworkMonitor) {
        let fonts = monitor.resources.filter { $0.resourceType == .font }

        if fonts.count > 4 {
            suggestions.append(OptimizationSuggestion(
                title: "Reduce Font Variants",
                description: "\(fonts.count) font files loaded. Each font adds load time. Limit to 2-3 essential fonts.",
                impact: .medium,
                difficulty: .easy,
                category: .fonts,
                affectedResources: fonts.map { $0.url },
                estimatedSavings: "Each font removal saves ~50-200 KB"
            ))
        }
    }

    private func analyzeConnections(_ monitor: NetworkMonitor) {
        let domains = Set(monitor.resources.map { $0.domain })

        if domains.count > 10 {
            suggestions.append(OptimizationSuggestion(
                title: "Reduce Third-Party Domains",
                description: "\(domains.count) different domains require separate connections. Each connection adds latency.",
                impact: .medium,
                difficulty: .hard,
                category: .thirdParty,
                affectedResources: Array(domains),
                estimatedSavings: "Each domain adds ~100-300ms connection overhead"
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
