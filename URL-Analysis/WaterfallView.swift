//
//  WaterfallView.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct WaterfallView: View {
    @ObservedObject var networkMonitor: NetworkMonitor
    @Binding var selectedResource: NetworkResource?
    @Binding var showInspector: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Summary header
            WaterfallSummary(networkMonitor: networkMonitor)
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Waterfall chart
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(networkMonitor.filteredResources) { resource in
                        WaterfallRow(
                            resource: resource,
                            sessionStart: networkMonitor.sessionStartTime ?? Date(),
                            maxDuration: networkMonitor.totalDuration,
                            isSelected: selectedResource?.id == resource.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedResource = resource
                            showInspector = true
                        }

                        Divider()
                    }
                }
            }
        }
    }
}

struct WaterfallSummary: View {
    @ObservedObject var networkMonitor: NetworkMonitor

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(networkMonitor.filteredResources.count) requests")
                    .font(.headline)
                Text(ByteCountFormatter.string(fromByteCount: networkMonitor.totalSize, countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Load time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatDuration(networkMonitor.totalDuration))
                    .font(.headline)
            }

            if networkMonitor.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }
}

struct WaterfallRow: View {
    let resource: NetworkResource
    let sessionStart: Date
    let maxDuration: TimeInterval
    let isSelected: Bool

    private let rowHeight: CGFloat = 28

    var body: some View {
        HStack(spacing: 8) {
            // Resource info
            HStack(spacing: 4) {
                // Status code badge
                StatusBadge(statusCode: resource.statusCode)

                // Resource type icon
                ResourceTypeIcon(type: resource.resourceType)

                // URL
                VStack(alignment: .leading, spacing: 2) {
                    Text(resourceName)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(resource.domain)
                        .font(.system(size: 9))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(width: 200, alignment: .leading)

            // Waterfall chart
            WaterfallChart(
                resource: resource,
                sessionStart: sessionStart,
                maxDuration: maxDuration
            )
            .frame(maxWidth: .infinity)

            // Duration and size
            HStack(spacing: 8) {
                Text(formatDuration(resource.totalDuration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 60, alignment: .trailing)

                Text(formatSize(resource.responseSize))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: rowHeight)
        .background(isSelected ? Color.accentColor : Color.clear)
    }

    private var resourceName: String {
        guard let url = URL(string: resource.url) else { return resource.url }
        let path = url.path
        return path.isEmpty ? url.host ?? resource.url : (url.lastPathComponent.isEmpty ? path : url.lastPathComponent)
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

struct WaterfallChart: View {
    let resource: NetworkResource
    let sessionStart: Date
    let maxDuration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            let chartWidth = geometry.size.width
            let offset = resource.startTime.timeIntervalSince(sessionStart)
            let offsetX = maxDuration > 0 ? CGFloat(offset / maxDuration) * chartWidth : 0

            ZStack(alignment: .leading) {
                // Timing bars
                HStack(spacing: 0) {
                    // DNS
                    if resource.timings.dns > 0 {
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: timingWidth(resource.timings.dns, in: chartWidth))
                    }

                    // Connect
                    if resource.timings.connect > 0 {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: timingWidth(resource.timings.connect, in: chartWidth))
                    }

                    // SSL
                    if resource.timings.ssl > 0 {
                        Rectangle()
                            .fill(Color.pink)
                            .frame(width: timingWidth(resource.timings.ssl, in: chartWidth))
                    }

                    // Wait (TTFB)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: timingWidth(resource.timings.wait, in: chartWidth))

                    // Receive
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: timingWidth(resource.timings.receive, in: chartWidth))
                }
                .frame(height: 16)
                .cornerRadius(2)
                .offset(x: offsetX)
            }
        }
        .frame(height: 20)
    }

    private func timingWidth(_ duration: TimeInterval, in totalWidth: CGFloat) -> CGFloat {
        guard maxDuration > 0 else { return 0 }
        return CGFloat(duration / maxDuration) * totalWidth
    }
}

struct StatusBadge: View {
    let statusCode: Int

    var body: some View {
        Text("\(statusCode)")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .cornerRadius(3)
    }

    private var backgroundColor: Color {
        switch statusCode {
        case 200..<300:
            return .green
        case 300..<400:
            return .blue
        case 400..<500:
            return .orange
        case 500..<600:
            return .red
        default:
            return .gray
        }
    }
}

struct ResourceTypeIcon: View {
    let type: NetworkResource.ResourceType

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 10))
            .foregroundColor(iconColor)
            .frame(width: 16, height: 16)
    }

    private var iconName: String {
        switch type {
        case .document:
            return "doc.text"
        case .stylesheet:
            return "paintbrush"
        case .script:
            return "curlybraces"
        case .image:
            return "photo"
        case .font:
            return "textformat"
        case .xhr, .fetch:
            return "arrow.left.arrow.right"
        case .websocket:
            return "bolt"
        case .media:
            return "film"
        case .other:
            return "questionmark.circle"
        }
    }

    private var iconColor: Color {
        switch type {
        case .document:
            return .blue
        case .stylesheet:
            return .purple
        case .script:
            return .yellow
        case .image:
            return .green
        case .font:
            return .orange
        case .xhr, .fetch:
            return .cyan
        case .websocket:
            return .pink
        case .media:
            return .red
        case .other:
            return .gray
        }
    }
}
