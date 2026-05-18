//
//  ThirdPartyAnalysisView.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ThirdPartyAnalysisView: View {
    @ObservedObject var analyzer: ThirdPartyAnalyzer
    @State private var sortBy: SortOption = .duration
    @State private var showOnlyThirdParty = true

    enum SortOption: String, CaseIterable {
        case duration = "Duration"
        case size = "Size"
        case requests = "Requests"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Third-Party Analysis")
                    .font(.headline)

                if !analyzer.thirdPartyDomains.isEmpty {
                    // Overall summary
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Third-Party Impact")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(analyzer.thirdPartyPercentage))%")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(impactColor(analyzer.thirdPartyPercentage))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Requests")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(analyzer.totalThirdPartyRequests)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Size")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatSize(analyzer.totalThirdPartySize))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }

                    // Category breakdown
                    let categorySummary = analyzer.categorySummary()
                    if !categorySummary.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Categories")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                ForEach(Array(categorySummary.keys.sorted(by: { categorySummary[$0]! > categorySummary[$1]! })), id: \.self) { category in
                                    HStack(spacing: 4) {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 10))
                                        Text(category.rawValue)
                                            .font(.caption2)
                                        Text("(\(categorySummary[category]!))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
            .padding()

            Divider()

            // Toolbar
            HStack {
                Toggle("Third-Party Only", isOn: $showOnlyThirdParty)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Spacer()

                Picker("Sort by", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Domain list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(sortedDomains) { domain in
                        ThirdPartyDomainCard(domain: domain, isFirstParty: domain.domain == analyzer.firstPartyDomain)
                    }
                }
                .padding()
            }
        }
    }

    private var sortedDomains: [ThirdPartyDomain] {
        let filtered = showOnlyThirdParty ? analyzer.thirdPartyDomains : analyzer.domains

        switch sortBy {
        case .duration:
            return filtered.sorted { $0.totalDuration > $1.totalDuration }
        case .size:
            return filtered.sorted { $0.totalSize > $1.totalSize }
        case .requests:
            return filtered.sorted { $0.requestCount > $1.requestCount }
        }
    }

    private func impactColor(_ percentage: Double) -> Color {
        if percentage > 50 { return .red }
        if percentage > 30 { return .orange }
        return .green
    }

    private func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct ThirdPartyDomainCard: View {
    let domain: ThirdPartyDomain
    let isFirstParty: Bool
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Provider icon or generic icon
                if let provider = domain.provider {
                    Image(systemName: provider.category.icon)
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                } else if isFirstParty {
                    Image(systemName: "house.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                        .frame(width: 24)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .frame(width: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(domain.domain)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        if isFirstParty {
                            Text("1st Party")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    if let provider = domain.provider {
                        Text("\(provider.name) · \(provider.description)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Impact badge
                Text(domain.impact.text)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(domain.impact.color)
                    .cornerRadius(4)

                // Expand button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Metrics
            HStack(spacing: 24) {
                MetricLabel(icon: "clock", value: formatDuration(domain.totalDuration))
                MetricLabel(icon: "doc.text", value: "\(domain.requestCount) req")
                MetricLabel(icon: "arrow.down.circle", value: formatSize(domain.totalSize))
            }
            .font(.caption)

            // Expanded resource list
            if isExpanded {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Resources (\(domain.resources.count)):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)

                    ForEach(domain.resources.prefix(10)) { resource in
                        HStack {
                            ResourceTypeIcon(type: resource.resourceType)
                            Text(shortPath(resource.url))
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            Text(formatSize(resource.responseSize))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    if domain.resources.count > 10 {
                        Text("... and \(domain.resources.count - 10) more")
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
    }

    private func shortPath(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let path = url.path.isEmpty ? "/" : url.path
        return path.count > 50 ? String(path.prefix(47)) + "..." : path
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }

    private func formatSize(_ size: Int64) -> String {
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024 * 1024))
        }
    }
}

struct MetricLabel: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
