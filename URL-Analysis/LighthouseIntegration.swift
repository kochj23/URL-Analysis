//
//  LighthouseIntegration.swift
//  URL Analysis
//
//  Google Lighthouse integration for SEO, accessibility, and best practices analysis
//  Created by Jordan Koch on 2026-01-22
//

import Foundation
import SwiftUI

/// Manager for Google Lighthouse CLI integration
@MainActor
class LighthouseManager: ObservableObject {
    @Published var isInstalled: Bool = false
    @Published var version: String? = nil
    @Published var isRunning: Bool = false
    @Published var lastResult: LighthouseResult? = nil
    @Published var error: LighthouseError? = nil

    enum LighthouseError: Error, LocalizedError {
        case notInstalled
        case executionFailed(String)
        case invalidOutput
        case timeout
        case chromeNotFound

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "Lighthouse is not installed. Install with: npm install -g lighthouse"
            case .executionFailed(let msg):
                return "Lighthouse execution failed: \(msg)"
            case .invalidOutput:
                return "Could not parse Lighthouse output"
            case .timeout:
                return "Lighthouse analysis timed out after 60 seconds"
            case .chromeNotFound:
                return "Chrome/Chromium not found. Lighthouse requires Chrome to be installed."
            }
        }
    }

    init() {
        checkInstallation()
    }

    /// Check if Lighthouse is installed
    func checkInstallation() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["lighthouse", "--version"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                isInstalled = true
            } else {
                isInstalled = false
                version = nil
            }
        } catch {
            isInstalled = false
            version = nil
        }
    }

    /// Run Lighthouse analysis
    func runLighthouse(
        url: String,
        device: DeviceProfile? = nil,
        categories: [LighthouseCategory] = LighthouseCategory.allCases
    ) async throws -> LighthouseResult {
        guard isInstalled else { throw LighthouseError.notInstalled }

        isRunning = true
        error = nil
        defer { isRunning = false }

        // Create temp file for output
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("lighthouse-\(UUID().uuidString).json")

        // Build command arguments
        var args = ["lighthouse", url, "--output=json", "--output-path=\(outputPath.path)", "--quiet"]

        // Device emulation
        if let device = device {
            let formFactor = device.platform == .mobile ? "mobile" : "desktop"
            args.append("--form-factor=\(formFactor)")
            args.append("--screenEmulation.width=\(device.width)")
            args.append("--screenEmulation.height=\(device.height)")
        }

        // Categories (only run specified categories)
        if !categories.isEmpty {
            let categoryList = categories.map { $0.rawValue }.joined(separator: ",")
            args.append("--only-categories=\(categoryList)")
        }

        // Chrome flags for headless mode
        args.append("--chrome-flags=--headless --no-sandbox --disable-gpu")

        // Execute Lighthouse
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = args

        let errorPipe = Pipe()
        task.standardError = errorPipe
        task.standardOutput = Pipe()  // Suppress stdout

        do {
            try task.run()

            // Wait with timeout (60 seconds)
            var elapsed = 0.0
            while task.isRunning && elapsed < 60.0 {
                try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
                elapsed += 0.5
            }

            if task.isRunning {
                task.terminate()
                throw LighthouseError.timeout
            }

            guard task.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw LighthouseError.executionFailed(errorMsg)
            }

            // Parse output
            let data = try Data(contentsOf: outputPath)
            let result = try JSONDecoder().decode(LighthouseResult.self, from: data)

            // Cleanup temp file
            try? FileManager.default.removeItem(at: outputPath)

            lastResult = result
            return result

        } catch let error as LighthouseError {
            self.error = error
            throw error
        } catch {
            self.error = .executionFailed(error.localizedDescription)
            throw error
        }
    }

    /// Check if Chrome is installed
    func isChromeInstalled() -> Bool {
        let chromePaths = [
            "/Applications/Google Chrome.app",
            "/Applications/Chromium.app",
            "/Applications/Google Chrome Canary.app"
        ]

        return chromePaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
}
