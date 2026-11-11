//
//  AIURLAnalyzer.swift
//  URL Analysis
//
//  AI-powered URL and performance analysis via NovaAIKit (AppAI.shared).
//  Every feature has a built-in (non-AI) result that is used when AI is off, unreachable, or its reply fails
//  validation (URLAnalysisAIValidators). `lastSource` says where the latest value came from.
//  Author: Jordan Koch
//  Date: 2025-01-17
//
//  THIRD-PARTY ATTRIBUTION:
//  - TinyLLM by Jason Cox (https://github.com/jasonacox/TinyLLM)
//

import Foundation
import SwiftUI
import NovaAIKit

/// AI-powered URL analysis manager
@MainActor
class AIURLAnalyzer: ObservableObject {
    @Published var isAnalyzing = false
    @Published var performanceInsights: String = ""
    @Published var securityAnalysis: SecurityAnalysisResult?
    @Published var optimizationAdvice: [AIOptimizationAdvice] = []
    @Published var technologyStack: TechnologyStack?
    @Published var privacyAnalysis: PrivacyAnalysis?
    @Published var lastError: String?

    // New AI Features
    @Published var generatedCode: [CodeFix] = []
    @Published var whatIfResults: [WhatIfScenario] = []
    @Published var trendAnalysis: TrendAnalysisResult?
    @Published var regressionReport: RegressionReport?

    /// Where the most recent result came from ("AI · Ollama (qwen3:8b)" / "Built-in").
    @Published var lastSource: NovaAISource?
    /// Per-feature source labels, keyed by feature name ("insights", "security", …).
    @Published var sources: [String: NovaAISource] = [:]

    private let ai: NovaAI

    init(ai: NovaAI? = nil) {
        self.ai = ai ?? AppAI.shared
    }

    /// Runs one AI request with the never-throwing NovaAIKit contract and records its source.
    private func run<Value: Sendable>(_ feature: String, _ request: NovaAIRequest,
                                      validate: @escaping @Sendable (String) throws -> Value,
                                      fallback: Value) async -> Value {
        isAnalyzing = true
        defer { isAnalyzing = false }
        let result = await ai.generate(request, validate: validate, fallback: { fallback })
        record(feature, result.source)
        return result.value
    }

    /// True when the last result for `feature` fell back because AI is off or unreachable (not a rejected reply):
    /// the remaining items of a batch then use the built-in result straight away instead of waiting on timeouts.
    private func stopAfterFallback(_ feature: String) -> Bool {
        guard case .fallback(let reason)? = sources[feature] else { return false }
        if case .validationFailed = reason { return false }
        return true
    }

    private func record(_ feature: String, _ source: NovaAISource) {
        sources[feature] = source
        lastSource = source
        switch source {
        case .ai: lastError = nil
        case .fallback(.disabled): lastError = nil
        case .fallback(.unavailable(let why)): lastError = why
        case .fallback(.validationFailed(let why)): lastError = "AI reply rejected: \(why)"
        }
    }

    // MARK: - Feature 1: AI Performance Insights

    /// Generate natural language performance insights
    func analyzePerformance(monitor: NetworkMonitor, score: Int, vitals: WebVitals?) async -> String {
        let fallback = generateBasicPerformanceInsight(monitor: monitor, score: score)
        let context = buildPerformanceContext(monitor: monitor, score: score, vitals: vitals)

        let prompt = """
        Analyze this web page's performance and provide insights in 3-4 sentences.
        Be specific, mention actual numbers, and explain WHY performance is good or bad.

        PERFORMANCE DATA:
        \(context)

        Provide a clear, actionable summary focusing on the biggest issues.
        """

        let request = NovaAIRequest(prompt: prompt,
                                    system: "You are a web performance expert. Provide concise, actionable insights. Only use the numbers given.",
                                    temperature: 0.4, maxTokens: 300)
        let insights = await run("insights", request,
                                 validate: { try URLAnalysisAIValidators.insight($0, source: context) },
                                 fallback: fallback)
        performanceInsights = insights
        return insights
    }

    private func buildPerformanceContext(monitor: NetworkMonitor, score: Int, vitals: WebVitals?) -> String {
        let totalSize = monitor.resources.reduce(0) { $0 + $1.responseSize }
        let totalTime = monitor.resources.map { $0.timings.total }.max() ?? 0
        let requestCount = monitor.resources.count

        var context = """
        - Performance Score: \(score)/100
        - Total Load Time: \(String(format: "%.2f", totalTime))s
        - Total Requests: \(requestCount)
        - Total Size: \(formatBytes(totalSize))
        """

        if let vitals = vitals {
            context += """

            - LCP (Largest Contentful Paint): \(vitals.lcp.value)
            - CLS (Cumulative Layout Shift): \(vitals.cls.value)
            - FID (First Input Delay): \(vitals.fid.value)
            """
        }

        // Add slow resources
        let slowResources = monitor.resources
            .filter { $0.totalDuration > 1.0 }
            .sorted { $0.totalDuration > $1.totalDuration }
            .prefix(3)

        if !slowResources.isEmpty {
            context += "\n\nSlowest Resources:"
            for resource in slowResources {
                if let url = URL(string: resource.url) {
                    context += "\n- \(url.lastPathComponent): \(String(format: "%.2f", resource.totalDuration))s"
                }
            }
        }

        return context
    }

