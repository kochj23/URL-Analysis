//
//  AITrendAnalysisView.swift
//  URL Analysis
//
//  AI-powered performance trend analysis and forecasting
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// AI-powered trend analysis view
struct AITrendAnalysisView: View {
    @ObservedObject var analyzer: AIURLAnalyzer
    @ObservedObject var historyManager: SessionHistoryManager
    let currentURL: String
    @State private var isAnalyzing = false
    @Environment(\.colorScheme) var colorScheme

    private var urlSessions: [PersistentSession] {
        historyManager.sessions.filter { session in
            session.url == currentURL || session.domain == domainFromURL(currentURL)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("📈 AI Trend Analysis")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                Text("AI-powered performance forecasting and anomaly detection")
                    .font(.body)
                    .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                if urlSessions.count < 5 {
                    // Not enough data
                    VStack(spacing: 16) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 48))
                            .foregroundColor(AdaptiveColors.accent)

                        Text("Need More Historical Data")
                            .font(.headline)
                            .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                        Text("Trend analysis requires at least 5 historical sessions for this URL. You currently have \(urlSessions.count).")
                            .font(.caption)
                            .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .padding(40)
                    .glassCard()
                } else if let analysis = analyzer.trendAnalysis {
                    // Show results
                    VStack(alignment: .leading, spacing: 16) {
                        // Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summary")
                                .font(.headline)
                                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                            Text(analysis.summary)
                                .font(.body)
                                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                        }
                        .padding()
                        .glassCard()

                        // Predictions
                        if !analysis.predictions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Predictions")
                                    .font(.headline)
                                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                                ForEach(analysis.predictions) { prediction in
                                    PredictionCard(prediction: prediction)
                                }
                            }
                            .padding()
                            .glassCard()
                        }

                        // Anomalies
                        if !analysis.anomalies.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Anomalies Detected")
                                    .font(.headline)
                                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                                ForEach(analysis.anomalies) { anomaly in
                                    AnomalyCard(anomaly: anomaly)
                                }
                            }
                            .padding()
                            .glassCard()
                        }

                        // Patterns
                        if !analysis.patterns.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Performance Patterns")
                                    .font(.headline)
                                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                                ForEach(analysis.patterns) { pattern in
                                    PatternCard(pattern: pattern)
                                }
                            }
                            .padding()
                            .glassCard()
                        }

                        // Recommendation
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(AdaptiveColors.yellow)
                                Text("Recommendation")
                                    .font(.headline)
                                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                            }

                            Text(analysis.recommendation)
                                .font(.body)
                                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                        }
                        .padding()
                        .glassCard()

                        Button(action: {
                            Task {
                                isAnalyzing = true
                                await analyzer.analyzeTrends(sessions: urlSessions, forURL: currentURL)
                                isAnalyzing = false
                            }
                        }) {
                            Label("Re-analyze Trends", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    // Analyze button
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 48))
                            .foregroundColor(AdaptiveColors.accent)

                        Text("Ready to Analyze")
                            .font(.headline)
                            .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                        Text("Analyze \(urlSessions.count) historical sessions to identify trends, predict future performance, and detect anomalies")
                            .font(.caption)
                            .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)

                        Button(action: {
                            Task {
                                isAnalyzing = true
                                await analyzer.analyzeTrends(sessions: urlSessions, forURL: currentURL)
                                isAnalyzing = false
                            }
                        }) {
                            HStack {
                                if isAnalyzing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                }
                                Text(isAnalyzing ? "Analyzing Trends..." : "Analyze Trends")
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

    private func domainFromURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return urlString
        }
        return host
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// Prediction card
struct PredictionCard: View {
    let prediction: TrendAnalysisResult.Prediction
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Image(systemName: trendIcon)
                .foregroundColor(trendColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(prediction.metric)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                Text(prediction.forecast)
                    .font(.caption)
                    .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()

            Text(prediction.confidence)
                .font(.caption2)
                .foregroundColor(confidenceColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(confidenceColor.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(12)
        .background(AdaptiveColors.glassBackground(for: colorScheme))
        .cornerRadius(8)
    }

    private var trendIcon: String {
        switch prediction.trend.lowercased() {
        case "improving":
            return "arrow.up.right"
        case "degrading":
            return "arrow.down.right"
        default:
            return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch prediction.trend.lowercased() {
        case "improving":
            return .green
        case "degrading":
            return .red
        default:
            return .yellow
        }
    }

    private var confidenceColor: Color {
        switch prediction.confidence.lowercased() {
        case "high":
            return .green
        case "medium":
            return .orange
        default:
            return .red
        }
    }
}

/// Anomaly card
struct AnomalyCard: View {
    let anomaly: TrendAnalysisResult.Anomaly
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text("\(anomaly.metric) - \(anomaly.deviation)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                Spacer()

                Text(formatDate(anomaly.date))
                    .font(.caption2)
                    .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
            }

            if !anomaly.possibleCauses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Possible Causes:")
                        .font(.caption2)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                    ForEach(anomaly.possibleCauses, id: \.self) { cause in
                        HStack {
                            Text("•")
                            Text(cause)
                        }
                        .font(.caption)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

/// Pattern card
struct PatternCard: View {
    let pattern: TrendAnalysisResult.Pattern
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(AdaptiveColors.cyan)

            VStack(alignment: .leading, spacing: 4) {
                Text(pattern.description)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                Text("Frequency: \(pattern.frequency) • Impact: \(pattern.impact)")
                    .font(.caption2)
                    .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()
        }
        .padding(12)
        .background(AdaptiveColors.glassBackground(for: colorScheme))
        .cornerRadius(8)
    }
}
