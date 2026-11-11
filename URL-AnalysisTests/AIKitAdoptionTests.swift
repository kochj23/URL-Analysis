//
//  AIKitAdoptionTests.swift
//  URL-AnalysisTests
//
//  The app's NovaAIKit contract: every AI feature works with AI off/offline (built-in analysis), replies are
//  validated/clamped, legacy settings and keys migrate, keys only live in the Keychain, no old AI client is left.
//  Never touches the real network or the real Keychain (stub URLProtocol, memory key store/storage).
//
//  Categories: security, performance, retry, unit, integration, functional, frame (UI state).
//
//  Author: Jordan Koch
//

import XCTest
import SwiftUI
import NovaAIKit
@testable import URL_Analysis

// MARK: - Support

/// Refuses every request: "every backend down".
final class RefuseAllProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)) }
    override func stopLoading() {}
}

/// Answers Ollama chat requests from a queue of canned replies (then refuses). Counts chat requests.
final class CannedOllamaProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var replies: [String] = []
    private static var chats = 0

    static func load(_ r: [String]) { lock.lock(); replies = r; chats = 0; lock.unlock() }
    static var chatCount: Int { lock.lock(); defer { lock.unlock() }; return chats }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        var body = "{\"models\":[{\"name\":\"test-model\"}]}"
        if url.path.hasSuffix("/api/chat") {
            Self.lock.lock()
            Self.chats += 1
            let next = Self.replies.isEmpty ? nil : Self.replies.removeFirst()
            Self.lock.unlock()
            guard let text = next else {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost)); return
            }
            let content = String(data: try! JSONSerialization.data(withJSONObject: [text]), encoding: .utf8)!.dropFirst().dropLast()
            body = "{\"model\":\"test-model\",\"message\":{\"role\":\"assistant\",\"content\":\(content)},\"done\":true}"
        }
        let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

enum AITestSupport {
    static let appID = "urlanalysis"

    @MainActor
    static func makeAI(_ s: NovaAISettings = NovaAISettings(), protocolClass: AnyClass = RefuseAllProtocol.self,
                       keys: NovaAIMemoryKeyStore = NovaAIMemoryKeyStore()) -> NovaAI {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [protocolClass]
        return NovaAI(configuration: NovaAIConfiguration(appID: appID, appName: "URL Analysis"),
                      storage: NovaAIMemoryStorage(s), keyStore: keys,
                      session: URLSession(configuration: cfg), sleep: { _ in })
    }

    /// Ollama only, answered by `CannedOllamaProtocol`.
    @MainActor
    static func cannedAI(_ replies: [String]) -> NovaAI {
        CannedOllamaProtocol.load(replies)
        var s = NovaAISettings(backend: .ollama)
        s.setURL("http://localhost:11434", for: .ollama)
        return makeAI(s, protocolClass: CannedOllamaProtocol.self)
    }

    static func resource(_ url: String, type: NetworkResource.ResourceType = .script, size: Int64 = 50_000,
                         duration: TimeInterval = 0.4, headers: [String: String] = [:]) -> NetworkResource {
        NetworkResource(id: UUID(), url: url, method: "GET", statusCode: 200, mimeType: nil, resourceType: type,
                        startTime: Date(),
                        timings: ResourceTimings(blocked: 0, dns: 0, connect: 0, ssl: 0, send: 0, wait: duration * 0.8, receive: duration * 0.2),
                        requestSize: 200, responseSize: size, requestHeaders: [:], responseHeaders: headers,
                        requestBody: nil, responseBody: nil)
    }

    static var sampleResources: [NetworkResource] {
        [resource("https://example.com/", type: .document, size: 20_000, duration: 0.3, headers: ["Server": "nginx"]),
         resource("https://cdn.example.com/react.production.min.js", size: 140_000, duration: 1.4),
         resource("https://www.google-analytics.com/analytics.js", size: 50_000),
         resource("https://connect.facebook.net/fbevents.js", size: 90_000),
         resource("http://insecure.example.net/pixel.gif", type: .image, size: 1_000)]
    }

    static func suggestion(_ title: String = "Compress images", category: OptimizationSuggestion.Category = .images) -> OptimizationSuggestion {
        OptimizationSuggestion(title: title, description: "Images are large", impact: .high, difficulty: .easy, category: category,
                               affectedResources: [], estimatedSavings: nil, currentState: "2 MB", targetState: "500 KB")
    }

