//
//  RegressionDetectionView.swift
//  URL Analysis
//
//  AI-powered regression detection and root cause analysis
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// Regression detection and root cause analysis view
struct RegressionDetectionView: View {
    @ObservedObject var analyzer: AIURLAnalyzer
    let currentSession: NetworkMonitor
    @ObservedObject var historyManager: SessionHistoryManager
    @State private var isAnalyzing = false
    @State private var selectedBaseline: PersistentSession?
    @Environment(\.colorScheme) var colorScheme

    private var recentSessions: [PersistentSession] {
        historyManager.sessions.prefix(30).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("🔍 Regression Detection")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                Text("AI-powered detection of performance regressions with root cause analysis")
                    .font(.body)
                    .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                if recentSessions.isEmpty {
                    // No historical data
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(AdaptiveColors.accent)

                        Text("No Historical Data")
                            .font(.headline)
                            .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                        Text("Regression detection requires historical sessions for baseline comparison. Analyze this URL a few times to build history.")
                            .font(.caption)
                            .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .padding(40)
                    .glassCard()
                } else if let report = analyzer.regressionReport {
                    // Show results
                    VStack(alignment: .leading, spacing: 16) {
                        // Severity indicator
                        HStack {
                            Image(systemName: report.hasRegression ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(report.severity.color)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(report.hasRegression ? "Regression Detected" : "No Regression")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                                Text(report.severity.label)
                                    .font(.caption)
                                    .foregroundColor(report.severity.color)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(report.severity.color.opacity(0.1))
                        .cornerRadius(12)

                        // Affected metrics
                        if !report.affectedMetrics.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Affected Metrics")
                                    .font(.headline)
                                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                                ForEach(report.affectedMetrics) { metric in
                                    MetricRegressionRow(metric: metric)
                                }
                            }
                            .padding()
                            .glassCard()
                        }

                        // Root causes
                        if !report.rootCauses.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Root Causes")
                                    .font(.headline)
                                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                                ForEach(report.rootCauses) { cause in
                                    RootCauseCard(cause: cause)
                                }
                            }
                            .padding()
                            .glassCard()
                        }

                        // Timeline
                        if let timeline = report.timelineEstimate {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(AdaptiveColors.cyan)
                                Text(timeline)
                                    .font(.body)
                                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                            }
                            .padding()
                            .glassCard()
                        }

                        // Recommendations
                        if !report.recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recommendations")
                                    .font(.headline)
                                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                                ForEach(report.recommendations, id: \.self) { recommendation in
                                    HStack(alignment: .top) {
                                        Text("•")
                                        Text(recommendation)
                                    }
                                    .font(.body)
                                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                                }
                            }
                            .padding()
                            .glassCard()
                        }

                        Button(action: {
                            Task {
                                isAnalyzing = true
                                await analyzer.detectRegression(
                                    currentSession: currentSession,
                                    historicalSessions: recentSessions,
                                    baseline: selectedBaseline
                                )
                                isAnalyzing = false
                            }
                        }) {
                            Label("Re-analyze Regression", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    // Detect button
                    VStack(spacing: 16) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 48))
                            .foregroundColor(AdaptiveColors.accent)

                        Text("Detect Regression")
                            .font(.headline)
                            .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                        Text("Compare current performance against historical baseline to detect regressions and identify root causes")
                            .font(.caption)
                            .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)

                        Button(action: {
                            Task {
                                isAnalyzing = true
                                await analyzer.detectRegression(
                                    currentSession: currentSession,
                                    historicalSessions: recentSessions,
                                    baseline: selectedBaseline
                                )
                                isAnalyzing = false
                            }
                        }) {
                            HStack {
                                if isAnalyzing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass.circle")
                                }
                                Text(isAnalyzing ? "Detecting Regression..." : "Detect Regression")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAnalyzing)
                    }
                    .padding(40)
                    .glassCard()
                }
            }
            .padding()
        }
    }
}

/// Metric regression row
struct MetricRegressionRow: View {
    let metric: RegressionReport.MetricRegression
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.metric)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                HStack(spacing: 8) {
                    Text("Baseline: \(metric.baseline)")
                        .font(.caption2)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Current: \(metric.current)")
                        .font(.caption2)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            Text(metric.change)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(severityColor(metric.severity))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(severityColor(metric.severity).opacity(0.2))
                .cornerRadius(4)
        }
        .padding(12)
        .background(AdaptiveColors.glassBackground(for: colorScheme))
        .cornerRadius(8)
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "critical":
            return .red
        case "warning":
            return .orange
        case "minor":
            return .yellow
        default:
            return .green
        }
    }
}

/// Root cause card
struct RootCauseCard: View {
    let cause: RegressionReport.RootCause
    @State private var showEvidence = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showEvidence.toggle() }) {
                HStack {
                    Image(systemName: "exclamationmark.bubble")
                        .foregroundColor(AdaptiveColors.orange)

                    Text(cause.cause)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                    Spacer()

                    // Confidence badge
                    Text(cause.confidence)
                        .font(.caption2)
                        .foregroundColor(confidenceColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(confidenceColor.opacity(0.2))
                        .cornerRadius(4)

                    Image(systemName: showEvidence ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showEvidence && !cause.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Evidence:")
                        .font(.caption2)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                    ForEach(cause.evidence, id: \.self) { evidence in
                        HStack(alignment: .top) {
                            Text("•")
                            Text(evidence)
                        }
                        .font(.caption)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(AdaptiveColors.glassBackground(for: colorScheme))
        .cornerRadius(8)
    }

    private var confidenceColor: Color {
        switch cause.confidence.lowercased() {
        case "high":
            return .green
        case "medium":
            return .orange
        default:
            return .red
        }
    }
}
