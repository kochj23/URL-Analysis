//
//  SharedDataManager.swift
//  URL-Analysis Widget
//
//  Manages data sharing between main app and widget via App Group
//  Created by Jordan Koch on 2026-02-04
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

/// App Group identifier for sharing data between app and widget
let appGroupIdentifier = "group.com.jkoch.urlanalysis"

// MARK: - Shared Data Manager

class SharedDataManager {
    static let shared = SharedDataManager()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let dataFileName = "widget_data.json"

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private var dataFileURL: URL? {
        containerURL?.appendingPathComponent(dataFileName)
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Read Data

    /// Load widget data from App Group container
    func loadWidgetData() -> WidgetAnalysisData? {
        guard let url = dataFileURL else {
            print("[Widget] Error: Could not get App Group container URL")
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[Widget] No existing widget data found")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let widgetData = try decoder.decode(WidgetAnalysisData.self, from: data)
            print("[Widget] Successfully loaded widget data with \(widgetData.recentAnalyses.count) analyses")
            return widgetData
        } catch {
            print("[Widget] Error loading widget data: \(error)")
            return nil
        }
    }

    // MARK: - Write Data

    /// Save widget data to App Group container (called from main app)
    func saveWidgetData(_ data: WidgetAnalysisData) {
        guard let url = dataFileURL else {
            print("[Widget] Error: Could not get App Group container URL")
            return
        }

        do {
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: url, options: .atomic)
            print("[Widget] Successfully saved widget data")

            // Notify widget to reload
            WidgetCenter.shared.reloadTimelines(ofKind: "URLAnalysisWidget")
        } catch {
            print("[Widget] Error saving widget data: \(error)")
        }
    }

    // MARK: - Convenience Methods

    /// Update widget data with a new analysis entry
    func addAnalysisEntry(_ entry: WidgetAnalysisEntry, backendStatus: WidgetAnalysisData.BackendStatus? = nil) {
        let currentData = loadWidgetData() ?? createEmptyData()

        // Add new entry at the beginning
        var entries = currentData.recentAnalyses
        entries.insert(entry, at: 0)

        // Keep only the most recent 10 entries
        if entries.count > 10 {
            entries = Array(entries.prefix(10))
        }

        // Update statistics
        let stats = calculateStatistics(from: entries)

        let updatedData = WidgetAnalysisData(
            lastUpdated: Date(),
            recentAnalyses: entries,
            backendStatus: backendStatus ?? currentData.backendStatus,
            statistics: stats
        )

        saveWidgetData(updatedData)
    }

    /// Update backend status only
    func updateBackendStatus(_ status: WidgetAnalysisData.BackendStatus) {
        let currentData = loadWidgetData() ?? createEmptyData()

        let updatedData = WidgetAnalysisData(
            lastUpdated: Date(),
            recentAnalyses: currentData.recentAnalyses,
            backendStatus: status,
            statistics: currentData.statistics
        )

        saveWidgetData(updatedData)
    }

    /// Create widget entry from PersistentSession
    func createWidgetEntry(from session: PersistentSession) -> WidgetAnalysisEntry {
        WidgetAnalysisEntry(
            id: session.id,
            url: session.url,
            domain: session.domain,
            timestamp: session.timestamp,
            overallScore: session.overallScore.map { Int($0) },
            lcpValue: session.lcpValue,
            fidValue: session.fidValue,
            clsValue: session.clsValue,
            loadTime: session.duration,
            requestCount: session.requestCount,
            totalSize: session.totalSize
        )
    }

    // MARK: - Private Helpers

    private func createEmptyData() -> WidgetAnalysisData {
        WidgetAnalysisData(
            lastUpdated: Date(),
            recentAnalyses: [],
            backendStatus: WidgetAnalysisData.BackendStatus(
                isAvailable: false,
                activeBackend: nil,
                lastChecked: Date()
            ),
            statistics: WidgetAnalysisData.AnalysisStatistics(
                totalAnalyses: 0,
                averageScore: 0,
                todayCount: 0,
                weekCount: 0
            )
        )
    }

    private func calculateStatistics(from entries: [WidgetAnalysisEntry]) -> WidgetAnalysisData.AnalysisStatistics {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!

        let todayEntries = entries.filter { $0.timestamp >= todayStart }
        let weekEntries = entries.filter { $0.timestamp >= weekAgo }

        let scores = entries.compactMap { $0.overallScore }
        let averageScore = scores.isEmpty ? 0.0 : Double(scores.reduce(0, +)) / Double(scores.count)

        return WidgetAnalysisData.AnalysisStatistics(
            totalAnalyses: entries.count,
            averageScore: averageScore,
            todayCount: todayEntries.count,
            weekCount: weekEntries.count
        )
    }
}

// MARK: - PersistentSession Extension (for reference in main app)

/// This struct mirrors PersistentSession from the main app for widget data creation
/// The main app should import this or use the createWidgetEntry method
struct PersistentSession {
    let id: UUID
    let url: String
    let timestamp: Date
    let overallScore: Double?
    let lcpValue: String?
    let fidValue: String?
    let clsValue: String?
    let duration: TimeInterval
    let requestCount: Int
    let totalSize: Int64

    var domain: String {
        guard let url = URL(string: url),
              let host = url.host else {
            return url
        }
        return host
    }
}
