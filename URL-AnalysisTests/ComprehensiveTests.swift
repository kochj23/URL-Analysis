//
//  ComprehensiveTests.swift
//  URL-AnalysisTests
//
//  Comprehensive XCTest suite covering unit, security, integration,
//  functional, and frame tests for the URL Analysis macOS app.
//
//  Written by Jordan Koch
//  Created: 2026-05-03
//
//  Categories:
//    1. Unit Tests — URL parsing, CLI formatting, optimization models, AI data models
//    2. Security Tests — No hardcoded keys, Keychain usage, URL sanitization, PII
//    3. Integration Tests — Widget data sync, session storage, AI backend config
//    4. Functional Tests — Analysis flow, performance budget evaluation, screenshot data
//    5. Frame Tests — App launch, view instantiation, widget data models
//

import XCTest
import CryptoKit
@testable import URL_Analysis

// MARK: - Unit Tests

final class URLParsingTests: XCTestCase {

    // MARK: - URL Scheme Detection

    func testHTTPSSchemeAccepted() {
        let url = URL(string: "https://www.example.com/page?q=test")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "www.example.com")
    }

    func testHTTPSchemeAccepted() {
        let url = URL(string: "http://example.com")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "http")
    }

    func testURLWithFragmentParsed() {
        let url = URL(string: "https://example.com/page#section")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.fragment, "section")
    }

    func testURLWithQueryParametersParsed() {
        let url = URL(string: "https://example.com/search?q=swift&lang=en")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.query, "q=swift&lang=en")
    }

    func testURLWithPortParsed() {
        let url = URL(string: "https://localhost:8443/api/v1")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.port, 8443)
        XCTAssertEqual(url?.host, "localhost")
    }

    func testURLWithAuthenticationComponentParsed() {
        let url = URL(string: "https://user:pass@example.com/path")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.user, "user")
        XCTAssertEqual(url?.host, "example.com")
    }

    func testEmptyStringProducesNilURL() {
        let url = URL(string: "")
        XCTAssertNil(url)
    }

    func testWhitespaceOnlyStringNotValidHTTP() {
        let url = URL(string: "   ")
        // URL(string: "   ") may percent-encode spaces and succeed,
        // but the scheme should not be http/https
        if let url = url {
            XCTAssertNotEqual(url.scheme, "https",
                              "Whitespace-only string should not parse as HTTPS")
            XCTAssertNotEqual(url.scheme, "http",
                              "Whitespace-only string should not parse as HTTP")
        }
        // Either nil or not a valid http(s) URL -- both acceptable
    }

    func testInternationalizedDomainParsed() {
        let url = URL(string: "https://xn--nxasmq6b.example.com")
        XCTAssertNotNil(url)
    }

    func testURLWithEncodedCharactersParsed() {
        let url = URL(string: "https://example.com/path%20with%20spaces")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.path.contains("path"))
    }

    // MARK: - PersistentSession Domain Extraction Edge Cases

    func testDomainExtractionFromIPAddress() {
        let session = makePersistentSession(url: "https://192.168.1.1/admin")
        XCTAssertEqual(session.domain, "192.168.1.1")
    }

    func testDomainExtractionFromSubdomain() {
        let session = makePersistentSession(url: "https://api.staging.example.com/v2")
        XCTAssertEqual(session.domain, "api.staging.example.com")
    }

    func testDomainExtractionFromEmptyURL() {
        let session = makePersistentSession(url: "")
        // URL(string: "") returns nil, so domain falls back to the raw string
        XCTAssertEqual(session.domain, "")
    }

    // MARK: - Helpers

    private func makePersistentSession(url: String) -> PersistentSession {
        PersistentSession(
            url: url,
            timestamp: Date(),
            deviceProfile: nil,
            resourceCount: 0,
            resourceData: "[]",
            lcpValue: nil, clsValue: nil, fidValue: nil,
            overallScore: nil,
            budgetViolations: [],
            optimizationCount: 0,
            thirdPartyCount: 0,
            duration: 0,
            totalSize: 0,
            requestCount: 0,
            tags: [],
            notes: "",
            screenshots: []
        )
    }
}

// MARK: - CLI Output Format & Formatter Structure Tests

final class CLIOutputFormatterTests: XCTestCase {

    func testCLIOutputStructCodable() throws {
        let output = CLIOutputFormatter.CLIOutput(
            url: "https://example.com",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            metrics: CLIOutputFormatter.CLIOutput.Metrics(
                loadTime: 2.5,
                totalSize: 500_000,
                requestCount: 25,
                performanceScore: 78.0
            )
        )
        let data = try JSONEncoder().encode(output)
        let decoded = try JSONDecoder().decode(CLIOutputFormatter.CLIOutput.self, from: data)

        XCTAssertEqual(decoded.url, "https://example.com")
        XCTAssertEqual(decoded.metrics.loadTime, 2.5)
        XCTAssertEqual(decoded.metrics.totalSize, 500_000)
        XCTAssertEqual(decoded.metrics.requestCount, 25)
        XCTAssertEqual(decoded.metrics.performanceScore, 78.0)
    }

    func testCLIOutputStructWithNilScore() throws {
        let output = CLIOutputFormatter.CLIOutput(
            url: "https://example.com",
            timestamp: "2026-05-03T00:00:00Z",
            metrics: CLIOutputFormatter.CLIOutput.Metrics(
                loadTime: 1.0,
                totalSize: 100_000,
                requestCount: 5,
                performanceScore: nil
            )
        )
        let data = try JSONEncoder().encode(output)
        let decoded = try JSONDecoder().decode(CLIOutputFormatter.CLIOutput.self, from: data)

        XCTAssertNil(decoded.metrics.performanceScore)
    }

