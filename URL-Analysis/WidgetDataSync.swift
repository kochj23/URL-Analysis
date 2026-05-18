//
//  WidgetDataSync.swift
//  URL Analysis
//
//  Syncs analysis data to the widget via App Group
//  Created by Jordan Koch on 2026-02-04
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

// MARK: - App Group Configuration

/// App Group identifier for sharing data between app and widget
private let appGroupIdentifier = "group.com.jkoch.urlanalysis"
private let widgetDataFileName = "widget_data.json"

// MARK: - Widget Data Models (duplicated for main app)

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
}

// MARK: - Widget Data Sync Manager

/// Manages syncing data from the main app to the widget
@MainActor
class WidgetDataSyncManager: ObservableObject {
    static let shared = WidgetDataSyncManager()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private var dataFileURL: URL? {
        containerURL?.appendingPathComponent(widgetDataFileName)
    }

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public Methods

    /// Sync a new analysis session to the widget
    func syncAnalysis(_ session: PersistentSession) {
        let entry = createWidgetEntry(from: session)

        let currentData = loadWidgetData() ?? createEmptyData()

        // Add new entry at the beginning
        var entries = currentData.recentAnalyses
        entries.insert(entry, at: 0)

        // Keep only the most recent 10 entries
        if entries.count > 10 {
            entries = Array(entries.prefix(10))
        }

        // Calculate updated statistics
        let stats = calculateStatistics(from: entries)

        let updatedData = WidgetAnalysisData(
            lastUpdated: Date(),
            recentAnalyses: entries,
            backendStatus: currentData.backendStatus,
            statistics: stats
        )

        saveWidgetData(updatedData)
        print("[WidgetSync] Analysis synced to widget: \(session.domain)")
    }

    /// Sync multiple sessions (e.g., on app launch)
    func syncSessions(_ sessions: [PersistentSession]) {
        let entries = sessions.prefix(10).map { createWidgetEntry(from: $0) }

        let stats = calculateStatistics(from: Array(entries))
        let backendStatus = getCurrentBackendStatus()

        let data = WidgetAnalysisData(
            lastUpdated: Date(),
            recentAnalyses: Array(entries),
            backendStatus: backendStatus,
            statistics: stats
        )

        saveWidgetData(data)
        print("[WidgetSync] Synced \(entries.count) sessions to widget")
    }

    /// Update backend status in widget
    func syncBackendStatus() {
        let status = getCurrentBackendStatus()

        let currentData = loadWidgetData() ?? createEmptyData()

        let updatedData = WidgetAnalysisData(
            lastUpdated: Date(),
            recentAnalyses: currentData.recentAnalyses,
            backendStatus: status,
            statistics: currentData.statistics
        )

        saveWidgetData(updatedData)
        print("[WidgetSync] Backend status synced: \(status.activeBackend ?? "None")")
    }

    /// Force widget refresh
    func refreshWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "URLAnalysisWidget")
        print("[WidgetSync] Widget timeline refresh requested")
    }

    // MARK: - Private Methods

    private func loadWidgetData() -> WidgetAnalysisData? {
        guard let url = dataFileURL else {
            print("[WidgetSync] Error: Could not get App Group container URL")
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(WidgetAnalysisData.self, from: data)
        } catch {
            print("[WidgetSync] Error loading widget data: \(error)")
            return nil
        }
    }

    private func saveWidgetData(_ data: WidgetAnalysisData) {
        guard let url = dataFileURL else {
            print("[WidgetSync] Error: Could not get App Group container URL")
            return
        }

        do {
            // Ensure directory exists
            if let containerURL = containerURL {
                try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            }

            let jsonData = try encoder.encode(data)
            try jsonData.write(to: url, options: .atomic)

            // Notify widget to reload
            WidgetCenter.shared.reloadTimelines(ofKind: "URLAnalysisWidget")
        } catch {
            print("[WidgetSync] Error saving widget data: \(error)")
        }
    }

    private func createWidgetEntry(from session: PersistentSession) -> WidgetAnalysisEntry {
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

    private func getCurrentBackendStatus() -> WidgetAnalysisData.BackendStatus {
        let manager = AIBackendManager.shared
        return WidgetAnalysisData.BackendStatus(
            isAvailable: true,
            activeBackend: manager.activeBackend.rawValue,
            lastChecked: Date()
        )
    }

    private func createEmptyData() -> WidgetAnalysisData {
        WidgetAnalysisData(
            lastUpdated: Date(),
            recentAnalyses: [],
            backendStatus: getCurrentBackendStatus(),
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

// MARK: - SessionHistoryManager Extension

extension SessionHistoryManager {
    /// Sync all sessions to widget on app launch
    func syncToWidget() {
        Task { @MainActor in
            let recentSessions = Array(sessions.prefix(10))
            WidgetDataSyncManager.shared.syncSessions(recentSessions)
        }
    }
}

// MARK: - Convenience for Analysis Completion

/// Call this after completing an analysis to sync to widget
func syncAnalysisToWidget(_ session: PersistentSession) {
    Task { @MainActor in
        WidgetDataSyncManager.shared.syncAnalysis(session)
    }
}
