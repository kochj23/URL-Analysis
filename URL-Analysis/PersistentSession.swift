//
//  PersistentSession.swift
//  URL Analysis
//
//  Persistent storage model for analysis sessions
//  Created by Jordan Koch on 2026-01-22
//

import Foundation
import AppKit

/// A persistent snapshot of an analysis session
struct PersistentSession: Codable, Identifiable {
    let id: UUID
    let url: String
    let timestamp: Date
    let deviceProfile: DeviceProfile?

    // Core performance data (simplified for Codable)
    let resourceCount: Int
    let resourceData: String  // JSON string of resources

    // Web Vitals (as simple values)
    let lcpValue: String?
    let clsValue: String?
    let fidValue: String?

    // Performance Score (as simple value)
    let overallScore: Double?

    // Analysis results
    let budgetViolations: [String]
    let optimizationCount: Int
    let thirdPartyCount: Int

    // Metadata
    let duration: TimeInterval
    let totalSize: Int64
    let requestCount: Int
    var tags: [String]
    var notes: String

    // Screenshots (stored as PNG data)
    let screenshots: [ScreenshotData]

    struct ScreenshotData: Codable {
        let timestamp: TimeInterval
        let imageData: Data

        var image: NSImage? {
            NSImage(data: imageData)
        }
    }

    init(id: UUID = UUID(), url: String, timestamp: Date = Date(), deviceProfile: DeviceProfile? = nil,
         resourceCount: Int, resourceData: String, lcpValue: String?, clsValue: String?, fidValue: String?,
         overallScore: Double?, budgetViolations: [String], optimizationCount: Int, thirdPartyCount: Int,
         duration: TimeInterval, totalSize: Int64, requestCount: Int, tags: [String] = [],
         notes: String = "", screenshots: [ScreenshotData] = []) {
        self.id = id
        self.url = url
        self.timestamp = timestamp
        self.deviceProfile = deviceProfile
        self.resourceCount = resourceCount
        self.resourceData = resourceData
        self.lcpValue = lcpValue
        self.clsValue = clsValue
        self.fidValue = fidValue
        self.overallScore = overallScore
        self.budgetViolations = budgetViolations
        self.optimizationCount = optimizationCount
        self.thirdPartyCount = thirdPartyCount
        self.duration = duration
        self.totalSize = totalSize
        self.requestCount = requestCount
        self.tags = tags
        self.notes = notes
        self.screenshots = screenshots
    }

    /// Create from AnalysisSession
    @MainActor
    static func from(_ session: AnalysisSession, deviceProfile: DeviceProfile? = nil) -> PersistentSession {
        // Convert screenshots
        let screenshotData = session.timeline.frames.compactMap { frame -> ScreenshotData? in
            let image = frame.image
            guard let imageData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: imageData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return nil
            }
            return ScreenshotData(timestamp: frame.timestamp, imageData: pngData)
        }

        // Encode resources to JSON string (simplified storage)
        let resourceDataString: String
        if let jsonData = try? JSONEncoder().encode(session.monitor.resources),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            resourceDataString = jsonString
        } else {
            resourceDataString = "[]"
        }

        return PersistentSession(
            url: session.url,
            deviceProfile: deviceProfile,
            resourceCount: session.monitor.resources.count,
            resourceData: resourceDataString,
            lcpValue: session.monitor.webVitals?.lcp.value,
            clsValue: session.monitor.webVitals?.cls.value,
            fidValue: session.monitor.webVitals?.fid.value,
            overallScore: session.monitor.performanceScore.map { Double($0.overall) },
            budgetViolations: [],
            optimizationCount: 0,
            thirdPartyCount: 0,
            duration: session.monitor.totalDuration,
            totalSize: session.monitor.totalSize,
            requestCount: session.monitor.resources.count,
            screenshots: screenshotData
        )
    }

    /// Get domain from URL
    var domain: String {
        guard let url = URL(string: url),
              let host = url.host else {
            return url
        }
        return host
    }

    /// Get formatted timestamp
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    /// Get performance rating
    var performanceRating: String {
        guard let score = overallScore else { return "N/A" }
        if score >= 75 { return "Good" }
        if score >= 50 { return "Needs Improvement" }
        return "Poor"
    }
}

/// Lightweight session metadata for quick loading
struct SessionMetadata: Codable {
    let id: UUID
    let url: String
    let timestamp: Date
    let score: Double?
    let loadTime: TimeInterval
    let totalSize: Int64
    let requestCount: Int
    let deviceName: String?

    init(from session: PersistentSession) {
        self.id = session.id
        self.url = session.url
        self.timestamp = session.timestamp
        self.score = session.overallScore
        self.loadTime = session.duration
        self.totalSize = session.totalSize
        self.requestCount = session.requestCount
        self.deviceName = session.deviceProfile?.name
    }
}

/// Index file for fast session lookup
struct SessionIndex: Codable {
    var sessions: [SessionMetadata]

    mutating func add(_ metadata: SessionMetadata) {
        sessions.append(metadata)
        // Keep sorted by timestamp (newest first)
        sessions.sort { $0.timestamp > $1.timestamp }
    }

    mutating func remove(id: UUID) {
        sessions.removeAll { $0.id == id }
    }
}
