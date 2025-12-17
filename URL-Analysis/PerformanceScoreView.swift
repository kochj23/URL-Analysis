//
//  PerformanceScoreView.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct PerformanceScoreView: View {
    let score: PerformanceScore

    var body: some View {
        VStack(spacing: 16) {
            // Overall score circle
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: CGFloat(score.overall) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("\(score.overall)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        Text("Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(overallRating)
                    .font(.headline)
                    .foregroundColor(scoreColor)
            }
            .padding(.top)

            Divider()

            // Category breakdown
            VStack(spacing: 12) {
                ScoreCategoryRow(title: "Load Time", category: score.loadTime)
                ScoreCategoryRow(title: "Resources", category: score.resourceCount)
                ScoreCategoryRow(title: "Total Size", category: score.totalSize)
                ScoreCategoryRow(title: "Web Vitals", category: score.webVitals)
            }
            .padding(.horizontal)

            Spacer()
        }
        .frame(width: 300)
    }

    private var scoreColor: Color {
        if score.overall >= 90 { return .green }
        if score.overall >= 50 { return .orange }
        return .red
    }

    private var overallRating: String {
        if score.overall >= 90 { return "Excellent" }
        if score.overall >= 75 { return "Good" }
        if score.overall >= 50 { return "Needs Improvement" }
        return "Poor"
    }
}

struct ScoreCategoryRow: View {
    let title: String
    let category: PerformanceScore.ScoreCategory

    @State private var showRecommendation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category.rating.emoji)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Text(category.value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                Text("\(category.score)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(category.rating.color)
                    .frame(width: 30, alignment: .trailing)

                Button(action: { showRecommendation.toggle() }) {
                    Image(systemName: showRecommendation ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if showRecommendation {
                Text(category.recommendation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
    }
}

struct WebVitalsDetailView: View {
    let vitals: WebVitals

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Core Web Vitals")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                WebVitalRow(
                    title: "LCP",
                    subtitle: "Largest Contentful Paint",
                    metric: vitals.lcp,
                    description: "Measures loading performance. Should occur within 2.5s."
                )

                Divider()

                WebVitalRow(
                    title: "CLS",
                    subtitle: "Cumulative Layout Shift",
                    metric: vitals.cls,
                    description: "Measures visual stability. Should maintain a score under 0.1."
                )

                Divider()

                WebVitalRow(
                    title: "FID",
                    subtitle: "First Input Delay",
                    metric: vitals.fid,
                    description: "Measures interactivity. Should be less than 100ms."
                )
            }

            Text("Captured at: \(vitals.captureTime.formatted(date: .omitted, time: .standard))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct WebVitalRow: View {
    let title: String
    let subtitle: String
    let metric: WebVitals.Metric
    let description: String

    @State private var showDescription = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(metric.value)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(metric.rating.color)

                Text(metric.rating.emoji)
                    .font(.system(size: 16))

                Button(action: { showDescription.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if showDescription {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
        }
    }
}

#Preview {
    let sampleScore = PerformanceScore(
        overall: 85,
        loadTime: PerformanceScore.ScoreCategory(
            score: 90,
            value: "1.2 s",
            rating: .good,
            recommendation: "Excellent load time!"
        ),
        resourceCount: PerformanceScore.ScoreCategory(
            score: 85,
            value: "35 requests",
            rating: .good,
            recommendation: "Good resource count."
        ),
        totalSize: PerformanceScore.ScoreCategory(
            score: 75,
            value: "2.5 MB",
            rating: .good,
            recommendation: "Consider image optimization."
        ),
        webVitals: PerformanceScore.ScoreCategory(
            score: 90,
            value: "All metrics good",
            rating: .good,
            recommendation: "Great user experience!"
        )
    )

    return PerformanceScoreView(score: sampleScore)
}
