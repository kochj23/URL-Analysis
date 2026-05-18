//
//  CodeGenerationView.swift
//  URL Analysis
//
//  AI-generated code fixes for performance optimization
//  Created by Jordan Koch on 2026-01-22
//

import SwiftUI

/// View displaying AI-generated code fixes
struct CodeGenerationView: View {
    @ObservedObject var analyzer: AIURLAnalyzer
    @ObservedObject var optimizationAnalyzer: OptimizationAnalyzer
    let techStack: TechnologyStack?
    let resources: [NetworkResource]
    @State private var isGenerating = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("💻 AI Code Generation")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                Text("Generate production-ready code to fix performance issues")
                    .font(.body)
                    .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                if analyzer.generatedCode.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 48))
                            .foregroundColor(AdaptiveColors.accent)

                        Text("Generate Code Fixes")
                            .font(.headline)
                            .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                        Text("AI will generate production-ready code to fix the top 5 optimization issues")
                            .font(.caption)
                            .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)

                        Button(action: {
                            Task {
                                isGenerating = true
                                await analyzer.generateCodeFixes(
                                    suggestions: optimizationAnalyzer.suggestions,
                                    techStack: techStack,
                                    resources: resources
                                )
                                isGenerating = false
                            }
                        }) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text(isGenerating ? "Generating Code..." : "Generate Code Fixes")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isGenerating || optimizationAnalyzer.suggestions.isEmpty)
                    }
                    .padding(40)
                    .glassCard()
                } else {
                    // Code fixes list
                    VStack(spacing: 16) {
                        HStack {
                            Text("\(analyzer.generatedCode.count) Code Fixes Generated")
                                .font(.headline)
                                .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                            Spacer()

                            Button(action: { copyAllCode() }) {
                                Label("Copy All", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)

                            Button(action: {
                                Task {
                                    isGenerating = true
                                    await analyzer.generateCodeFixes(
                                        suggestions: optimizationAnalyzer.suggestions,
                                        techStack: techStack,
                                        resources: resources
                                    )
                                    isGenerating = false
                                }
                            }) {
                                Label("Regenerate", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isGenerating)
                        }

                        ForEach(analyzer.generatedCode) { fix in
                            CodeFixCard(fix: fix)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func copyAllCode() {
        let allCode = analyzer.generatedCode.map { fix in
            """
            // \(fix.title)
            // \(fix.description)
            // Estimated Impact: \(fix.estimatedImpact)

            \(fix.code)


            """
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allCode, forType: .string)
    }
}

/// Individual code fix card
struct CodeFixCard: View {
    let fix: CodeFix
    @State private var copied = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fix.title)
                        .font(.headline)
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))

                    Text(fix.description)
                        .font(.caption)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()

                // Language badge
                Text(fix.language.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(languageColor(fix.language))
                    .cornerRadius(4)

                // Framework badge
                if let framework = fix.framework {
                    Text(framework.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AdaptiveColors.purple)
                        .cornerRadius(4)
                }
            }

            // Impact
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AdaptiveColors.accentGreen)
                Text(fix.estimatedImpact)
                    .font(.caption)
                    .foregroundColor(AdaptiveColors.accentGreen)
            }

            // Code block
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Code")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AdaptiveColors.textSecondary(for: colorScheme))

                    Spacer()

                    Button(action: { copyCode() }) {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied!" : "Copy")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    Text(fix.code)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(AdaptiveColors.textPrimary(for: colorScheme))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .frame(height: min(CGFloat(fix.code.components(separatedBy: "\n").count * 20 + 24), 300))
            }
        }
        .padding()
        .glassCard()
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fix.code, forType: .string)
        copied = true

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    private func languageColor(_ language: String) -> Color {
        switch language.lowercased() {
        case "javascript", "js":
            return AdaptiveColors.yellow
        case "css":
            return AdaptiveColors.cyan
        case "html":
            return AdaptiveColors.orange
        case "nginx", "htaccess":
            return AdaptiveColors.accentGreen
        default:
            return AdaptiveColors.purple
        }
    }
}