    func generateBasicPerformanceInsight(monitor: NetworkMonitor, score: Int) -> String {
        if score >= 90 {
            return "Excellent performance! Page loads quickly with minimal overhead."
        } else if score >= 70 {
            return "Good performance, but there's room for improvement. Check the Optimize tab for suggestions."
        } else if score >= 50 {
            return "Moderate performance issues detected. Multiple optimization opportunities available."
        } else {
            return "Significant performance issues. Immediate optimization recommended."
        }
    }

    // MARK: - Feature 2: AI Security Analysis

    /// Analyze URL for security threats
    func analyzeURLSecurity(url: URL, resources: [NetworkResource]) async -> SecurityAnalysisResult {
        let basic = performBasicSecurityCheck(url: url, resources: resources)
        let floor = basic.riskLevel
        let context = buildSecurityContext(url: url, resources: resources)

        let prompt = """
        Analyze this URL and network activity for security concerns.
        Look for: phishing indicators, malware patterns, suspicious redirects, insecure connections,
        known malicious domains, data exfiltration patterns.

        URL AND NETWORK DATA:
        \(context)

        Respond in JSON format:
        {
            "riskLevel": "safe|low|medium|high|critical",
            "threats": ["list of identified threats"],
            "explanation": "brief explanation",
            "recommendations": ["security recommendations"]
        }
        """

        let request = NovaAIRequest(prompt: prompt,
                                    system: "You are a cybersecurity expert analyzing URLs for threats. Reply with JSON only.",
                                    temperature: 0.3, maxTokens: 500, format: .json)
        let result = await run("security", request,
                               validate: { try URLAnalysisAIValidators.security($0, floor: floor) },
                               fallback: basic)
        securityAnalysis = result
        return result
    }

    private func buildSecurityContext(url: URL, resources: [NetworkResource]) -> String {
        let httpCount = resources.filter { URL(string: $0.url)?.scheme == "http" }.count
        let domains = Set(resources.compactMap { URL(string: $0.url)?.host }).joined(separator: ", ")
        let redirects = resources.filter { $0.responseHeaders["Location"] != nil }.count

        return """
        Main URL: \(url.absoluteString)
        Total Requests: \(resources.count)
        Unique Domains: \(Set(resources.compactMap { URL(string: $0.url)?.host }).count)
        Insecure (HTTP): \(httpCount)
        Redirects: \(redirects)
        Domains: \(domains)
        """
    }

    func performBasicSecurityCheck(url: URL, resources: [NetworkResource]) -> SecurityAnalysisResult {
        var threats: [String] = []
        var riskLevel: SecurityRiskLevel = .safe

        // Check for HTTP
        if url.scheme == "http" {
            threats.append("Insecure connection (HTTP instead of HTTPS)")
            riskLevel = .medium
        }

        // Check for suspicious TLDs
        let suspiciousTLDs = [".tk", ".ml", ".ga", ".cf", ".gq", ".zip", ".review"]
        if let host = url.host, suspiciousTLDs.contains(where: { host.hasSuffix($0) }) {
            threats.append("Suspicious top-level domain")
            riskLevel = .high
        }

        // Check for mixed content
        let mixedContent = resources.filter { URL(string: $0.url)?.scheme == "http" }.count
        if url.scheme == "https" && mixedContent > 0 {
            threats.append("Mixed content: \(mixedContent) insecure resources on secure page")
            riskLevel = max(riskLevel, .low)
        }

        if threats.isEmpty {
            threats.append("No obvious security threats detected")
        }

        return SecurityAnalysisResult(
            riskLevel: riskLevel,
            threats: threats,
            explanation: threats.joined(separator: ". "),
            recommendations: riskLevel == .safe ? ["Continue monitoring for changes"] : ["Use HTTPS", "Verify domain legitimacy"]
        )
    }

    // MARK: - Feature 3: AI Optimization Coach

