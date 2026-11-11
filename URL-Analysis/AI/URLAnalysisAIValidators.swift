//
//  URLAnalysisAIValidators.swift
//  URL Analysis
//
//  Output validation for every AI feature. Each function parses one model reply, clamps enums/ranges/counts to the
//  legal values and throws `NovaAIValidationError` to reject it (NovaAIKit then asks once more, then falls back to
//  the built-in analysis). Pure and network-free, so tests call them directly.
//
//  Author: Jordan Koch
//

import Foundation
import NovaAIKit

enum URLAnalysisAIValidators {
    static let maxInsightCharacters = 1_200
    static let maxAdviceCharacters = 4_000
    static let maxAnswerCharacters = 2_000
    static let maxListItems = 12
    static let maxItemCharacters = 300
    static let confidenceLevels = ["High", "Medium", "Low"]
    static let trendLabels = ["Improving", "Stable", "Degrading"]
    static let codeLanguages = ["javascript", "css", "html", "nginx", "htaccess", "typescript", "json", "apache", "text"]

    // MARK: - Text

    /// Performance insight: non-empty plain text whose figures come from the measured data (rounding tolerated).
    static func insight(_ reply: String, source: String) throws -> String {
        guard let cleaned = NovaAIText.clean(reply) else { throw NovaAIValidationError("empty reply") }
        let text = NovaAIText.plain(cleaned, max: maxInsightCharacters)
        guard text.count >= 20 else { throw NovaAIValidationError("reply too short") }
        let invented = inventedNumbers(in: text, source: source)
        if !invented.isEmpty {
            throw NovaAIValidationError("it mentions figures that are not in the data (\(invented.sorted().prefix(3).joined(separator: ", "))); use only the numbers given")
        }
        return text
    }

    /// Optimization coaching: non-empty, code blocks kept, capped.
    static func advice(_ reply: String) throws -> String {
        guard let text = NovaAIText.clean(reply, max: maxAdviceCharacters), text.count >= 20 else {
            throw NovaAIValidationError("empty or too short reply")
        }
        return text
    }

    /// Q&A answer: non-empty plain text, capped.
    static func answer(_ reply: String) throws -> String {
        guard let cleaned = NovaAIText.clean(reply) else { throw NovaAIValidationError("empty reply") }
        return NovaAIText.plain(cleaned, max: maxAnswerCharacters)
    }

    /// Numbers in `text` that are neither small counts (0–10) nor within rounding distance of a number in `source`.
    static func inventedNumbers(in text: String, source: String) -> Set<String> {
        let known = NovaAIText.numbers(source).compactMap(Double.init)
        return NovaAIText.numbers(text).filter { token in
            guard let v = Double(token) else { return false }
            if v <= 10 && v == v.rounded() { return false }
            return !known.contains { abs($0 - v) <= max(0.06, abs($0) * 0.02) || abs($0 * 100 - v) < 0.6 }
        }
    }

    // MARK: - Structured

    /// Security analysis. Unknown risk level → rejected. The AI can raise the risk but never lower it below
    /// what the built-in checks found (`floor`).
    static func security(_ reply: String, floor: SecurityRiskLevel) throws -> SecurityAnalysisResult {
        let json = try object(reply)
        guard let raw = (json["riskLevel"] as? String)?.lowercased().trimmingCharacters(in: .whitespaces),
              let level = SecurityRiskLevel(rawValue: raw) else {
            throw NovaAIValidationError("riskLevel must be one of safe, low, medium, high, critical")
        }
        let threats = strings(json["threats"])
        let explanation = string(json["explanation"]) ?? ""
        guard !threats.isEmpty || !explanation.isEmpty else { throw NovaAIValidationError("no threats or explanation given") }
        return SecurityAnalysisResult(riskLevel: max(level, floor), threats: threats.isEmpty ? [explanation] : threats,
                                      explanation: explanation, recommendations: strings(json["recommendations"]))
    }

    /// Technology stack: at least one detected field.
    static func techStack(_ reply: String) throws -> TechnologyStack {
        let json = try object(reply)
        let stack = TechnologyStack(frontend: string(json["frontend"]), backend: string(json["backend"]), cms: string(json["cms"]),
                                    analytics: strings(json["analytics"]), cdn: string(json["cdn"]),
                                    libraries: strings(json["libraries"]), hosting: string(json["hosting"]))
        let empty = [stack.frontend, stack.backend, stack.cms, stack.cdn, stack.hosting].allSatisfy { $0 == nil }
            && stack.analytics.isEmpty && stack.libraries.isEmpty
        if empty { throw NovaAIValidationError("no technology identified") }
        return stack
    }

    /// Privacy analysis: score clamped to 0…100; tracker list/count always the locally detected ones.
    static func privacy(_ reply: String, trackers: [String]) throws -> PrivacyAnalysis {
        let json = try object(reply)
        guard let score = number(json["privacyScore"]) else { throw NovaAIValidationError("privacyScore must be a number 0-100") }
        return PrivacyAnalysis(privacyScore: Int(min(100, max(0, score)).rounded()), trackerCount: trackers.count,
                               trackers: trackers, dataCollected: strings(json["dataCollected"]),
                               risks: strings(json["risks"]), recommendations: strings(json["recommendations"]))
    }

