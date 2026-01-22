//
//  URLAnalysisApp.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI
import AppKit

@main
struct URLAnalysisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 800)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.effectiveColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // NetworkInterceptor not used with WKWebView - monitoring handled via JavaScript
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
