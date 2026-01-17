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
    @StateObject private var budgetManager = BudgetManager()
    @StateObject private var optimizationAnalyzer = OptimizationAnalyzer()
    @StateObject private var thirdPartyAnalyzer = ThirdPartyAnalyzer()
    @StateObject private var aiAnalyzer = AIURLAnalyzer()
    @State private var selectedResource: NetworkResource?
    @State private var showInspector = false
    @State private var selectedRightTab = 0  // 0: Waterfall, 1: Performance, 2: Web Vitals, 3: Blocking, 4: Optimization, 5: Third-Party, 6: Budgets, 7: AI Analysis
    @State private var loadTrigger = 0  // Increment to trigger load

    private var activeSession: AnalysisSession {
        comparisonManager.activeSession
    }

    var body: some View {
        ZStack {
            // Glassmorphic background
            GlassmorphicBackground()

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
                        HStack {
                            TextField("Enter URL", text: Binding(
                                get: { activeSession.url },
                                set: { activeSession.url = $0 }
                            ))
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    loadURL()
                                }

                            if !activeSession.url.isEmpty {
                                Button(action: {
                                    activeSession.url = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                        Button("Load") {
                            loadURL()
                        }
                        .keyboardShortcut(.return)
                        .buttonStyle(.borderedProminent)

                        Button("Clear All") {
                            clearAll()
                        }
                        .buttonStyle(.bordered)

                        // Budget alert banner
                        BudgetAlertBanner(budgetManager: budgetManager)

                        Menu {
                            Button("Export HAR (JSON)") {
                                exportHAR()
                            }

                            Button("Export PDF Report") {
                                exportPDF()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                            }
                        }
                        .buttonStyle(.bordered)

                        Menu {
                            Button("Apple.com") { activeSession.url = "https://www.apple.com" }
                            Button("Google.com") { activeSession.url = "https://www.google.com" }
                            Button("GitHub.com") { activeSession.url = "https://www.github.com" }
                            Button("Amazon.com") { activeSession.url = "https://www.amazon.com" }
                            Button("CNN.com") { activeSession.url = "https://www.cnn.com" }
                        } label: {
                            Image(systemName: "star.fill")
                        }
                        .buttonStyle(.bordered)
                        .help("Quick URLs")

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
                        loadTrigger: $loadTrigger,
                        networkMonitor: activeSession.monitor,
                        screenshotTimeline: activeSession.timeline,
                        blockingManager: blockingManager,
                        budgetManager: budgetManager,
                        optimizationAnalyzer: optimizationAnalyzer,
                        thirdPartyAnalyzer: thirdPartyAnalyzer
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        Picker("", selection: $selectedRightTab) {
                            Text("Waterfall").tag(0)
                            Text("Performance").tag(1)
                            Text("Web Vitals").tag(2)
                            Text("Optimize").tag(4)
                            Text("3rd Party").tag(5)
                            Text("Budgets").tag(6)
                            Text("🤖 AI Analysis").tag(7)
                            Text("Blocking").tag(3)
                        }
                        .pickerStyle(.segmented)
                    }
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

                        // Optimization Suggestions tab
                        if activeSession.monitor.resources.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.yellow)
                                Text("No optimization data yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Load a page to get automatic optimization suggestions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(4)
                        } else {
                            OptimizationSuggestionsView(analyzer: optimizationAnalyzer)
                                .tag(4)
                        }

                        // Third-Party Analysis tab
                        if activeSession.monitor.resources.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.system(size: 48))
                                    .foregroundColor(.blue)
                                Text("No third-party data yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Load a page to analyze external dependencies")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(5)
                        } else {
                            ThirdPartyAnalysisView(analyzer: thirdPartyAnalyzer)
                                .tag(5)
                        }

                        // Performance Budgets tab
                        PerformanceBudgetView(budgetManager: budgetManager)
                            .tag(6)

                        // AI Analysis tab
                        AIAnalysisView(analyzer: aiAnalyzer, monitor: activeSession.monitor, currentURL: activeSession.url)
                            .tag(7)

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
    }

    private func loadURL() {
        // Trigger load by incrementing loadTrigger
        loadTrigger += 1
    }

    private func clearAll() {
        // Clear URL
        activeSession.url = "about:blank"

        // Clear all monitoring data
        activeSession.monitor.clearResources()

        // Stop and clear screenshots
        activeSession.timeline.stopCapture()
        activeSession.timeline.frames.removeAll()

        // Clear all analyzers
        optimizationAnalyzer.suggestions.removeAll()
        thirdPartyAnalyzer.domains.removeAll()
        budgetManager.violations.removeAll()

        // Load blank page to clear browser
        loadTrigger += 1

        // Then clear URL text after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            activeSession.url = ""
        }
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

    private func exportPDF() {
        // Generate PDF report
        guard let pdfDocument = PDFReportGenerator.generateReport(
            url: activeSession.url,
            monitor: activeSession.monitor,
            webVitals: activeSession.monitor.webVitals,
            performanceScore: activeSession.monitor.performanceScore,
            optimizationSuggestions: optimizationAnalyzer.suggestions,
            thirdPartyDomains: thirdPartyAnalyzer.domains,
            budgetViolations: budgetManager.violations,
            screenshots: activeSession.timeline.frames
        ) else {
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Failed to Generate PDF"
            alert.informativeText = "Unable to create PDF report. Please try again."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        // Save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        let host = URL(string: activeSession.url)?.host ?? "report"
        savePanel.nameFieldStringValue = "performance-report-\(host).pdf"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                pdfDocument.write(to: url)
            }
        }
    }
}


#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
