//
//  PDFReport.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import AppKit
import PDFKit

/// Generates comprehensive PDF performance reports
@MainActor
class PDFReportGenerator {

    /// Generate a complete performance analysis PDF report
    static func generateReport(
        url: String,
        monitor: NetworkMonitor,
        webVitals: WebVitals?,
        performanceScore: PerformanceScore?,
        optimizationSuggestions: [OptimizationSuggestion],
        thirdPartyDomains: [ThirdPartyDomain],
        budgetViolations: [BudgetViolation],
        screenshots: [ScreenshotFrame]
    ) -> PDFDocument? {

        let pageWidth: CGFloat = 612  // 8.5 inches at 72 DPI
        let pageHeight: CGFloat = 792  // 11 inches at 72 DPI
        let margin: CGFloat = 50

        let pdfDocument = PDFDocument()
        var currentPage = 0

        // Page 1: Executive Summary
        let summaryPage = createExecutiveSummaryPage(
            url: url,
            monitor: monitor,
            performanceScore: performanceScore,
            webVitals: webVitals,
            pageSize: CGSize(width: pageWidth, height: pageHeight),
            margin: margin
        )
        pdfDocument.insert(summaryPage, at: currentPage)
        currentPage += 1

        // Page 2: Performance Score Details
        if let score = performanceScore {
            let scorePage = createScoreDetailsPage(
                score: score,
                pageSize: CGSize(width: pageWidth, height: pageHeight),
                margin: margin
            )
            pdfDocument.insert(scorePage, at: currentPage)
            currentPage += 1
        }

        // Page 3: Web Vitals Details
        if let vitals = webVitals {
            let vitalsPage = createWebVitalsPage(
                vitals: vitals,
                pageSize: CGSize(width: pageWidth, height: pageHeight),
                margin: margin
            )
            pdfDocument.insert(vitalsPage, at: currentPage)
            currentPage += 1
        }

        // Page 4-N: Optimization Suggestions
        if !optimizationSuggestions.isEmpty {
            let suggestionsPages = createOptimizationPages(
                suggestions: optimizationSuggestions,
                pageSize: CGSize(width: pageWidth, height: pageHeight),
                margin: margin
            )
            for page in suggestionsPages {
                pdfDocument.insert(page, at: currentPage)
                currentPage += 1
            }
        }

        // Page: Third-Party Analysis
        if !thirdPartyDomains.isEmpty {
            let thirdPartyPage = createThirdPartyPage(
                domains: thirdPartyDomains,
                pageSize: CGSize(width: pageWidth, height: pageHeight),
                margin: margin
            )
            pdfDocument.insert(thirdPartyPage, at: currentPage)
            currentPage += 1
        }

        // Page: Budget Violations (if any)
        if !budgetViolations.isEmpty {
            let budgetPage = createBudgetViolationsPage(
                violations: budgetViolations,
                pageSize: CGSize(width: pageWidth, height: pageHeight),
                margin: margin
            )
            pdfDocument.insert(budgetPage, at: currentPage)
            currentPage += 1
        }

        // Page: Screenshot Timeline
        if !screenshots.isEmpty {
            let screenshotsPage = createScreenshotsPage(
                screenshots: screenshots,
                pageSize: CGSize(width: pageWidth, height: pageHeight),
                margin: margin
            )
            pdfDocument.insert(screenshotsPage, at: currentPage)
            currentPage += 1
        }

        // Page: Resource Summary
        let resourcePage = createResourceSummaryPage(
            monitor: monitor,
            pageSize: CGSize(width: pageWidth, height: pageHeight),
            margin: margin
        )
        pdfDocument.insert(resourcePage, at: currentPage)
        currentPage += 1

        return pdfDocument
    }

    // MARK: - Page Generators