    static func session(score: Double, daysAgo: Double) -> PersistentSession {
        PersistentSession(url: "https://example.com", timestamp: Date().addingTimeInterval(-daysAgo * 86_400), deviceProfile: nil,
                          resourceCount: 10, resourceData: "[]", lcpValue: nil, clsValue: nil, fidValue: nil,
                          overallScore: score, budgetViolations: [], optimizationCount: 0, thirdPartyCount: 0,
                          duration: 2, totalSize: 1_000_000, requestCount: 10, tags: [], notes: "", screenshots: [])
    }

    /// The app's Swift sources (resolved from this file, not a machine-specific path).
    static var appSourceFiles: [URL] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var files: [URL] = []
        for dir in ["URL-Analysis", "URL-Analysis Widget", "CLI"] {
            let e = FileManager.default.enumerator(at: root.appendingPathComponent(dir), includingPropertiesForKeys: nil)
            while let u = e?.nextObject() as? URL { if u.pathExtension == "swift" { files.append(u) } }
        }
        return files
    }
}

// MARK: - Unit

final class AIKitUnitTests: XCTestCase {
    func testKeychainServiceNames() {
        let c = NovaAIConfiguration(appID: "urlanalysis", appName: "URL Analysis")
        XCTAssertEqual(c.keychainService(for: .openRouter), "com.jkoch.urlanalysis.openrouter")
        XCTAssertEqual(c.keychainService(for: .openAI), "com.jkoch.urlanalysis.openai")
        XCTAssertEqual(NovaAIConfiguration.keychainAccount, "apiKey")
    }

    @MainActor func testAppAIIdentity() {
        XCTAssertEqual(AppAI.appID, "urlanalysis")
        XCTAssertEqual(AppAI.shared.configuration.appID, "urlanalysis")
        XCTAssertEqual(AppAI.legacyKeychainService, "com.jordankoch.URLAnalysis")
        XCTAssertFalse(AppAI.settingsFooter.isEmpty)
    }

    func testBackendSetIsTheFullNovaAIKitSet() {
        XCTAssertEqual(NovaAIBackend.allCases.count, 9)
        for b in [NovaAIBackend.auto, .ollama, .mlx, .tinyLLM, .tinyChat, .openWebUI, .novaGateway, .openRouter, .openAI] {
            XCTAssertTrue(NovaAIBackend.allCases.contains(b))
        }
    }