    /// Code fix: code required; language clamped to the known set.
    static func codeFix(_ reply: String, defaultTitle: String) throws -> CodeFix {
        let json = try object(reply)
        guard let code = json["code"] as? String, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NovaAIValidationError("code must be a non-empty string")
        }
        let lang = (string(json["language"]) ?? "javascript").lowercased()
        return CodeFix(title: string(json["title"]) ?? defaultTitle, description: string(json["description"]) ?? "",
                       code: String(code.prefix(20_000)), language: codeLanguages.contains(lang) ? lang : "text",
                       framework: string(json["framework"]).flatMap { $0.lowercased() == "null" ? nil : $0 },
                       estimatedImpact: string(json["estimatedImpact"]) ?? "")
    }

    /// What-if simulation: score required and clamped to 0…100, confidence clamped.
    static func whatIf(_ reply: String, scenario: String) throws -> WhatIfScenario {
        let json = try object(reply)
        guard let score = number(json["predictedScore"]) else { throw NovaAIValidationError("predictedScore must be a number 0-100") }
        return WhatIfScenario(scenario: scenario, predictedScore: min(100, max(0, score)),
                              predictedLCP: string(json["predictedLCP"]) ?? "N/A",
                              sizeSavings: string(json["sizeSavings"]) ?? "Unknown",
                              timeSavings: string(json["timeSavings"]) ?? "Unknown",
                              confidence: oneOf(json["confidence"], confidenceLevels, default: "Low"),
                              explanation: string(json["explanation"]) ?? "")
    }

    /// Trend analysis: summary required; labels clamped; anomalies need an ISO-8601 date.
    static func trend(_ reply: String) throws -> TrendAnalysisResult {
        let json = try object(reply)
        guard let summary = string(json["summary"]) else { throw NovaAIValidationError("summary is required") }
        let dicts = { (k: String) in Array(((json[k] as? [[String: Any]]) ?? []).prefix(maxListItems)) }
        let predictions = dicts("predictions").map {
            TrendAnalysisResult.Prediction(metric: string($0["metric"]) ?? "", forecast: string($0["forecast"]) ?? "",
                                           confidence: oneOf($0["confidence"], confidenceLevels, default: "Low"),
                                           trend: oneOf($0["trend"], trendLabels, default: "Stable"))
        }
        let iso = ISO8601DateFormatter()
        let day = ISO8601DateFormatter(); day.formatOptions = [.withFullDate]
        let anomalies = dicts("anomalies").compactMap { d -> TrendAnalysisResult.Anomaly? in
            guard let s = d["date"] as? String, let date = iso.date(from: s) ?? day.date(from: s) else { return nil }
            return TrendAnalysisResult.Anomaly(date: date, metric: string(d["metric"]) ?? "", deviation: string(d["deviation"]) ?? "",
                                               possibleCauses: strings(d["possibleCauses"]))
        }
        let patterns = dicts("patterns").map {
            TrendAnalysisResult.Pattern(description: string($0["description"]) ?? "", frequency: string($0["frequency"]) ?? "",
                                        impact: oneOf($0["impact"], confidenceLevels, default: "Low"))
        }
        return TrendAnalysisResult(summary: summary, predictions: predictions, anomalies: anomalies, patterns: patterns,
                                   recommendation: string(json["recommendation"]) ?? "")
    }

    /// Regression report: severity clamped; "no regression" forces severity none.
    static func regression(_ reply: String) throws -> RegressionReport {
        let json = try object(reply)
        guard let has = json["hasRegression"] as? Bool else { throw NovaAIValidationError("hasRegression must be true or false") }
        let severity: RegressionReport.Severity
        switch (string(json["severity"]) ?? "none").lowercased() {
        case "critical": severity = .critical
        case "warning": severity = .warning
        case "minor": severity = .minor
        default: severity = .none
        }
        let dicts = { (k: String) in Array(((json[k] as? [[String: Any]]) ?? []).prefix(maxListItems)) }
        return RegressionReport(
            hasRegression: has,
            severity: has ? (severity == .none ? .minor : severity) : .none,
            affectedMetrics: dicts("affectedMetrics").map {
                RegressionReport.MetricRegression(metric: string($0["metric"]) ?? "", baseline: string($0["baseline"]) ?? "",
                                                  current: string($0["current"]) ?? "", change: string($0["change"]) ?? "",
                                                  severity: string($0["severity"]) ?? "")
            },
            rootCauses: dicts("rootCauses").map {
                RegressionReport.RootCause(cause: string($0["cause"]) ?? "", evidence: strings($0["evidence"]),
                                           confidence: oneOf($0["confidence"], confidenceLevels, default: "Low"))
            },
            recommendations: strings(json["recommendations"]),
            timelineEstimate: string(json["timelineEstimate"]))
    }

    // MARK: - JSON helpers

    static func object(_ reply: String) throws -> [String: Any] {
        guard let payload = NovaAIText.jsonPayload(NovaAIText.clean(reply) ?? ""),
              let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NovaAIValidationError("reply must be a single JSON object")
        }
        return json
    }

    static func string(_ any: Any?) -> String? {
        let s: String?
        switch any {
        case let v as String: s = v
        case let v as NSNumber: s = v.stringValue
        default: s = nil
        }
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return String(t.prefix(maxItemCharacters * 4))
    }

    static func strings(_ any: Any?) -> [String] {
        ((any as? [Any]) ?? []).compactMap { string($0).map { String($0.prefix(maxItemCharacters)) } }.prefix(maxListItems).map { $0 }
    }

    static func number(_ any: Any?) -> Double? {
        switch any {
        case let v as NSNumber: return v.doubleValue.isFinite ? v.doubleValue : nil
        case let v as String: return Double(v.trimmingCharacters(in: .whitespaces))
        default: return nil
        }
    }

    static func oneOf(_ any: Any?, _ allowed: [String], default def: String) -> String {
        guard let s = string(any) else { return def }
        return allowed.first { $0.caseInsensitiveCompare(s) == .orderedSame } ?? def
    }
}
