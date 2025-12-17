//
//  HARFormat.swift
//  URL Analysis
//
//  Created by Jordan Koch on 2025-12-17.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//
//  HAR (HTTP Archive) format structures - v1.2 specification
//  Reference: http://www.softwareishard.com/blog/har-12-spec/
//

import Foundation

struct HARFile: Codable {
    let log: HARLog
}

struct HARLog: Codable {
    let version: String
    let creator: HARCreator
    let pages: [HARPage]
    let entries: [HAREntry]
}

struct HARCreator: Codable {
    let name: String
    let version: String
}

struct HARPage: Codable {
    let startedDateTime: Date
    let id: String
    let title: String
    let pageTimings: HARPageTimings
}

struct HARPageTimings: Codable {
    let onContentLoad: TimeInterval
    let onLoad: TimeInterval
}

struct HAREntry: Codable {
    let startedDateTime: Date
    let time: TimeInterval
    let request: HARRequest
    let response: HARResponse
    let cache: HARCache
    let timings: HARTimings
    let pageref: String
}

struct HARRequest: Codable {
    let method: String
    let url: String
    let httpVersion: String
    let headers: [HARHeader]
    let queryString: [HARQueryString]
    let headersSize: Int64
    let bodySize: Int64
}

struct HARResponse: Codable {
    let status: Int
    let statusText: String
    let httpVersion: String
    let headers: [HARHeader]
    let content: HARContent
    let redirectURL: String
    let headersSize: Int64
    let bodySize: Int64
}

struct HARHeader: Codable {
    let name: String
    let value: String
}

struct HARQueryString: Codable {
    let name: String
    let value: String
}

struct HARContent: Codable {
    let size: Int64
    let mimeType: String
}

struct HARCache: Codable {
    // Empty for now, but required by HAR spec
}

struct HARTimings: Codable {
    let blocked: TimeInterval
    let dns: TimeInterval
    let connect: TimeInterval
    let ssl: TimeInterval
    let send: TimeInterval
    let wait: TimeInterval
    let receive: TimeInterval
}
