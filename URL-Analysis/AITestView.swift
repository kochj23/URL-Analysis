//
//  AITestView.swift
//  URL Analysis
//
//  Quick AI backend test view
//  Author: Jordan Koch
//  Date: 2025-01-17
//

import SwiftUI

struct AITestView: View {
    @State private var testResult = ""
    @State private var isTesting = false

    var body: some View {
        VStack(spacing: 20) {
            Text("AI Backend Test")
                .font(.title)
                .bold()

            Divider()

            // Backend status
            VStack(alignment: .leading, spacing: 8) {
                Text("Backend Status:")
                    .font(.headline)

                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)

                    Text("Active: \(AIBackendManager.shared.activeBackend.rawValue)")
                        .foregroundColor(.green)
                }

                Text("Ollama: \(AIBackendManager.shared.isOllamaAvailable ? "✅ Available" : "❌ Not Available")")
                Text("TinyLLM: \(AIBackendManager.shared.isTinyLLMAvailable ? "✅ Available" : "❌ Not Available")")
                Text("MLX: \(AIBackendManager.shared.isMLXAvailable ? "✅ Available" : "❌ Not Available")")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            // Test button
            Button(isTesting ? "Testing..." : "Test AI Generation") {
                testAI()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isTesting || AIBackendManager.shared.activeBackend == nil)

            // Result display
            if !testResult.isEmpty {
                ScrollView {
                    Text(testResult)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                }
            }

            Spacer()

            Text("If test fails, check Console.app for error messages")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 500, height: 500)
    }

    private func testAI() {
        isTesting = true
        testResult = "Testing AI backend..."

        Task {
            do {
                print("🧪 Testing AI backend...")

                let response = try await AIBackendManager.shared.generate(
                    prompt: "Say 'Hello from URL Analysis!' and explain in one sentence what you can do.",
                    systemPrompt: "You are a helpful AI assistant.",
                    temperature: 0.7,
                    maxTokens: 100
                )

                print("🧪 Test successful! Response: \(response)")

                await MainActor.run {
                    testResult = "✅ SUCCESS!\n\nAI Response:\n\(response)"
                    isTesting = false
                }
            } catch {
                print("🧪 Test failed: \(error)")

                await MainActor.run {
                    testResult = "❌ ERROR:\n\(error.localizedDescription)\n\nCheck Console.app for details"
                    isTesting = false
                }
            }
        }
    }
}
