//
//  ResourceInspector.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ResourceInspector: View {
    let resource: NetworkResource
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resource Inspector")
                        .font(.headline)
                    Text(resource.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusBadge(statusCode: resource.statusCode)
            }
            .padding()

            Divider()

            // Tabs
            Picker("", selection: $selectedTab) {
                Text("Headers").tag(0)
                Text("Timing").tag(1)
                Text("Request").tag(2)
                Text("Response").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // Tab content
            TabView(selection: $selectedTab) {
                HeadersTab(resource: resource)
                    .tag(0)

                TimingTab(resource: resource)
                    .tag(1)

                RequestTab(resource: resource)
                    .tag(2)

                ResponseTab(resource: resource)
                    .tag(3)
            }
            .tabViewStyle(.automatic)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct HeadersTab: View {
    let resource: NetworkResource

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Request headers
                VStack(alignment: .leading, spacing: 8) {
                    Text("Request Headers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(resource.requestHeaders.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text(key)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 150, alignment: .leading)

                            Text(value)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }

                Divider()

                // Response headers
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response Headers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(resource.responseHeaders.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text(key)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 150, alignment: .leading)

                            Text(value)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct TimingTab: View {
    let resource: NetworkResource

    var body: some View {
        VStack(spacing: 0) {
            // Timing breakdown
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TimingRow(name: "DNS Lookup", duration: resource.timings.dns, color: .purple)
                    TimingRow(name: "TCP Connection", duration: resource.timings.connect, color: .orange)
                    TimingRow(name: "SSL/TLS", duration: resource.timings.ssl, color: .pink)
                    TimingRow(name: "Waiting (TTFB)", duration: resource.timings.wait, color: .green)
                    TimingRow(name: "Content Download", duration: resource.timings.receive, color: .blue)

                    Divider()

                    TimingRow(name: "Total", duration: resource.totalDuration, color: .primary, isTotal: true)
                }
                .padding()
            }
        }
    }
}

struct TimingRow: View {
    let name: String
    let duration: TimeInterval
    let color: Color
    var isTotal: Bool = false

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if !isTotal {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }

                Text(name)
                    .font(.system(size: isTotal ? 13 : 12, weight: isTotal ? .semibold : .regular))
            }

            Spacer()

            Text(formatDuration(duration))
                .font(.system(size: isTotal ? 13 : 12, weight: isTotal ? .semibold : .regular, design: .monospaced))
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.2f ms", duration * 1000)
        } else {
            return String(format: "%.3f s", duration)
        }
    }
}

struct RequestTab: View {
    let resource: NetworkResource

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Request info
                InfoRow(label: "Method", value: resource.method)
                InfoRow(label: "URL", value: resource.url)

                if resource.requestSize > 0 {
                    InfoRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: resource.requestSize, countStyle: .file))
                }

                // Request body
                if let body = resource.requestBody, !body.isEmpty {
                    Divider()

                    Text("Request Body")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let bodyString = String(data: body, encoding: .utf8) {
                        Text(bodyString)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(4)
                    } else {
                        Text("Binary data (\(body.count) bytes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

struct ResponseTab: View {
    let resource: NetworkResource

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Response info
                InfoRow(label: "Status", value: "\(resource.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: resource.statusCode))")
                if let mimeType = resource.mimeType {
                    InfoRow(label: "Content Type", value: mimeType)
                }
                InfoRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: resource.responseSize, countStyle: .file))

                // Response body preview
                if let body = resource.responseBody, !body.isEmpty {
                    Divider()

                    Text("Response Body Preview")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let bodyString = String(data: body, encoding: .utf8) {
                        let preview = String(bodyString.prefix(1000))
                        Text(preview + (bodyString.count > 1000 ? "\n..." : ""))
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(4)
                    } else {
                        Text("Binary data (\(body.count) bytes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