    private static func createExecutiveSummaryPage(
        url: String,
        monitor: NetworkMonitor,
        performanceScore: PerformanceScore?,
        webVitals: WebVitals?,
        pageSize: CGSize,
        margin: CGFloat
    ) -> PDFPage {
        let data = NSMutableData()

        let pdfConsumer = CGDataConsumer(data: data as CFMutableData)!
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!

        pdfContext.beginPage(mediaBox: &mediaBox)

        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = nsContext

        var yPosition = pageSize.height - margin

        // Title
        drawText("Performance Analysis Report", at: CGPoint(x: margin, y: yPosition), fontSize: 24, bold: true, color: .black)
        yPosition -= 40

        // URL
        drawText("URL: \(url)", at: CGPoint(x: margin, y: yPosition), fontSize: 12, bold: false, color: .darkGray)
        yPosition -= 25

        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        drawText("Generated: \(dateFormatter.string(from: Date()))", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: .darkGray)
        yPosition -= 40

        // Horizontal line
        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageSize.width - margin, y: yPosition), color: .gray)
        yPosition -= 30

        // Performance Score (if available)
        if let score = performanceScore {
            drawText("Overall Performance Score", at: CGPoint(x: margin, y: yPosition), fontSize: 16, bold: true, color: .black)
            yPosition -= 30

            // Draw score circle
            let scoreCircleCenter = CGPoint(x: margin + 60, y: yPosition - 60)
            let scoreCircleRadius: CGFloat = 50

            // Background circle
            let circlePath = NSBezierPath()
            circlePath.appendArc(withCenter: scoreCircleCenter, radius: scoreCircleRadius, startAngle: 0, endAngle: 360, clockwise: false)
            NSColor.lightGray.withAlphaComponent(0.2).setFill()
            circlePath.fill()

            // Score arc
            let scoreArc = NSBezierPath()
            scoreArc.lineWidth = 10
            let endAngle = CGFloat(score.overall) / 100.0 * 360.0
            scoreArc.appendArc(withCenter: scoreCircleCenter, radius: scoreCircleRadius, startAngle: 90, endAngle: 90 - endAngle, clockwise: true)
            scoreColor(score.overall).setStroke()
            scoreArc.stroke()

            // Score text
            let scoreText = "\(score.overall)"
            let scoreAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: NSColor.black
            ]
            let scoreSize = scoreText.size(withAttributes: scoreAttributes)
            scoreText.draw(at: CGPoint(x: scoreCircleCenter.x - scoreSize.width / 2, y: scoreCircleCenter.y - scoreSize.height / 2), withAttributes: scoreAttributes)

            // Category scores
            let categoryX = margin + 150
            drawText("Category Breakdown:", at: CGPoint(x: categoryX, y: yPosition), fontSize: 12, bold: true, color: .black)
            yPosition -= 20

            drawCategoryScore("Load Time", score: score.loadTime, at: CGPoint(x: categoryX, y: yPosition))
            yPosition -= 18
            drawCategoryScore("Resources", score: score.resourceCount, at: CGPoint(x: categoryX, y: yPosition))
            yPosition -= 18
            drawCategoryScore("Total Size", score: score.totalSize, at: CGPoint(x: categoryX, y: yPosition))
            yPosition -= 18
            drawCategoryScore("Web Vitals", score: score.webVitals, at: CGPoint(x: categoryX, y: yPosition))
            yPosition -= 40
        }

        // Key Metrics Summary
        drawText("Key Metrics", at: CGPoint(x: margin, y: yPosition), fontSize: 16, bold: true, color: .black)
        yPosition -= 25

        drawMetric("Load Time:", value: formatDuration(monitor.totalDuration), at: CGPoint(x: margin, y: yPosition))
        yPosition -= 20
        drawMetric("Total Requests:", value: "\(monitor.resources.count)", at: CGPoint(x: margin, y: yPosition))
        yPosition -= 20
        drawMetric("Total Size:", value: formatSize(monitor.totalSize), at: CGPoint(x: margin, y: yPosition))
        yPosition -= 20
        drawMetric("Domains:", value: "\(monitor.domains.count)", at: CGPoint(x: margin, y: yPosition))
        yPosition -= 30

        // Web Vitals Summary
        if let vitals = webVitals {
            drawText("Core Web Vitals", at: CGPoint(x: margin, y: yPosition), fontSize: 16, bold: true, color: .black)
            yPosition -= 25

            drawWebVital("LCP:", value: vitals.lcp.value, rating: vitals.lcp.rating, at: CGPoint(x: margin, y: yPosition))
            yPosition -= 20
            drawWebVital("CLS:", value: vitals.cls.value, rating: vitals.cls.rating, at: CGPoint(x: margin, y: yPosition))
            yPosition -= 20
            drawWebVital("FID:", value: vitals.fid.value, rating: vitals.fid.rating, at: CGPoint(x: margin, y: yPosition))
            yPosition -= 30
        }

        // Footer
        drawText("Generated by URL Analysis v1.2.0 - Jordan Koch", at: CGPoint(x: margin, y: 30), fontSize: 8, bold: false, color: .gray)
        drawText("Page 1", at: CGPoint(x: pageSize.width - margin - 50, y: 30), fontSize: 8, bold: false, color: .gray)

        pdfContext.endPage()
        pdfContext.closePDF()

        return PDFPage(image: NSImage(data: data as Data)!) ?? PDFPage()
    }

    private static func createScoreDetailsPage(
        score: PerformanceScore,
        pageSize: CGSize,
        margin: CGFloat
    ) -> PDFPage {
        let data = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: data as CFMutableData)!
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!

        pdfContext.beginPage(mediaBox: &mediaBox)
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = nsContext

        var yPosition = pageSize.height - margin

        // Title
        drawText("Performance Score Details", at: CGPoint(x: margin, y: yPosition), fontSize: 20, bold: true, color: .black)
        yPosition -= 35

        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageSize.width - margin, y: yPosition), color: .gray)
        yPosition -= 30

        // Load Time
        drawCategoryDetail("Load Time", category: score.loadTime, at: &yPosition, margin: margin, width: pageSize.width - 2 * margin)
        yPosition -= 25

        // Resource Count
        drawCategoryDetail("Resource Count", category: score.resourceCount, at: &yPosition, margin: margin, width: pageSize.width - 2 * margin)
        yPosition -= 25

        // Total Size
        drawCategoryDetail("Total Size", category: score.totalSize, at: &yPosition, margin: margin, width: pageSize.width - 2 * margin)
        yPosition -= 25

        // Web Vitals
        drawCategoryDetail("Web Vitals", category: score.webVitals, at: &yPosition, margin: margin, width: pageSize.width - 2 * margin)

        // Footer
        drawText("Generated by URL Analysis v1.2.0", at: CGPoint(x: margin, y: 30), fontSize: 8, bold: false, color: .gray)
        drawText("Page 2", at: CGPoint(x: pageSize.width - margin - 50, y: 30), fontSize: 8, bold: false, color: .gray)

        pdfContext.endPage()
        pdfContext.closePDF()

        return PDFPage(image: NSImage(data: data as Data)!) ?? PDFPage()
    }

    private static func createWebVitalsPage(
        vitals: WebVitals,
        pageSize: CGSize,
        margin: CGFloat
    ) -> PDFPage {
        let data = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: data as CFMutableData)!
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!

        pdfContext.beginPage(mediaBox: &mediaBox)
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = nsContext

        var yPosition = pageSize.height - margin

        drawText("Core Web Vitals Analysis", at: CGPoint(x: margin, y: yPosition), fontSize: 20, bold: true, color: .black)
        yPosition -= 35

        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageSize.width - margin, y: yPosition), color: .gray)
        yPosition -= 30

        // LCP
        drawText("LCP (Largest Contentful Paint)", at: CGPoint(x: margin, y: yPosition), fontSize: 14, bold: true, color: .black)
        yPosition -= 22
        drawText("Measures loading performance - when the largest content element becomes visible", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: .darkGray)
        yPosition -= 20
        drawWebVital("Value:", value: vitals.lcp.value, rating: vitals.lcp.rating, at: CGPoint(x: margin, y: yPosition))
        yPosition -= 18
        drawText("Score: \(vitals.lcp.score)/100", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: .black)
        yPosition -= 18
        drawText("Rating: \(vitals.lcp.rating.rawValue.capitalized)", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: ratingColor(vitals.lcp.rating))
        yPosition -= 18
        drawText("Target: < 2.5s (Good), < 4.0s (Needs Improvement)", at: CGPoint(x: margin, y: yPosition), fontSize: 9, bold: false, color: .darkGray)
        yPosition -= 35

        // CLS
        drawText("CLS (Cumulative Layout Shift)", at: CGPoint(x: margin, y: yPosition), fontSize: 14, bold: true, color: .black)
        yPosition -= 22
        drawText("Measures visual stability - how much content shifts unexpectedly during load", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: .darkGray)
        yPosition -= 20
        drawWebVital("Value:", value: vitals.cls.value, rating: vitals.cls.rating, at: CGPoint(x: margin, y: yPosition))
        yPosition -= 18
        drawText("Score: \(vitals.cls.score)/100", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: .black)
        yPosition -= 18
        drawText("Rating: \(vitals.cls.rating.rawValue.capitalized)", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: ratingColor(vitals.cls.rating))
        yPosition -= 18
        drawText("Target: < 0.1 (Good), < 0.25 (Needs Improvement)", at: CGPoint(x: margin, y: yPosition), fontSize: 9, bold: false, color: .darkGray)
        yPosition -= 35

        // FID
        drawText("FID (First Input Delay)", at: CGPoint(x: margin, y: yPosition), fontSize: 14, bold: true, color: .black)
        yPosition -= 22
        drawText("Measures interactivity - time from first user interaction to browser response", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: .darkGray)
        yPosition -= 20
        drawWebVital("Value:", value: vitals.fid.value, rating: vitals.fid.rating, at: CGPoint(x: margin, y: yPosition))
        yPosition -= 18
        drawText("Score: \(vitals.fid.score)/100", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: .black)
        yPosition -= 18
        drawText("Rating: \(vitals.fid.rating.rawValue.capitalized)", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: ratingColor(vitals.fid.rating))
        yPosition -= 18
        drawText("Target: < 100ms (Good), < 300ms (Needs Improvement)", at: CGPoint(x: margin, y: yPosition), fontSize: 9, bold: false, color: .darkGray)

        // Footer
        drawText("Generated by URL Analysis v1.2.0", at: CGPoint(x: margin, y: 30), fontSize: 8, bold: false, color: .gray)
        drawText("Page 3", at: CGPoint(x: pageSize.width - margin - 50, y: 30), fontSize: 8, bold: false, color: .gray)

        pdfContext.endPage()
        pdfContext.closePDF()

        return PDFPage(image: NSImage(data: data as Data)!) ?? PDFPage()
    }

    private static func createOptimizationPages(
        suggestions: [OptimizationSuggestion],
        pageSize: CGSize,
        margin: CGFloat
    ) -> [PDFPage] {
        var pages: [PDFPage] = []
        let maxY: CGFloat = 100  // Leave room for footer
        var currentSuggestions: [OptimizationSuggestion] = []

        // Group suggestions that fit on same page
        for suggestion in suggestions {
            currentSuggestions.append(suggestion)

            // Estimate if we need a new page (roughly 150 points per suggestion)
            let estimatedHeight = CGFloat(currentSuggestions.count) * 200
            if estimatedHeight > pageSize.height - margin - maxY - 100 {
                // Create page with current suggestions
                let page = createSingleOptimizationPage(
                    suggestions: Array(currentSuggestions.dropLast()),
                    pageSize: pageSize,
                    margin: margin,
                    pageNumber: pages.count + 4  // Offset by previous pages
                )
                pages.append(page)
                currentSuggestions = [suggestion]
            }
        }

        // Create final page with remaining suggestions
        if !currentSuggestions.isEmpty {
            let page = createSingleOptimizationPage(
                suggestions: currentSuggestions,
                pageSize: pageSize,
                margin: margin,
                pageNumber: pages.count + 4
            )
            pages.append(page)
        }

        return pages
    }

    private static func createSingleOptimizationPage(
        suggestions: [OptimizationSuggestion],
        pageSize: CGSize,
        margin: CGFloat,
        pageNumber: Int
    ) -> PDFPage {
        let data = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: data as CFMutableData)!
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!

        pdfContext.beginPage(mediaBox: &mediaBox)
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = nsContext

        var yPosition = pageSize.height - margin

        // Title
        drawText("Optimization Suggestions", at: CGPoint(x: margin, y: yPosition), fontSize: 20, bold: true, color: .black)
        yPosition -= 35

        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageSize.width - margin, y: yPosition), color: .gray)
        yPosition -= 25

        // Suggestions
        for (index, suggestion) in suggestions.enumerated() {
            // Impact and difficulty badges
            let impactColor = impactNSColor(suggestion.impact)
            drawText("[\(suggestion.impact.rawValue.uppercased())] [\(suggestion.difficulty.rawValue)]", at: CGPoint(x: margin, y: yPosition), fontSize: 9, bold: true, color: impactColor)
            yPosition -= 20

            // Title
            drawText("\(index + 1). \(suggestion.title)", at: CGPoint(x: margin, y: yPosition), fontSize: 12, bold: true, color: .black)
            yPosition -= 18

            // Description
            let wrappedDescription = wrapText(suggestion.description, width: pageSize.width - 2 * margin, fontSize: 10)
            for line in wrappedDescription {
                drawText(line, at: CGPoint(x: margin + 10, y: yPosition), fontSize: 10, bold: false, color: .darkGray)
                yPosition -= 15
            }
            yPosition -= 5

            // Current State
            drawText("Current: \(suggestion.currentState)", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 9, bold: false, color: .orange)
            yPosition -= 15

            // Target State
            if let target = suggestion.targetState {
                let wrappedTarget = wrapText(target, width: pageSize.width - 2 * margin - 20, fontSize: 9)
                for line in wrappedTarget {
                    drawText("Target: \(line)", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 9, bold: false, color: .systemGreen)
                    yPosition -= 14
                }
            }
            yPosition -= 5

            // Savings
            if let savings = suggestion.estimatedSavings {
                let wrappedSavings = wrapText(savings, width: pageSize.width - 2 * margin - 20, fontSize: 9)
                for line in wrappedSavings {
                    drawText("💰 \(line)", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 9, bold: true, color: .systemGreen)
                    yPosition -= 14
                }
            }

            // Affected resources (top 5)
            if !suggestion.affectedResources.isEmpty {
                yPosition -= 10
                drawText("Affected Resources (showing \(min(5, suggestion.affectedResources.count)) of \(suggestion.affectedResources.count)):", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 9, bold: false, color: .darkGray)
                yPosition -= 15

                for resource in suggestion.affectedResources.prefix(5) {
                    let shortURL = URL(string: resource.url)?.lastPathComponent ?? resource.url
                    drawText("  • \(shortURL) - \(formatSize(resource.size))", at: CGPoint(x: margin + 15, y: yPosition), fontSize: 8, bold: false, color: .darkGray)
                    yPosition -= 12
                }
            }

            yPosition -= 20

            // Stop if we're too low on the page
            if yPosition < 120 {
                break
            }
        }

        // Footer
        drawText("Generated by URL Analysis v1.2.0", at: CGPoint(x: margin, y: 30), fontSize: 8, bold: false, color: .gray)
        drawText("Page \(pageNumber)", at: CGPoint(x: pageSize.width - margin - 50, y: 30), fontSize: 8, bold: false, color: .gray)

        pdfContext.endPage()
        pdfContext.closePDF()

        return PDFPage(image: NSImage(data: data as Data)!) ?? PDFPage()
    }

    private static func createThirdPartyPage(
        domains: [ThirdPartyDomain],
        pageSize: CGSize,
        margin: CGFloat
    ) -> PDFPage {
        let data = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: data as CFMutableData)!
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!

        pdfContext.beginPage(mediaBox: &mediaBox)
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = nsContext

        var yPosition = pageSize.height - margin

        drawText("Third-Party Analysis", at: CGPoint(x: margin, y: yPosition), fontSize: 20, bold: true, color: .black)
        yPosition -= 35

        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageSize.width - margin, y: yPosition), color: .gray)
        yPosition -= 25

        // Summary
        let totalSize = domains.reduce(0) { $0 + $1.totalSize }
        let totalRequests = domains.reduce(0) { $0 + $1.requestCount }

        drawText("Total Third-Party Domains: \(domains.count)", at: CGPoint(x: margin, y: yPosition), fontSize: 12, bold: false, color: .black)
        yPosition -= 18
        drawText("Total Requests: \(totalRequests)", at: CGPoint(x: margin, y: yPosition), fontSize: 12, bold: false, color: .black)
        yPosition -= 18
        drawText("Total Size: \(formatSize(totalSize))", at: CGPoint(x: margin, y: yPosition), fontSize: 12, bold: false, color: .black)
        yPosition -= 30

        // Top domains (up to 15)
        drawText("Top Domains by Impact:", at: CGPoint(x: margin, y: yPosition), fontSize: 14, bold: true, color: .black)
        yPosition -= 25

        for (index, domain) in domains.prefix(15).enumerated() {
            let providerName = domain.provider?.name ?? domain.domain
            drawText("\(index + 1). \(providerName)", at: CGPoint(x: margin, y: yPosition), fontSize: 11, bold: true, color: .black)
            yPosition -= 16

            if domain.provider != nil {
                drawText("   Domain: \(domain.domain)", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 9, bold: false, color: .darkGray)
                yPosition -= 14
            }

            drawText("   Requests: \(domain.requestCount) | Size: \(formatSize(domain.totalSize)) | Duration: \(formatDuration(domain.totalDuration))", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 9, bold: false, color: .darkGray)
            yPosition -= 14

            if let provider = domain.provider {
                drawText("   Category: \(provider.category.rawValue) - \(provider.description)", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 9, bold: false, color: .darkGray)
                yPosition -= 14
            }

            yPosition -= 8

            if yPosition < 120 {
                drawText("... and \(domains.count - index - 1) more domains", at: CGPoint(x: margin, y: yPosition), fontSize: 10, bold: false, color: .darkGray)
                break
            }
        }

        // Footer
        drawText("Generated by URL Analysis v1.2.0", at: CGPoint(x: margin, y: 30), fontSize: 8, bold: false, color: .gray)

        pdfContext.endPage()
        pdfContext.closePDF()

        return PDFPage(image: NSImage(data: data as Data)!) ?? PDFPage()
    }

    private static func createBudgetViolationsPage(
        violations: [BudgetViolation],
        pageSize: CGSize,
        margin: CGFloat
    ) -> PDFPage {
        let data = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: data as CFMutableData)!
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!

        pdfContext.beginPage(mediaBox: &mediaBox)
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = nsContext

        var yPosition = pageSize.height - margin

        drawText("Performance Budget Violations", at: CGPoint(x: margin, y: yPosition), fontSize: 20, bold: true, color: .black)
        yPosition -= 35

        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageSize.width - margin, y: yPosition), color: .gray)
        yPosition -= 25

        let critical = violations.filter { $0.severity == .critical }.count
        let warnings = violations.filter { $0.severity == .warning }.count
        let minor = violations.filter { $0.severity == .minor }.count

        drawText("Summary: \(critical) Critical, \(warnings) Warnings, \(minor) Minor", at: CGPoint(x: margin, y: yPosition), fontSize: 12, bold: true, color: .red)
        yPosition -= 30

        for (index, violation) in violations.enumerated() {
            let severityColor: NSColor
            switch violation.severity {
            case .critical: severityColor = .red
            case .warning: severityColor = .orange
            case .minor: severityColor = .systemYellow
            }

            drawText("\(index + 1). \(violation.metric) [\(violation.severity)]".uppercased(), at: CGPoint(x: margin, y: yPosition), fontSize: 11, bold: true, color: severityColor)
            yPosition -= 18

            drawText("   Actual: \(violation.actual) | Budget: \(violation.budget)", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 10, bold: false, color: .black)
            yPosition -= 16

            let wrappedRec = wrapText(violation.recommendation, width: pageSize.width - 2 * margin - 20, fontSize: 9)
            for line in wrappedRec {
                drawText("   \(line)", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 9, bold: false, color: .darkGray)
                yPosition -= 14
            }

            yPosition -= 15

            if yPosition < 120 {
                break
            }
        }

        // Footer
        drawText("Generated by URL Analysis v1.2.0", at: CGPoint(x: margin, y: 30), fontSize: 8, bold: false, color: .gray)

        pdfContext.endPage()
        pdfContext.closePDF()

        return PDFPage(image: NSImage(data: data as Data)!) ?? PDFPage()
    }

    private static func createScreenshotsPage(
        screenshots: [ScreenshotFrame],
        pageSize: CGSize,
        margin: CGFloat
    ) -> PDFPage {
        let data = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: data as CFMutableData)!
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!

        pdfContext.beginPage(mediaBox: &mediaBox)
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = nsContext

        var yPosition = pageSize.height - margin

        drawText("Screenshot Timeline", at: CGPoint(x: margin, y: yPosition), fontSize: 20, bold: true, color: .black)
        yPosition -= 35

        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageSize.width - margin, y: yPosition), color: .gray)
        yPosition -= 25

        // Draw screenshots in a 2x3 grid
        let imageWidth = (pageSize.width - 2 * margin - 20) / 2
        let imageHeight = imageWidth * 0.75

        for (index, frame) in screenshots.enumerated() {
            let col = index % 2
            let row = index / 2

            let xPos = margin + CGFloat(col) * (imageWidth + 20)
            let yPos = yPosition - CGFloat(row) * (imageHeight + 40)

            // Draw image
            let imageRect = CGRect(x: xPos, y: yPos - imageHeight, width: imageWidth, height: imageHeight)
            frame.image.draw(in: imageRect)

            // Draw caption
            drawText(frame.caption, at: CGPoint(x: xPos, y: yPos - imageHeight - 15), fontSize: 10, bold: true, color: .black)

            if index >= 5 {
                break  // Max 6 screenshots per page
            }
        }

        // Footer
        drawText("Generated by URL Analysis v1.2.0", at: CGPoint(x: margin, y: 30), fontSize: 8, bold: false, color: .gray)

        pdfContext.endPage()
        pdfContext.closePDF()

        return PDFPage(image: NSImage(data: data as Data)!) ?? PDFPage()
    }

    private static func createResourceSummaryPage(
        monitor: NetworkMonitor,
        pageSize: CGSize,
        margin: CGFloat
    ) -> PDFPage {
        let data = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: data as CFMutableData)!
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!

        pdfContext.beginPage(mediaBox: &mediaBox)
        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = nsContext

        var yPosition = pageSize.height - margin

        drawText("Resource Summary", at: CGPoint(x: margin, y: yPosition), fontSize: 20, bold: true, color: .black)
        yPosition -= 35

        drawLine(from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageSize.width - margin, y: yPosition), color: .gray)
        yPosition -= 25

        // Group by type
        let byType = Dictionary(grouping: monitor.resources, by: { $0.resourceType })

        drawText("Resources by Type:", at: CGPoint(x: margin, y: yPosition), fontSize: 14, bold: true, color: .black)
        yPosition -= 25

        for type in NetworkResource.ResourceType.allCases {
            if let resources = byType[type] {
                let count = resources.count
                let size = resources.reduce(0) { $0 + $1.responseSize }
                let duration = resources.reduce(0) { $0 + $1.totalDuration }

                drawText("\(type.rawValue):", at: CGPoint(x: margin, y: yPosition), fontSize: 11, bold: true, color: .black)
                yPosition -= 16
                drawText("   Count: \(count) | Size: \(formatSize(size)) | Total Duration: \(formatDuration(duration))", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 9, bold: false, color: .darkGray)
                yPosition -= 18
            }
        }

        // Footer
        drawText("Generated by URL Analysis v1.2.0", at: CGPoint(x: margin, y: 30), fontSize: 8, bold: false, color: .gray)

        pdfContext.endPage()
        pdfContext.closePDF()

        return PDFPage(image: NSImage(data: data as Data)!) ?? PDFPage()
    }

    // MARK: - Helper Functions

    private static func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, bold: Bool, color: NSColor) {
        let font = bold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        text.draw(at: point, withAttributes: attributes)
    }

    private static func drawLine(from start: CGPoint, to end: CGPoint, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = 1
        color.setStroke()
        path.stroke()
    }

    private static func drawMetric(_ label: String, value: String, at point: CGPoint) {
        drawText(label, at: point, fontSize: 11, bold: true, color: .darkGray)
        drawText(value, at: CGPoint(x: point.x + 150, y: point.y), fontSize: 11, bold: false, color: .black)
    }

    private static func drawWebVital(_ label: String, value: String, rating: WebVitals.Metric.Rating, at point: CGPoint) {
        drawText(label, at: point, fontSize: 11, bold: true, color: .darkGray)
        drawText(value, at: CGPoint(x: point.x + 150, y: point.y), fontSize: 11, bold: false, color: ratingColor(rating))
    }

    private static func drawCategoryScore(_ name: String, score: PerformanceScore.ScoreCategory, at point: CGPoint) {
        drawText("\(name): \(score.score)", at: point, fontSize: 10, bold: false, color: .black)
        drawText(score.value, at: CGPoint(x: point.x + 150, y: point.y), fontSize: 10, bold: false, color: categoryColor(score.rating))
    }

    private static func drawCategoryDetail(_ name: String, category: PerformanceScore.ScoreCategory, at yPosition: inout CGFloat, margin: CGFloat, width: CGFloat) {
        drawText(name, at: CGPoint(x: margin, y: yPosition), fontSize: 13, bold: true, color: .black)
        yPosition -= 18

        drawText("Score: \(category.score)/100 [\(category.rating)]", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 10, bold: false, color: categoryColor(category.rating))
        yPosition -= 15

        drawText("Value: \(category.value)", at: CGPoint(x: margin + 10, y: yPosition), fontSize: 10, bold: false, color: .black)
        yPosition -= 15

        let wrappedRec = wrapText(category.recommendation, width: width - 20, fontSize: 9)
        for line in wrappedRec {
            drawText(line, at: CGPoint(x: margin + 10, y: yPosition), fontSize: 9, bold: false, color: .darkGray)
            yPosition -= 13
        }
    }

    private static func wrapText(_ text: String, width: CGFloat, fontSize: CGFloat) -> [String] {
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        var lines: [String] = []
        var currentLine = ""
        let words = text.components(separatedBy: " ")

        for word in words {
            let testLine = currentLine.isEmpty ? word : currentLine + " " + word
            let size = testLine.size(withAttributes: attributes)

            if size.width > width && !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = word
            } else {
                currentLine = testLine
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines
    }

    private static func scoreColor(_ score: Int) -> NSColor {
        if score >= 90 { return .systemGreen }
        if score >= 50 { return .orange }
        return .red
    }

    private static func categoryColor(_ rating: PerformanceScore.ScoreCategory.Rating) -> NSColor {
        switch rating {
        case .good: return .systemGreen
        case .needsImprovement: return .orange
        case .poor: return .red
        }
    }

    private static func ratingColor(_ rating: WebVitals.Metric.Rating) -> NSColor {
        switch rating {
        case .good: return .systemGreen
        case .needsImprovement: return .orange
        case .poor: return .red
        }
    }

    private static func impactNSColor(_ impact: OptimizationSuggestion.Impact) -> NSColor {
        switch impact {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .systemYellow
        case .low: return .blue
        }
    }

    private static func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }
}