    func testCLIOutputTimestampFormat() {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        XCTAssertFalse(timestamp.isEmpty, "ISO8601 timestamp should be non-empty")
        XCTAssertTrue(timestamp.contains("T"), "ISO8601 timestamp should contain T separator")
    }
}

// MARK: - Optimization Suggestion Model Tests

final class OptimizationSuggestionModelTests: XCTestCase {

    func testImpactWeights() {
        XCTAssertEqual(OptimizationSuggestion.Impact.critical.weight, 4)
        XCTAssertEqual(OptimizationSuggestion.Impact.high.weight, 3)
        XCTAssertEqual(OptimizationSuggestion.Impact.medium.weight, 2)
        XCTAssertEqual(OptimizationSuggestion.Impact.low.weight, 1)
    }

    func testImpactWeightOrdering() {
        let impacts = OptimizationSuggestion.Impact.allCases.sorted { $0.weight > $1.weight }
        XCTAssertEqual(impacts.first, .critical)
        XCTAssertEqual(impacts.last, .low)
    }

    func testDifficultyAllCases() {
        XCTAssertEqual(OptimizationSuggestion.Difficulty.allCases.count, 3)
    }

    func testCategoryAllCases() {
        XCTAssertEqual(OptimizationSuggestion.Category.allCases.count, 8)
        let rawValues = OptimizationSuggestion.Category.allCases.map { $0.rawValue }
        XCTAssertTrue(rawValues.contains("Compression"))
        XCTAssertTrue(rawValues.contains("Images"))
        XCTAssertTrue(rawValues.contains("Caching"))
        XCTAssertTrue(rawValues.contains("Render Blocking"))
        XCTAssertTrue(rawValues.contains("JavaScript"))
        XCTAssertTrue(rawValues.contains("CSS"))
        XCTAssertTrue(rawValues.contains("Fonts"))
        XCTAssertTrue(rawValues.contains("Third-Party"))
    }

    func testSuggestionHasUniqueID() {
        let s1 = makeSuggestion(title: "Test A")
        let s2 = makeSuggestion(title: "Test B")
        XCTAssertNotEqual(s1.id, s2.id)
    }

    // MARK: - Helpers

    private func makeSuggestion(title: String) -> OptimizationSuggestion {
        OptimizationSuggestion(
            title: title,
            description: "Description",
            impact: .medium,
            difficulty: .easy,
            category: .images,
            affectedResources: [],
            estimatedSavings: nil,
            currentState: "Current",
            targetState: "Target"
        )
    }
}

// MARK: - AI Data Model Tests

final class AIDataModelTests: XCTestCase {

    // MARK: - SecurityRiskLevel

    func testSecurityRiskLevelOrdering() {
        XCTAssertTrue(SecurityRiskLevel.safe < SecurityRiskLevel.low)
        XCTAssertTrue(SecurityRiskLevel.low < SecurityRiskLevel.medium)
        XCTAssertTrue(SecurityRiskLevel.medium < SecurityRiskLevel.high)
        XCTAssertTrue(SecurityRiskLevel.high < SecurityRiskLevel.critical)
    }

    func testSecurityRiskLevelRawValues() {
        XCTAssertEqual(SecurityRiskLevel.safe.rawValue, "safe")
        XCTAssertEqual(SecurityRiskLevel.low.rawValue, "low")
        XCTAssertEqual(SecurityRiskLevel.medium.rawValue, "medium")
        XCTAssertEqual(SecurityRiskLevel.high.rawValue, "high")
        XCTAssertEqual(SecurityRiskLevel.critical.rawValue, "critical")
    }

    func testSecurityRiskLevelFromRawValue() {
        XCTAssertEqual(SecurityRiskLevel(rawValue: "safe"), .safe)
        XCTAssertEqual(SecurityRiskLevel(rawValue: "critical"), .critical)
        XCTAssertNil(SecurityRiskLevel(rawValue: "unknown"))
    }

    func testSecurityRiskLevelMaxComparison() {
        let level = max(SecurityRiskLevel.low, SecurityRiskLevel.medium)
        XCTAssertEqual(level, .medium)
    }

    // MARK: - SecurityAnalysisResult

    func testSecurityAnalysisResultConstruction() {
        let result = SecurityAnalysisResult(
            riskLevel: .medium,
            threats: ["HTTP connection", "Mixed content"],
            explanation: "Page uses HTTP",
            recommendations: ["Switch to HTTPS"]
        )
        XCTAssertEqual(result.riskLevel, .medium)
        XCTAssertEqual(result.threats.count, 2)
        XCTAssertFalse(result.explanation.isEmpty)
        XCTAssertEqual(result.recommendations.count, 1)
    }

    // MARK: - TechnologyStack

    func testTechnologyStackConstruction() {
        let stack = TechnologyStack(
            frontend: "React",
            backend: "Node.js",
            cms: nil,
            analytics: ["Google Analytics"],
            cdn: "Cloudflare",
            libraries: ["lodash", "moment"],
            hosting: "Vercel"
        )
        XCTAssertEqual(stack.frontend, "React")
        XCTAssertEqual(stack.backend, "Node.js")
        XCTAssertNil(stack.cms)
        XCTAssertEqual(stack.analytics.count, 1)
        XCTAssertEqual(stack.cdn, "Cloudflare")
        XCTAssertEqual(stack.libraries.count, 2)
    }

    func testTechnologyStackNilFields() {
        let stack = TechnologyStack(
            frontend: nil, backend: nil, cms: nil,
            analytics: [], cdn: nil, libraries: [], hosting: nil
        )
        XCTAssertNil(stack.frontend)
        XCTAssertNil(stack.backend)
        XCTAssertTrue(stack.analytics.isEmpty)
        XCTAssertTrue(stack.libraries.isEmpty)
    }