    /// Generate detailed optimization advice with implementation examples
    func generateOptimizationCoaching(suggestions: [OptimizationSuggestion], resources: [NetworkResource]) async -> [AIOptimizationAdvice] {
        var aiAdvice: [AIOptimizationAdvice] = []

        // Process top 5 suggestions
        for suggestion in suggestions.prefix(5) {
            let context = """
            Issue: \(suggestion.title)
            Category: \(suggestion.category.rawValue)
            Impact: \(suggestion.impact.rawValue)
            Difficulty: \(suggestion.difficulty.rawValue)
            Current State: \(suggestion.currentState)
            Affected Resources: \(suggestion.affectedResources.count)
            """

            let prompt = """
            Provide detailed optimization advice for this web performance issue.
            Include: WHY it matters, HOW to fix it (with code examples), and EXPECTED impact.

            ISSUE:
            \(context)

            Format response as:
            WHY: [1-2 sentences]
            HOW: [specific implementation steps with code example if applicable]
            IMPACT: [expected improvement]
            """

            let request = NovaAIRequest(prompt: prompt,
                                        system: "You are a web performance optimization expert. Provide practical, implementable advice.",
                                        temperature: 0.4, maxTokens: 400)
            let advice = await run("coach", request, validate: { try URLAnalysisAIValidators.advice($0) },
                                   fallback: Self.basicAdvice(for: suggestion))
            aiAdvice.append(AIOptimizationAdvice(
                suggestion: suggestion,
                aiAdvice: advice,
                implementationExample: extractCodeExample(from: advice)
            ))
            if stopAfterFallback("coach") { break }
        }

        if aiAdvice.count < min(5, suggestions.count) {
            aiAdvice += suggestions.prefix(5).dropFirst(aiAdvice.count).map {
                AIOptimizationAdvice(suggestion: $0, aiAdvice: Self.basicAdvice(for: $0), implementationExample: nil)
            }
        }
        optimizationAdvice = aiAdvice
        return aiAdvice
    }

    static func basicAdvice(for suggestion: OptimizationSuggestion) -> String {
        "Priority: \(suggestion.impact.rawValue) impact, \(suggestion.difficulty.rawValue) difficulty. \(suggestion.description)"
    }

    // MARK: - Feature 4: AI Technology Stack Detection

    /// Detect frameworks, CMS, and libraries from network traffic
    func detectTechnologyStack(url: URL, resources: [NetworkResource]) async -> TechnologyStack {
        let basic = performBasicTechDetection(resources: resources)

        // Collect clues from URLs, headers, and patterns
        let clues = extractTechnologyClues(from: resources)

        let prompt = """
        Analyze these network requests to identify the technology stack.
        Identify: Framework (React, Vue, Angular, etc.), CMS (WordPress, Shopify, etc.),
        Analytics, CDN, Hosting provider, Libraries.

        CLUES FROM NETWORK TRAFFIC:
        \(clues)

        Respond in JSON format:
        {
            "frontend": "Framework name and version (if detected)",
            "backend": "Server technology (if detected)",
            "cms": "CMS name (if detected)",
            "analytics": ["list of analytics tools"],
            "cdn": "CDN provider (if detected)",
            "libraries": ["detected libraries"],
            "hosting": "Hosting provider (if detected)"
        }
        """

        let request = NovaAIRequest(prompt: prompt,
                                    system: "You are a web technology expert. Identify technologies from network patterns. Reply with JSON only.",
                                    temperature: 0.2, maxTokens: 400, format: .json)
        let stack = await run("techstack", request, validate: { try URLAnalysisAIValidators.techStack($0) }, fallback: basic)
        technologyStack = stack
        return stack
    }

    private func extractTechnologyClues(from resources: [NetworkResource]) -> String {
        var clues: [String] = []

        for resource in resources.prefix(50) {
            let urlString = resource.url.lowercased()

            // Look for framework indicators
            if urlString.contains("react") { clues.append("React framework detected") }
            if urlString.contains("vue") { clues.append("Vue.js detected") }
            if urlString.contains("angular") { clues.append("Angular detected") }
            if urlString.contains("jquery") { clues.append("jQuery detected") }
            if urlString.contains("next") { clues.append("Next.js detected") }
            if urlString.contains("nuxt") { clues.append("Nuxt.js detected") }

            // Analytics
            if urlString.contains("google-analytics") || urlString.contains("gtag") {
                clues.append("Google Analytics detected")
            }
            if urlString.contains("facebook.com/tr") || urlString.contains("fbevents") {
                clues.append("Facebook Pixel detected")
            }

            // CDN
            if urlString.contains("cloudflare") { clues.append("Cloudflare CDN") }
            if urlString.contains("akamai") { clues.append("Akamai CDN") }
            if urlString.contains("fastly") { clues.append("Fastly CDN") }
            if urlString.contains("jsdelivr") { clues.append("jsDelivr CDN") }

            // Check server header
            if let server = resource.responseHeaders["Server"] {
                clues.append("Server: \(server)")
            }

            // Check X-Powered-By header
            if let poweredBy = resource.responseHeaders["X-Powered-By"] {
                clues.append("Powered by: \(poweredBy)")
            }
        }

        return clues.isEmpty ? "No obvious technology indicators found" : clues.prefix(20).joined(separator: "\n")
    }

    func performBasicTechDetection(resources: [NetworkResource]) -> TechnologyStack {
        var frontend: String? = nil
        var analytics: [String] = []
        var cdn: String? = nil

        for resource in resources {
            let urlString = resource.url.lowercased()

            if frontend == nil {
                if urlString.contains("react") { frontend = "React" }
                else if urlString.contains("vue") { frontend = "Vue.js" }
                else if urlString.contains("angular") { frontend = "Angular" }
            }

            if urlString.contains("google-analytics") { analytics.append("Google Analytics") }
            if urlString.contains("facebook.com/tr") { analytics.append("Facebook Pixel") }

            if cdn == nil {
                if urlString.contains("cloudflare") { cdn = "Cloudflare" }
                else if urlString.contains("akamai") { cdn = "Akamai" }
            }
        }

        return TechnologyStack(
            frontend: frontend ?? "Unknown",
            backend: nil,
            cms: nil,
            analytics: Set(analytics).sorted(),
            cdn: cdn,
            libraries: [],
            hosting: nil
        )
    }

