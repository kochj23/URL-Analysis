//
//  ScreenshotTimeline.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI
import WebKit

/// Represents a screenshot captured at a specific time
struct ScreenshotFrame: Identifiable {
    let id = UUID()
    let image: NSImage
    let timestamp: TimeInterval  // Seconds since page load started
    let caption: String
}

/// Manages screenshot capture timeline
@MainActor
class ScreenshotTimeline: ObservableObject {
    @Published var frames: [ScreenshotFrame] = []
    @Published var isCapturing = false

    private weak var webView: WKWebView?
    private var captureTask: Task<Void, Never>?
    private var sessionStart: Date?

    /// Start capturing screenshots at intervals
    func startCapture(webView: WKWebView, sessionStart: Date) {
        self.webView = webView
        self.sessionStart = sessionStart
        frames.removeAll()
        isCapturing = true

        // Capture at: 0s, 0.5s, 1s, 2s, 3s, 5s
        let intervals: [TimeInterval] = [0, 0.5, 1.0, 2.0, 3.0, 5.0]

        captureTask = Task {
            for interval in intervals {
                if Task.isCancelled { break }

                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                if Task.isCancelled { break }

                await captureScreenshot(at: interval)
            }

            isCapturing = false
        }
    }

    /// Stop capturing screenshots
    func stopCapture() {
        captureTask?.cancel()
        captureTask = nil
        isCapturing = false
    }

    /// Capture a single screenshot
    private func captureScreenshot(at interval: TimeInterval) async {
        guard let webView = webView else { return }

        // Use WKWebView's snapshot API
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(origin: .zero, size: webView.bounds.size)

        do {
            let snapshot = try await webView.takeSnapshot(configuration: config)

            let caption: String
            if interval == 0 {
                caption = "Start"
            } else if interval < 1 {
                caption = String(format: "%.1f s", interval)
            } else {
                caption = String(format: "%.0f s", interval)
            }

            let frame = ScreenshotFrame(
                image: snapshot,
                timestamp: interval,
                caption: caption
            )

            frames.append(frame)
        } catch {
            print("Failed to capture screenshot: \(error)")
        }
    }
}

/// Screenshot timeline view
struct ScreenshotTimelineView: View {
    @ObservedObject var timeline: ScreenshotTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Screenshot Timeline")
                    .font(.headline)

                Spacer()

                if timeline.isCapturing {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Capturing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            if timeline.frames.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No screenshots captured yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Load a page to see visual timeline")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(timeline.frames) { frame in
                            ScreenshotCard(frame: frame)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(height: 180)
    }
}

struct ScreenshotCard: View {
    let frame: ScreenshotFrame

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: frame.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 90)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Text(frame.caption)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
