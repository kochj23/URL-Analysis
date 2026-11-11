# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Performance improvements
- Additional features based on community feedback

## [1.4.0] - 2026-11-11

### Changed
- AI: migrated to NovaAIKit 1.0.0 (AI on/off, built-in fallback for all 10 AI features, backend picker with Auto
  failover over Ollama, MLX, TinyLLM, TinyChat, OpenWebUI, Nova Gateway, OpenRouter and OpenAI, model picker,
  editable URLs, Keychain-only keys under `com.jkoch.urlanalysis.*`, https-only keys, status indicator, timeouts and
  retries, validated/clamped AI output, per-result source labels).
- AI settings moved to a standard Settings window (NovaAISettingsView).
- Widget AI status now reflects the real backend state.

### Removed
- The app's own AI backend manager, status menu, ethical guardian and unused AI capability/image/voice stubs.
- Google Cloud, Azure, AWS and IBM Watson backends.

### Security
- Legacy API keys left in UserDefaults in plaintext are moved to the Keychain (OpenAI) or deleted (removed
  backends); the old `com.jordankoch.URLAnalysis` Keychain items are migrated once and removed.
- Security analysis can no longer be downgraded by an AI reply below the rule-based risk level.

### Fixed
- Regression detection no longer crashes when there is no history; trend analysis no longer force-unwraps.
- Project referenced NovaAPIServer.swift by an absolute path; all pre-existing compiler warnings fixed.

## [1.0.0] - 2025-01-01

### Added
- Initial release
- Core functionality
- macOS native interface
- MIT License

---

*For detailed release notes, see [GitHub Releases](https://github.com/kochj23/URL-Analysis/releases).*
