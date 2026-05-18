//
//  URLAnalysisWidget.swift
//  URL-Analysis Widget
//
//  WidgetKit widget for URL Analysis app
//  Shows recent analysis scores, performance metrics, and backend status
//  Created by Jordan Koch on 2026-02-04
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Provider

struct URLAnalysisWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = URLAnalysisTimelineEntry
    typealias Intent = ConfigurationAppIntent

    func placeholder(in context: Context) -> URLAnalysisTimelineEntry {
        URLAnalysisTimelineEntry.placeholder
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> URLAnalysisTimelineEntry {
        // Return current data or placeholder for preview
        let data = SharedDataManager.shared.loadWidgetData() ?? .placeholder
        return URLAnalysisTimelineEntry(date: Date(), data: data, configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<URLAnalysisTimelineEntry> {
        // Load data from App Group
        let data = SharedDataManager.shared.loadWidgetData() ?? .placeholder

        let entry = URLAnalysisTimelineEntry(
            date: Date(),
            data: data,
            configuration: configuration
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Widget Entry View

struct URLAnalysisWidgetEntryView: View {
    var entry: URLAnalysisTimelineEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: URLAnalysisTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with score
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("URL Analysis")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Spacer()

            // Latest score
            if let latestAnalysis = entry.data.recentAnalyses.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        ScoreCircle(score: latestAnalysis.overallScore, size: 44)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(latestAnalysis.domain)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                            Text(latestAnalysis.formattedTimestamp)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                VStack {
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No analyses yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()

            // Backend status
            HStack {
                Circle()
                    .fill(entry.data.backendStatus.isAvailable ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(entry.data.backendStatus.activeBackend ?? "Offline")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: URLAnalysisTimelineEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Latest analysis
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                    Text("URL Analysis")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                if let latestAnalysis = entry.data.recentAnalyses.first {
                    ScoreCircle(score: latestAnalysis.overallScore, size: 56)

                    Text(latestAnalysis.domain)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)

                    // Web Vitals
                    if entry.configuration?.showWebVitals != false {
                        HStack(spacing: 8) {
                            VitalBadge(label: "LCP", value: latestAnalysis.lcpValue ?? "--")
                            VitalBadge(label: "FID", value: latestAnalysis.fidValue ?? "--")
                            VitalBadge(label: "CLS", value: latestAnalysis.clsValue ?? "--")
                        }
                    }
                } else {
                    Spacer()
                    Text("No analyses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            Divider()

            // Right side - Recent list and stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                ForEach(entry.data.recentAnalyses.prefix(3)) { analysis in
                    RecentAnalysisRow(analysis: analysis)
                }

                Spacer()

                // Backend status
                if entry.configuration?.showBackendStatus != false {
                    HStack {
                        Circle()
                            .fill(entry.data.backendStatus.isAvailable ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(entry.data.backendStatus.activeBackend ?? "Offline")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(entry.data.statistics.todayCount) today")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let entry: URLAnalysisTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("URL Analysis")
                    .font(.headline)
                Spacer()

                // Quick Analyze Button
                Button(intent: QuickAnalyzeIntent()) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Analyze")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            // Statistics row
            HStack(spacing: 16) {
                StatBox(title: "Avg Score", value: String(format: "%.0f", entry.data.statistics.averageScore), color: scoreColor(entry.data.statistics.averageScore))
                StatBox(title: "Today", value: "\(entry.data.statistics.todayCount)", color: .blue)
                StatBox(title: "This Week", value: "\(entry.data.statistics.weekCount)", color: .purple)
                StatBox(title: "Total", value: "\(entry.data.statistics.totalAnalyses)", color: .gray)
            }

            Divider()

            // Latest analysis with Web Vitals
            if let latestAnalysis = entry.data.recentAnalyses.first {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Latest Analysis")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(latestAnalysis.formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 16) {
                        // Score
                        ScoreCircle(score: latestAnalysis.overallScore, size: 64)

                        // Details
                        VStack(alignment: .leading, spacing: 4) {
                            Text(latestAnalysis.domain)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            HStack(spacing: 12) {
                                Label(latestAnalysis.formattedLoadTime, systemImage: "clock")
                                Label("\(latestAnalysis.requestCount) req", systemImage: "arrow.up.arrow.down")
                                Label(latestAnalysis.formattedSize, systemImage: "doc")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Web Vitals
                        if entry.configuration?.showWebVitals != false {
                            VStack(alignment: .trailing, spacing: 4) {
                                WebVitalRow(label: "LCP", value: latestAnalysis.lcpValue ?? "--")
                                WebVitalRow(label: "FID", value: latestAnalysis.fidValue ?? "--")
                                WebVitalRow(label: "CLS", value: latestAnalysis.clsValue ?? "--")
                            }
                        }
                    }
                }
            }

            Divider()

            // Recent analyses list
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent Analyses")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(entry.data.recentAnalyses.dropFirst().prefix(4)) { analysis in
                    DetailedAnalysisRow(analysis: analysis)
                }

                if entry.data.recentAnalyses.count <= 1 {
                    Text("Analyze URLs to see history")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }

            Spacer()

            // Backend status footer
            if entry.configuration?.showBackendStatus != false {
                HStack {
                    Circle()
                        .fill(entry.data.backendStatus.isAvailable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(entry.data.backendStatus.isAvailable ? "AI Backend: \(entry.data.backendStatus.activeBackend ?? "Active")" : "AI Backend: Offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Updated \(entry.data.lastUpdated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
}

// MARK: - Helper Views

struct ScoreCircle: View {
    let score: Int?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(scoreColor.opacity(0.3), lineWidth: size * 0.08)
            Circle()
                .trim(from: 0, to: CGFloat(score ?? 0) / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if let score = score {
                Text("\(score)")
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
            } else {
                Text("--")
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private var scoreColor: Color {
        guard let score = score else { return .gray }
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
}

struct VitalBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
}

struct WebVitalRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

struct RecentAnalysisRow: View {
    let analysis: WidgetAnalysisEntry

    var body: some View {
        HStack {
            Circle()
                .fill(analysis.scoreColor == .good ? Color.green :
                      analysis.scoreColor == .needsImprovement ? Color.orange : Color.red)
                .frame(width: 6, height: 6)

            Text(analysis.domain)
                .font(.caption2)
                .lineLimit(1)

            Spacer()

            if let score = analysis.overallScore {
                Text("\(score)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct DetailedAnalysisRow: View {
    let analysis: WidgetAnalysisEntry

    var body: some View {
        HStack {
            Circle()
                .fill(analysis.scoreColor == .good ? Color.green :
                      analysis.scoreColor == .needsImprovement ? Color.orange : Color.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(analysis.domain)
                    .font(.caption)
                    .lineLimit(1)
                Text(analysis.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let score = analysis.overallScore {
                    Text("\(score)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(analysis.scoreColor == .good ? .green :
                                         analysis.scoreColor == .needsImprovement ? .orange : .red)
                }
                Text(analysis.formattedLoadTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Widget Definition

struct URLAnalysisWidget: Widget {
    let kind: String = "URLAnalysisWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: URLAnalysisWidgetProvider()
        ) { entry in
            URLAnalysisWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("URL Analysis")
        .description("View recent web performance analyses and Core Web Vitals.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct URLAnalysisWidgetBundle: WidgetBundle {
    var body: some Widget {
        URLAnalysisWidget()
    }
}

// MARK: - Previews

#if DEBUG
struct URLAnalysisWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            URLAnalysisWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")

            URLAnalysisWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")

            URLAnalysisWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
        }
    }
}
#endif
