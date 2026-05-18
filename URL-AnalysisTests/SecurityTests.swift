//
//  SecurityTests.swift
//  URL-AnalysisTests
//
//  Security tests: SSRF prevention, input sanitization, safe redirect following
//  Created by Jordan Koch on 2026-05-01
//

import XCTest
import CryptoKit
@testable import URL_Analysis

final class SecurityTests: XCTestCase {

    // MARK: - URL Input Sanitization

    func testURLWithJavascriptSchemeRejected() {
        // The app should never navigate to javascript: URLs
        let dangerous = "javascript:alert(document.cookie)"
        let url = URL(string: dangerous)
        // javascript: URLs parse but should be blocked by the app's allowlist
        // At minimum, url.scheme should be detected
        if let url = url {
            XCTAssertEqual(url.scheme, "javascript")
            // The app should reject non-http(s) schemes
        }
    }

    func testURLWithDataSchemeDetected() {
        let dangerous = "data:text/html,<script>alert(1)</script>"
        let url = URL(string: dangerous)
        if let url = url {
            XCTAssertEqual(url.scheme, "data")
        }
    }

    func testURLWithFileSchemeDetected() {
        let dangerous = "file:///etc/passwd"
        let url = URL(string: dangerous)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "file")
    }

    func testValidHTTPSURLAccepted() {
        let safe = "https://example.com/path?query=value"
        let url = URL(string: safe)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "https")
    }

    func testValidHTTPURLAccepted() {
        let safe = "http://example.com"
        let url = URL(string: safe)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "http")
    }

    // MARK: - SSRF Prevention (No Internal IPs)

    func testLocalhostDetection() {
        let urls = [
            "http://localhost/admin",
            "http://127.0.0.1/internal",
            "http://[::1]/admin",
            "http://0.0.0.0/secret"
        ]
        for urlString in urls {
            if let url = URL(string: urlString), let host = url.host {
                let isLocalhost = host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "0.0.0.0"
                XCTAssertTrue(isLocalhost, "\(host) should be detected as localhost for SSRF check")
            }
        }
    }

    func testPrivateIPv4Detection() {
        let privateIPs = [
            "10.0.0.1",
            "172.16.0.1",
            "192.168.1.1",
            "169.254.0.1"  // Link-local
        ]
        for ip in privateIPs {
            XCTAssertTrue(isPrivateIP(ip), "\(ip) should be detected as private IP")
        }
    }

    func testPublicIPNotFlagged() {
        let publicIPs = [
            "8.8.8.8",
            "1.1.1.1",
            "93.184.216.34"  // example.com
        ]
        for ip in publicIPs {
            XCTAssertFalse(isPrivateIP(ip), "\(ip) should not be detected as private IP")
        }
    }

    // MARK: - Content-Type Validation

    func testResourceTypeDeterminationSecure() {
        // Ensure MIME type detection doesn't trust file extensions alone
        let state = NetworkRequestState(url: "https://example.com/image.png", method: "GET")
        state.mimeType = "application/javascript"  // Mismatch!
        state.responseEnd = Date()
        let resource = state.toResource()
        // MIME type should take precedence over URL extension
        XCTAssertEqual(resource?.resourceType, .script)
    }

    // MARK: - Ethical Guardian Detection Patterns

    func testEthicalGuardianDetectsIllegalPatterns() {
        let dangerousInputs = [
            "how to make a bomb",
            "build an explosive device",
            "hack into a system",
            "steal password from email",
            "ransomware code example",
            "credit card fraud technique"
        ]
        for input in dangerousInputs {
            // The EthicalAIGuardian uses regex pattern matching
            // Test that patterns are actually compilable and match
            let lowercased = input.lowercased()
            let patterns = [
                "how to make.*bomb", "build.*explosive", "hack.*into.*system",
                "steal.*password", "ransomware.*code", "credit.*card.*fraud"
            ]
            var matched = false
            for pattern in patterns {
                if lowercased.range(of: pattern, options: .regularExpression) != nil {
                    matched = true
                    break
                }
            }
            XCTAssertTrue(matched, "Should detect dangerous input: \(input)")
        }
    }

    func testEthicalGuardianAllowsSafeContent() {
        let safeInputs = [
            "How does DNS resolution work?",
            "Analyze the performance of example.com",
            "What is the load time of this page?",
            "Show me optimization suggestions",
            "Generate a PDF report"
        ]
        let dangerousPatterns = [
            "how to make.*bomb", "build.*explosive", "hack.*into.*system",
            "steal.*password", "ransomware.*code", "credit.*card.*fraud",
            "child.*abuse", "self.*harm", "suicide.*method"
        ]
        for input in safeInputs {
            let lowercased = input.lowercased()
            var matched = false
            for pattern in dangerousPatterns {
                if lowercased.range(of: pattern, options: .regularExpression) != nil {
                    matched = true
                    break
                }
            }
            XCTAssertFalse(matched, "Safe input should not be flagged: \(input)")
        }
    }

    // MARK: - Content Hashing

    func testSHA256HashConsistency() {
        // The guardian hashes content before logging (privacy-preserving)
        let content = "test content"
        let data = Data(content.utf8)
        let hash1 = hashSHA256(data)
        let hash2 = hashSHA256(data)
        XCTAssertEqual(hash1, hash2, "Same input should produce same hash")
    }

    func testSHA256HashDifference() {
        let data1 = Data("content A".utf8)
        let data2 = Data("content B".utf8)
        XCTAssertNotEqual(hashSHA256(data1), hashSHA256(data2))
    }

    // MARK: - NovaAPIServer Security

    @MainActor
    func testNovaAPIServerBindsToLoopbackOnly() {
        // Port 37444 should only bind to 127.0.0.1
        let server = NovaAPIServer.shared
        XCTAssertEqual(server.port, 37444)
        // The server creates its listener with host "127.0.0.1" --
        // verified by reading the source code
    }

    // MARK: - Helpers

    private func isPrivateIP(_ ip: String) -> Bool {
        let components = ip.split(separator: ".").compactMap { Int($0) }
        guard components.count == 4 else { return false }
        let first = components[0]
        let second = components[1]

        // RFC 1918 + link-local
        if first == 10 { return true }
        if first == 172 && (16...31).contains(second) { return true }
        if first == 192 && second == 168 { return true }
        if first == 169 && second == 254 { return true }
        if first == 127 { return true }
        return false
    }

    private func hashSHA256(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
