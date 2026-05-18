//
//  main.swift
//  URL Analysis CLI
//
//  Command-line interface for URL Analysis
//  Created by Jordan Koch on 2026-01-22
//

import Foundation
import ArgumentParser

@main
struct URLAnalysisCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "url-analysis",
        abstract: "Analyze web page performance from the command line",
        version: "1.4.0",
        subcommands: [Analyze.self, Batch.self],
        defaultSubcommand: Analyze.self
    )
}

// MARK: - Analyze Command

struct Analyze: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Analyze a single URL"
    )

    @Argument(help: "URL to analyze")
    var url: String

    @Option(name: .shortAndLong, help: "Output format: json, csv, har, summary")
    var format: OutputFormat = .json

    @Option(name: .shortAndLong, help: "Output file path (default: stdout)")
    var output: String?

    @Option(help: "Performance budget file (JSON)")
    var budget: String?

    @Option(help: "Device emulation: desktop, iphone, ipad, android")
    var device: String = "desktop"

    @Option(help: "Timeout in seconds (default: 30)")
    var timeout: Int = 30

    @Flag(help: "Exit with code 1 if budget violations detected")
    var failOnBudget: Bool = false

    @Flag(name: .shortAndLong, help: "Verbose output to stderr")
    var verbose: Bool = false

    mutating func run() async throws {
        if verbose {
            fputs("Analyzing: \(url)\n", stderr)
            fputs("Device: \(device)\n", stderr)
            fputs("Timeout: \(timeout)s\n", stderr)
        }

        // Create analyzer
        let analyzer = HeadlessAnalyzer()
        let deviceProfile = DeviceProfile.fromString(device)

        // Run analysis
        let result = try await analyzer.analyze(
            url: url,
            device: deviceProfile != .desktop ? deviceProfile : nil,
            timeout: TimeInterval(timeout)
        )

        if verbose {
            fputs("Analysis complete. Resources: \(result.requestCount)\n", stderr)
        }

        // Check budget if specified (simplified)
        if let budgetPath = budget {
            // Budget checking can be implemented later
            if verbose {
                fputs("\nNote: Budget checking not yet implemented in CLI mode\n", stderr)
            }
        }

        // Format output
        let outputData: Data
        switch format {
        case .json:
            outputData = try CLIOutputFormatter.formatJSON(result)
        case .csv:
            outputData = CLIOutputFormatter.formatCSV(result)
        case .har:
            outputData = try CLIOutputFormatter.formatHAR(result)
        case .summary:
            outputData = CLIOutputFormatter.formatSummary(result)
        }

        // Write output
        if let outputPath = output {
            let outputURL = URL(fileURLWithPath: outputPath)
            try outputData.write(to: outputURL)
            if verbose {
                fputs("Wrote output to: \(outputPath)\n", stderr)
            }
        } else {
            // Write to stdout
            if let outputString = String(data: outputData, encoding: .utf8) {
                print(outputString)
            }
        }
    }

}

// MARK: - Batch Command

struct Batch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "batch",
        abstract: "Analyze multiple URLs from a file"
    )

    @Option(name: .shortAndLong, help: "Input file with URLs (one per line)")
    var input: String

    @Option(name: .shortAndLong, help: "Output directory for results")
    var output: String = "."

    @Option(name: .shortAndLong, help: "Output format: json, csv, har, summary")
    var format: OutputFormat = .json

    @Option(help: "Device emulation: desktop, iphone, ipad, android")
    var device: String = "desktop"

    @Option(help: "Delay between requests in seconds (default: 2)")
    var delay: Int = 2

    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false

    mutating func run() async throws {
        // Read URLs from file
        let fileURL = URL(fileURLWithPath: input)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let urls = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.hasPrefix("http") }

        if urls.isEmpty {
            fputs("No valid URLs found in \(input)\n", stderr)
            throw ExitCode(1)
        }

        if verbose {
            fputs("Found \(urls.count) URLs to analyze\n", stderr)
        }

        // Create output directory
        let outputDir = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Analyze each URL
        let analyzer = HeadlessAnalyzer()
        let deviceProfile = DeviceProfile.fromString(device)

        for (index, url) in urls.enumerated() {
            if verbose {
                fputs("[\(index + 1)/\(urls.count)] Analyzing: \(url)\n", stderr)
            }

            do {
                let result = try await analyzer.analyze(
                    url: url,
                    device: deviceProfile != .desktop ? deviceProfile : nil,
                    timeout: 30
                )

                // Format output
                let outputData: Data
                switch format {
                case .json:
                    outputData = try CLIOutputFormatter.formatJSON(result)
                case .csv:
                    outputData = CLIOutputFormatter.formatCSV(result)
                case .har:
                    outputData = try CLIOutputFormatter.formatHAR(result)
                case .summary:
                    outputData = CLIOutputFormatter.formatSummary(result)
                }

                // Write to file
                let filename = "\(sanitizeFilename(url)).\(format.fileExtension)"
                let fileURL = outputDir.appendingPathComponent(filename)
                try outputData.write(to: fileURL)

                if verbose {
                    fputs("  Written: \(filename)\n", stderr)
                }

                // Rate limit
                if index < urls.count - 1 {
                    try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                }
            } catch {
                fputs("  Error analyzing \(url): \(error.localizedDescription)\n", stderr)
            }
        }

        if verbose {
            fputs("\nBatch analysis complete. Results saved to: \(output)\n", stderr)
        }
    }

    private func sanitizeFilename(_ url: String) -> String {
        url.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .prefix(100)
            .description
    }
}

// MARK: - Output Format Enum

enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    case json
    case csv
    case har
    case summary

    var fileExtension: String {
        switch self {
        case .json, .har: return "json"
        case .csv: return "csv"
        case .summary: return "txt"
        }
    }
}
