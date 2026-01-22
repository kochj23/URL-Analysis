//
//  DeviceEmulation.swift
//  URL Analysis
//
//  Device profiles and emulation management for mobile testing
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// Device profile for emulation
struct DeviceProfile: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let name: String
    let width: Int
    let height: Int
    let userAgent: String
    let pixelRatio: Double
    let isTouchEnabled: Bool
    let platform: Platform

    enum Platform: String, Codable {
        case desktop
        case mobile
        case tablet
    }

    init(id: UUID = UUID(), name: String, width: Int, height: Int, userAgent: String, pixelRatio: Double, isTouchEnabled: Bool, platform: Platform) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.userAgent = userAgent
        self.pixelRatio = pixelRatio
        self.isTouchEnabled = isTouchEnabled
        self.platform = platform
    }

    // MARK: - Preset Devices

    static let desktop = DeviceProfile(
        name: "Desktop",
        width: 1920,
        height: 1080,
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        pixelRatio: 1.0,
        isTouchEnabled: false,
        platform: .desktop
    )

    static let iPhone15Pro = DeviceProfile(
        name: "iPhone 15 Pro",
        width: 393,
        height: 852,
        userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        pixelRatio: 3.0,
        isTouchEnabled: true,
        platform: .mobile
    )

    static let iPhone15ProMax = DeviceProfile(
        name: "iPhone 15 Pro Max",
        width: 430,
        height: 932,
        userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        pixelRatio: 3.0,
        isTouchEnabled: true,
        platform: .mobile
    )

    static let iPhoneSE = DeviceProfile(
        name: "iPhone SE",
        width: 375,
        height: 667,
        userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        pixelRatio: 2.0,
        isTouchEnabled: true,
        platform: .mobile
    )

    static let iPadPro13 = DeviceProfile(
        name: "iPad Pro 13\"",
        width: 1024,
        height: 1366,
        userAgent: "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        pixelRatio: 2.0,
        isTouchEnabled: true,
        platform: .tablet
    )

    static let iPadAir = DeviceProfile(
        name: "iPad Air",
        width: 820,
        height: 1180,
        userAgent: "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        pixelRatio: 2.0,
        isTouchEnabled: true,
        platform: .tablet
    )

    static let galaxyS24 = DeviceProfile(
        name: "Samsung Galaxy S24",
        width: 360,
        height: 780,
        userAgent: "Mozilla/5.0 (Linux; Android 14; SM-S921B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        pixelRatio: 3.0,
        isTouchEnabled: true,
        platform: .mobile
    )

    static let galaxyS24Ultra = DeviceProfile(
        name: "Samsung Galaxy S24 Ultra",
        width: 412,
        height: 915,
        userAgent: "Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        pixelRatio: 3.5,
        isTouchEnabled: true,
        platform: .mobile
    )

    static let pixel8Pro = DeviceProfile(
        name: "Google Pixel 8 Pro",
        width: 412,
        height: 915,
        userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        pixelRatio: 3.0,
        isTouchEnabled: true,
        platform: .mobile
    )

    static let pixelFold = DeviceProfile(
        name: "Google Pixel Fold",
        width: 673,
        height: 841,
        userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel Fold) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        pixelRatio: 2.5,
        isTouchEnabled: true,
        platform: .tablet
    )

    // MARK: - All Presets

    static let allPresets: [DeviceProfile] = [
        .desktop,
        .iPhone15Pro,
        .iPhone15ProMax,
        .iPhoneSE,
        .iPadPro13,
        .iPadAir,
        .galaxyS24,
        .galaxyS24Ultra,
        .pixel8Pro,
        .pixelFold
    ]

    // MARK: - Helper Methods

    /// Get device by name
    static func fromString(_ name: String) -> DeviceProfile {
        switch name.lowercased() {
        case "desktop":
            return .desktop
        case "iphone", "iphone15pro":
            return .iPhone15Pro
        case "iphone15promax":
            return .iPhone15ProMax
        case "iphonese":
            return .iPhoneSE
        case "ipad", "ipadpro", "ipadpro13":
            return .iPadPro13
        case "ipadair":
            return .iPadAir
        case "android", "galaxy", "galaxys24":
            return .galaxyS24
        case "galaxys24ultra":
            return .galaxyS24Ultra
        case "pixel", "pixel8pro":
            return .pixel8Pro
        case "pixelfold":
            return .pixelFold
        default:
            return .desktop
        }
    }

    /// Get icon for platform
    var platformIcon: String {
        switch platform {
        case .desktop:
            return "desktopcomputer"
        case .mobile:
            return "iphone"
        case .tablet:
            return "ipad"
        }
    }

    /// Get viewport description
    var viewportDescription: String {
        "\(width) × \(height) (@\(String(format: "%.1f", pixelRatio))x)"
    }
}

/// Manager for device emulation state
@MainActor
class DeviceEmulationManager: ObservableObject {
    @Published var selectedDevice: DeviceProfile = .desktop
    @Published var isEnabled: Bool = false

    /// Apply device emulation to WebView
    func applyEmulation(to webView: WKWebView) {
        if isEnabled {
            // Set user agent
            webView.customUserAgent = selectedDevice.userAgent

            // Inject viewport meta tag
            let viewportScript = """
            var viewport = document.querySelector('meta[name=viewport]');
            if (viewport) {
                viewport.setAttribute('content', 'width=\(selectedDevice.width), initial-scale=1');
            } else {
                viewport = document.createElement('meta');
                viewport.name = 'viewport';
                viewport.content = 'width=\(selectedDevice.width), initial-scale=1';
                document.head.appendChild(viewport);
            }
            """

            let script = WKUserScript(source: viewportScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            webView.configuration.userContentController.addUserScript(script)
        } else {
            // Reset to default
            webView.customUserAgent = nil
        }
    }

    /// Reset to desktop mode
    func resetToDesktop() {
        selectedDevice = .desktop
        isEnabled = false
    }

    /// Quick set device and enable
    func setDevice(_ device: DeviceProfile) {
        selectedDevice = device
        isEnabled = true
    }
}

// MARK: - Import for WKWebView
import WebKit
