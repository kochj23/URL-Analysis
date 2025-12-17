//
//  OptimizationSuggestionsView.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct OptimizationSuggestionsView: View {
    @ObservedObject var analyzer: OptimizationAnalyzer
    @State private var selectedCategory: OptimizationSuggestion.Category?
    @State private var expandedSuggestions: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Optimization Suggestions")
                    .font(.headline)

                if analyzer.suggestions.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No major issues detected")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 16) {
                        SummaryBadge(
                            count: analyzer.suggestions.filter { $0.impact == .critical }.count,
                            label: "Critical",
                            color: .red
                        )
                        SummaryBadge(
                            count: analyzer.suggestions.filter { $0.impact == .high }.count,
                            label: "High",
                            color: .orange
                        )
                        SummaryBadge(
                            count: analyzer.suggestions.filter { $0.impact == .medium }.count,
                            label: "Medium",
                            color: .yellow
                        )
                        SummaryBadge(
                            count: analyzer.suggestions.filter { $0.impact == .low }.count,
                            label: "Low",
                            color: .blue
                        )
                    }
                }
            }
            .padding()

            Divider()

            // Category filter
            if !analyzer.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(
                            title: "All",
                            count: analyzer.suggestions.count,
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        ForEach(OptimizationSuggestion.Category.allCases, id: \.self) { category in
                            let count = analyzer.suggestions.filter { $0.category == category }.count
                            if count > 0 {
                                CategoryChip(
                                    title: category.rawValue,
                                    count: count,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                Divider()
            }

            // Suggestions list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredSuggestions) { suggestion in
                        SuggestionCard(
                            suggestion: suggestion,
                            isExpanded: expandedSuggestions.contains(suggestion.id),
                            onToggle: {
                                if expandedSuggestions.contains(suggestion.id) {
                                    expandedSuggestions.remove(suggestion.id)
                                } else {
                                    expandedSuggestions.insert(suggestion.id)
                                }
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var filteredSuggestions: [OptimizationSuggestion] {
        if let category = selectedCategory {
            return analyzer.suggestions.filter { $0.category == category }
        }
        return analyzer.suggestions
    }
}

struct SuggestionCard: View {
    let suggestion: OptimizationSuggestion
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 8) {
                // Impact badge
                Text(suggestion.impact.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(suggestion.impact.color)
                    .cornerRadius(4)

                // Difficulty badge
                Text(suggestion.difficulty.rawValue)
                    .font(.caption)
                    .foregroundColor(suggestion.difficulty.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(suggestion.difficulty.color.opacity(0.1))
                    .cornerRadius(4)

                Spacer()

                // Expand button
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Title
            Text(suggestion.title)
                .font(.subheadline)
                .fontWeight(.semibold)

            // Description
            Text(suggestion.description)
                .font(.caption)
                .foregroundColor(.secondary)

            // Estimated savings
            if let savings = suggestion.estimatedSavings {
                HStack {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(savings)
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }

            // Expanded details
            if isExpanded && !suggestion.affectedResources.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Affected Resources (\(suggestion.affectedResources.count)):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)

                    ForEach(suggestion.affectedResources.prefix(10), id: \.self) { resource in
                        Text("• \(shortURL(resource))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if suggestion.affectedResources.count > 10 {
                        Text("... and \(suggestion.affectedResources.count - 10) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(suggestion.impact.color.opacity(0.3), lineWidth: 1)
        )
    }

    private func shortURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let path = url.path.isEmpty ? "/" : url.path
        return (url.host ?? "") + path
    }
}

struct SummaryBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CategoryChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