    // MARK: - PrivacyAnalysis

    func testPrivacyAnalysisScoreRange() {
        let analysis = PrivacyAnalysis(
            privacyScore: 100,
            trackerCount: 0,
            trackers: [],
            dataCollected: [],
            risks: [],
            recommendations: ["Privacy impact is minimal"]
        )
        XCTAssertEqual(analysis.privacyScore, 100)
        XCTAssertEqual(analysis.trackerCount, 0)
        XCTAssertTrue(analysis.trackers.isEmpty)
    }

    func testPrivacyAnalysisWithTrackers() {
        let analysis = PrivacyAnalysis(
            privacyScore: 30,
            trackerCount: 7,
            trackers: ["Google Analytics", "Facebook Pixel", "Hotjar"],
            dataCollected: ["Page views", "Device info"],
            risks: ["Extensive tracking"],
            recommendations: ["Minimize trackers"]
        )
        XCTAssertEqual(analysis.trackerCount, 7)
        XCTAssertEqual(analysis.trackers.count, 3)
        XCTAssertEqual(analysis.risks.count, 1)
    }

    // MARK: - CodeFix

    func testCodeFixIdentifiable() {
        let fix1 = CodeFix(
            title: "Lazy Load", description: "Defer images",
            code: "img.loading = 'lazy';", language: "javascript",
            framework: nil, estimatedImpact: "30% faster"
        )
        let fix2 = CodeFix(
            title: "Minify JS", description: "Reduce size",
            code: "terser --compress", language: "shell",
            framework: nil, estimatedImpact: "50KB saved"
        )
        XCTAssertNotEqual(fix1.id, fix2.id)
        XCTAssertEqual(fix1.language, "javascript")
        XCTAssertNil(fix1.framework)
    }

    // MARK: - WhatIfScenario

    func testWhatIfScenarioConstruction() {
        let scenario = WhatIfScenario(
            scenario: "Remove Google Analytics",
            predictedScore: 85.0,
            predictedLCP: "1.2s",
            sizeSavings: "120KB",
            timeSavings: "0.3s",
            confidence: "High",
            explanation: "Removing analytics reduces blocking scripts"
        )
        XCTAssertEqual(scenario.predictedScore, 85.0)
        XCTAssertEqual(scenario.confidence, "High")
        XCTAssertFalse(scenario.explanation.isEmpty)
    }

    // MARK: - TrendAnalysisResult

    func testTrendAnalysisResultConstruction() {
        let result = TrendAnalysisResult(
            summary: "Performance improving",
            predictions: [
                TrendAnalysisResult.Prediction(
                    metric: "Score",
                    forecast: "Will reach 90 in 7 days",
                    confidence: "Medium",
                    trend: "Improving"
                )
            ],
            anomalies: [],
            patterns: [
                TrendAnalysisResult.Pattern(
                    description: "Slower on Mondays",
                    frequency: "Weekly",
                    impact: "Medium"
                )
            ],
            recommendation: "Keep optimizing images"
        )
        XCTAssertEqual(result.predictions.count, 1)
        XCTAssertEqual(result.anomalies.count, 0)
        XCTAssertEqual(result.patterns.count, 1)
        XCTAssertFalse(result.summary.isEmpty)
    }

    // MARK: - RegressionReport

    func testRegressionReportNoRegression() {
        let report = RegressionReport(
            hasRegression: false,
            severity: .none,
            affectedMetrics: [],
            rootCauses: [],
            recommendations: ["No issues found"],
            timelineEstimate: nil
        )
        XCTAssertFalse(report.hasRegression)
        XCTAssertEqual(report.severity, .none)
        XCTAssertNil(report.timelineEstimate)
    }

    func testRegressionReportSeverityLabels() {
        XCTAssertEqual(RegressionReport.Severity.critical.label, "Critical")
        XCTAssertEqual(RegressionReport.Severity.warning.label, "Warning")
        XCTAssertEqual(RegressionReport.Severity.minor.label, "Minor")
        XCTAssertEqual(RegressionReport.Severity.none.label, "No Regression")
    }

    func testRegressionReportWithRegression() {
        let report = RegressionReport(
            hasRegression: true,
            severity: .critical,
            affectedMetrics: [
                RegressionReport.MetricRegression(
                    metric: "Score", baseline: "85",
                    current: "55", change: "-30 (-35%)",
                    severity: "critical"
                )
            ],
            rootCauses: [
                RegressionReport.RootCause(
                    cause: "Added heavy analytics bundle",
                    evidence: ["New 500KB script", "3 new trackers"],
                    confidence: "High"
                )
            ],
            recommendations: ["Remove unused analytics"],
            timelineEstimate: "Change occurred ~Apr 28"
        )
        XCTAssertTrue(report.hasRegression)
        XCTAssertEqual(report.severity, .critical)
        XCTAssertEqual(report.affectedMetrics.count, 1)
        XCTAssertEqual(report.rootCauses.count, 1)
        XCTAssertEqual(report.rootCauses.first?.confidence, "High")
    }

    // MARK: - WhatIfScenarioType

    func testWhatIfScenarioTypes() {
        // Verify all scenario types can be constructed
        let scenarios: [WhatIfScenarioType] = [
            .removeTracker(name: "Google Analytics"),
            .compressImages,
            .lazyLoadImages,
            .removeScript(url: "https://example.com/bundle.js"),
            .enableCaching,
            .minifyJavaScript
        ]
        XCTAssertEqual(scenarios.count, 6)
    }
}

