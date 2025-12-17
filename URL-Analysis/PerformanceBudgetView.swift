//
//  PerformanceBudgetView.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

struct PerformanceBudgetView: View {
    @ObservedObject var budgetManager: BudgetManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Performance Budgets")
                    .font(.headline)

                Spacer()

                Toggle("Enabled", isOn: $budgetManager.budget.isEnabled)
                    .toggleStyle(.switch)
            }

            // Violations summary
            if budgetManager.budget.isEnabled && !budgetManager.violations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Budget Violations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(budgetManager.violations) { violation in
                        ViolationCard(violation: violation)
                    }
                }
            } else if budgetManager.budget.isEnabled && budgetManager.violations.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All performance budgets met!")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            Divider()

            // Quick presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Presets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Button("Mobile Fast") {
                        budgetManager.budget = .mobileFast
                    }
                    .buttonStyle(.bordered)

                    Button("Desktop Standard") {
                        budgetManager.budget = .desktopStandard
                    }
                    .buttonStyle(.bordered)

                    Button("PWA") {
                        budgetManager.budget = .pwa
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            // Budget configuration
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BudgetSlider(
                        title: "Max Load Time",
                        value: $budgetManager.budget.maxLoadTime,
                        range: 0.5...10.0,
                        unit: "s"
                    )

                    BudgetSlider(
                        title: "Max Total Size",
                        value: Binding(
                            get: { Double(budgetManager.budget.maxSize) / 1_048_576.0 },
                            set: { budgetManager.budget.maxSize = Int64($0 * 1_048_576.0) }
                        ),
                        range: 0.5...20.0,
                        unit: "MB",
                        step: 0.5
                    )

                    BudgetSlider(
                        title: "Max Requests",
                        value: Binding(
                            get: { Double(budgetManager.budget.maxRequests) },
                            set: { budgetManager.budget.maxRequests = Int($0) }
                        ),
                        range: 10...200,
                        unit: "requests",
                        step: 5
                    )

                    BudgetSlider(
                        title: "Min Performance Score",
                        value: Binding(
                            get: { Double(budgetManager.budget.minScore) },
                            set: { budgetManager.budget.minScore = Int($0) }
                        ),
                        range: 0...100,
                        unit: "score",
                        step: 5
                    )

                    Text("Web Vitals Budgets")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    BudgetSlider(
                        title: "Max LCP",
                        value: Binding(
                            get: { budgetManager.budget.maxLCP / 1000.0 },
                            set: { budgetManager.budget.maxLCP = $0 * 1000.0 }
                        ),
                        range: 1.0...5.0,
                        unit: "s",
                        step: 0.1
                    )

                    BudgetSlider(
                        title: "Max CLS",
                        value: $budgetManager.budget.maxCLS,
                        range: 0.0...0.5,
                        unit: "",
                        step: 0.01
                    )

                    BudgetSlider(
                        title: "Max FID",
                        value: Binding(
                            get: { budgetManager.budget.maxFID },
                            set: { budgetManager.budget.maxFID = $0 }
                        ),
                        range: 50...500,
                        unit: "ms",
                        step: 10
                    )
                }
            }
        }
        .padding()
    }
}

struct ViolationCard: View {
    let violation: BudgetViolation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: violation.severity.icon)
                .font(.system(size: 20))
                .foregroundColor(violation.severity.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(violation.metric)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    Text("Actual:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(violation.actual)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text("Budget:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    Text(violation.budget)
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Text(violation.recommendation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            Spacer()
        }
        .padding(12)
        .background(violation.severity.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct BudgetSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    var step: Double = 0.1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formattedValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
        }
    }

    private var formattedValue: String {
        if unit.isEmpty {
            return String(format: "%.2f", value)
        } else if unit == "MB" {
            return String(format: "%.1f %@", value, unit)
        } else if unit == "s" {
            return String(format: "%.1f %@", value, unit)
        } else if unit == "ms" {
            return String(format: "%.0f %@", value, unit)
        } else {
            return String(format: "%.0f %@", value, unit)
        }
    }
}

/// Budget alert banner for toolbar
struct BudgetAlertBanner: View {
    @ObservedObject var budgetManager: BudgetManager

    var body: some View {
        if budgetManager.budget.isEnabled && !budgetManager.violations.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: budgetManager.hasCriticalViolations ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(budgetManager.hasCriticalViolations ? .red : .orange)

                Text(budgetManager.summaryText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(budgetManager.hasCriticalViolations ? .red : .orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background((budgetManager.hasCriticalViolations ? Color.red : Color.orange).opacity(0.15))
            .cornerRadius(6)
        }
    }
}