    // MARK: - Feature 5: AI Privacy Impact Analysis

    /// Analyze trackers and privacy implications
    func analyzePrivacyImpact(resources: [NetworkResource]) async -> PrivacyAnalysis {
        let basic = performBasicPrivacyAnalysis(resources: resources)
        let trackers = identifyTrackers(from: resources)
        let thirdPartyDomains = Set(resources.compactMap { URL(string: $0.url)?.host }).count

        let context = """
        Page loads from \(thirdPartyDomains) different domains.
        Identified trackers: \(trackers.joined(separator: ", "))
        Total third-party requests: \(resources.count)

        Tracker details:
        \(trackers.prefix(10).joined(separator: "\n"))
        """

        let prompt = """
        Analyze the privacy impact of these trackers and third-party resources.
        Explain: What data they collect, why it matters, privacy risks.

        TRACKING DATA:
        \(context)

        Respond in JSON:
        {
            "privacyScore": 0-100 (100 = best privacy),
            "dataCollected": ["list of data types being collected"],
            "risks": ["privacy risks"],
            "recommendations": ["privacy improvements"]
        }
        """

        let request = NovaAIRequest(prompt: prompt,
                                    system: "You are a privacy expert. Explain tracker implications clearly. Reply with JSON only.",
                                    temperature: 0.3, maxTokens: 500, format: .json)
        let analysis = await run("privacy", request,
                                 validate: { try URLAnalysisAIValidators.privacy($0, trackers: trackers) },
                                 fallback: basic)
        privacyAnalysis = analysis
        return analysis
    }

    private func identifyTrackers(from resources: [NetworkResource]) -> [String] {
        let trackerKeywords = [
            "google-analytics", "gtag", "ga.js",
            "facebook.com/tr", "fbevents", "fbq",
            "doubleclick", "googletagmanager",
            "hotjar", "mixpanel", "segment",
            "amplitude", "heap", "fullstory",
            "linkedin.com/px", "twitter.com/i",
            "pinterest.com/ct"
        ]

        var trackers: [String] = []

        for resource in resources {
            let urlString = resource.url.lowercased()
            for keyword in trackerKeywords {
                if urlString.contains(keyword) {
                    let host = URL(string: resource.url)?.host ?? "unknown"
                    trackers.append("\(keyword) - \(host)")
                    break
                }
            }
        }

        return trackers
    }

    func performBasicPrivacyAnalysis(resources: [NetworkResource]) -> PrivacyAnalysis {
        let trackers = identifyTrackers(from: resources)
        let trackerCount = trackers.count

        let privacyScore = max(0, 100 - (trackerCount * 10))

        let dataCollected = trackerCount > 0 ? [
            "Page views and browsing behavior",
            "Device and browser information",
            "Approximate location (IP-based)",
            "Click and scroll patterns"
        ] : []

        let risks = trackerCount > 5 ? [
            "Extensive tracking across multiple providers",
            "Potential cross-site tracking",
            "User profiling and behavioral analysis"
        ] : trackerCount > 0 ? [
            "Basic analytics tracking active",
            "Some user data collection"
        ] : []

        return PrivacyAnalysis(
            privacyScore: privacyScore,
            trackerCount: trackerCount,
            trackers: trackers,
            dataCollected: dataCollected,
            risks: risks,
            recommendations: trackerCount > 3 ? [
                "Consider using privacy-focused alternatives",
                "Minimize third-party trackers",
                "Review data collection policies"
            ] : ["Privacy impact is minimal"]
        )
    }

    // MARK: - Feature 6: AI Q&A Interface

    /// Answer questions about the loaded URL and its performance
    func askQuestion(_ question: String, context: URLAnalysisContext) async -> String {
        let contextData = buildQAContext(context: context)

        let prompt = """
        Answer this question about the web page's performance and network activity.

        PAGE DATA:
        \(contextData)

        QUESTION: \(question)

        Provide a clear, specific answer based on the data above.
        """

        let request = NovaAIRequest(prompt: prompt,
                                    system: "You are a web performance expert answering questions about this page's analysis.",
                                    temperature: 0.5, maxTokens: 400)
        let answer = await run("qa", request, validate: { try URLAnalysisAIValidators.answer($0) }, fallback: "")
        if !answer.isEmpty { return answer }
        return Self.builtInAnswer(source: sources["qa"], contextData: contextData)
    }

    /// The Q&A fallback: says why AI didn't answer and shows the measured data instead.
    static func builtInAnswer(source: NovaAISource?, contextData: String) -> String {
        let why: String
        switch source {
        case .fallback(.disabled)?: why = "AI is turned off (Settings > AI)."
        case .fallback(.unavailable(let reason))?: why = "AI is unavailable: \(reason)"
        case .fallback(.validationFailed(let reason))?: why = "The AI reply was rejected: \(reason)"
        default: why = "AI is unavailable."
        }
        return "\(why)\n\nBuilt-in analysis of this page:\n\(contextData)"
    }

