//
//  TimeMachineView.swift
//  URL Analysis
//
//  Performance Time Machine - What-If Analysis
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// Performance Time Machine for what-if analysis
struct TimeMachineView: View {
    @ObservedObject var analyzer: AIURLAnalyzer
    let currentSession: NetworkMonitor
    let historicalSessions: [PersistentSession]
    @State private var selectedScenario: PresetScenario = .removeGoogleAnalytics
    @State private var customScenarioText = ""
    @State private var isSimulating = false
    @Environment(\.colorScheme) var colorScheme

    enum PresetScenario: String, CaseIterable, Identifiable {
        case removeGoogleAnalytics = "Remove Google Analytics"
        case removeFacebookPixel = "Remove Facebook Pixel"
        case compressImages = "Compress All Images to WebP"
        case lazyLoadImages = "Lazy Load Below-the-Fold Images"
        case enableCaching = "Enable Browser Caching"
        case minifyJavaScript = "Minify JavaScript Bundles"

        var id: String { rawValue }

        var scenarioType: WhatIfScenarioType {
            switch self {
            case .removeGoogleAnalytics:
                return .removeTracker(name: "google-analytics")
            case .removeFacebookPixel:
                return .removeTracker(name: "facebook")
            case .compressImages:
                return .compressImages
            case .lazyLoadImages:
                return .lazyLoadImages
            case .enableCaching:
                return .enableCaching
            case .minifyJavaScript:
                return .minifyJavaScript
            }
        }

        var icon: String {
            switch self {
            case .removeGoogleAnalytics, .removeFacebookPixel:
                return "minus.circle"
            case .compressImages:
                return "photo.stack"
            case .lazyLoadImages:
                return "eye.slash"
            case .enableCaching:
                return "externaldrive.badge.timemachine"
            case .minifyJavaScript:
                return "chevron.left.forwardslash.chevron.right"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("⏰ Performance Time Machine")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                Text("Predict the impact of performance optimizations before implementing them")
                    .font(.body)
                    .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                // Scenario selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Scenario")
                        .font(.headline)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                    Picker("Scenario", selection: $selectedScenario) {
                        ForEach(PresetScenario.allCases) { scenario in
                            Label(scenario.rawValue, systemImage: scenario.icon)
                                .tag(scenario)
                        }
                    }
                    .pickerStyle(.menu)
                    .buttonStyle(.bordered)

                    Button(action: {
                        Task {
                            isSimulating = true
                            await analyzer.simulateWhatIf(
                                scenario: selectedScenario.scenarioType,
                                currentSession: currentSession,
                                historicalData: historicalSessions
                            )
                            isSimulating = false
                        }
                    }) {
                        HStack {
                            if isSimulating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text(isSimulating ? "Simulating..." : "Run Simulation")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSimulating)
                }
                .padding()
                .glassCard()

                // Results
                if !analyzer.whatIfResults.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Simulation Results")
                                .font(.headline)
                                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                            Spacer()

                            Button(action: {
                                analyzer.whatIfResults = []
                            }) {
                                Label("Clear", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }

                        ForEach(analyzer.whatIfResults) { result in
                            WhatIfResultCard(result: result, currentSession: currentSession)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

/// Individual what-if result card
struct WhatIfResultCard: View {
    let result: WhatIfScenario
    let currentSession: NetworkMonitor
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Scenario title
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AdaptiveColors.yellow)
                Text(result.scenario)
                    .font(.headline)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                Spacer()

                // Confidence badge
                confidenceBadge
            }

            // Before/After comparison
            HStack(spacing: 20) {
                // Before
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                    MetricRow(label: "Score", value: "\(currentSession.performanceScore?.overall ?? 0)", color: .orange)
                    MetricRow(label: "Load Time", value: String(format: "%.2fs", currentSession.totalDuration), color: .blue)
                    MetricRow(label: "Size", value: formatBytes(currentSession.totalSize), color: .purple)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassCard(prominent: true)

                Image(systemName: "arrow.right")
                    .font(.title)
                    .foregroundColor(AdaptiveColors.accent)

                // After
                VStack(alignment: .leading, spacing: 8) {
                    Text("Predicted")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                    MetricRow(label: "Score", value: String(format: "%.0f", result.predictedScore), color: .green)
                    MetricRow(label: "Load Time", value: "−\(result.timeSavings)", color: .green)
                    MetricRow(label: "Size", value: "−\(result.sizeSavings)", color: .green)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassCard(prominent: true)
            }

            // Explanation
            VStack(alignment: .leading, spacing: 8) {
                Text("Analysis")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                Text(result.explanation)
                    .font(.body)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
            }

            // Impact summary
            HStack(spacing: 12) {
                ImpactBadge(label: "Score", value: "+\(String(format: "%.0f", result.predictedScore - Double(currentSession.performanceScore?.overall ?? 0)))")
                ImpactBadge(label: "Time", value: "−\(result.timeSavings)")
                ImpactBadge(label: "Size", value: "−\(result.sizeSavings)")
            }
        }
        .padding()
        .glassCard()
    }

    private var confidenceBadge: some View {
        Text(result.confidence)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(confidenceColor)
            .cornerRadius(4)
    }

    private var confidenceColor: Color {
        switch result.confidence.lowercased() {
        case "high":
            return .green
        case "medium":
            return .orange
        default:
            return .red
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// Metric row for comparison
struct MetricRow: View {
    let label: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

/// Impact badge
struct ImpactBadge: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(AdaptiveColors.accentGreen)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(AdaptiveColors.glassBackground(for: colorScheme))
        .cornerRadius(8)
    }
}