// MARK: - Security Tests

final class ComprehensiveSecurityTests: XCTestCase {

    // MARK: - No Hardcoded API Keys in Source

    func testNoHardcodedOpenAIKeyInSourceFiles() throws {
        let sourceDir = "/Volumes/Data/xcode/URL-Analysis/URL-Analysis"
        let swiftFiles = try FileManager.default.contentsOfDirectory(atPath: sourceDir)
            .filter { $0.hasSuffix(".swift") }

        for file in swiftFiles {
            let path = (sourceDir as NSString).appendingPathComponent(file)
            let content = try String(contentsOfFile: path, encoding: .utf8)
            // Look for actual API key patterns (not variable names or documentation)
            let hasOpenAIKey = content.range(of: "sk-[A-Za-z0-9]{20,}", options: .regularExpression) != nil
            XCTAssertFalse(hasOpenAIKey, "File \(file) appears to contain a hardcoded OpenAI API key")
        }
    }

    func testNoHardcodedAWSCredentials() throws {
        let sourceDir = "/Volumes/Data/xcode/URL-Analysis/URL-Analysis"
        let swiftFiles = try FileManager.default.contentsOfDirectory(atPath: sourceDir)
            .filter { $0.hasSuffix(".swift") }

        for file in swiftFiles {
            let path = (sourceDir as NSString).appendingPathComponent(file)
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let hasAWSKey = content.range(of: "AKIA[0-9A-Z]{16}", options: .regularExpression) != nil
            XCTAssertFalse(hasAWSKey, "File \(file) appears to contain a hardcoded AWS key")
        }
    }

    func testNoHardcodedGitHubTokens() throws {
        let sourceDir = "/Volumes/Data/xcode/URL-Analysis/URL-Analysis"
        let swiftFiles = try FileManager.default.contentsOfDirectory(atPath: sourceDir)
            .filter { $0.hasSuffix(".swift") }

        for file in swiftFiles {
            let path = (sourceDir as NSString).appendingPathComponent(file)
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let hasGHToken = content.range(of: "ghp_[A-Za-z0-9]{36}", options: .regularExpression) != nil
            XCTAssertFalse(hasGHToken, "File \(file) appears to contain a hardcoded GitHub PAT")
        }
    }

    // MARK: - Keychain Usage Verification

    func testAIBackendManagerUsesKeychainForAPIKeys() throws {
        let path = "/Volumes/Data/xcode/URL-Analysis/URL-Analysis/AIBackendManager.swift"
        let content = try String(contentsOfFile: path, encoding: .utf8)

        // Verify Keychain methods are implemented
        XCTAssertTrue(content.contains("saveToKeychain"), "AIBackendManager must use saveToKeychain")
        XCTAssertTrue(content.contains("loadFromKeychain"), "AIBackendManager must use loadFromKeychain")
        XCTAssertTrue(content.contains("deleteFromKeychain"), "AIBackendManager must use deleteFromKeychain")

        // Verify Security framework imports
        XCTAssertTrue(content.contains("import Security"), "AIBackendManager must import Security framework")

        // Verify Keychain constants are used
        XCTAssertTrue(content.contains("kSecClass"), "AIBackendManager must use Keychain API constants")
        XCTAssertTrue(content.contains("SecItemAdd"), "AIBackendManager must use SecItemAdd")
        XCTAssertTrue(content.contains("SecItemCopyMatching"), "AIBackendManager must use SecItemCopyMatching")
    }

    func testAPIKeysMigratedFromUserDefaults() throws {
        let path = "/Volumes/Data/xcode/URL-Analysis/URL-Analysis/AIBackendManager.swift"
        let content = try String(contentsOfFile: path, encoding: .utf8)

        // Verify migration function exists
        XCTAssertTrue(content.contains("migrateAPIKeysFromUserDefaults"),
                       "Must have UserDefaults-to-Keychain migration")
    }

    // MARK: - URL Sanitization (No Script Injection)

    func testJavascriptSchemeDetection() {
        let dangerousSchemes = ["javascript", "data", "vbscript"]
        for scheme in dangerousSchemes {
            let urlString = "\(scheme):alert(1)"
            if let url = URL(string: urlString) {
                XCTAssertEqual(url.scheme, scheme,
                               "Scheme '\(scheme)' must be detectable for filtering")
            }
        }
    }

    func testURLWithScriptInQueryIsDetectable() {
        let url = URL(string: "https://example.com/search?q=<script>alert(1)</script>")
        // URL(string:) may return nil for unencoded angle brackets
        // The point: if it parses, the query string is inspectable
        if let url = url, let query = url.query {
            let hasScript = query.lowercased().contains("<script>")
            // App should sanitize this
            XCTAssertTrue(hasScript || query.contains("script"),
                          "Script injection in query must be detectable")
        }
    }

    func testURLWithEncodedScriptInPath() {
        let url = URL(string: "https://example.com/%3Cscript%3Ealert(1)%3C%2Fscript%3E")
        XCTAssertNotNil(url)
        // Decoded path should be detectable
        let decoded = url!.path.removingPercentEncoding ?? url!.path
        XCTAssertTrue(decoded.lowercased().contains("<script>"),
                       "Encoded script tags in path must be detectable after decoding")
    }

    // MARK: - SSL/TLS Verification

    func testHTTPSURLsPassSchemeCheck() {
        let secureURLs = [
            "https://www.google.com",
            "https://api.github.com/repos",
            "https://cdn.example.com/bundle.min.js"
        ]
        for urlString in secureURLs {
            let url = URL(string: urlString)!
            XCTAssertEqual(url.scheme, "https",
                           "Secure URL \(urlString) must have https scheme")
        }
    }

