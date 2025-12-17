//
//  WaterfallToolbar.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct WaterfallToolbar: View {
    @ObservedObject var networkMonitor: NetworkMonitor
    @State private var showFilterPopover = false
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Filter URL", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onChange(of: searchText) { newValue in
                        networkMonitor.filter.searchText = newValue
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)

            // Filter button
            Button(action: { showFilterPopover.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 14))
                    Text("Filter")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $showFilterPopover) {
                FilterPopover(networkMonitor: networkMonitor)
                    .frame(width: 300, height: 400)
            }

            // Network throttle picker
            Picker("Throttle", selection: $networkMonitor.throttle) {
                ForEach(NetworkThrottle.allCases, id: \.self) { throttle in
                    Text(throttle.rawValue).tag(throttle)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            Spacer()

            // Legend button
            Button(action: { showLegend() }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func showLegend() {
        let alert = NSAlert()
        alert.messageText = "Waterfall Timing Legend"
        alert.informativeText = """
        Purple: DNS Resolution
        Orange: TCP Connection
        Pink: SSL/TLS Handshake
        Green: Waiting (TTFB)
        Blue: Content Download

        TTFB = Time To First Byte
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct FilterPopover: View {
    @ObservedObject var networkMonitor: NetworkMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resource Filters")
                .font(.headline)

            // Resource types
            VStack(alignment: .leading, spacing: 8) {
                Text("Resource Types")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(NetworkResource.ResourceType.allCases, id: \.self) { type in
                    Toggle(isOn: Binding(
                        get: { networkMonitor.filter.types.contains(type) },
                        set: { isOn in
                            if isOn {
                                networkMonitor.filter.types.insert(type)
                            } else {
                                networkMonitor.filter.types.remove(type)
                            }
                        }
                    )) {
                        HStack {
                            ResourceTypeIcon(type: type)
                            Text(type.rawValue)
                                .font(.system(size: 12))
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            Divider()

            // Domain filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Domains")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if networkMonitor.domains.isEmpty {
                    Text("Load a page to see domains")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(networkMonitor.domains).sorted(), id: \.self) { domain in
                                Toggle(isOn: Binding(
                                    get: { networkMonitor.filter.domains.isEmpty || networkMonitor.filter.domains.contains(domain) },
                                    set: { isOn in
                                        if isOn {
                                            networkMonitor.filter.domains.remove(domain)
                                        } else {
                                            networkMonitor.filter.domains.insert(domain)
                                        }
                                    }
                                )) {
                                    Text(domain)
                                        .font(.system(size: 11))
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            Spacer()

            // Reset button
            HStack {
                Spacer()
                Button("Reset Filters") {
                    networkMonitor.filter = ResourceFilter()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
