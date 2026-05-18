//
//  URLComparison.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI

/// Session data for a single URL analysis
@MainActor
class AnalysisSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var url: String
    @Published var monitor: NetworkMonitor
    @Published var timeline: ScreenshotTimeline
    @Published var isActive: Bool

    init(url: String = "https://www.example.com") {
        self.url = url
        self.monitor = NetworkMonitor()
        self.timeline = ScreenshotTimeline()
        self.isActive = false
    }
}

/// Manages multiple URL comparison sessions
@MainActor
class ComparisonManager: ObservableObject {
    @Published var sessions: [AnalysisSession] = []
    @Published var selectedSessionIndex: Int = 0

    init() {
        // Start with one session
        addSession()
    }

    var activeSession: AnalysisSession {
        guard selectedSessionIndex < sessions.count else {
            return sessions.first!
        }
        return sessions[selectedSessionIndex]
    }

    func addSession() {
        let session = AnalysisSession()
        sessions.append(session)
        selectedSessionIndex = sessions.count - 1
    }

    func removeSession(at index: Int) {
        guard sessions.count > 1, index < sessions.count else { return }
        sessions.remove(at: index)
        if selectedSessionIndex >= sessions.count {
            selectedSessionIndex = sessions.count - 1
        }
    }

    func removeSession(_ session: AnalysisSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            removeSession(at: index)
        }
    }
}

/// Comparison view showing multiple URLs side-by-side
struct URLComparisonView: View {
    @ObservedObject var manager: ComparisonManager
    @State private var showingComparison = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar for sessions
            HStack(spacing: 0) {
                ForEach(Array(manager.sessions.enumerated()), id: \.element.id) { index, session in
                    ComparisonTab(
                        session: session,
                        isSelected: manager.selectedSessionIndex == index,
                        onSelect: { manager.selectedSessionIndex = index },
                        onClose: manager.sessions.count > 1 ? { manager.removeSession(session) } : nil
                    )
                }

                // Add button
                if manager.sessions.count < 4 {
                    Button(action: { manager.addSession() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 30, height: 32)
                }

                Spacer()

                // Compare button
                if manager.sessions.count > 1 {
                    Button(action: { showingComparison.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 12))
                            Text("Compare")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.trailing, 8)
                }
            }
            .padding(.leading, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Show comparison or single session
            if showingComparison && manager.sessions.count > 1 {
                ComparisonDetailView(sessions: manager.sessions)
            } else {
                // Current session content (handled by parent ContentView)
                EmptyView()
            }
        }
    }
}

struct ComparisonTab: View {
    @ObservedObject var session: AnalysisSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortURL)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .primary : .secondary)

                if session.monitor.resources.count > 0 {
                    Text("\(session.monitor.resources.count) req")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 150)

            if let onClose = onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var shortURL: String {
        guard let url = URL(string: session.url) else { return session.url }
        return url.host ?? session.url
    }
}

struct ComparisonDetailView: View {
    let sessions: [AnalysisSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Performance comparison table
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Comparison")
                        .font(.headline)

                    HStack(spacing: 0) {
                        Text("Metric")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 120, alignment: .leading)

                        ForEach(sessions) { session in
                            Text(shortURL(session.url))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .center)
                                .lineLimit(1)
                        }
                    }
                    .padding(.bottom, 4)

                    Divider()

                    ComparisonRow(title: "Load Time", values: sessions.map { formatDuration($0.monitor.totalDuration) })
                    ComparisonRow(title: "Requests", values: sessions.map { "\($0.monitor.resources.count)" })
                    ComparisonRow(title: "Total Size", values: sessions.map { formatSize($0.monitor.totalSize) })

                    if let firstScore = sessions.first?.monitor.performanceScore {
                        ComparisonRow(title: "Score", values: sessions.map {
                            $0.monitor.performanceScore.map { "\($0.overall)" } ?? "-"
                        })
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                // Web Vitals comparison
                if sessions.contains(where: { $0.monitor.webVitals != nil }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Core Web Vitals Comparison")
                            .font(.headline)

                        HStack(spacing: 0) {
                            Text("Metric")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)

                            ForEach(sessions) { session in
                                Text(shortURL(session.url))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 100, alignment: .center)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.bottom, 4)

                        Divider()

                        ComparisonRow(title: "LCP", values: sessions.map {
                            $0.monitor.webVitals?.lcp.value ?? "-"
                        })
                        ComparisonRow(title: "CLS", values: sessions.map {
                            $0.monitor.webVitals?.cls.value ?? "-"
                        })
                        ComparisonRow(title: "FID", values: sessions.map {
                            $0.monitor.webVitals?.fid.value ?? "-"
                        })
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }

    private func shortURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        return url.host ?? urlString
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

struct ComparisonRow: View {
    let title: String
    let values: [String]

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 12))
                .frame(width: 120, alignment: .leading)

            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 100, alignment: .center)
                    .padding(.vertical, 4)
                    .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
            }
        }
    }
}
