//
//  AdaptiveColors.swift
//  URL Analysis
//
//  Adaptive color system supporting light and dark modes
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// Adaptive color system that responds to light/dark mode
struct AdaptiveColors {

    // MARK: - Background Colors

    static func gradientStart(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.08, green: 0.12, blue: 0.22)  // Dark navy
            : Color(red: 0.95, green: 0.96, blue: 0.98)  // Light gray
    }

    static func gradientMid(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.10, green: 0.15, blue: 0.28)  // Navy blue
            : Color(red: 0.93, green: 0.94, blue: 0.96)  // Mid gray
    }

    static func gradientEnd(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.12, green: 0.18, blue: 0.32)  // Lighter navy
            : Color(red: 0.90, green: 0.92, blue: 0.95)  // Darker gray
    }

    static func backgroundGradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                gradientStart(for: scheme),
                gradientMid(for: scheme),
                gradientEnd(for: scheme)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Accent Colors (Same in both modes for vibrancy)

    static let cyan = Color(red: 0.3, green: 0.85, blue: 0.95)
    static let teal = Color(red: 0.2, green: 0.8, blue: 0.8)
    static let purple = Color(red: 0.6, green: 0.4, blue: 0.95)
    static let orange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let yellow = Color(red: 1.0, green: 0.85, blue: 0.3)
    static let pink = Color(red: 1.0, green: 0.35, blue: 0.65)
    static let accent = Color(red: 0.3, green: 0.85, blue: 0.95)  // Cyan
    static let accentBlue = Color(red: 0.3, green: 0.7, blue: 1.0)
    static let accentGreen = Color(red: 0.3, green: 0.9, blue: 0.6)
    static let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.2)

    // MARK: - Blob Colors (Animated background elements)

    static func blobCyan(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.2, green: 0.7, blue: 0.9)
            : Color(red: 0.4, green: 0.8, blue: 0.95).opacity(0.5)
    }

    static func blobPurple(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.5, green: 0.3, blue: 0.8)
            : Color(red: 0.65, green: 0.5, blue: 0.9).opacity(0.5)
    }

    static func blobPink(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.9, green: 0.3, blue: 0.6)
            : Color(red: 0.95, green: 0.5, blue: 0.7).opacity(0.5)
    }

    static func blobOrange(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.9, green: 0.5, blue: 0.2)
            : Color(red: 0.95, green: 0.65, blue: 0.4).opacity(0.5)
    }

    static func blobYellow(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 1.0, green: 0.85, blue: 0.3)
            : Color(red: 1.0, green: 0.9, blue: 0.5).opacity(0.5)
    }

    // MARK: - Status Colors (Performance indicators)

    static let statusLow = Color(red: 0.3, green: 0.9, blue: 0.6)      // Green
    static let statusMedium = Color(red: 1.0, green: 0.85, blue: 0.3)  // Yellow
    static let statusHigh = Color(red: 1.0, green: 0.6, blue: 0.2)     // Orange
    static let statusCritical = Color(red: 1.0, green: 0.3, blue: 0.4) // Red

    // MARK: - Text Colors

    static func textPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white
            : Color.black
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.7)
            : Color.black.opacity(0.6)
    }

    static func textTertiary(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.5)
            : Color.black.opacity(0.4)
    }

    // MARK: - Glass Card Colors

    static func glassBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.05)
            : Color.black.opacity(0.03)
    }

    static func glassBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.1)
    }

    static func glassMaterial(for scheme: ColorScheme) -> Material {
        scheme == .dark
            ? .ultraThinMaterial
            : .thin
    }

    // MARK: - Shadow Colors

    static func shadowColor(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.3)
            : Color.black.opacity(0.1)
    }

    static func highlightShadow(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.1)
            : Color.white.opacity(0.8)
    }

    // MARK: - Helper Functions

    /// Get heat map color for percentage (0-100)
    static func heatColor(percentage: Double) -> Color {
        switch percentage {
        case 0..<25:
            return statusLow
        case 25..<50:
            return statusMedium
        case 50..<75:
            return statusHigh
        default:
            return statusCritical
        }
    }

    /// Get performance rating color (good/needs improvement/poor)
    static func performanceColor(score: Double) -> Color {
        if score >= 75 {
            return statusLow  // Good (green)
        } else if score >= 50 {
            return statusMedium  // Needs improvement (yellow)
        } else {
            return statusCritical  // Poor (red)
        }
    }
}

// MARK: - Environment Value Extension

/// Convenience extension to get current color scheme from environment
extension View {
    func adaptiveBackground(_ scheme: ColorScheme) -> some View {
        self.background(AdaptiveColors.backgroundGradient(for: scheme))
    }

    func adaptiveTextColor(_ scheme: ColorScheme) -> some View {
        self.foregroundColor(AdaptiveColors.textPrimary(for: scheme))
    }
}
