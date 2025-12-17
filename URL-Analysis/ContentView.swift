//
//  ContentView.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var urlString = "https://www.example.com"
    @State private var selectedResource: NetworkResource?
    @State private var showInspector = false

    var body: some View {
        HSplitView {
            // Left side: Browser
            VStack(spacing: 0) {
                // URL Bar
                HStack {
                    TextField("Enter URL", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            loadURL()
                        }

                    Button("Load") {
                        loadURL()
                    }
                    .keyboardShortcut(.return)

                    Button("Clear") {
                        networkMonitor.clearResources()
                    }

                    Button("Export HAR") {
                        exportHAR()
                    }
                }
                .padding()

                // Browser View
                WebView(url: $urlString, networkMonitor: networkMonitor)
            }
            .frame(minWidth: 600)

            // Right side: Waterfall View
            VStack(spacing: 0) {
                // Toolbar with filters
                WaterfallToolbar(networkMonitor: networkMonitor)

                Divider()

                // Waterfall list
                WaterfallView(
                    networkMonitor: networkMonitor,
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
            .frame(minWidth: 500)
        }
    }

    private func loadURL() {
        networkMonitor.startNewSession()
        // The WebView will automatically trigger loading
    }

    private func exportHAR() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "network-export.har"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                networkMonitor.exportHAR(to: url)
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
