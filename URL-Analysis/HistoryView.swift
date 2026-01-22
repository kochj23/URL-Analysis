//
//  HistoryView.swift
//  URL Analysis
//
//  Historical session browser with search and comparison
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// Main historical sessions browser
struct HistoryView: View {
    @ObservedObject var historyManager: SessionHistoryManager
    @State private var searchText = ""
    @State private var dateFilter: DateFilter = .all
    @State private var selectedSession: PersistentSession?
    @State private var selectedSessions: Set<UUID> = []
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    enum DateFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case week = "This Week"
        case month = "This Month"

        var icon: String {
            switch self {
            case .all: return "calendar"
            case .today: return "calendar.badge.clock"
            case .week: return "7.square"
            case .month: return "calendar.badge.plus"
            }
        }
    }

    var filteredSessions: [PersistentSession] {
        var sessions: [PersistentSession]

        switch dateFilter {
        case .all:
            sessions = historyManager.sessions
        case .today:
            sessions = historyManager.todaySessions
        case .week:
            sessions = historyManager.weekSessions
        case .month:
            sessions = historyManager.monthSessions
        }

        if !searchText.isEmpty {
            sessions = historyManager.search(query: searchText, from: nil, to: nil)
        }

        return sessions
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar: Session list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Session History")
                        .font(.headline)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search URL or domain", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(AdaptiveColors.glassBackground(for: colorScheme))
                .cornerRadius(8)
                .padding(.horizontal)

                // Date filter
                Picker("Filter", selection: $dateFilter) {
                    ForEach(DateFilter.allCases, id: \.self) { filter in
                        Label(filter.rawValue, systemImage: filter.icon)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Session list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSessions) { session in
                            SessionListItem(
                                session: session,
                                isSelected: selectedSession?.id == session.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSession = session
                            }
                        }

                        if filteredSessions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No sessions found")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(40)
                        }
                    }
                    .padding()
                }
            }
            .frame(minWidth: 300)
        } detail: {
            // Detail: Selected session
            if let session = selectedSession {
                SessionDetailView(session: session, historyManager: historyManager)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a session to view details")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .task {
            do {
                try await historyManager.loadSessions()
            } catch {
                historyManager.error = error
            }
        }
    }
}

/// Individual session list item
struct SessionListItem: View {
    let session: PersistentSession
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // URL
            Text(session.domain)
                .font(.headline)
                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                .lineLimit(1)

            // Timestamp
            Text(session.formattedTimestamp)
                .font(.caption)
                .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

            // Metrics
            HStack(spacing: 12) {
                // Score
                if let score = session.performanceScore?.overall {
                    Label(String(format: "%.0f", score), systemImage: "speedometer")
                        .font(.caption)
                        .foregroundColor(AdaptiveColors.performanceColor(score: score))
                }

                // Load time
                Label(String(format: "%.2fs", session.duration), systemImage: "clock")
                    .font(.caption)

                // Size
                Label(formatBytes(session.totalSize), systemImage: "arrow.down.circle")
                    .font(.caption)

                // Device
                if let device = session.deviceProfile {
                    Label(device.name, systemImage: device.platformIcon)
                        .font(.caption)
                }
            }
            .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? AdaptiveColors.accent.opacity(0.2) : AdaptiveColors.glassBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? AdaptiveColors.accent : AdaptiveColors.glassBorder(for: colorScheme), lineWidth: 1)
        )
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

/// Session detail view
struct SessionDetailView: View {
    let session: PersistentSession
    @ObservedObject var historyManager: SessionHistoryManager
    @State private var showingDeleteAlert = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.url)
                            .font(.title2)
                            .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                        Text(session.formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Button(action: { showingDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                // Performance score card
                if let score = session.performanceScore {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance Score")
                            .font(.headline)
                            .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                        HStack(spacing: 20) {
                            CircularGauge(
                                value: score.overall,
                                color: AdaptiveColors.performanceColor(score: score.overall),
                                size: 100,
                                lineWidth: 10,
                                showValue: true,
                                label: "Overall"
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                ScoreCategory(name: "Load Time", score: score.loadTimeScore, color: .green)
                                ScoreCategory(name: "Resources", score: score.resourceCountScore, color: .blue)
                                ScoreCategory(name: "Size", score: score.sizeScore, color: .orange)
                                ScoreCategory(name: "Web Vitals", score: score.webVitalsScore, color: .purple)
                            }
                        }
                    }
                    .padding()
                    .glassCard()
                }

                // Web Vitals
                if let vitals = session.webVitals {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Core Web Vitals")
                            .font(.headline)
                            .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                        HStack(spacing: 16) {
                            VitalCard(name: "LCP", value: vitals.lcp.value, rating: vitals.lcp.rating)
                            VitalCard(name: "CLS", value: vitals.cls.value, rating: vitals.cls.rating)
                            VitalCard(name: "FID", value: vitals.fid.value, rating: vitals.fid.rating)
                        }
                    }
                    .padding()
                    .glassCard()
                }

                // Basic metrics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Metrics")
                        .font(.headline)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                    HStack(spacing: 20) {
                        MetricItem(icon: "clock", label: "Load Time", value: String(format: "%.2fs", session.duration))
                        MetricItem(icon: "arrow.down.circle", label: "Total Size", value: formatBytes(session.totalSize))
                        MetricItem(icon: "network", label: "Requests", value: "\(session.requestCount)")
                        if let device = session.deviceProfile {
                            MetricItem(icon: device.platformIcon, label: "Device", value: device.name)
                        }
                    }
                }
                .padding()
                .glassCard()
            }
            .padding()
        }
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                try? historyManager.deleteSession(id: session.id)
            }
        } message: {
            Text("Are you sure you want to delete this session? This cannot be undone.")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

/// Score category row
struct ScoreCategory: View {
    let name: String
    let score: Double
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
            Spacer()
            Text(String(format: "%.0f", score))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

/// Web Vital card
struct VitalCard: View {
    let name: String
    let value: String
    let rating: WebVitals.Rating
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Text(name)
                .font(.caption)
                .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

            Text(rating.emoji)
                .font(.title2)

            Text(rating.label)
                .font(.caption2)
                .foregroundColor(rating.color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard()
    }
}

/// Metric item
struct MetricItem: View {
    let icon: String
    let label: String
    let value: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AdaptiveColors.accent)

            Text(label)
                .font(.caption)
                .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}