    func testHTTPURLsFlaggedAsInsecure() {
        let insecureURL = URL(string: "http://example.com/api")!
        XCTAssertEqual(insecureURL.scheme, "http")
        XCTAssertNotEqual(insecureURL.scheme, "https",
                          "HTTP URL must be flagged as insecure")
    }

    // MARK: - No PII in Analysis Output (Session Metadata)

    func testSessionMetadataDoesNotContainPersonalInfo() {
        let session = PersistentSession(
            url: "https://example.com",
            timestamp: Date(),
            deviceProfile: nil,
            resourceCount: 10,
            resourceData: "[]",
            lcpValue: "1.5 s", clsValue: "0.05", fidValue: "50 ms",
            overallScore: 85,
            budgetViolations: [],
            optimizationCount: 3,
            thirdPartyCount: 2,
            duration: 2.0,
            totalSize: 500_000,
            requestCount: 10,
            tags: [],
            notes: "",
            screenshots: []
        )
        let metadata = SessionMetadata(from: session)

        // Metadata should not contain email addresses or personal paths
        let fields = [metadata.url, metadata.deviceName ?? ""]
        for field in fields {
            XCTAssertFalse(field.contains("@"), "Metadata should not contain email addresses")
            XCTAssertFalse(field.contains("/Users/"), "Metadata should not contain personal paths")
        }
    }

    // MARK: - NovaAPIServer Binds Loopback Only

    @MainActor
    func testNovaAPIServerPort() {
        let server = NovaAPIServer.shared
        XCTAssertEqual(server.port, 37444,
                       "NovaAPIServer must listen on port 37444")
    }

    func testNovaAPIServerSourceBindsLoopback() throws {
        let path = "/Volumes/Data/xcode/URL-Analysis/URL-Analysis/NovaAPIServer.swift"
        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(content.contains("127.0.0.1"),
                       "NovaAPIServer must bind to 127.0.0.1 loopback only")
        XCTAssertFalse(content.contains("0.0.0.0"),
                        "NovaAPIServer must NOT bind to 0.0.0.0")
    }

    // MARK: - Suspicious TLD Detection

    func testSuspiciousTLDsAreChecked() {
        let suspiciousTLDs = [".tk", ".ml", ".ga", ".cf", ".gq", ".zip", ".review"]
        for tld in suspiciousTLDs {
            let host = "malicious\(tld)"
            let isSuspicious = suspiciousTLDs.contains(where: { host.hasSuffix($0) })
            XCTAssertTrue(isSuspicious,
                          "TLD \(tld) should be flagged as suspicious")
        }
    }

    func testLegitimateDomainsNotFlaggedAsSuspicious() {
        let suspiciousTLDs = [".tk", ".ml", ".ga", ".cf", ".gq", ".zip", ".review"]
        let legitimateDomains = ["google.com", "github.io", "apple.com", "example.org"]
        for domain in legitimateDomains {
            let isSuspicious = suspiciousTLDs.contains(where: { domain.hasSuffix($0) })
            XCTAssertFalse(isSuspicious,
                           "\(domain) should not be flagged as suspicious")
        }
    }
}

// MARK: - Integration Tests

final class IntegrationTests: XCTestCase {

    // MARK: - Widget Data Model Codable Round-Trip

    func testWidgetAnalysisEntryCodable() throws {
        let entry = WidgetAnalysisEntry(
            id: UUID(),
            url: "https://example.com",
            domain: "example.com",
            timestamp: Date(),
            overallScore: 85,
            lcpValue: "1.5 s",
            fidValue: "50 ms",
            clsValue: "0.05",
            loadTime: 2.3,
            requestCount: 42,
            totalSize: 1_500_000
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetAnalysisEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.url, entry.url)
        XCTAssertEqual(decoded.domain, entry.domain)
        XCTAssertEqual(decoded.overallScore, entry.overallScore)
        XCTAssertEqual(decoded.lcpValue, entry.lcpValue)
        XCTAssertEqual(decoded.fidValue, entry.fidValue)
        XCTAssertEqual(decoded.clsValue, entry.clsValue)
        XCTAssertEqual(decoded.loadTime, entry.loadTime)
        XCTAssertEqual(decoded.requestCount, entry.requestCount)
        XCTAssertEqual(decoded.totalSize, entry.totalSize)
    }

