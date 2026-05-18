//
//  RequestBlocking.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import WebKit

/// Request blocking configuration
struct BlockingRules: Codable {
    var blockedDomains: Set<String> = []
    var blockedTypes: Set<NetworkResource.ResourceType> = []
    var isEnabled: Bool = false

    // Pre-defined blocking profiles
    static let adsAndTrackers = BlockingRules(
        blockedDomains: Set([
            "doubleclick.net",
            "googleadservices.com",
            "google-analytics.com",
            "googletagmanager.com",
            "facebook.net",
            "connect.facebook.net",
            "ads.yahoo.com",
            "amazon-adsystem.com",
            "googlesyndication.com",
            "adservice.google.com"
        ]),
        blockedTypes: [],
        isEnabled: true
    )

    static let imagesOnly = BlockingRules(
        blockedDomains: [],
        blockedTypes: [.image],
        isEnabled: true
    )

    static let scriptsOnly = BlockingRules(
        blockedDomains: [],
        blockedTypes: [.script],
        isEnabled: true
    )

    /// Generate WKContentRuleList JSON for blocking
    func generateContentRules() -> String {
        var rules: [[String: Any]] = []

        // Block domains
        for domain in blockedDomains {
            rules.append([
                "trigger": [
                    "url-filter": ".*\(domain).*",
                    "resource-type": ["document", "image", "style-sheet", "script", "font", "raw", "svg-document", "media"]
                ],
                "action": [
                    "type": "block"
                ]
            ])
        }

        // Block resource types
        for type in blockedTypes {
            let resourceType = mapToWKResourceType(type)
            if !resourceType.isEmpty {
                rules.append([
                    "trigger": [
                        "url-filter": ".*",
                        "resource-type": resourceType
                    ],
                    "action": [
                        "type": "block"
                    ]
                ])
            }
        }

        let json: [String: Any] = [
            "version": 1,
            "rules": rules
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return string
    }

    private func mapToWKResourceType(_ type: NetworkResource.ResourceType) -> [String] {
        switch type {
        case .document:
            return ["document"]
        case .stylesheet:
            return ["style-sheet"]
        case .script:
            return ["script"]
        case .image:
            return ["image"]
        case .font:
            return ["font"]
        case .media:
            return ["media"]
        case .xhr, .fetch:
            return ["fetch", "raw"]
        default:
            return []
        }
    }
}

/// Manages WKContentRuleList creation and application
@MainActor
class BlockingManager: ObservableObject {
    @Published var rules = BlockingRules()
    @Published var isApplying = false

    private var currentRuleList: WKContentRuleList?

    /// Apply blocking rules to a WKWebViewConfiguration
    func applyRules(to config: WKWebViewConfiguration, completion: @escaping () -> Void) {
        guard rules.isEnabled else {
            // Remove existing rules
            if let ruleList = currentRuleList {
                config.userContentController.remove(ruleList)
                currentRuleList = nil
            }
            completion()
            return
        }

        isApplying = true

        let rulesJSON = rules.generateContentRules()

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "URLAnalysisBlockingRules",
            encodedContentRuleList: rulesJSON
        ) { [weak self] ruleList, error in
            Task { @MainActor in
                self?.isApplying = false

                if let error = error {
                    print("Failed to compile content rules: \(error)")
                    completion()
                    return
                }

                guard let ruleList = ruleList else {
                    completion()
                    return
                }

                // Remove old rules
                if let oldRuleList = self?.currentRuleList {
                    config.userContentController.remove(oldRuleList)
                }

                // Add new rules
                config.userContentController.add(ruleList)
                self?.currentRuleList = ruleList

                completion()
            }
        }
    }

    /// Load pre-defined profile
    func loadProfile(_ profile: BlockingRules) {
        rules = profile
    }
}
