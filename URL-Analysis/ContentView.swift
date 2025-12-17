//
//  ContentView.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var comparisonManager = ComparisonManager()
    @StateObject private var blockingManager = BlockingManager()
    @State private var selectedResource: NetworkResource?
    @State private var showInspector = false
    @State private var selectedRightTab = 0  // 0: Waterfall, 1: Performance, 2: Web Vitals, 3: Blocking

    private var activeSession: AnalysisSession {
        comparisonManager.activeSession
    }

    var body: some View {
        VStack(spacing: 0) {
            // Session tabs (for multiple URL comparison)
            if comparisonManager.sessions.count > 1 {
                URLComparisonView(manager: comparisonManager)
            }

            HSplitView {
                // Left side: Browser
                VStack(spacing: 0) {
                    // URL Bar
                    HStack {
                        TextField("Enter URL", text: Binding(
                            get: { activeSession.url },
                            set: { activeSession.url = $0 }
                        ))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                loadURL()
                            }

                        Button("Load") {
                            loadURL()
                        }
                        .keyboardShortcut(.return)

                        Button("Clear") {
                            activeSession.monitor.clearResources()
                            activeSession.timeline.stopCapture()
                        }

                        Button("Export HAR") {
                            exportHAR()
                        }

                        if comparisonManager.sessions.count == 1 {
                            Button(action: { comparisonManager.addSession() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.square")
                                    Text("Add URL")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()

                    // Browser View
                    WebView(
                        url: Binding(
                            get: { activeSession.url },
                            set: { activeSession.url = $0 }
                        ),
                        networkMonitor: activeSession.monitor,
                        screenshotTimeline: activeSession.timeline,
                        blockingManager: blockingManager
                    )

                    // Screenshot Timeline
                    if !activeSession.timeline.frames.isEmpty {
                        Divider()
                        ScreenshotTimelineView(timeline: activeSession.timeline)
                    }
                }
                .frame(minWidth: 600)

                // Right side: Tabs (Waterfall, Performance, Vitals, Blocking)
                VStack(spacing: 0) {
                    // Tab picker
                    Picker("", selection: $selectedRightTab) {
                        Text("Waterfall").tag(0)
                        Text("Performance").tag(1)
                        Text("Web Vitals").tag(2)
                        Text("Blocking").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    Divider()

                    // Tab content
                    TabView(selection: $selectedRightTab) {
                        // Waterfall tab
                        VStack(spacing: 0) {
                            WaterfallToolbar(networkMonitor: activeSession.monitor)
                            Divider()
                            WaterfallView(
                                networkMonitor: activeSession.monitor,
                                selectedResource: $selectedResource,
                                showInspector: $showInspector
                            )

                            // Resource Inspector (bottom panel)
                            if showInspector, let resource = selectedResource {
                                Divider()
                                ResourceInspector(resource: resource)
                                    .frame(height: 300)
                            }
                        }
                        .tag(0)

                        // Performance Score tab
                        ScrollView {
                            if let score = activeSession.monitor.performanceScore {
                                PerformanceScoreView(score: score)
                                    .padding()
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("No performance data yet")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("Load a page to see performance score")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .tag(1)

                        // Web Vitals tab
                        ScrollView {
                            if let vitals = activeSession.monitor.webVitals {
                                WebVitalsDetailView(vitals: vitals)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "speedometer")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("No Web Vitals yet")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("Load a page to measure Core Web Vitals")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .tag(2)

                        // Request Blocking tab
                        RequestBlockingView(blockingManager: blockingManager)
                            .tag(3)
                    }
                    .tabViewStyle(.automatic)
                }
                .frame(minWidth: 500)
            }
        }
    }

    private func loadURL() {
        // The WebView will automatically start a new session when navigation begins
    }

    private func exportHAR() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "network-export.har"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                activeSession.monitor.exportHAR(to: url)
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
