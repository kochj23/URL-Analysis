//
//  AppAI.swift
//  URL Analysis
//
//  The app's one AI object (NovaAIKit 1.0.0). Settings persist in UserDefaults (no secrets); keys live in the
//  Keychain under com.jkoch.urlanalysis.<backend>. Backends: Auto, Ollama, MLX, TinyLLM, TinyChat, OpenWebUI,
//  Nova Gateway, OpenRouter, OpenAI.
//
//  Author: Jordan Koch
//

import Foundation
import NovaAIKit

@MainActor
enum AppAI {
    static let appID = "urlanalysis"
    static let appName = "URL Analysis"

    static let shared: NovaAI = {
        let ai = NovaAI(configuration: NovaAIConfiguration(appID: appID, appName: appName,
                                                           appURL: "https://github.com/kochj23/URL-Analysis"))
        AppAI.migrateLegacy(ai)
        return ai
    }()

    /// Footer shown under the AI settings.
    static let settingsFooter = "When AI is off or unreachable, URL Analysis uses its built-in analysis: score-based insights, "
        + "rule-based security, tracker and technology detection, template code fixes and statistical trend/regression checks."
}

extension AppAI {
    /// The pre-NovaAIKit backend manager's Keychain service.
    static let legacyKeychainService = "com.jordankoch.URLAnalysis"

    /// Accounts the old manager stored for the removed Google Cloud / Azure / AWS / IBM Watson backends.
    static let legacyObsoleteAccounts = [
        "AIBackend_GoogleCloud_Key", "AIBackend_Azure_Key", "AIBackend_Azure_Endpoint",
        "AIBackend_AWS_AccessKey", "AIBackend_AWS_SecretKey", "AIBackend_IBM_Key", "AIBackend_IBM_URL",
    ]

    /// Set once the old Keychain items were handled, so the Keychain isn't touched on every launch.
    /// The old Keychain account of the OpenAI key (same name the old manager used in UserDefaults).
    static let legacyOpenAIAccount = NovaAILegacySettings.openAIKeyKeys[0]

    static let keychainMigrationMarker = "URLAnalysis.legacyKeychainMigrated"

    /// One-time migration from the old copy-pasted AI backend manager (idempotent).
    /// Security fix: the old manager could leave API keys for OpenAI and the removed Google/Azure/AWS/IBM backends in
    /// UserDefaults in plaintext; they are moved to the Keychain (OpenAI) or deleted (the rest).
    static func migrateLegacy(_ ai: NovaAI, defaults: UserDefaults = .standard, legacyStore: (any NovaAIKeyStore)? = nil) {
        // UserDefaults: backend, URLs, Ollama model, on/off; plaintext OpenAI key → Keychain; obsolete secrets/logs deleted.
        ai.migrateFromLegacyAIBackendManager(defaults: defaults)
        defaults.removeObject(forKey: "AIBackend_AWS_Region")
        guard !defaults.bool(forKey: keychainMigrationMarker) else { return }
        // Old Keychain item (this app's alone) → com.jkoch.urlanalysis.openai, old item deleted after a verified copy.
        let result = ai.migrateLegacyKey(service: legacyKeychainService, account: legacyOpenAIAccount, to: .openAI,
                                         deleteLegacy: true, legacyStore: legacyStore)
        // Removed backends' secrets: delete only, never read out.
        ai.keys.deleteObsoleteLegacyItems(service: legacyKeychainService, accounts: legacyObsoleteAccounts, legacyStore: legacyStore)
        ai.keys.deleteObsoleteLegacyItems(service: legacyKeychainService, legacyStore: legacyStore)
        if result != .writeFailed { defaults.set(true, forKey: keychainMigrationMarker) }
    }
}