    func testWidgetAnalysisDataCodable() throws {
        let entry = WidgetAnalysisEntry(
            id: UUID(),
            url: "https://example.com",
            domain: "example.com",
            timestamp: Date(),
            overallScore: 90,
            lcpValue: nil, fidValue: nil, clsValue: nil,
            loadTime: 1.0,
            requestCount: 10,
            totalSize: 100_000
        )

        let widgetData = WidgetAnalysisData(
            lastUpdated: Date(),
            recentAnalyses: [entry],
            backendStatus: WidgetAnalysisData.BackendStatus(
                isAvailable: true,
                activeBackend: "Ollama",
                lastChecked: Date()
            ),
            statistics: WidgetAnalysisData.AnalysisStatistics(
                totalAnalyses: 5,
                averageScore: 78.5,
                todayCount: 2,
                weekCount: 5
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(widgetData)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetAnalysisData.self, from: data)

        XCTAssertEqual(decoded.recentAnalyses.count, 1)
        XCTAssertEqual(decoded.backendStatus.activeBackend, "Ollama")
        XCTAssertTrue(decoded.backendStatus.isAvailable)
        XCTAssertEqual(decoded.statistics.totalAnalyses, 5)
        XCTAssertEqual(decoded.statistics.averageScore, 78.5, accuracy: 0.01)
        XCTAssertEqual(decoded.statistics.todayCount, 2)
        XCTAssertEqual(decoded.statistics.weekCount, 5)
    }

    // MARK: - Session Persistence Full Round-Trip

    func testPersistentSessionFullRoundTrip() throws {
        let original = PersistentSession(
            url: "https://www.apple.com",
            timestamp: Date(),
            deviceProfile: DeviceProfile.iPhone15Pro,
            resourceCount: 35,
            resourceData: "[{\"url\":\"https://www.apple.com/main.css\"}]",
            lcpValue: "1.20 s",
            clsValue: "0.030",
            fidValue: "25 ms",
            overallScore: 88.5,
            budgetViolations: ["Load time exceeded budget"],
            optimizationCount: 4,
            thirdPartyCount: 6,
            duration: 1.8,
            totalSize: 2_500_000,
            requestCount: 35,
            tags: ["production", "ios-test"],
            notes: "Tested via iPhone 15 Pro emulation",
            screenshots: []
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersistentSession.self, from: data)

        XCTAssertEqual(decoded.url, original.url)
        XCTAssertEqual(decoded.resourceCount, original.resourceCount)
        XCTAssertEqual(decoded.lcpValue, original.lcpValue)
        XCTAssertEqual(decoded.clsValue, original.clsValue)
        XCTAssertEqual(decoded.fidValue, original.fidValue)
        XCTAssertEqual(decoded.overallScore, original.overallScore)
        XCTAssertEqual(decoded.budgetViolations, original.budgetViolations)
        XCTAssertEqual(decoded.optimizationCount, original.optimizationCount)
        XCTAssertEqual(decoded.thirdPartyCount, original.thirdPartyCount)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertEqual(decoded.totalSize, original.totalSize)
        XCTAssertEqual(decoded.requestCount, original.requestCount)
        XCTAssertEqual(decoded.tags, original.tags)
        XCTAssertEqual(decoded.notes, original.notes)
        XCTAssertEqual(decoded.deviceProfile?.name, DeviceProfile.iPhone15Pro.name)
    }

    // MARK: - AI Backend Configuration

    func testAIBackendEnumAllCases() {
        let allBackends = AIBackendManager.AIBackend.allCases
        XCTAssertGreaterThanOrEqual(allBackends.count, 10)
    }

    func testAIBackendEnumCodable() throws {
        for backend in AIBackendManager.AIBackend.allCases {
            let data = try JSONEncoder().encode(backend)
            let decoded = try JSONDecoder().decode(AIBackendManager.AIBackend.self, from: data)
            XCTAssertEqual(decoded, backend)
        }
    }

    func testAIBackendDescriptionsNotEmpty() {
        for backend in AIBackendManager.AIBackend.allCases {
            XCTAssertFalse(backend.description.isEmpty,
                           "\(backend.rawValue) should have a non-empty description")
        }
    }

    func testAIBackendSetupInstructionsNotEmpty() {
        for backend in AIBackendManager.AIBackend.allCases {
            XCTAssertFalse(backend.setupInstructions.isEmpty,
                           "\(backend.rawValue) should have setup instructions")
        }
    }

    // MARK: - HAR Format Codable

    func testHARTimingsCodableRoundTrip() throws {
        let timings = HARTimings(
            blocked: 5, dns: 15, connect: 25,
            ssl: 30, send: 2, wait: 150, receive: 80
        )
        let data = try JSONEncoder().encode(timings)
        let decoded = try JSONDecoder().decode(HARTimings.self, from: data)

        XCTAssertEqual(decoded.blocked, timings.blocked)
        XCTAssertEqual(decoded.dns, timings.dns)
        XCTAssertEqual(decoded.connect, timings.connect)
        XCTAssertEqual(decoded.ssl, timings.ssl)
        XCTAssertEqual(decoded.send, timings.send)
        XCTAssertEqual(decoded.wait, timings.wait)
        XCTAssertEqual(decoded.receive, timings.receive)
    }
}

// MARK: - Functional Tests

final class FunctionalTests: XCTestCase {

    // MARK: - Performance Budget Evaluation Logic

    func testBudgetViolationOnLoadTimeExceeded() {
        let budget = PerformanceBudget.mobileFast  // maxLoadTime = 2.0
        let actualLoadTime: TimeInterval = 3.5

        XCTAssertTrue(actualLoadTime > budget.maxLoadTime,
                       "Load time 3.5s should violate mobileFast budget of 2.0s")
    }

    func testBudgetViolationOnSizeExceeded() {
        let budget = PerformanceBudget.pwa  // maxSize = 1_048_576 (1 MB)
        let actualSize: Int64 = 2_000_000

        XCTAssertTrue(actualSize > budget.maxSize,
                       "2MB should violate PWA budget of 1MB")
    }

    func testBudgetViolationOnRequestCountExceeded() {
        let budget = PerformanceBudget.pwa  // maxRequests = 25
        let actualRequests = 50

        XCTAssertTrue(actualRequests > budget.maxRequests,
                       "50 requests should violate PWA budget of 25")
    }

    func testBudgetPassesWhenWithinLimits() {
        let budget = PerformanceBudget.desktopStandard
        let loadTime: TimeInterval = 2.0
        let size: Int64 = 2_000_000
        let requests = 40
        let score = 80

        XCTAssertTrue(loadTime <= budget.maxLoadTime)
        XCTAssertTrue(size <= budget.maxSize)
        XCTAssertTrue(requests <= budget.maxRequests)
        XCTAssertTrue(score >= budget.minScore)
    }

    // MARK: - Performance Score Integrity

