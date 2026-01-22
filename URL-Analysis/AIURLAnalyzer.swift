//
//  AIURLAnalyzer.swift
//  URL Analysis
//
//  AI-powered URL and performance analysis
//  Supports Ollama, MLX Toolkit, and TinyLLM by Jason Cox
//  Author: Jordan Koch
//  Date: 2025-01-17
//
//  THIRD-PARTY ATTRIBUTION:
//  - TinyLLM by Jason Cox (https://github.com/jasonacox/TinyLLM)
//

import Foundation
import SwiftUI

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

    private let aiBackend = AIBackendManager.shared

    // MARK: - Feature 1: AI Performance Insights

    /// Generate natural language performance insights
    func analyzePerformance(monitor: NetworkMonitor, score: Int, vitals: WebVitals?) async -> String {
        guard aiBackend.activeBackend != nil else {
            return generateBasicPerformanceInsight(monitor: monitor, score: score)
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let context = buildPerformanceContext(monitor: monitor, score: score, vitals: vitals)

        let prompt = """
        Analyze this web page's performance and provide insights in 3-4 sentences.
        Be specific, mention actual numbers, and explain WHY performance is good or bad.

        PERFORMANCE DATA:
        \(context)

        Provide a clear, actionable summary focusing on the biggest issues.
        """

        do {
            let insights = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a web performance expert. Provide concise, actionable insights.",
                temperature: 0.4,
                maxTokens: 300
            )

            await MainActor.run {
                self.performanceInsights = insights
            }

            return insights
        } catch {
            return generateBasicPerformanceInsight(monitor: monitor, score: score)
        }
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

    private func generateBasicPerformanceInsight(monitor: NetworkMonitor, score: Int) -> String {
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
        guard aiBackend.activeBackend != nil else {
            return performBasicSecurityCheck(url: url, resources: resources)
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

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

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a cybersecurity expert analyzing URLs for threats.",
                temperature: 0.3,
                maxTokens: 500
            )

            // Parse JSON response
            if let result = parseSecurityResponse(response) {
                await MainActor.run {
                    self.securityAnalysis = result
                }
                return result
            }
        } catch {
            lastError = error.localizedDescription
        }

        return performBasicSecurityCheck(url: url, resources: resources)
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

    private func performBasicSecurityCheck(url: URL, resources: [NetworkResource]) -> SecurityAnalysisResult {
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
        guard aiBackend.activeBackend != nil else {
            return generateBasicOptimizationAdvice(suggestions: suggestions)
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

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

            do {
                let advice = try await aiBackend.generate(
                    prompt: prompt,
                    systemPrompt: "You are a web performance optimization expert. Provide practical, implementable advice.",
                    temperature: 0.4,
                    maxTokens: 400
                )

                aiAdvice.append(AIOptimizationAdvice(
                    suggestion: suggestion,
                    aiAdvice: advice,
                    implementationExample: extractCodeExample(from: advice)
                ))
            } catch {
                continue
            }
        }

        await MainActor.run {
            self.optimizationAdvice = aiAdvice
        }

        return aiAdvice
    }

    private func generateBasicOptimizationAdvice(suggestions: [OptimizationSuggestion]) -> [AIOptimizationAdvice] {
        return suggestions.prefix(5).map { suggestion in
            let basicAdvice = "Priority: \(suggestion.impact.rawValue) impact, \(suggestion.difficulty.rawValue) difficulty. \(suggestion.description)"
            return AIOptimizationAdvice(
                suggestion: suggestion,
                aiAdvice: basicAdvice,
                implementationExample: nil
            )
        }
    }

    // MARK: - Feature 4: AI Technology Stack Detection

    /// Detect frameworks, CMS, and libraries from network traffic
    func detectTechnologyStack(url: URL, resources: [NetworkResource]) async -> TechnologyStack {
        guard aiBackend.activeBackend != nil else {
            return performBasicTechDetection(resources: resources)
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

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

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a web technology expert. Identify technologies from network patterns.",
                temperature: 0.2,
                maxTokens: 400
            )

            if let stack = parseTechnologyStack(response) {
                await MainActor.run {
                    self.technologyStack = stack
                }
                return stack
            }
        } catch {
            lastError = error.localizedDescription
        }

        return performBasicTechDetection(resources: resources)
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

    private func performBasicTechDetection(resources: [NetworkResource]) -> TechnologyStack {
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
        guard aiBackend.activeBackend != nil else {
            return performBasicPrivacyAnalysis(resources: resources)
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

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

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a privacy expert. Explain tracker implications clearly.",
                temperature: 0.3,
                maxTokens: 500
            )

            if let analysis = parsePrivacyAnalysis(response) {
                await MainActor.run {
                    self.privacyAnalysis = analysis
                }
                return analysis
            }
        } catch {
            lastError = error.localizedDescription
        }

        return performBasicPrivacyAnalysis(resources: resources)
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

    private func performBasicPrivacyAnalysis(resources: [NetworkResource]) -> PrivacyAnalysis {
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
        guard aiBackend.activeBackend != nil else {
            return "AI backend not available. Please configure Ollama, TinyLLM (by Jason Cox), or MLX in Settings."
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let contextData = buildQAContext(context: context)

        let prompt = """
        Answer this question about the web page's performance and network activity.

        PAGE DATA:
        \(contextData)

        QUESTION: \(question)

        Provide a clear, specific answer based on the data above.
        """

        do {
            let answer = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a web performance expert answering questions about this page's analysis.",
                temperature: 0.5,
                maxTokens: 400
            )

            return answer
        } catch {
            return "Error generating answer: \(error.localizedDescription)"
        }
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

    private func parseSecurityResponse(_ response: String) -> SecurityAnalysisResult? {
        // Try to parse JSON from response
        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        let riskLevelStr = json["riskLevel"] as? String ?? "low"
        let riskLevel = SecurityRiskLevel(rawValue: riskLevelStr) ?? .low
        let threats = json["threats"] as? [String] ?? []
        let explanation = json["explanation"] as? String ?? ""
        let recommendations = json["recommendations"] as? [String] ?? []

        return SecurityAnalysisResult(
            riskLevel: riskLevel,
            threats: threats,
            explanation: explanation,
            recommendations: recommendations
        )
    }

    private func parseTechnologyStack(_ response: String) -> TechnologyStack? {
        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        return TechnologyStack(
            frontend: json["frontend"] as? String,
            backend: json["backend"] as? String,
            cms: json["cms"] as? String,
            analytics: json["analytics"] as? [String] ?? [],
            cdn: json["cdn"] as? String,
            libraries: json["libraries"] as? [String] ?? [],
            hosting: json["hosting"] as? String
        )
    }

    private func parsePrivacyAnalysis(_ response: String) -> PrivacyAnalysis? {
        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        return PrivacyAnalysis(
            privacyScore: json["privacyScore"] as? Int ?? 50,
            trackerCount: 0,
            trackers: [],
            dataCollected: json["dataCollected"] as? [String] ?? [],
            risks: json["risks"] as? [String] ?? [],
            recommendations: json["recommendations"] as? [String] ?? []
        )
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Feature 7: AI Code Generation for Fixes

    /// Generate production-ready code to fix performance issues
    func generateCodeFixes(
        suggestions: [OptimizationSuggestion],
        techStack: TechnologyStack?,
        resources: [NetworkResource]
    ) async -> [CodeFix] {
        guard aiBackend.activeBackend != nil else {
            return generateGenericCodeFixes(suggestions: suggestions)
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        var fixes: [CodeFix] = []

        // Generate code for top 5 suggestions
        for suggestion in suggestions.prefix(5) {
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

            do {
                let response = try await aiBackend.generate(
                    prompt: prompt,
                    systemPrompt: "You are an expert web performance engineer who writes production-ready optimization code. Always return valid JSON.",
                    temperature: 0.3,
                    maxTokens: 800
                )

                if let fix = parseCodeFix(from: response, suggestion: suggestion) {
                    fixes.append(fix)
                }
            } catch {
                lastError = error.localizedDescription
            }
        }

        await MainActor.run {
            self.generatedCode = fixes
        }

        return fixes
    }

    private func parseCodeFix(from response: String, suggestion: OptimizationSuggestion) -> CodeFix? {
        // Try to parse JSON response
        let jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        return CodeFix(
            title: json["title"] as? String ?? suggestion.title,
            description: json["description"] as? String ?? "",
            code: json["code"] as? String ?? "",
            language: json["language"] as? String ?? "javascript",
            framework: json["framework"] as? String,
            estimatedImpact: json["estimatedImpact"] as? String ?? ""
        )
    }

    private func generateGenericCodeFixes(suggestions: [OptimizationSuggestion]) -> [CodeFix] {
        // Fallback: Generate generic code templates
        var fixes: [CodeFix] = []

        for suggestion in suggestions.prefix(5) {
            if suggestion.category == .images {
                fixes.append(CodeFix(
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
                ))
            }
        }

        return fixes
    }

    // MARK: - Feature 8: Performance Time Machine

    /// Simulate performance impact of hypothetical changes
    func simulateWhatIf(
        scenario: WhatIfScenarioType,
        currentSession: NetworkMonitor,
        historicalData: [PersistentSession]
    ) async -> WhatIfScenario {
        guard aiBackend.activeBackend != nil else {
            return simulateBasicWhatIf(scenario: scenario, session: currentSession)
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

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

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a web performance expert who accurately predicts optimization impact. Always return valid JSON.",
                temperature: 0.4,
                maxTokens: 500
            )

            if let scenario = parseWhatIfScenario(from: response, originalScenario: scenarioDescription) {
                await MainActor.run {
                    self.whatIfResults.append(scenario)
                }
                return scenario
            }
        } catch {
            lastError = error.localizedDescription
        }

        return simulateBasicWhatIf(scenario: scenario, session: currentSession)
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

    private func parseWhatIfScenario(from response: String, originalScenario: String) -> WhatIfScenario? {
        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        return WhatIfScenario(
            scenario: originalScenario,
            predictedScore: json["predictedScore"] as? Double ?? 0,
            predictedLCP: json["predictedLCP"] as? String ?? "N/A",
            sizeSavings: json["sizeSavings"] as? String ?? "Unknown",
            timeSavings: json["timeSavings"] as? String ?? "Unknown",
            confidence: json["confidence"] as? String ?? "Low",
            explanation: json["explanation"] as? String ?? ""
        )
    }

    private func simulateBasicWhatIf(scenario: WhatIfScenarioType, session: NetworkMonitor) -> WhatIfScenario {
        let affected = identifyAffectedResources(scenario: scenario, session: session)
        let sizeSavings = affected.reduce(0) { $0 + $1.responseSize }
        let estimatedTimeSavings = Double(sizeSavings) / 1_000_000.0 * 0.5 // Rough estimate

        return WhatIfScenario(
            scenario: describeScenario(scenario, session: session),
            predictedScore: Double(session.performanceScore?.overall ?? 50) + 10,
            predictedLCP: "Estimated improvement",
            sizeSavings: formatBytes(sizeSavings),
            timeSavings: String(format: "~%.1fs", estimatedTimeSavings),
            confidence: "Low",
            explanation: "Basic estimation based on affected resources. AI analysis unavailable."
        )
    }

    // MARK: - Feature 9: AI Trend Analysis & Predictions

    /// Analyze performance trends and make predictions
    func analyzeTrends(sessions: [PersistentSession], forURL: String) async -> TrendAnalysisResult {
        guard aiBackend.activeBackend != nil, sessions.count >= 5 else {
            return generateBasicTrendAnalysis(sessions: sessions)
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Calculate statistics
        let scores = sessions.compactMap { $0.overallScore }
        let loadTimes = sessions.map { $0.duration }
        let sizes = sessions.map { $0.totalSize }

        let scoreMean = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
        let scoreStd = calculateStdDev(scores)

        let prompt = """
        Analyze these performance trends and make predictions:

        Historical Data (\(sessions.count) sessions over \(daysBetween(sessions.first!.timestamp, sessions.last!.timestamp)) days):

        \(sessions.prefix(20).map { session in
            "- Date: \(session.formattedTimestamp), Score: \(session.overallScore ?? 0), Load Time: \(String(format: "%.2f", session.duration))s, Size: \(formatBytes(session.totalSize))"
        }.joined(separator: "\n"))

        Statistical Summary:
        - Score: mean=\(String(format: "%.1f", scoreMean)), std=\(String(format: "%.1f", scoreStd))
        - Load Time: mean=\(String(format: "%.2f", loadTimes.reduce(0, +) / Double(loadTimes.count)))s
        - Trend: \(scores.first! < scores.last! ? "Improving" : "Degrading")

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

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a data scientist specializing in web performance forecasting. Always return valid JSON.",
                temperature: 0.3,
                maxTokens: 800
            )

            if let result = parseTrendAnalysis(from: response) {
                await MainActor.run {
                    self.trendAnalysis = result
                }
                return result
            }
        } catch {
            lastError = error.localizedDescription
        }

        return generateBasicTrendAnalysis(sessions: sessions)
    }

    private func parseTrendAnalysis(from response: String) -> TrendAnalysisResult? {
        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        let predictions = (json["predictions"] as? [[String: Any]])?.compactMap { dict -> TrendAnalysisResult.Prediction in
            TrendAnalysisResult.Prediction(
                metric: dict["metric"] as? String ?? "",
                forecast: dict["forecast"] as? String ?? "",
                confidence: dict["confidence"] as? String ?? "Low",
                trend: dict["trend"] as? String ?? "Stable"
            )
        } ?? []

        let anomalies = (json["anomalies"] as? [[String: Any]])?.compactMap { dict -> TrendAnalysisResult.Anomaly? in
            let formatter = ISO8601DateFormatter()
            guard let dateString = dict["date"] as? String,
                  let date = formatter.date(from: dateString) else {
                return nil
            }
            return TrendAnalysisResult.Anomaly(
                date: date,
                metric: dict["metric"] as? String ?? "",
                deviation: dict["deviation"] as? String ?? "",
                possibleCauses: dict["possibleCauses"] as? [String] ?? []
            )
        } ?? []

        let patterns = (json["patterns"] as? [[String: Any]])?.compactMap { dict -> TrendAnalysisResult.Pattern in
            TrendAnalysisResult.Pattern(
                description: dict["description"] as? String ?? "",
                frequency: dict["frequency"] as? String ?? "",
                impact: dict["impact"] as? String ?? ""
            )
        } ?? []

        return TrendAnalysisResult(
            summary: json["summary"] as? String ?? "",
            predictions: predictions,
            anomalies: anomalies,
            patterns: patterns,
            recommendation: json["recommendation"] as? String ?? ""
        )
    }

    private func generateBasicTrendAnalysis(sessions: [PersistentSession]) -> TrendAnalysisResult {
        let scores = sessions.compactMap { $0.overallScore }
        let trend = scores.count >= 2 && scores.first! < scores.last! ? "Improving" : "Stable"

        return TrendAnalysisResult(
            summary: "Performance is \(trend.lowercased()) over the last \(sessions.count) sessions.",
            predictions: [],
            anomalies: [],
            patterns: [],
            recommendation: "Need at least 5 sessions for detailed trend analysis. AI backend unavailable."
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
    func detectRegression(
        currentSession: NetworkMonitor,
        historicalSessions: [PersistentSession],
        baseline: PersistentSession? = nil
    ) async -> RegressionReport {
        guard aiBackend.activeBackend != nil else {
            return generateBasicRegression(current: currentSession, baseline: baseline)
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Calculate baseline (median of last 30 days or use provided)
        let baselineSession: PersistentSession
        if let provided = baseline {
            baselineSession = provided
        } else {
            let recent = historicalSessions.prefix(30)
            let sortedByScore = recent.sorted { ($0.overallScore ?? 0) < ($1.overallScore ?? 0) }
            baselineSession = sortedByScore[sortedByScore.count / 2]
        }

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

        do {
            let response = try await aiBackend.generate(
                prompt: prompt,
                systemPrompt: "You are a senior performance engineer who debugs regressions. Always return valid JSON.",
                temperature: 0.3,
                maxTokens: 700
            )

            if let report = parseRegressionReport(from: response) {
                await MainActor.run {
                    self.regressionReport = report
                }
                return report
            }
        } catch {
            lastError = error.localizedDescription
        }

        return generateBasicRegression(current: currentSession, baseline: baseline)
    }

    private func parseRegressionReport(from response: String) -> RegressionReport? {
        guard let jsonData = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        let hasRegression = json["hasRegression"] as? Bool ?? false
        let severityString = json["severity"] as? String ?? "none"
        let severity: RegressionReport.Severity = {
            switch severityString {
            case "critical": return .critical
            case "warning": return .warning
            case "minor": return .minor
            default: return .none
            }
        }()

        let metrics = (json["affectedMetrics"] as? [[String: Any]])?.map { dict -> RegressionReport.MetricRegression in
            RegressionReport.MetricRegression(
                metric: dict["metric"] as? String ?? "",
                baseline: dict["baseline"] as? String ?? "",
                current: dict["current"] as? String ?? "",
                change: dict["change"] as? String ?? "",
                severity: dict["severity"] as? String ?? ""
            )
        } ?? []

        let causes = (json["rootCauses"] as? [[String: Any]])?.map { dict -> RegressionReport.RootCause in
            RegressionReport.RootCause(
                cause: dict["cause"] as? String ?? "",
                evidence: dict["evidence"] as? [String] ?? [],
                confidence: dict["confidence"] as? String ?? "Low"
            )
        } ?? []

        return RegressionReport(
            hasRegression: hasRegression,
            severity: severity,
            affectedMetrics: metrics,
            rootCauses: causes,
            recommendations: json["recommendations"] as? [String] ?? [],
            timelineEstimate: json["timelineEstimate"] as? String
        )
    }

    private func generateBasicRegression(current: NetworkMonitor, baseline: PersistentSession?) -> RegressionReport {
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
            recommendations: ["AI analysis unavailable - enable AI backend for detailed root cause analysis"],
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
