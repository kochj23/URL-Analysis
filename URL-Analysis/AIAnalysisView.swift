//
//  AIAnalysisView.swift
//  URL Analysis
//
//  Comprehensive AI analysis view showing all 6 AI features
//  Author: Jordan Koch
//  Date: 2025-01-17
//
//  Features powered by: Ollama, MLX Toolkit, and TinyLLM by Jason Cox
//

import SwiftUI

struct AIAnalysisView: View {
    @ObservedObject var analyzer: AIURLAnalyzer
    @ObservedObject var monitor: NetworkMonitor
    let currentURL: String
    @State private var selectedTab = 0
    @State private var question = ""
    @State private var answer = ""
    @State private var isAsking = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with backend status
            aiHeader

            Divider()

            // Tab selector
            Picker("Feature", selection: $selectedTab) {
                Text("💡 Insights").tag(0)
                Text("🔒 Security").tag(1)
                Text("🚀 Coach").tag(2)
                Text("🔧 Tech Stack").tag(3)
                Text("🛡️ Privacy").tag(4)
                Text("💬 Ask AI").tag(5)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Divider()

            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0: performanceInsightsView
                    case 1: securityAnalysisView
                    case 2: optimizationCoachView
                    case 3: technologyStackView
                    case 4: privacyAnalysisView
                    case 5: qaInterfaceView
                    default: Text("Unknown tab")
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Header

    private var aiHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("🤖 AI-Powered Analysis")
                    .font(.headline)

                HStack(spacing: 8) {
                    if let backend = AIBackendManager.shared.activeBackend {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("AI: \(backend.rawValue)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("AI Not Available")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if analyzer.isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Analyzing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button("⚙️ AI Settings") {
                openAISettings()
            }
            .buttonStyle(.borderless)

            Button("Run Full AI Analysis") {
                runFullAnalysis()
            }
            .buttonStyle(.borderedProminent)
            .disabled(analyzer.isAnalyzing || monitor.resources.isEmpty)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Feature Views

    private var performanceInsightsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💡 Performance Insights")
                .font(.title2)
                .bold()

            if !analyzer.performanceInsights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(analyzer.performanceInsights)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
            } else {
                emptyStateView(
                    icon: "lightbulb",
                    title: "No insights yet",
                    message: "Click 'Run Full AI Analysis' to get AI-powered performance insights"
                )
            }
        }
    }

    private var securityAnalysisView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🔒 Security Analysis")
                .font(.title2)
                .bold()