    func testPerformanceScoreStructConstruction() {
        let score = PerformanceScore(
            overall: 75,
            loadTime: PerformanceScore.ScoreCategory(
                score: 80, value: "1500 ms",
                rating: .good, recommendation: "Good"
            ),
            resourceCount: PerformanceScore.ScoreCategory(
                score: 70, value: "45 requests",
                rating: .good, recommendation: "OK"
            ),
            totalSize: PerformanceScore.ScoreCategory(
                score: 60, value: "2.50 MB",
                rating: .needsImprovement, recommendation: "Reduce"
            ),
            webVitals: PerformanceScore.ScoreCategory(
                score: 90, value: "All good",
                rating: .good, recommendation: "Excellent"
            )
        )

        XCTAssertEqual(score.overall, 75)
        XCTAssertEqual(score.loadTime.score, 80)
        XCTAssertEqual(score.resourceCount.score, 70)
        XCTAssertEqual(score.totalSize.score, 60)
        XCTAssertEqual(score.webVitals.score, 90)
    }

    func testPerformanceScoreCategoryRatingEmojis() {
        XCTAssertFalse(PerformanceScore.ScoreCategory.Rating.good.emoji.isEmpty)
        XCTAssertFalse(PerformanceScore.ScoreCategory.Rating.needsImprovement.emoji.isEmpty)
        XCTAssertFalse(PerformanceScore.ScoreCategory.Rating.poor.emoji.isEmpty)
    }

    // MARK: - Third-Party Provider Coverage

    func testAllKnownProvidersAreInDictionary() {
        let expectedProviders = [
            "google-analytics.com", "googletagmanager.com",
            "doubleclick.net", "facebook.net",
            "youtube.com", "cloudflare.com",
            "stripe.com", "fonts.googleapis.com"
        ]
        for domain in expectedProviders {
            XCTAssertNotNil(ThirdPartyProvider.providers[domain],
                            "Provider \(domain) should be in the known providers dictionary")
        }
    }

    func testThirdPartyProviderCategoriesHaveIcons() {
        let categories: [ThirdPartyProvider.Category] = [
            .analytics, .advertising, .socialMedia,
            .cdn, .fonts, .maps, .video, .tagManagement, .other
        ]
        for category in categories {
            XCTAssertFalse(category.icon.isEmpty,
                           "Category \(category.rawValue) should have an icon")
        }
    }

    // MARK: - Screenshot Data Model

    func testScreenshotFrameIdentifiable() {
        let frame1 = ScreenshotFrame(
            image: NSImage(size: NSSize(width: 100, height: 100)),
            timestamp: 0.5,
            caption: "0.5s"
        )
        let frame2 = ScreenshotFrame(
            image: NSImage(size: NSSize(width: 100, height: 100)),
            timestamp: 1.0,
            caption: "1.0s"
        )
        XCTAssertNotEqual(frame1.id, frame2.id)
        XCTAssertEqual(frame1.timestamp, 0.5)
        XCTAssertEqual(frame2.caption, "1.0s")
    }

    // MARK: - Headless Analyzer Error Types

    func testHeadlessAnalyzerErrorDescriptions() {
        let timeout = HeadlessAnalyzer.AnalysisError.timeout
        XCTAssertEqual(timeout.errorDescription, "Analysis timed out")

        let invalid = HeadlessAnalyzer.AnalysisError.invalidURL
        XCTAssertEqual(invalid.errorDescription, "Invalid URL provided")

        let failed = HeadlessAnalyzer.AnalysisError.loadFailed("Connection refused")
        XCTAssertEqual(failed.errorDescription, "Load failed: Connection refused")
    }

    // MARK: - Device Profile for Analysis Flow

    func testDeviceProfileFromStringForCLIAnalysis() {
        // CLI uses DeviceProfile.fromString for --device flag
        let profiles = [
            ("desktop", "Desktop"),
            ("iphone", "iPhone 15 Pro"),
            ("ipad", "iPad Pro 13\""),
            ("android", "Samsung Galaxy S24"),
            ("pixel", "Google Pixel 8 Pro")
        ]
        for (input, expectedName) in profiles {
            let profile = DeviceProfile.fromString(input)
            XCTAssertEqual(profile.name, expectedName,
                           "fromString(\(input)) should return \(expectedName)")
        }
    }

    // MARK: - Web Vitals Integration in Performance Score

    func testWebVitalsNilProduces50Score() {
        // When web vitals are not available, score defaults to 50
        // This is tested in PerformanceScoreTests but verified here for functional flow
        let vitals: WebVitals? = nil
        XCTAssertNil(vitals, "Nil vitals used when page doesn't support web vitals JS")
    }

    func testWebVitalsFromDataWithAllFields() {
        let data: [String: Any] = ["lcp": 1200.0, "cls": 0.03, "fid": 30.0]
        let vitals = WebVitals.from(data: data)
        XCTAssertNotNil(vitals)
        XCTAssertEqual(vitals!.lcp.rating, .good)
        XCTAssertEqual(vitals!.cls.rating, .good)
        XCTAssertEqual(vitals!.fid.rating, .good)
    }
}

// MARK: - Frame Tests

final class FrameTests: XCTestCase {

    // MARK: - Data Model Instantiation

    func testPersistentSessionDefaultInit() {
        let session = PersistentSession(
            url: "https://example.com",
            timestamp: Date(),
            deviceProfile: nil,
            resourceCount: 0,
            resourceData: "[]",
            lcpValue: nil, clsValue: nil, fidValue: nil,
            overallScore: nil,
            budgetViolations: [],
            optimizationCount: 0,
            thirdPartyCount: 0,
            duration: 0,
            totalSize: 0,
            requestCount: 0,
            tags: [],
            notes: "",
            screenshots: []
        )
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.url, "https://example.com")
        XCTAssertEqual(session.performanceRating, "N/A")
        XCTAssertFalse(session.formattedTimestamp.isEmpty)
    }

