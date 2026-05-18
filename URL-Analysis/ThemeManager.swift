//
//  ThemeManager.swift
//  URL Analysis
//
//  Theme management for dark/light mode support
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// Manages app-wide theme (dark/light/system) with persistence
@MainActor
class ThemeManager: ObservableObject {

    // MARK: - Published Properties

    @Published var currentTheme: Theme = .system

    // MARK: - Persisted Storage

    @AppStorage("selectedTheme") private var storedTheme: String = Theme.system.rawValue

    // MARK: - Theme Enum

    enum Theme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }

        var displayName: String { rawValue }

        var icon: String {
            switch self {
            case .system:
                return "circle.lefthalf.filled"
            case .light:
                return "sun.max.fill"
            case .dark:
                return "moon.fill"
            }
        }
    }

    // MARK: - Initialization

    init() {
        // Load persisted theme
        if let theme = Theme(rawValue: storedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .system
        }
    }

    // MARK: - Computed Properties

    /// Returns the effective color scheme to apply
    /// - nil means follow system appearance
    /// - .light or .dark overrides system
    var effectiveColorScheme: ColorScheme? {
        switch currentTheme {
        case .system:
            return nil  // Follow system
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    // MARK: - Public Methods

    /// Set theme and persist preference
    func setTheme(_ theme: Theme) {
        currentTheme = theme
        storedTheme = theme.rawValue
    }

    /// Quick check if currently using dark mode
    func isDarkMode(systemScheme: ColorScheme) -> Bool {
        switch currentTheme {
        case .system:
            return systemScheme == .dark
        case .light:
            return false
        case .dark:
            return true
        }
    }
}