            if let security = analyzer.securityAnalysis {
                VStack(alignment: .leading, spacing: 12) {
                    // Risk level badge
                    HStack {
                        Text("Risk Level:")
                            .font(.headline)
                        Text(security.riskLevel.rawValue.uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(security.riskLevel.color)
                            .cornerRadius(6)
                    }

                    // Threats
                    if !security.threats.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Identified Threats:")
                                .font(.subheadline)
                                .bold()

                            ForEach(security.threats, id: \.self) { threat in
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(threat)
                                        .font(.body)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }

                    // Explanation
                    Text("Analysis:")
                        .font(.subheadline)
                        .bold()
                    Text(security.explanation)
                        .font(.body)
                        .foregroundColor(.secondary)

                    // Recommendations
                    if !security.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommendations:")
                                .font(.subheadline)
                                .bold()

                            ForEach(security.recommendations, id: \.self) { recommendation in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(recommendation)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
            } else {
                emptyStateView(
                    icon: "shield.checkered",
                    title: "No security analysis yet",
                    message: "Click 'Run Full AI Analysis' to get AI-powered security assessment"
                )
            }
        }
    }

    private var optimizationCoachView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🚀 AI Optimization Coach")
                .font(.title2)
                .bold()

            if !analyzer.optimizationAdvice.isEmpty {
                ForEach(analyzer.optimizationAdvice) { advice in
                    VStack(alignment: .leading, spacing: 12) {
                        // Issue header
                        HStack {
                            VStack(alignment: .leading) {
                                Text(advice.suggestion.title)
                                    .font(.headline)
                                HStack {
                                    Text(advice.suggestion.impact.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(advice.suggestion.impact.color)
                                        .cornerRadius(4)

                                    Text(advice.suggestion.difficulty.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(advice.suggestion.difficulty.color)
                                        .cornerRadius(4)
                                }
                            }
                            Spacer()
                        }

                        Divider()

                        // AI advice
                        Text(advice.aiAdvice)
                            .font(.body)
                            .foregroundColor(.primary)

                        // Implementation example
                        if let example = advice.implementationExample {
                            Text("Implementation:")
                                .font(.subheadline)
                                .bold()

                            Text(example)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(radius: 2)
                    )
                }
            } else {
                emptyStateView(
                    icon: "graduationcap",
                    title: "No coaching advice yet",
                    message: "Click 'Run Full AI Analysis' to get detailed optimization coaching"
                )
            }
        }
    }

    private var technologyStackView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🔧 Technology Stack")
                .font(.title2)
                .bold()

            if let stack = analyzer.technologyStack {
                VStack(alignment: .leading, spacing: 12) {
                    if let frontend = stack.frontend {
                        techItem(label: "Frontend", value: frontend, icon: "gear")
                    }
                    if let backend = stack.backend {
                        techItem(label: "Backend", value: backend, icon: "server.rack")
                    }
                    if let cms = stack.cms {
                        techItem(label: "CMS", value: cms, icon: "square.grid.2x2")
                    }
                    if !stack.analytics.isEmpty {
                        techItem(label: "Analytics", value: stack.analytics.joined(separator: ", "), icon: "chart.bar")
                    }
                    if let cdn = stack.cdn {
                        techItem(label: "CDN", value: cdn, icon: "network")
                    }
                    if !stack.libraries.isEmpty {
                        techItem(label: "Libraries", value: stack.libraries.joined(separator: ", "), icon: "books.vertical")
                    }
                    if let hosting = stack.hosting {
                        techItem(label: "Hosting", value: hosting, icon: "cloud")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(radius: 2)
                )
            } else {
                emptyStateView(
                    icon: "wrench.and.screwdriver",
                    title: "No stack detection yet",
                    message: "Click 'Run Full AI Analysis' to detect frameworks and technologies"
                )
            }
        }
    }

    private var privacyAnalysisView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🛡️ Privacy Impact")
                .font(.title2)
                .bold()

            if let privacy = analyzer.privacyAnalysis {
                VStack(alignment: .leading, spacing: 12) {
                    // Privacy score
                    HStack {
                        Text("Privacy Score:")
                            .font(.headline)
                        Text("\(privacy.privacyScore)/100")
                            .font(.title)
                            .bold()
                            .foregroundColor(privacyScoreColor(privacy.privacyScore))
                    }

                    Divider()

                    // Trackers
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trackers Found: \(privacy.trackerCount)")
                            .font(.subheadline)
                            .bold()

                        if !privacy.trackers.isEmpty {
                            ForEach(privacy.trackers.prefix(10), id: \.self) { tracker in
                                Text("• \(tracker)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()

                    // Data collected
                    if !privacy.dataCollected.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Data Being Collected:")
                                .font(.subheadline)
                                .bold()

                            ForEach(privacy.dataCollected, id: \.self) { data in
                                HStack(spacing: 8) {
                                    Image(systemName: "eye.fill")
                                        .foregroundColor(.orange)
                                    Text(data)
                                        .font(.body)
                                }
                            }
                        }
                    }

                    Divider()

                    // Risks
                    if !privacy.risks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Privacy Risks:")
                                .font(.subheadline)
                                .bold()

                            ForEach(privacy.risks, id: \.self) { risk in
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.shield.fill")
                                        .foregroundColor(.red)
                                    Text(risk)
                                        .font(.body)
                                }
                            }
                        }
                    }

                    // Recommendations
                    if !privacy.recommendations.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommendations:")
                                .font(.subheadline)
                                .bold()

                            ForEach(privacy.recommendations, id: \.self) { recommendation in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(recommendation)
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(radius: 2)
                )
            } else {
                emptyStateView(
                    icon: "hand.raised.shield",
                    title: "No privacy analysis yet",
                    message: "Click 'Run Full AI Analysis' to assess privacy impact"
                )
            }
        }
    }

    private var qaInterfaceView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💬 Ask AI About This Page")
                .font(.title2)
                .bold()

            // Example questions
            if answer.isEmpty && !isAsking {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example Questions:")
                        .font(.subheadline)
                        .bold()

                    exampleQuestion("Why is the page loading slowly?")
                    exampleQuestion("What's causing the high LCP?")
                    exampleQuestion("Is this URL safe to visit?")
                    exampleQuestion("What trackers are on this page?")
                    exampleQuestion("How can I improve the performance score?")
                    exampleQuestion("What frameworks is this site using?")
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }

            // Answer display
            if !answer.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("AI Answer")
                            .font(.headline)

                        Spacer()

                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(answer, forType: .string)
                        }
                        .buttonStyle(.borderless)
                    }

                    Text(answer)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.1))
                        )
                }
            }

            // Input area
            HStack(spacing: 12) {
                TextField("Ask a question about this page...", text: $question)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(monitor.resources.isEmpty)
                    .onSubmit {
                        askAI()
                    }

                Button(isAsking ? "Asking..." : "Ask") {
                    askAI()
                }
                .disabled(question.isEmpty || isAsking || monitor.resources.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Helper Views

    private func techItem(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .bold()
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func exampleQuestion(_ text: String) -> some View {
        Button(action: {
            question = text
            askAI()
        }) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.blue)
                Text(text)
                    .font(.caption)
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func privacyScoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }

    // MARK: - Actions

    private func openAISettings() {
        let settingsView = AIBackendSettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        hostingController.title = "AI Backend Settings"

        let window = NSWindow(contentViewController: hostingController)
        window.title = "AI Backend Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 700))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func runFullAnalysis() {
        guard let url = URL(string: currentURL) else { return }

        Task {
            // Run all analyses in parallel
            async let insights = analyzer.analyzePerformance(monitor: monitor, score: monitor.performanceScore?.overall ?? 0, vitals: monitor.webVitals)
            async let security = analyzer.analyzeURLSecurity(url: url, resources: monitor.resources)
            async let stack = analyzer.detectTechnologyStack(url: url, resources: monitor.resources)
            async let privacy = analyzer.analyzePrivacyImpact(resources: monitor.resources)

            _ = await (insights, security, stack, privacy)
        }
    }

    private func askAI() {
        guard !question.isEmpty, let url = URL(string: currentURL) else { return }

        isAsking = true
        let currentQuestion = question
        question = ""

        Task {
            let context = URLAnalysisContext(
                url: url,
                performanceScore: monitor.performanceScore?.overall ?? 0,
                loadTime: monitor.resources.map { $0.timings.total }.max() ?? 0,
                requestCount: monitor.resources.count,
                totalSize: monitor.resources.reduce(0) { $0 + $1.responseSize },
                largestResource: monitor.resources.max(by: { $0.responseSize < $1.responseSize }),
                slowestResource: monitor.resources.max(by: { $0.totalDuration < $1.totalDuration }),
                thirdPartyDomains: Set(monitor.resources.compactMap { URL(string: $0.url)?.host }),
                securityIssues: []
            )

            let response = await analyzer.askQuestion(currentQuestion, context: context)

            await MainActor.run {
                answer = response
                isAsking = false
            }
        }
    }
}

#Preview {
    AIAnalysisView(analyzer: AIURLAnalyzer(), monitor: NetworkMonitor(), currentURL: "https://example.com")
}