    func testValidatorClampsSecurityAndNeverLowersBuiltInRisk() throws {
        let r = try URLAnalysisAIValidators.security(#"{"riskLevel":"safe","threats":["none"],"explanation":"ok","recommendations":[]}"#, floor: .medium)
        XCTAssertEqual(r.riskLevel, .medium)
        XCTAssertThrowsError(try URLAnalysisAIValidators.security(#"{"riskLevel":"apocalyptic","threats":["x"]}"#, floor: .safe))
        XCTAssertThrowsError(try URLAnalysisAIValidators.security("not json", floor: .safe))
    }

    func testValidatorClampsScoresAndLabels() throws {
        let p = try URLAnalysisAIValidators.privacy(#"{"privacyScore": 250, "risks": ["a"]}"#, trackers: ["t1", "t2"])
        XCTAssertEqual(p.privacyScore, 100)
        XCTAssertEqual(p.trackerCount, 2)
        let w = try URLAnalysisAIValidators.whatIf(#"{"predictedScore": -40, "confidence": "absolutely"}"#, scenario: "s")
        XCTAssertEqual(w.predictedScore, 0)
        XCTAssertEqual(w.confidence, "Low")
        let f = try URLAnalysisAIValidators.codeFix(#"{"code":"a{}","language":"cobol"}"#, defaultTitle: "T")
        XCTAssertEqual(f.language, "text")
        XCTAssertEqual(f.title, "T")
        let reg = try URLAnalysisAIValidators.regression(#"{"hasRegression": false, "severity": "critical"}"#)
        XCTAssertEqual(reg.severity, .none)
        let reg2 = try URLAnalysisAIValidators.regression(#"{"hasRegression": true, "severity": "bogus"}"#)
        XCTAssertEqual(reg2.severity, .minor)
    }

    func testValidatorRejectsNonsense() {
        XCTAssertThrowsError(try URLAnalysisAIValidators.privacy(#"{"privacyScore":"lots"}"#, trackers: []))
        XCTAssertThrowsError(try URLAnalysisAIValidators.techStack(#"{"frontend": null}"#))
        XCTAssertThrowsError(try URLAnalysisAIValidators.codeFix(#"{"code": ""}"#, defaultTitle: "x"))
        XCTAssertThrowsError(try URLAnalysisAIValidators.trend(#"{"predictions": []}"#))
        XCTAssertThrowsError(try URLAnalysisAIValidators.regression(#"{"severity":"critical"}"#))
        XCTAssertThrowsError(try URLAnalysisAIValidators.advice("   "))
        XCTAssertThrowsError(try URLAnalysisAIValidators.answer(""))
    }

    func testInsightValidatorRejectsInventedFigures() throws {
        let source = "- Performance Score: 62/100\n- Total Load Time: 3.41s\n- Total Requests: 48"
        XCTAssertNoThrow(try URLAnalysisAIValidators.insight("The score is 62 with a 3.4s load across 48 requests, which is slow.", source: source))
        XCTAssertThrowsError(try URLAnalysisAIValidators.insight("The page makes 912 requests and takes 27 seconds to load.", source: source))
    }

    func testJSONInFencesAndThinkBlocksIsAccepted() throws {
        let reply = "<think>hmm</think>Here you go:\n```json\n{\"frontend\":\"React\",\"cdn\":\"Cloudflare\"}\n```"
        let s = try URLAnalysisAIValidators.techStack(reply)
        XCTAssertEqual(s.frontend, "React")
        XCTAssertEqual(s.cdn, "Cloudflare")
    }
}

// MARK: - Security

final class AIKitSecurityTests: XCTestCase {
    @MainActor func testKeysGoOnlyToTheKeyStore() {
        let keys = NovaAIMemoryKeyStore()
        let ai = AITestSupport.makeAI(keys: keys)
        XCTAssertTrue(ai.setAPIKey("sk-test-not-real", for: .openAI))
        XCTAssertTrue(ai.hasAPIKey(for: .openAI))
        XCTAssertEqual(keys.read(service: "com.jkoch.urlanalysis.openai", account: "apiKey"), "sk-test-not-real")
        let encoded = String(data: (try? JSONEncoder().encode(ai.settings)) ?? Data(), encoding: .utf8) ?? ""
        XCTAssertFalse(encoded.contains("sk-test-not-real"), "settings must never contain a key")
    }

    @MainActor func testPlaintextLegacyKeysMoveToKeychainAndObsoleteSecretsAreDeleted() {
        let suite = "urla.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("sk-legacy-plaintext", forKey: "AIBackend_OpenAI_Key")
        defaults.set("gcp-secret", forKey: "AIBackend_GoogleCloud_Key")
        defaults.set("us-east-1", forKey: "AIBackend_AWS_Region")
        let keys = NovaAIMemoryKeyStore()
        let legacy = NovaAIMemoryKeyStore([:])
        legacy.write("azure-secret", service: AppAI.legacyKeychainService, account: "AIBackend_Azure_Key")
        legacy.write("ibm-secret", service: AppAI.legacyKeychainService, account: "AIBackend_IBM_Key")
        let ai = AITestSupport.makeAI(keys: keys)

        AppAI.migrateLegacy(ai, defaults: defaults, legacyStore: legacy)

        XCTAssertNil(defaults.string(forKey: "AIBackend_OpenAI_Key"), "plaintext key must leave UserDefaults")
        XCTAssertNil(defaults.string(forKey: "AIBackend_GoogleCloud_Key"))
        XCTAssertNil(defaults.string(forKey: "AIBackend_AWS_Region"))
        XCTAssertTrue(ai.hasAPIKey(for: .openAI))
        XCTAssertNil(legacy.read(service: AppAI.legacyKeychainService, account: "AIBackend_Azure_Key"))
        XCTAssertNil(legacy.read(service: AppAI.legacyKeychainService, account: "AIBackend_IBM_Key"))
    }

    @MainActor func testLegacyKeychainOpenAIKeyMigratesAndOldItemIsRemoved() {
        let suite = "urla.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(AppAI.legacyOpenAIAccount, "AIBackend_" + "OpenAI_Key")
        let keys = NovaAIMemoryKeyStore()
        let legacy = NovaAIMemoryKeyStore()
        legacy.write("sk-old-keychain", service: AppAI.legacyKeychainService, account: AppAI.legacyOpenAIAccount)
        let ai = AITestSupport.makeAI(keys: keys)
        AppAI.migrateLegacy(ai, defaults: defaults, legacyStore: legacy)
        XCTAssertEqual(keys.read(service: "com.jkoch.urlanalysis.openai", account: "apiKey"), "sk-old-keychain")
        XCTAssertNil(legacy.read(service: AppAI.legacyKeychainService, account: AppAI.legacyOpenAIAccount))
        XCTAssertTrue(defaults.bool(forKey: AppAI.keychainMigrationMarker))
    }

    @MainActor func testKeyIsNeverSentOverPlainHTTP() async {
        var s = NovaAISettings(backend: .openAI)
        s.setURL("http://api.example.com", for: .openAI)
        let keys = NovaAIMemoryKeyStore()
        let ai = AITestSupport.makeAI(s, keys: keys)
        ai.setAPIKey("sk-test-not-real", for: .openAI)
        do {
            _ = try await ai.complete(NovaAIRequest(prompt: "x"))
            XCTFail("must refuse")
        } catch {
            XCTAssertEqual(error as? NovaAIError, .insecureTransport("api.example.com"))
        }
    }

    func testNoLegacyAIClientInSources() throws {
        let files = AITestSupport.appSourceFiles
        XCTAssertFalse(files.isEmpty)
        for f in files {
            let text = try String(contentsOf: f, encoding: .utf8)
            for banned in ["AIBackendManager", "EthicalAIGuardian", "AIBackendStatusMenu", "OPENAI_API_KEY", "AIBackend_OpenAI_Key\")"] {
                if banned == "AIBackendManager" && text.contains("migrateFromLegacyAIBackendManager") {
                    XCTAssertFalse(text.replacingOccurrences(of: "migrateFromLegacyAIBackendManager", with: "").contains(banned), f.lastPathComponent)
                } else {
                    XCTAssertFalse(text.contains(banned), "\(f.lastPathComponent) still references \(banned)")
                }
            }
            XCTAssertNil(text.range(of: "sk-[A-Za-z0-9]{20,}", options: .regularExpression), "\(f.lastPathComponent): hardcoded key?")
        }
    }
}

// MARK: - Functional (AI off / offline: every feature still produces its built-in result)

@MainActor
final class AIKitFunctionalTests: XCTestCase {
    func runAllFeatures(_ analyzer: AIURLAnalyzer) async -> [String: Bool] {
        let url = URL(string: "https://example.com")!
        let resources = AITestSupport.sampleResources
        let monitor = NetworkMonitor()
        monitor.resources = resources
        var ok: [String: Bool] = [:]
        ok["insights"] = !(await analyzer.analyzePerformance(monitor: monitor, score: 55, vitals: nil)).isEmpty
        let sec = await analyzer.analyzeURLSecurity(url: url, resources: resources)
        ok["security"] = !sec.threats.isEmpty && sec.riskLevel >= .low
        ok["coach"] = (await analyzer.generateOptimizationCoaching(suggestions: [AITestSupport.suggestion(), AITestSupport.suggestion("Defer JS", category: .javascript)], resources: resources)).count == 2
        ok["techstack"] = (await analyzer.detectTechnologyStack(url: url, resources: resources)).frontend == "React"
        let privacy = await analyzer.analyzePrivacyImpact(resources: resources)
        ok["privacy"] = privacy.trackerCount >= 2 && (0...100).contains(privacy.privacyScore)
        let ctx = URLAnalysisContext(url: url, performanceScore: 55, loadTime: 1.4, requestCount: 5, totalSize: 300_000,
                                     largestResource: nil, slowestResource: nil, thirdPartyDomains: [], securityIssues: [])
        let answer = await analyzer.askQuestion("Why is it slow?", context: ctx)
        ok["qa"] = answer.contains("Built-in analysis") && answer.contains("Performance Score: 55/100")
        ok["codefix"] = (await analyzer.generateCodeFixes(suggestions: [AITestSupport.suggestion()], techStack: nil, resources: resources)).count == 1
        ok["whatif"] = (0...100).contains((await analyzer.simulateWhatIf(scenario: .compressImages, currentSession: monitor, historicalData: [])).predictedScore)
        let sessions = (0..<6).map { AITestSupport.session(score: Double(60 + $0), daysAgo: Double(6 - $0)) }
        ok["trends"] = !(await analyzer.analyzeTrends(sessions: sessions, forURL: "https://example.com")).summary.isEmpty
        ok["regression"] = !(await analyzer.detectRegression(currentSession: monitor, historicalSessions: sessions)).recommendations.isEmpty
        return ok
    }

    func testEveryFeatureWorksWithAIOff() async {
        let analyzer = AIURLAnalyzer(ai: AITestSupport.makeAI(NovaAISettings(enabled: false)))
        let ok = await runAllFeatures(analyzer)
        XCTAssertEqual(ok.count, 10)
        for (feature, passed) in ok { XCTAssertTrue(passed, "\(feature) failed with AI off") }
        XCTAssertEqual(analyzer.sources["security"], .fallback(.disabled))
        XCTAssertNil(analyzer.lastError)
    }

    func testEveryFeatureFallsBackWhenOffline() async {
        let analyzer = AIURLAnalyzer(ai: AITestSupport.makeAI())
        let ok = await runAllFeatures(analyzer)
        for (feature, passed) in ok { XCTAssertTrue(passed, "\(feature) failed offline") }
        XCTAssertEqual(analyzer.sources["insights"]?.isAI, false)
        XCTAssertNotNil(analyzer.lastError)
    }

    func testRegressionWithNoHistoryDoesNotCrash() async {
        let analyzer = AIURLAnalyzer(ai: AITestSupport.makeAI())
        let r = await analyzer.detectRegression(currentSession: NetworkMonitor(), historicalSessions: [])
        XCTAssertFalse(r.hasRegression)
    }
}

// MARK: - Integration (stubbed backend → validated AI values)

@MainActor
final class AIKitIntegrationTests: XCTestCase {
    func testValidAIReplyIsUsedAndLabelled() async {
        let ai = AITestSupport.cannedAI([#"{"frontend":"Vue.js","cdn":"Fastly","analytics":["Matomo"]}"#])
        let analyzer = AIURLAnalyzer(ai: ai)
        let stack = await analyzer.detectTechnologyStack(url: URL(string: "https://example.com")!, resources: AITestSupport.sampleResources)
        XCTAssertEqual(stack.frontend, "Vue.js")
        XCTAssertEqual(analyzer.sources["techstack"]?.isAI, true)
        XCTAssertTrue(analyzer.lastSource?.label.hasPrefix("AI · Ollama") == true)
    }

    func testSecurityAIReplyCannotDowngradeHeuristicRisk() async {
        let ai = AITestSupport.cannedAI([#"{"riskLevel":"safe","threats":["none"],"explanation":"fine","recommendations":[]}"#])
        let analyzer = AIURLAnalyzer(ai: ai)
        let r = await analyzer.analyzeURLSecurity(url: URL(string: "http://login.example.tk")!, resources: [])
        XCTAssertEqual(r.riskLevel, .high)
        XCTAssertEqual(analyzer.securityAnalysis?.riskLevel, .high)
    }

    func testQuestionAnswerFromAI() async {
        let ai = AITestSupport.cannedAI(["The **largest** cost is the 140 KB React bundle."])
        let analyzer = AIURLAnalyzer(ai: ai)
        let ctx = URLAnalysisContext(url: URL(string: "https://example.com")!, performanceScore: 70, loadTime: 1, requestCount: 3,
                                     totalSize: 1, largestResource: nil, slowestResource: nil, thirdPartyDomains: [], securityIssues: [])
        let a = await analyzer.askQuestion("What is biggest?", context: ctx)
        XCTAssertEqual(a, "The largest cost is the 140 KB React bundle.")
    }

    func testLegacySettingsMigrate() {
        let suite = "urla.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("Ollama", forKey: "AIBackend_Active")
        defaults.set("http://studio.local:11434", forKey: "AIBackend_OllamaURL")
        defaults.set("qwen3:8b", forKey: "AIBackend_OllamaModel")
        let ai = AITestSupport.makeAI()
        AppAI.migrateLegacy(ai, defaults: defaults, legacyStore: NovaAIMemoryKeyStore())
        XCTAssertEqual(ai.settings.backend, .ollama)
        XCTAssertEqual(ai.settings.url(for: .ollama), "http://studio.local:11434")
        XCTAssertEqual(ai.settings.model(for: .ollama), "qwen3:8b")
    }
}

// MARK: - Retry

@MainActor
final class AIKitRetryTests: XCTestCase {
    func testRejectedReplyIsRetriedOnceThenAccepted() async {
        let ai = AITestSupport.cannedAI([#"{"privacyScore": "lots"}"#, #"{"privacyScore": 40, "risks": ["cross-site tracking"]}"#])
        let analyzer = AIURLAnalyzer(ai: ai)
        let p = await analyzer.analyzePrivacyImpact(resources: AITestSupport.sampleResources)
        XCTAssertEqual(p.privacyScore, 40)
        XCTAssertEqual(analyzer.sources["privacy"]?.isAI, true)
        XCTAssertEqual(CannedOllamaProtocol.chatCount, 2)
    }

    func testTwoRejectedRepliesFallBackToBuiltIn() async {
        let ai = AITestSupport.cannedAI([#"{"risks": []}"#, #"{"privacyScore": null}"#])
        let analyzer = AIURLAnalyzer(ai: ai)
        let p = await analyzer.analyzePrivacyImpact(resources: AITestSupport.sampleResources)
        XCTAssertEqual(p.trackerCount, 2)
        guard case .fallback(.validationFailed)? = analyzer.sources["privacy"] else {
            return XCTFail("expected validation fallback, got \(String(describing: analyzer.sources["privacy"]))")
        }
        XCTAssertTrue(analyzer.lastError?.contains("rejected") == true)
    }

    func testOfflineBatchStopsAfterFirstFailure() async {
        let ai = AITestSupport.cannedAI([])   // every chat request refused
        let analyzer = AIURLAnalyzer(ai: ai)
        let suggestions = (0..<5).map { AITestSupport.suggestion("S\($0)") }
        let advice = await analyzer.generateOptimizationCoaching(suggestions: suggestions, resources: [])
        XCTAssertEqual(advice.count, 5)
        XCTAssertLessThanOrEqual(CannedOllamaProtocol.chatCount, 4, "remaining items must not each wait on a dead backend")
    }
}

// MARK: - Performance

final class AIKitPerformanceTests: XCTestCase {
    func testValidatorsAreFast() {
        let reply = #"{"summary":"stable","predictions":[{"metric":"Score","forecast":"80","confidence":"High","trend":"Stable"}],"anomalies":[],"patterns":[],"recommendation":"r"}"#
        measure {
            for _ in 0..<500 { _ = try? URLAnalysisAIValidators.trend(reply) }
        }
    }

    @MainActor func testAIOffFallbackIsImmediate() async {
        let analyzer = AIURLAnalyzer(ai: AITestSupport.makeAI(NovaAISettings(enabled: false)))
        let start = Date()
        for _ in 0..<50 { _ = await analyzer.analyzePrivacyImpact(resources: AITestSupport.sampleResources) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }
}

// MARK: - Frame / UI state

@MainActor
final class AIKitFrameTests: XCTestCase {
    func testAnalyzerStateResetsAfterRun() async {
        let analyzer = AIURLAnalyzer(ai: AITestSupport.makeAI(NovaAISettings(enabled: false)))
        XCTAssertFalse(analyzer.isAnalyzing)
        XCTAssertNil(analyzer.lastSource)
        _ = await analyzer.analyzePrivacyImpact(resources: [])
        XCTAssertFalse(analyzer.isAnalyzing)
        XCTAssertEqual(analyzer.lastSource?.label, "Built-in")
        XCTAssertNotNil(analyzer.privacyAnalysis)
    }

    func testStatusIsOffWhenDisabled() {
        let ai = AITestSupport.makeAI(NovaAISettings(enabled: false))
        XCTAssertEqual(ai.status.state, .off)
        XCTAssertFalse(ai.isEnabled)
    }

    func testSettingsAndStatusViewsBuild() {
        let ai = AITestSupport.makeAI()
        let views: [NSView] = [
            NSHostingView(rootView: NovaAISettingsView(ai: ai, footer: AppAI.settingsFooter)),
            NSHostingView(rootView: NovaAIStatusIndicator(ai: ai, checksOnAppear: false)),
            NSHostingView(rootView: AIAnalysisView(analyzer: AIURLAnalyzer(ai: ai), monitor: NetworkMonitor(), currentURL: "https://example.com")),
        ]
        for v in views {
            v.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
            v.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(v.fittingSize.width, 0)
        }
    }

    func testWidgetBackendStatusReflectsAI() {
        let data = WidgetDataSyncManager.shared.currentBackendStatus()
        XCTAssertFalse((data.activeBackend ?? "").isEmpty)
    }
}