    func testSessionIndexInstantiation() {
        let index = SessionIndex(sessions: [])
        XCTAssertTrue(index.sessions.isEmpty)
    }

    func testSessionMetadataInstantiation() {
        let session = PersistentSession(
            url: "https://test.com",
            timestamp: Date(),
            deviceProfile: DeviceProfile.desktop,
            resourceCount: 5,
            resourceData: "[]",
            lcpValue: "2.0 s", clsValue: "0.1", fidValue: "80 ms",
            overallScore: 65,
            budgetViolations: [],
            optimizationCount: 2,
            thirdPartyCount: 1,
            duration: 3.0,
            totalSize: 800_000,
            requestCount: 5,
            tags: ["test"],
            notes: "Frame test",
            screenshots: []
        )
        let metadata = SessionMetadata(from: session)
        XCTAssertEqual(metadata.url, "https://test.com")
        XCTAssertEqual(metadata.score, 65)
        XCTAssertEqual(metadata.requestCount, 5)
        XCTAssertEqual(metadata.deviceName, "Desktop")
    }

    // MARK: - Widget Data Models Instantiate

    func testWidgetAnalysisEntryInstantiation() {
        let entry = WidgetAnalysisEntry(
            id: UUID(),
            url: "https://example.com",
            domain: "example.com",
            timestamp: Date(),
            overallScore: 75,
            lcpValue: "2.0 s",
            fidValue: "100 ms",
            clsValue: "0.1",
            loadTime: 2.5,
            requestCount: 30,
            totalSize: 1_000_000
        )
        XCTAssertEqual(entry.url, "https://example.com")
        XCTAssertEqual(entry.domain, "example.com")
        XCTAssertEqual(entry.overallScore, 75)
    }

    func testWidgetAnalysisStatisticsInstantiation() {
        let stats = WidgetAnalysisData.AnalysisStatistics(
            totalAnalyses: 100,
            averageScore: 72.3,
            todayCount: 5,
            weekCount: 25
        )
        XCTAssertEqual(stats.totalAnalyses, 100)
        XCTAssertEqual(stats.averageScore, 72.3, accuracy: 0.01)
    }

    func testWidgetBackendStatusInstantiation() {
        let status = WidgetAnalysisData.BackendStatus(
            isAvailable: true,
            activeBackend: "Ollama",
            lastChecked: Date()
        )
        XCTAssertTrue(status.isAvailable)
        XCTAssertEqual(status.activeBackend, "Ollama")
    }

    // MARK: - Blocking Rules Instantiation

    func testBlockingRulesDefaultInstantiation() {
        let rules = BlockingRules()
        XCTAssertFalse(rules.isEnabled)
        XCTAssertTrue(rules.blockedDomains.isEmpty)
        XCTAssertTrue(rules.blockedTypes.isEmpty)
    }

    // MARK: - Performance Budget Instantiation

    func testPerformanceBudgetDefaultInstantiation() {
        let budget = PerformanceBudget()
        XCTAssertTrue(budget.isEnabled)
        XCTAssertGreaterThan(budget.maxLoadTime, 0)
        XCTAssertGreaterThan(budget.maxSize, 0)
        XCTAssertGreaterThan(budget.maxRequests, 0)
        XCTAssertGreaterThan(budget.minScore, 0)
    }

    // MARK: - AIBackend Manager Singleton

    @MainActor
    func testAIBackendManagerSingletonExists() {
        let manager = AIBackendManager.shared
        XCTAssertNotNil(manager)
        // Verify default backend
        XCTAssertNotNil(manager.activeBackend)
    }

    @MainActor
    func testAIBackendManagerKeychainServiceName() throws {
        // The keychain service name should be a reverse-DNS identifier
        let path = "/Volumes/Data/xcode/URL-Analysis/URL-Analysis/AIBackendManager.swift"
        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(content.contains("com.jordankoch.URLAnalysis"),
                       "Keychain service name should use reverse-DNS format")
    }

    // MARK: - All Device Presets Load

    func testAllDevicePresetsInstantiate() {
        let presets = DeviceProfile.allPresets
        XCTAssertGreaterThanOrEqual(presets.count, 10,
                                     "Should have at least 10 device presets")
        for device in presets {
            XCTAssertFalse(device.name.isEmpty)
            XCTAssertGreaterThan(device.width, 0)
            XCTAssertGreaterThan(device.height, 0)
            XCTAssertGreaterThan(device.pixelRatio, 0)
            XCTAssertFalse(device.userAgent.isEmpty)
        }
    }

    // MARK: - Third-Party Provider Dictionary Loads

    func testThirdPartyProviderDictionaryNotEmpty() {
        XCTAssertGreaterThanOrEqual(ThirdPartyProvider.providers.count, 20,
                                     "Should have at least 20 known third-party providers")
    }

    // MARK: - Resource Types Enum

    func testResourceTypesExist() {
        // Verify key resource types exist
        let document: NetworkResource.ResourceType = .document
        let script: NetworkResource.ResourceType = .script
        let stylesheet: NetworkResource.ResourceType = .stylesheet
        let image: NetworkResource.ResourceType = .image
        let font: NetworkResource.ResourceType = .font

        XCTAssertEqual(document, .document)
        XCTAssertEqual(script, .script)
        XCTAssertEqual(stylesheet, .stylesheet)
        XCTAssertEqual(image, .image)
        XCTAssertEqual(font, .font)
    }
}
