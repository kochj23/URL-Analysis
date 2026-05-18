//
//  RequestBlockingView.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct RequestBlockingView: View {
    @ObservedObject var blockingManager: BlockingManager
    @State private var newDomain = ""
    @State private var showingAddDomain = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with toggle
            HStack {
                Text("Request Blocking")
                    .font(.headline)

                Spacer()

                Toggle("Enabled", isOn: $blockingManager.rules.isEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: blockingManager.rules.isEnabled) { _ in
                        // Requires page reload to take effect
                    }
            }

            if blockingManager.isApplying {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Applying rules...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Quick profiles
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Profiles")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Button("Ads & Trackers") {
                        blockingManager.loadProfile(.adsAndTrackers)
                    }
                    .buttonStyle(.bordered)

                    Button("Block Images") {
                        blockingManager.loadProfile(.imagesOnly)
                    }
                    .buttonStyle(.bordered)

                    Button("Block Scripts") {
                        blockingManager.loadProfile(.scriptsOnly)
                    }
                    .buttonStyle(.bordered)

                    Button("Clear All") {
                        blockingManager.rules = BlockingRules()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            // Resource types
            VStack(alignment: .leading, spacing: 8) {
                Text("Block Resource Types")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(NetworkResource.ResourceType.allCases, id: \.self) { type in
                        Toggle(isOn: Binding(
                            get: { blockingManager.rules.blockedTypes.contains(type) },
                            set: { isOn in
                                if isOn {
                                    blockingManager.rules.blockedTypes.insert(type)
                                } else {
                                    blockingManager.rules.blockedTypes.remove(type)
                                }
                            }
                        )) {
                            HStack {
                                ResourceTypeIcon(type: type)
                                Text(type.rawValue)
                                    .font(.system(size: 11))
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }

            Divider()

            // Blocked domains
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Blocked Domains")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: { showingAddDomain.toggle() }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }

                if blockingManager.rules.blockedDomains.isEmpty {
                    Text("No domains blocked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(blockingManager.rules.blockedDomains).sorted(), id: \.self) { domain in
                                HStack {
                                    Text(domain)
                                        .font(.system(size: 11, design: .monospaced))

                                    Spacer()

                                    Button(action: {
                                        blockingManager.rules.blockedDomains.remove(domain)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            if showingAddDomain {
                Divider()

                HStack {
                    TextField("Enter domain (e.g., ads.example.com)", text: $newDomain)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))

                    Button("Add") {
                        if !newDomain.isEmpty {
                            blockingManager.rules.blockedDomains.insert(newDomain)
                            newDomain = ""
                            showingAddDomain = false
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Cancel") {
                        newDomain = ""
                        showingAddDomain = false
                    }
                    .buttonStyle(.borderless)
                }
            }

            Spacer()

            // Impact summary
            if blockingManager.rules.isEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ Note: Blocking requires page reload to take effect")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text("Blocking: \(blockingManager.rules.blockedDomains.count) domains, \(blockingManager.rules.blockedTypes.count) types")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
