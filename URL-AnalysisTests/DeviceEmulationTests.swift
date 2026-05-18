//
//  DeviceEmulationTests.swift
//  URL-AnalysisTests
//
//  Unit tests for device profiles and emulation
//  Created by Jordan Koch on 2026-05-01
//

import XCTest
@testable import URL_Analysis

final class DeviceEmulationTests: XCTestCase {

    // MARK: - Preset Devices

    func testDesktopProfile() {
        let device = DeviceProfile.desktop
        XCTAssertEqual(device.width, 1920)
        XCTAssertEqual(device.height, 1080)
        XCTAssertEqual(device.pixelRatio, 1.0)
        XCTAssertFalse(device.isTouchEnabled)
        XCTAssertEqual(device.platform, .desktop)
    }

    func testIPhone15ProProfile() {
        let device = DeviceProfile.iPhone15Pro
        XCTAssertEqual(device.width, 393)
        XCTAssertEqual(device.height, 852)
        XCTAssertEqual(device.pixelRatio, 3.0)
        XCTAssertTrue(device.isTouchEnabled)
        XCTAssertEqual(device.platform, .mobile)
    }

    func testIPadPro13Profile() {
        let device = DeviceProfile.iPadPro13
        XCTAssertEqual(device.platform, .tablet)
        XCTAssertTrue(device.isTouchEnabled)
        XCTAssertEqual(device.pixelRatio, 2.0)
    }

    func testGalaxyS24Profile() {
        let device = DeviceProfile.galaxyS24
        XCTAssertEqual(device.platform, .mobile)
        XCTAssertTrue(device.userAgent.contains("Android"))
    }

    // MARK: - All Presets

    func testAllPresetsNonEmpty() {
        XCTAssertGreaterThanOrEqual(DeviceProfile.allPresets.count, 10)
    }

    func testAllPresetsUniqueNames() {
        let names = DeviceProfile.allPresets.map { $0.name }
        let unique = Set(names)
        XCTAssertEqual(names.count, unique.count, "Preset device names must be unique")
    }

    func testAllPresetsHaveValidDimensions() {
        for device in DeviceProfile.allPresets {
            XCTAssertGreaterThan(device.width, 0, "\(device.name) has invalid width")
            XCTAssertGreaterThan(device.height, 0, "\(device.name) has invalid height")
            XCTAssertGreaterThan(device.pixelRatio, 0, "\(device.name) has invalid pixel ratio")
        }
    }

    func testAllPresetsHaveUserAgent() {
        for device in DeviceProfile.allPresets {
            XCTAssertFalse(device.userAgent.isEmpty, "\(device.name) has empty user agent")
            XCTAssertTrue(device.userAgent.contains("Mozilla"), "\(device.name) UA should contain Mozilla")
        }
    }

    // MARK: - fromString Lookup

    func testFromStringDesktop() {
        let device = DeviceProfile.fromString("desktop")
        XCTAssertEqual(device.name, "Desktop")
    }

    func testFromStringIPhone() {
        let device = DeviceProfile.fromString("iphone")
        XCTAssertEqual(device.name, "iPhone 15 Pro")
    }

    func testFromStringIPad() {
        let device = DeviceProfile.fromString("ipad")
        XCTAssertEqual(device.platform, .tablet)
    }

    func testFromStringAndroid() {
        let device = DeviceProfile.fromString("android")
        XCTAssertEqual(device.name, "Samsung Galaxy S24")
    }

    func testFromStringPixel() {
        let device = DeviceProfile.fromString("pixel")
        XCTAssertEqual(device.name, "Google Pixel 8 Pro")
    }

    func testFromStringUnknownDefaultsToDesktop() {
        let device = DeviceProfile.fromString("unknown-device")
        XCTAssertEqual(device.name, "Desktop")
    }

    // MARK: - Platform Icon

    func testPlatformIconDesktop() {
        XCTAssertEqual(DeviceProfile.desktop.platformIcon, "desktopcomputer")
    }

    func testPlatformIconMobile() {
        XCTAssertEqual(DeviceProfile.iPhone15Pro.platformIcon, "iphone")
    }

    func testPlatformIconTablet() {
        XCTAssertEqual(DeviceProfile.iPadPro13.platformIcon, "ipad")
    }

    // MARK: - Viewport Description

    func testViewportDescription() {
        let desc = DeviceProfile.iPhone15Pro.viewportDescription
        XCTAssertTrue(desc.contains("393"))
        XCTAssertTrue(desc.contains("852"))
        XCTAssertTrue(desc.contains("3.0"))
    }

    // MARK: - Codable

    func testDeviceProfileCodable() throws {
        let device = DeviceProfile.iPhone15Pro
        let data = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(DeviceProfile.self, from: data)
        XCTAssertEqual(decoded.name, device.name)
        XCTAssertEqual(decoded.width, device.width)
        XCTAssertEqual(decoded.height, device.height)
        XCTAssertEqual(decoded.pixelRatio, device.pixelRatio)
        XCTAssertEqual(decoded.platform, device.platform)
    }

    // MARK: - Equatable / Hashable

    func testDeviceProfileEquatable() {
        let a = DeviceProfile.desktop
        let b = DeviceProfile.desktop
        // Same preset instances should share the same properties
        XCTAssertEqual(a.name, b.name)
        XCTAssertEqual(a.width, b.width)
    }
}
