//
//  TrendChartView.swift
//  URL Analysis
//
//  Performance trend charts for historical analysis
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI
import Charts

/// Trend chart for performance metrics over time
struct TrendChartView: View {
    let sessions: [PersistentSession]
    @State private var selectedMetric: TrendMetric = .score
    @Environment(\.colorScheme) var colorScheme

    enum TrendMetric: String, CaseIterable {
        case score = "Performance Score"
        case loadTime = "Load Time"
        case size = "Total Size"
        case requests = "Requests"
        case lcp = "LCP"

        var icon: String {
            switch self {
            case .score: return "speedometer"
            case .loadTime: return "clock"
            case .size: return "arrow.down.circle"
            case .requests: return "network"
            case .lcp: return "chart.line.uptrend.xyaxis"
            }
        }

        var unit: String {
            switch self {
            case .score: return ""
            case .loadTime: return "s"
            case .size: return "MB"
            case .requests: return ""
            case .lcp: return "ms"
            }
        }
    }

    var sortedSessions: [PersistentSession] {
        sessions.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Performance Trends")
                    .font(.headline)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                Spacer()

                Picker("Metric", selection: $selectedMetric) {
                    ForEach(TrendMetric.allCases, id: \.self) { metric in
                        Label(metric.rawValue, systemImage: metric.icon)
                            .tag(metric)
                    }
                }
                .pickerStyle(.menu)
            }

            // Chart
            if sortedSessions.count >= 2 {
                Chart {
                    ForEach(sortedSessions) { session in
                        LineMark(
                            x: .value("Date", session.timestamp),
                            y: .value("Value", metricValue(for: session))
                        )
                        .foregroundStyle(AdaptiveColors.accent)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", session.timestamp),
                            y: .value("Value", metricValue(for: session))
                        )
                        .foregroundStyle(AdaptiveColors.accent)
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 300)
                .padding()
                .glassCard()

                // Statistics
                StatisticsView(sessions: sortedSessions, metric: selectedMetric)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Need at least 2 sessions to show trends")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .glassCard()
            }
        }
    }

    private func metricValue(for session: PersistentSession) -> Double {
        switch selectedMetric {
        case .score:
            return session.overallScore ?? 0
        case .loadTime:
            return session.duration
        case .size:
            return Double(session.totalSize) / 1_048_576.0  // Convert to MB
        case .requests:
            return Double(session.requestCount)
        case .lcp:
            // Parse LCP value if present
            if let lcpValue = session.lcpValue, let parsed = Double(lcpValue.replacingOccurrences(of: " s", with: "").replacingOccurrences(of: " ms", with: "")) {
                return parsed
            }
            return 0
        }
    }
}

/// Statistics summary view
struct StatisticsView: View {
    let sessions: [PersistentSession]
    let metric: TrendChartView.TrendMetric
    @Environment(\.colorScheme) var colorScheme

    var statistics: (min: Double, max: Double, avg: Double, latest: Double) {
        let values = sessions.map { session -> Double in
            switch metric {
            case .score:
                return session.overallScore ?? 0
            case .loadTime:
                return session.duration
            case .size:
                return Double(session.totalSize) / 1_048_576.0
            case .requests:
                return Double(session.requestCount)
            case .lcp:
                if let lcpValue = session.lcpValue, let parsed = Double(lcpValue.replacingOccurrences(of: " s", with: "").replacingOccurrences(of: " ms", with: "")) {
                    return parsed
                }
                return 0
            }
        }

        let min = values.min() ?? 0
        let max = values.max() ?? 0
        let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        let latest = values.last ?? 0

        return (min, max, avg, latest)
    }

    var body: some View {
        HStack(spacing: 20) {
            StatCard(title: "Minimum", value: statistics.min, unit: metric.unit)
            StatCard(title: "Maximum", value: statistics.max, unit: metric.unit)
            StatCard(title: "Average", value: statistics.avg, unit: metric.unit)
            StatCard(title: "Latest", value: statistics.latest, unit: metric.unit)
        }
        .padding()
        .glassCard()
    }
}

/// Statistic card
struct StatCard: View {
    let title: String
    let value: Double
    let unit: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

            Text(String(format: "%.1f", value) + unit)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}
