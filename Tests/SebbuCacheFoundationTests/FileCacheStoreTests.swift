// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

import Testing
@testable import SebbuCache
@testable import SebbuCacheFoundation

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private struct TestInput: CacheIdentifiable, Codable, Sendable {
    let value: Int

    func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder) {
        encoder.field("value", value)
    }
}

private struct TestResult: Codable, Equatable, Sendable {
    let text: String
}

private struct TestEntry: CachedEntry {
    static let namespace = "tests/file-cache"
    static let cacheVersion = 1

    typealias Codec = JSONResultCodec<TestResult>

    let input: TestInput
}

private func temporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    return root
}

@Suite
struct FileCacheStoreTests {
    @Test
    func fileCacheStoreReturnsMissForAbsentEntry() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        
        let cache = FileCacheStore(rootDirectory: root.path)
        let entry = TestEntry(input: .init(value: 1))
        
        #expect(try cache.load(entry) == nil)
    }
    
    @Test
    func fileCacheStoreRoundTripsResult() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        
        let cache = FileCacheStore(rootDirectory: root.path)
        let entry = TestEntry(input: .init(value: 1))
        let result = TestResult(text: "cached")
        
        try cache.store(result, for: entry)
        
        #expect(try cache.load(entry) == result)
    }
    
    @Test
    func fileCacheStorePersistsAcrossInstances() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        
        let entry = TestEntry(input: .init(value: 42))
        let result = TestResult(text: "persistent")
        
        try FileCacheStore(rootDirectory: root.path()).store(result, for: entry)
        
        let reloaded = try FileCacheStore(rootDirectory: root.path).load(entry)
        #expect(reloaded == result)
    }
    
    @Test
    func fileCacheStoreSeparatesDifferentInputs() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        
        let cache = FileCacheStore(rootDirectory: root.path)
        let first = TestEntry(input: .init(value: 1))
        let second = TestEntry(input: .init(value: 2))
        
        try cache.store(.init(text: "first"), for: first)
        
        #expect(try cache.load(first) == .init(text: "first"))
        #expect(try cache.load(second) == nil)
    }
    
    @Test
    func fileCacheStoreValueAvoidsRecomputation() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        
        let cache = FileCacheStore(rootDirectory: root.path)
        let entry = TestEntry(input: .init(value: 7))
        var calculations = 0
        
        let first = try cache.value(for: entry) {
            calculations += 1
            return TestResult(text: "computed")
        }
        
        let second = try cache.value(for: entry) {
            calculations += 1
            return TestResult(text: "recomputed")
        }
        
        #expect(first == .init(text: "computed"))
        #expect(second == first)
        #expect(calculations == 1)
    }
}
