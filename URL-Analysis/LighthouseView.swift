//
//  LighthouseView.swift
//  URL Analysis
//
//  UI for Google Lighthouse analysis results
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// Main Lighthouse analysis view
struct LighthouseView: View {
    @ObservedObject var lighthouseManager: LighthouseManager
    let currentURL: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            if !lighthouseManager.isInstalled {
                LighthouseInstallationPrompt(manager: lighthouseManager)
            } else if lighthouseManager.isRunning {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Running Lighthouse analysis...")
                        .font(.headline)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                    Text("This may take 30-60 seconds")
                        .font(.caption)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .padding(40)
                .glassCard()
            } else if let result = lighthouseManager.lastResult {
                LighthouseResultView(result: result)
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(.system(size: 64))
                        .foregroundColor(AdaptiveColors.accent)

                    Text("Run Lighthouse Analysis")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                    Text("Get comprehensive SEO, accessibility, and best practices scores from Google Lighthouse")
                        .font(.body)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)

                    Button(action: {
                        Task {
                            do {
                                try await lighthouseManager.runLighthouse(url: currentURL)
                            } catch {
                                lighthouseManager.error = error as? LighthouseManager.LighthouseError
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Run Lighthouse")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(40)
                .glassCard()
            }

            // Error display
            if let error = lighthouseManager.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error.localizedDescription)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        lighthouseManager.error = nil
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

/// Lighthouse result display
struct LighthouseResultView: View {
    let result: LighthouseResult
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lighthouse Report")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                    if let url = result.finalUrl {
                        Text(url)
                            .font(.caption)
                            .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Text(result.formattedDate)
                        .font(.caption2)
                        .foregroundColor(AdaptiveColors.textTertiary(for: colorScheme))
                }

                Divider()

                // Category scores
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(LighthouseCategory.allCases) { category in
                        if let score = result.score(for: category) {
                            LighthouseScoreCard(category: category, score: score, result: result)
                        }
                    }
                }

                // Detailed scores
                VStack(alignment: .leading, spacing: 16) {
                    Text("Category Details")
                        .font(.headline)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                    if let performance = result.categories.performance {
                        CategoryDetailCard(
                            category: .performance,
                            categoryData: performance,
                            result: result
                        )
                    }

                    if let accessibility = result.categories.accessibility {
                        CategoryDetailCard(
                            category: .accessibility,
                            categoryData: accessibility,
                            result: result
                        )
                    }

                    if let bestPractices = result.categories.bestPractices {
                        CategoryDetailCard(
                            category: .bestPractices,
                            categoryData: bestPractices,
                            result: result
                        )
                    }

                    if let seo = result.categories.seo {
                        CategoryDetailCard(
                            category: .seo,
                            categoryData: seo,
                            result: result
                        )
                    }

                    if let pwa = result.categories.pwa {
                        CategoryDetailCard(
                            category: .pwa,
                            categoryData: pwa,
                            result: result
                        )
                    }
                }
            }
            .padding()
        }
    }
}

/// Score card for individual category
struct LighthouseScoreCard: View {
    let category: LighthouseCategory
    let score: Double
    let result: LighthouseResult
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 32))
                .foregroundColor(category.color)

            CircularGauge(
                value: score,
                color: LighthouseResult.color(for: score),
                size: 100,
                lineWidth: 10,
                showValue: true
            )

            Text(category.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

            Text(LighthouseResult.rating(for: score))
                .font(.caption2)
                .foregroundColor(LighthouseResult.color(for: score))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard()
    }
}

/// Detailed category card
struct CategoryDetailCard: View {
    let category: LighthouseCategory
    let categoryData: LighthouseResult.CategoryScore
    let result: LighthouseResult
    @State private var isExpanded = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(category.color)

                    Text(categoryData.title)
                        .font(.headline)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                    Spacer()

                    if let score = categoryData.score {
                        Text(String(format: "%.0f", score * 100))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(LighthouseResult.color(for: score * 100))
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let description = categoryData.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                    .padding(.top, 4)
            }
        }
        .padding()
        .glassCard()
    }
}

/// Installation prompt
struct LighthouseInstallationPrompt: View {
    @ObservedObject var manager: LighthouseManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("Lighthouse Not Installed")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Google Lighthouse is required for SEO, accessibility, and best practices analysis.")
                .font(.body)
                .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 16) {
                Text("Installation Steps:")
                    .font(.headline)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                InstallStep(number: 1, text: "Install Node.js from nodejs.org")

                InstallStep(number: 2, text: "Open Terminal and run:")

                HStack {
                    Text("npm install -g lighthouse")
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(AdaptiveColors.glassBackground(for: colorScheme))
                        .cornerRadius(8)

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("npm install -g lighthouse", forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .help("Copy to clipboard")
                }

                InstallStep(number: 3, text: "Click 'Re-check Installation' below")
            }
            .padding(20)
            .background(AdaptiveColors.glassBackground(for: colorScheme))
            .cornerRadius(12)

            Button(action: {
                manager.checkInstallation()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Re-check Installation")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            if !manager.isChromeInstalled() {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Note: Lighthouse also requires Google Chrome to be installed")
                        .font(.caption)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(40)
        .glassCard()
    }
}

/// Installation step row
struct InstallStep: View {
    let number: Int
    let text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(AdaptiveColors.accent)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
        }
    }
}
