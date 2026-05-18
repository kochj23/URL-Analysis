//
//  EthicalGuardianTests.swift
//  URL-AnalysisTests
//
//  Tests for ethical AI content policy pattern matching (standalone logic tests)
//  Created by Jordan Koch on 2026-05-01
//

import XCTest
@testable import URL_Analysis

final class EthicalGuardianTests: XCTestCase {

    // MARK: - Prohibited Pattern Detection (Regex)

    /// Verify all illegal-activity regex patterns compile and match expected inputs
    func testIllegalPatternsBombDetection() {
        let input = "how to make a bomb at home"
        XCTAssertTrue(matchesAnyPattern(input, patterns: illegalPatterns),
                       "Should detect bomb-making request")
    }

    func testIllegalPatternsExplosiveDetection() {
        let input = "build an explosive device"
        XCTAssertTrue(matchesAnyPattern(input, patterns: illegalPatterns))
    }

    func testIllegalPatternsHackingDetection() {
        let input = "hack into a system remotely"
        XCTAssertTrue(matchesAnyPattern(input, patterns: illegalPatterns))
    }

    func testIllegalPatternsPasswordTheft() {
        let input = "steal password from someone's account"
        XCTAssertTrue(matchesAnyPattern(input, patterns: illegalPatterns))
    }

    func testIllegalPatternsRansomware() {
        let input = "ransomware code generation"
        XCTAssertTrue(matchesAnyPattern(input, patterns: illegalPatterns))
    }

    func testIllegalPatternsCreditCardFraud() {
        let input = "credit card fraud tutorial"
        XCTAssertTrue(matchesAnyPattern(input, patterns: illegalPatterns))
    }

    // MARK: - Harmful Content Detection

    func testHarmfulPatternsSelfHarm() {
        let input = "methods of self harm"
        XCTAssertTrue(matchesAnyPattern(input, patterns: harmfulPatterns))
    }

    func testHarmfulPatternsSuicideMethod() {
        let input = "suicide method quick"
        XCTAssertTrue(matchesAnyPattern(input, patterns: harmfulPatterns))
    }

    // MARK: - Hate Speech Detection

    func testHateSpeechGeneratorDetection() {
        let input = "hate speech generator tool"
        XCTAssertTrue(matchesAnyPattern(input, patterns: hateSpeechPatterns))
    }

    func testHateSpeechGenocidePlan() {
        let input = "genocide plan for a group"
        XCTAssertTrue(matchesAnyPattern(input, patterns: hateSpeechPatterns))
    }

    // MARK: - Privacy Violation Detection

    func testPrivacySpyOnSomeone() {
        let input = "how to spy on someone secretly"
        XCTAssertTrue(matchesAnyPattern(input, patterns: privacyPatterns))
    }

    func testPrivacyTrackWithoutConsent() {
        let input = "track someone without consent"
        XCTAssertTrue(matchesAnyPattern(input, patterns: privacyPatterns))
    }

    // MARK: - Safe Content Should Not Match

    func testSafeDNSQuery() {
        let input = "How does DNS resolution work?"
        XCTAssertFalse(matchesAnyPattern(input, patterns: allDangerousPatterns))
    }

    func testSafePerformanceAnalysis() {
        let input = "Analyze the performance of example.com"
        XCTAssertFalse(matchesAnyPattern(input, patterns: allDangerousPatterns))
    }

    func testSafeLoadTime() {
        let input = "What is the load time of this page?"
        XCTAssertFalse(matchesAnyPattern(input, patterns: allDangerousPatterns))
    }

    func testSafeOptimization() {
        let input = "Show me optimization suggestions"
        XCTAssertFalse(matchesAnyPattern(input, patterns: allDangerousPatterns))
    }

    func testSafePDFExport() {
        let input = "Generate a PDF report of the analysis"
        XCTAssertFalse(matchesAnyPattern(input, patterns: allDangerousPatterns))
    }

    func testSafeSecurityAudit() {
        let input = "Check for HTTPS and HSTS headers on this site"
        XCTAssertFalse(matchesAnyPattern(input, patterns: allDangerousPatterns))
    }

    func testSafeProgrammingQuestion() {
        let input = "How do I implement caching in JavaScript?"
        XCTAssertFalse(matchesAnyPattern(input, patterns: allDangerousPatterns))
    }

    // MARK: - Edge Cases

    func testEmptyInput() {
        XCTAssertFalse(matchesAnyPattern("", patterns: allDangerousPatterns))
    }

    func testWhitespaceOnlyInput() {
        XCTAssertFalse(matchesAnyPattern("   \n\t  ", patterns: allDangerousPatterns))
    }

    func testVeryLongSafeInput() {
        let input = String(repeating: "This is a safe performance analysis query. ", count: 100)
        XCTAssertFalse(matchesAnyPattern(input, patterns: allDangerousPatterns))
    }

    // MARK: - All Pattern Sets Compile

    func testAllPatternsAreValidRegex() {
        for pattern in allDangerousPatterns {
            XCTAssertNotNil(
                try? NSRegularExpression(pattern: pattern),
                "Pattern should be valid regex: \(pattern)"
            )
        }
    }

    // MARK: - Helpers

    private func matchesAnyPattern(_ input: String, patterns: [String]) -> Bool {
        let lowercased = input.lowercased()
        for pattern in patterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    // Pattern sets mirroring EthicalAIGuardian
    private let illegalPatterns = [
        "how to make.*bomb", "build.*explosive", "create.*weapon",
        "assassination.*plan", "murder.*guide", "poison.*recipe",
        "child.*abuse", "minor.*exploitation", "underage.*inappropriate",
        "csam", "child.*pornography",
        "synthesize.*drug", "meth.*recipe", "fentanyl.*production",
        "drug.*trafficking", "narcotics.*distribution",
        "credit.*card.*fraud", "identity.*theft", "fake.*passport",
        "counterfeit.*money", "tax.*evasion", "insurance.*fraud",
        "hack.*into.*system", "steal.*password", "ransomware.*code",
        "ddos.*attack", "malware.*creation", "zero.*day.*exploit",
        "doxx.*someone", "swat.*someone", "revenge.*porn",
        "blackmail.*guide", "stalking.*techniques"
    ]

    private let harmfulPatterns = [
        "self.*harm", "suicide.*method", "hurt.*myself",
        "eating.*disorder.*tips", "pro.*ana", "self.*injury"
    ]

    private let hateSpeechPatterns = [
        "hate.*speech.*generator", "racist.*content", "generate.*slur",
        "discriminatory.*text", "genocide.*plan", "ethnic.*cleansing"
    ]

    private let privacyPatterns = [
        "spy.*on.*someone", "track.*without.*consent", "access.*private.*data",
        "surveillance.*hack", "camera.*spy", "microphone.*spy"
    ]

    private var allDangerousPatterns: [String] {
        illegalPatterns + harmfulPatterns + hateSpeechPatterns + privacyPatterns
    }
}