    private func buildQAContext(context: URLAnalysisContext) -> String {
        let largestName = context.largestResource.flatMap { URL(string: $0.url) }?.lastPathComponent ?? "N/A"
        let slowestName = context.slowestResource.flatMap { URL(string: $0.url) }?.lastPathComponent ?? "N/A"

        return """
        URL: \(context.url.absoluteString)
        Performance Score: \(context.performanceScore)/100
        Load Time: \(String(format: "%.2f", context.loadTime))s
        Total Requests: \(context.requestCount)
        Total Size: \(formatBytes(context.totalSize))
        Largest Resource: \(largestName) (\(formatBytes(context.largestResource?.responseSize ?? 0)))
        Slowest Resource: \(slowestName) (\(String(format: "%.2f", context.slowestResource?.totalDuration ?? 0))s)
        Third-Party Domains: \(context.thirdPartyDomains.count)
        Security Issues: \(context.securityIssues.joined(separator: ", "))
        """
    }

    // MARK: - Helper Methods

    private func extractCodeExample(from text: String) -> String? {
        // Extract code blocks from markdown-style ```code```
        let pattern = "```[\\s\\S]*?```"
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Feature 7: AI Code Generation for Fixes

    /// Generate production-ready code to fix performance issues
    @discardableResult
    func generateCodeFixes(
        suggestions: [OptimizationSuggestion],
        techStack: TechnologyStack?,
        resources: [NetworkResource]
    ) async -> [CodeFix] {
        var fixes: [CodeFix] = []

        // Generate code for top 5 suggestions
        for (index, suggestion) in suggestions.prefix(5).enumerated() {
            let framework = techStack?.frontend ?? "vanilla JavaScript"

            let prompt = """
            Generate production-ready code to fix this performance issue.

            Title: \(suggestion.title)
            Description: \(suggestion.description)
            Impact: \(suggestion.impact.rawValue)
            Current State: \(suggestion.currentState)
            Target State: \(suggestion.targetState ?? "Optimized")
            Framework: \(framework)

            Affected Resources:
            \(suggestion.affectedResources.map { "- \($0.url) (\(formatBytes($0.size)))" }.joined(separator: "\n"))

            Return ONLY valid JSON in this exact format:
            {
              "title": "Short title",
              "description": "What this code does",
              "code": "actual code here (escaped for JSON)",
              "language": "javascript|css|html|nginx|htaccess",
              "framework": "\(framework.lowercased())|null",
              "estimatedImpact": "Reduce LCP by ~X.Xs or Save ~XKB"
            }
            """

            let title = suggestion.title
            let request = NovaAIRequest(prompt: prompt,
                                        system: "You are an expert web performance engineer who writes production-ready optimization code. Always return valid JSON.",
                                        temperature: 0.3, maxTokens: 800, format: .json)
            let fix: CodeFix? = await run("codefix", request,
                                          validate: { try URLAnalysisAIValidators.codeFix($0, defaultTitle: title) },
                                          fallback: Self.genericCodeFix(for: suggestion))
            if let fix { fixes.append(fix) }
            if stopAfterFallback("codefix") {
                fixes += suggestions.prefix(5).dropFirst(index + 1).compactMap(Self.genericCodeFix(for:))
                break
            }
        }

        generatedCode = fixes
        return fixes
    }

    /// Built-in code template for a suggestion (nil when there is no generic fix for its category).
    static func genericCodeFix(for suggestion: OptimizationSuggestion) -> CodeFix? {
        guard suggestion.category == .images else { return nil }
        return CodeFix(
            title: "Lazy Load Images",
            description: "Defer loading of below-the-fold images to improve initial page load",
            code: """
            // Lazy load images
            document.querySelectorAll('img[data-src]').forEach(img => {
              const observer = new IntersectionObserver(entries => {
                if (entries[0].isIntersecting) {
                  img.src = img.dataset.src;
                  observer.disconnect();
                }
              });
              observer.observe(img);
            });
            """,
            language: "javascript",
            framework: nil,
            estimatedImpact: "Reduce initial load by ~30%"
        )
    }

    // MARK: - Feature 8: Performance Time Machine

    /// Simulate performance impact of hypothetical changes
    @discardableResult
    func simulateWhatIf(
        scenario: WhatIfScenarioType,
        currentSession: NetworkMonitor,
        historicalData: [PersistentSession]
    ) async -> WhatIfScenario {
        let basic = simulateBasicWhatIf(scenario: scenario, session: currentSession)
        let scenarioDescription = describeScenario(scenario, session: currentSession)
        let affectedResources = identifyAffectedResources(scenario: scenario, session: currentSession)

        let prompt = """
        Simulate the performance impact of this change:

        Scenario: \(scenarioDescription)

        Current Performance:
        - Score: \(currentSession.performanceScore?.overall ?? 0)/100
        - Load Time: \(String(format: "%.2f", currentSession.totalDuration))s
        - LCP: \(currentSession.webVitals?.lcp.value ?? "N/A")
        - Total Size: \(formatBytes(currentSession.totalSize))
        - Requests: \(currentSession.resources.count)

        Resources That Would Be Affected:
        \(affectedResources.map { "- \($0.url) (\(formatBytes($0.responseSize)))" }.joined(separator: "\n"))

        Based on typical optimization gains, predict:
        1. New performance score (0-100)
        2. New load time
        3. New LCP
        4. Size savings
        5. Time savings
        6. Confidence level (High/Medium/Low)

        Return ONLY valid JSON:
        {
          "predictedScore": 85.0,
          "predictedLCP": "1.2s",
          "sizeSavings": "500KB",
          "timeSavings": "0.8s",
          "confidence": "High|Medium|Low",
          "explanation": "Detailed explanation of prediction..."
        }
        """

        let request = NovaAIRequest(prompt: prompt,
                                    system: "You are a web performance expert who accurately predicts optimization impact. Always return valid JSON.",
                                    temperature: 0.4, maxTokens: 500, format: .json)
        let result = await run("whatif", request,
                               validate: { try URLAnalysisAIValidators.whatIf($0, scenario: scenarioDescription) },
                               fallback: basic)
        whatIfResults.append(result)
        return result
    }

    private func describeScenario(_ scenario: WhatIfScenarioType, session: NetworkMonitor) -> String {
        switch scenario {
        case .removeTracker(let name):
            return "Remove \(name) tracker"
        case .compressImages:
            return "Compress all images to WebP/AVIF format"
        case .lazyLoadImages:
            return "Lazy load below-the-fold images"
        case .removeScript(let url):
            return "Remove script: \(url)"
        case .enableCaching:
            return "Enable browser caching for static assets"
        case .minifyJavaScript:
            return "Minify and compress JavaScript bundles"
        }
    }

    private func identifyAffectedResources(scenario: WhatIfScenarioType, session: NetworkMonitor) -> [NetworkResource] {
        switch scenario {
        case .removeTracker(let name):
            return session.resources.filter { $0.url.localizedCaseInsensitiveContains(name) }
        case .compressImages:
            return session.resources.filter { $0.resourceType == .image }
        case .lazyLoadImages:
            return session.resources.filter { $0.resourceType == .image }
        case .removeScript(let url):
            return session.resources.filter { $0.url == url }
        case .enableCaching:
            return session.resources.filter { $0.resourceType == .stylesheet || $0.resourceType == .script }
        case .minifyJavaScript:
            return session.resources.filter { $0.resourceType == .script }
        }
    }

    func simulateBasicWhatIf(scenario: WhatIfScenarioType, session: NetworkMonitor) -> WhatIfScenario {
        let affected = identifyAffectedResources(scenario: scenario, session: session)
        let sizeSavings = affected.reduce(0) { $0 + $1.responseSize }
        let estimatedTimeSavings = Double(sizeSavings) / 1_000_000.0 * 0.5 // Rough estimate

        return WhatIfScenario(
            scenario: describeScenario(scenario, session: session),
            predictedScore: min(100, Double(session.performanceScore?.overall ?? 50) + 10),
            predictedLCP: "Estimated improvement",
            sizeSavings: formatBytes(sizeSavings),
            timeSavings: String(format: "~%.1fs", estimatedTimeSavings),
            confidence: "Low",
            explanation: "Basic estimation based on affected resources. AI analysis unavailable."
        )
    }

    // MARK: - Feature 9: AI Trend Analysis & Predictions

    /// Analyze performance trends and make predictions
    @discardableResult
    func analyzeTrends(sessions: [PersistentSession], forURL: String) async -> TrendAnalysisResult {
        let basic = generateBasicTrendAnalysis(sessions: sessions)
        // Calculate statistics
        let scores = sessions.compactMap { $0.overallScore }
        let loadTimes = sessions.map { $0.duration }
        guard sessions.count >= 5, scores.count >= 2, let firstSession = sessions.first, let lastSession = sessions.last else {
            sources["trends"] = .fallback(.unavailable("needs at least 5 sessions"))
            trendAnalysis = basic
            return basic
        }

        let scoreMean = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
        let scoreStd = calculateStdDev(scores)

        let prompt = """
        Analyze these performance trends and make predictions:

        Historical Data (\(sessions.count) sessions over \(daysBetween(firstSession.timestamp, lastSession.timestamp)) days):

        \(sessions.prefix(20).map { session in
            "- Date: \(session.formattedTimestamp), Score: \(session.overallScore ?? 0), Load Time: \(String(format: "%.2f", session.duration))s, Size: \(formatBytes(session.totalSize))"
        }.joined(separator: "\n"))

        Statistical Summary:
        - Score: mean=\(String(format: "%.1f", scoreMean)), std=\(String(format: "%.1f", scoreStd))
        - Load Time: mean=\(String(format: "%.2f", loadTimes.reduce(0, +) / Double(loadTimes.count)))s
        - Trend: \(scores[0] < scores[scores.count - 1] ? "Improving" : "Degrading")

        Tasks:
        1. Identify overall performance trend
        2. Forecast performance for next 7, 14, and 30 days
        3. Flag any anomalies (sessions >2 std dev from mean)
        4. Detect patterns (day-of-week, time trends)
        5. Recommend actions

        Return ONLY valid JSON:
        {
          "summary": "Brief overall trend description",
          "predictions": [
            {"metric": "Score", "forecast": "Will reach X in Y days", "confidence": "High|Medium|Low", "trend": "Improving|Stable|Degrading"}
          ],
          "anomalies": [
            {"date": "ISO8601", "metric": "Score", "deviation": "3x higher", "possibleCauses": ["cause1", "cause2"]}
          ],
          "patterns": [
            {"description": "Performance degrades Mondays", "frequency": "Weekly", "impact": "High|Medium|Low"}
          ],
          "recommendation": "Top recommendation"
        }
        """

        let request = NovaAIRequest(prompt: prompt,
                                    system: "You are a data scientist specializing in web performance forecasting. Always return valid JSON.",
                                    temperature: 0.3, maxTokens: 800, format: .json)
        let result = await run("trends", request, validate: { try URLAnalysisAIValidators.trend($0) }, fallback: basic)
        trendAnalysis = result
        return result
    }

    func generateBasicTrendAnalysis(sessions: [PersistentSession]) -> TrendAnalysisResult {
        let scores = sessions.compactMap { $0.overallScore }
        let trend = scores.count >= 2 && scores[0] < scores[scores.count - 1] ? "Improving" : "Stable"

        return TrendAnalysisResult(
            summary: "Performance is \(trend.lowercased()) over the last \(sessions.count) sessions.",
            predictions: [],
            anomalies: [],
            patterns: [],
            recommendation: sessions.count < 5
                ? "Need at least 5 sessions for detailed trend analysis."
                : "Built-in trend summary (AI analysis unavailable)."
        )
    }

    private func calculateStdDev(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return abs(components.day ?? 0)
    }

    // MARK: - Feature 10: AI Regression Detection & Root Cause

    /// Detect performance regressions and identify root causes
    @discardableResult
    func detectRegression(
        currentSession: NetworkMonitor,
        historicalSessions: [PersistentSession],
        baseline: PersistentSession? = nil
    ) async -> RegressionReport {
        // Calculate baseline (median of last 30 days or use provided)
        let baselineSession: PersistentSession
        if let provided = baseline {
            baselineSession = provided
        } else {
            let recent = historicalSessions.prefix(30)
            let sortedByScore = recent.sorted { ($0.overallScore ?? 0) < ($1.overallScore ?? 0) }
            guard !sortedByScore.isEmpty else {
                let basic = generateBasicRegression(current: currentSession, baseline: nil)
                sources["regression"] = .fallback(.unavailable("no baseline"))
                regressionReport = basic
                return basic
            }
            baselineSession = sortedByScore[sortedByScore.count / 2]
        }
        let basic = generateBasicRegression(current: currentSession, baseline: baselineSession)

        let currentScore = currentSession.performanceScore?.overall ?? 0
        let baselineScore = baselineSession.overallScore ?? 0

        let prompt = """
        Analyze this performance regression:

        Baseline (median of \(historicalSessions.count) sessions):
        - Score: \(baselineScore)/100
        - Load Time: \(String(format: "%.2f", baselineSession.duration))s
        - Total Size: \(formatBytes(baselineSession.totalSize))
        - Requests: \(baselineSession.requestCount)

        Current:
        - Score: \(currentScore)/100 (Δ \(currentScore - Int(baselineScore)))
        - Load Time: \(String(format: "%.2f", currentSession.totalDuration))s (Δ \(String(format: "%.2f", currentSession.totalDuration - baselineSession.duration))s)
        - Total Size: \(formatBytes(currentSession.totalSize)) (Δ \(formatBytes(currentSession.totalSize - baselineSession.totalSize)))
        - Requests: \(currentSession.resources.count) (Δ \(currentSession.resources.count - baselineSession.requestCount))

        Analyze:
        1. Is there a regression?
        2. What are the root causes?
        3. When did it likely occur?
        4. What should be fixed first?

        Return ONLY valid JSON:
        {
          "hasRegression": true|false,
          "severity": "critical|warning|minor|none",
          "affectedMetrics": [
            {"metric": "Score", "baseline": "75", "current": "60", "change": "-15 (-20%)", "severity": "critical"}
          ],
          "rootCauses": [
            {"cause": "Added Google Tag Manager", "evidence": ["evidence1", "evidence2"], "confidence": "High|Medium|Low"}
          ],
          "recommendations": ["Fix 1", "Fix 2"],
          "timelineEstimate": "Change occurred ~Jan 15"
        }
        """

        let request = NovaAIRequest(prompt: prompt,
                                    system: "You are a senior performance engineer who debugs regressions. Always return valid JSON.",
                                    temperature: 0.3, maxTokens: 700, format: .json)
        let report = await run("regression", request, validate: { try URLAnalysisAIValidators.regression($0) }, fallback: basic)
        regressionReport = report
        return report
    }

    func generateBasicRegression(current: NetworkMonitor, baseline: PersistentSession?) -> RegressionReport {
        guard let baseline = baseline else {
            return RegressionReport(
                hasRegression: false,
                severity: .none,
                affectedMetrics: [],
                rootCauses: [],
                recommendations: ["No baseline available for comparison"],
                timelineEstimate: nil
            )
        }

        let currentScore = current.performanceScore?.overall ?? 0
        let baselineScore = Int(baseline.overallScore ?? 0)
        let scoreDelta = currentScore - baselineScore

        let hasRegression = scoreDelta < -10  // Score dropped by 10+ points

        return RegressionReport(
            hasRegression: hasRegression,
            severity: hasRegression ? .warning : .none,
            affectedMetrics: [
                RegressionReport.MetricRegression(
                    metric: "Score",
                    baseline: "\(baselineScore)",
                    current: "\(currentScore)",
                    change: "\(scoreDelta > 0 ? "+" : "")\(scoreDelta)",
                    severity: abs(scoreDelta) > 20 ? "critical" : "warning"
                )
            ],
            rootCauses: [],
            recommendations: ["Built-in comparison (AI analysis unavailable) - enable AI in Settings > AI for root cause analysis"],
            timelineEstimate: nil
        )
    }
}

// MARK: - Data Models

struct SecurityAnalysisResult {
    let riskLevel: SecurityRiskLevel
    let threats: [String]
    let explanation: String
    let recommendations: [String]
}

enum SecurityRiskLevel: String, Comparable {
    case safe = "safe"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var color: Color {
        switch self {
        case .safe: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    static func < (lhs: SecurityRiskLevel, rhs: SecurityRiskLevel) -> Bool {
        let order: [SecurityRiskLevel] = [.safe, .low, .medium, .high, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

struct AIOptimizationAdvice: Identifiable {
    let id = UUID()
    let suggestion: OptimizationSuggestion
    let aiAdvice: String
    let implementationExample: String?
}

struct TechnologyStack {
    let frontend: String?
    let backend: String?
    let cms: String?
    let analytics: [String]
    let cdn: String?
    let libraries: [String]
    let hosting: String?
}

struct PrivacyAnalysis {
    let privacyScore: Int // 0-100, 100 = best privacy
    let trackerCount: Int
    let trackers: [String]
    let dataCollected: [String]
    let risks: [String]
    let recommendations: [String]
}

struct URLAnalysisContext {
    let url: URL
    let performanceScore: Int
    let loadTime: TimeInterval
    let requestCount: Int
    let totalSize: Int64
    let largestResource: NetworkResource?
    let slowestResource: NetworkResource?
    let thirdPartyDomains: Set<String>
    let securityIssues: [String]
}

// MARK: - New AI Feature Data Models

struct CodeFix: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let code: String
    let language: String
    let framework: String?
    let estimatedImpact: String
}

enum WhatIfScenarioType {
    case removeTracker(name: String)
    case compressImages
    case lazyLoadImages
    case removeScript(url: String)
    case enableCaching
    case minifyJavaScript
}

struct WhatIfScenario: Identifiable {
    let id = UUID()
    let scenario: String
    let predictedScore: Double
    let predictedLCP: String
    let sizeSavings: String
    let timeSavings: String
    let confidence: String
    let explanation: String
}

struct TrendAnalysisResult: Identifiable {
    let id = UUID()
    let summary: String
    let predictions: [Prediction]
    let anomalies: [Anomaly]
    let patterns: [Pattern]
    let recommendation: String

    struct Prediction: Identifiable {
        let id = UUID()
        let metric: String
        let forecast: String
        let confidence: String
        let trend: String
    }

    struct Anomaly: Identifiable {
        let id = UUID()
        let date: Date
        let metric: String
        let deviation: String
        let possibleCauses: [String]
    }

    struct Pattern: Identifiable {
        let id = UUID()
        let description: String
        let frequency: String
        let impact: String
    }
}

struct RegressionReport: Identifiable {
    let id = UUID()
    let hasRegression: Bool
    let severity: Severity
    let affectedMetrics: [MetricRegression]
    let rootCauses: [RootCause]
    let recommendations: [String]
    let timelineEstimate: String?

    struct MetricRegression: Identifiable {
        let id = UUID()
        let metric: String
        let baseline: String
        let current: String
        let change: String
        let severity: String
    }

    struct RootCause: Identifiable {
        let id = UUID()
        let cause: String
        let evidence: [String]
        let confidence: String
    }

    enum Severity {
        case critical, warning, minor, none

        var color: Color {
            switch self {
            case .critical: return .red
            case .warning: return .orange
            case .minor: return .yellow
            case .none: return .green
            }
        }

        var label: String {
            switch self {
            case .critical: return "Critical"
            case .warning: return "Warning"
            case .minor: return "Minor"
            case .none: return "No Regression"
            }
        }
    }
}

// NetworkResource and related types defined in NetworkMonitor.swift
