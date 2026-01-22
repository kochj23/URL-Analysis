//
//  SessionHistoryManager.swift
//  URL Analysis
//
//  Manages persistent storage and retrieval of analysis sessions
//  Created by Jordan Koch on 2026-01-22
//

import Foundation

/// Manages historical analysis sessions with persistent storage
@MainActor
class SessionHistoryManager: ObservableObject {
    @Published var sessions: [PersistentSession] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let storageURL: URL
    private let indexURL: URL
    private var sessionIndex: SessionIndex

    // Retention settings
    private let maxSessions: Int = 1000
    private let maxAgeInDays: Int = 90

    init() {
        // Setup storage directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.storageURL = appSupport
            .appendingPathComponent("URL-Analysis")
            .appendingPathComponent("sessions")
        self.indexURL = storageURL.appendingPathComponent("index.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)

        // Load index
        self.sessionIndex = Self.loadIndex(from: indexURL) ?? SessionIndex(sessions: [])
    }

    // MARK: - Public Methods

    /// Save a session to disk
    func saveSession(_ session: PersistentSession) async throws {
        isLoading = true
        defer { isLoading = false }

        // Save session file
        let filename = "\(session.timestamp.formatted(.iso8601))-\(session.id.uuidString).json"
        let fileURL = storageURL.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(session)
        try data.write(to: fileURL)

        // Update index
        let metadata = SessionMetadata(from: session)
        sessionIndex.add(metadata)
        try saveIndex()

        // Add to in-memory list
        sessions.insert(session, at: 0)

        // Cleanup old sessions
        try await cleanup()
    }

    /// Load all sessions from disk
    func loadSessions() async throws {
        isLoading = true
        defer { isLoading = false }

        // Load from index for better performance
        let decoder = JSONDecoder()

        var loadedSessions: [PersistentSession] = []

        for metadata in sessionIndex.sessions {
            let pattern = "*-\(metadata.id.uuidString).json"
            let files = try FileManager.default.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.contains(metadata.id.uuidString) }

            if let fileURL = files.first {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let session = try decoder.decode(PersistentSession.self, from: data)
                    loadedSessions.append(session)
                } catch {
                    print("Failed to load session \(metadata.id): \(error)")
                }
            }
        }

        sessions = loadedSessions
    }

    /// Delete a session
    func deleteSession(id: UUID) throws {
        // Find and delete file
        let files = try FileManager.default.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains(id.uuidString) }

        for file in files {
            try FileManager.default.removeItem(at: file)
        }

        // Update index
        sessionIndex.remove(id: id)
        try saveIndex()

        // Remove from memory
        sessions.removeAll { $0.id == id }
    }

    /// Search sessions by query and date range
    func search(query: String, from startDate: Date? = nil, to endDate: Date? = nil) -> [PersistentSession] {
        var filtered = sessions

        // Filter by query
        if !query.isEmpty {
            filtered = filtered.filter { session in
                session.url.localizedCaseInsensitiveContains(query) ||
                session.domain.localizedCaseInsensitiveContains(query) ||
                session.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            }
        }

        // Filter by date range
        if let start = startDate {
            filtered = filtered.filter { $0.timestamp >= start }
        }
        if let end = endDate {
            filtered = filtered.filter { $0.timestamp <= end }
        }

        return filtered
    }

    /// Cleanup old sessions beyond retention policy
    func cleanup() async throws {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -maxAgeInDays, to: Date())!

        // Delete sessions older than retention period
        let oldSessions = sessions.filter { $0.timestamp < cutoffDate }
        for session in oldSessions {
            try deleteSession(id: session.id)
        }

        // If still over max sessions, delete oldest
        if sessions.count > maxSessions {
            let excessSessions = sessions
                .sorted { $0.timestamp < $1.timestamp }
                .prefix(sessions.count - maxSessions)

            for session in excessSessions {
                try deleteSession(id: session.id)
            }
        }
    }

    // MARK: - Private Methods

    private func saveIndex() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sessionIndex)
        try data.write(to: indexURL)
    }

    private static func loadIndex(from url: URL) -> SessionIndex? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SessionIndex.self, from: data)
        } catch {
            print("Failed to load index: \(error)")
            return nil
        }
    }

    // MARK: - Quick Filters

    /// Get sessions from today
    var todaySessions: [PersistentSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessions.filter { calendar.startOfDay(for: $0.timestamp) == today }
    }

    /// Get sessions from this week
    var weekSessions: [PersistentSession] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return sessions.filter { $0.timestamp >= weekAgo }
    }

    /// Get sessions from this month
    var monthSessions: [PersistentSession] {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date())!
        return sessions.filter { $0.timestamp >= monthAgo }
    }
}
