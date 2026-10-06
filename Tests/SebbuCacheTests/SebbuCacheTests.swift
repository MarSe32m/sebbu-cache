// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

import Testing
@testable import SebbuCache

private struct IdentityValue: CacheIdentifiable, Codable, Equatable, Sendable {
    let value: Int

    func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder) {
        encoder.field("value", value)
    }
}

private enum StringCodec: ResultCodec {
    static let fileExtension = "txt"

    static func encode(_ value: String) throws -> [UInt8] {
        Array(value.utf8)
    }

    static func decode(_ bytes: [UInt8]) throws -> String {
        String(decoding: bytes, as: UTF8.self)
    }
}

private struct TestEntry: CachedEntry {
    static let namespace = "tests/entry"
    static let cacheVersion = 1
    typealias Codec = StringCodec

    let input: IdentityValue
}

private struct VersionedTestEntry: CachedEntry {
    static let namespace = "tests/entry"
    static let cacheVersion = 2
    typealias Codec = StringCodec

    let input: IdentityValue
}

private struct NamespacedTestEntry: CachedEntry {
    static let namespace = "tests/other-entry"
    static let cacheVersion = 1
    typealias Codec = StringCodec

    let input: IdentityValue
}

private final class MemoryCacheStore: CacheStore, @unchecked Sendable {
    private var values: [CacheKey: String] = [:]
    private(set) var storeCount = 0

    func load<C: CachedEntry>(_ entry: C) throws -> C.Result? {
        values[entry.cacheDescriptor.key] as? C.Result
    }

    func store<C: CachedEntry>(_ result: C.Result, for entry: C) throws {
        guard let string = result as? String else { return }
        values[entry.cacheDescriptor.key] = string
        storeCount += 1
    }
}

@Suite struct SebbuCacheTests {
    @Test
    func cacheIdentityEncoderHasStablePrimitiveRepresentation() {
        var encoder = CacheIdentityEncoder()
        encoder.field("flag", true)
        encoder.field("count", -7)
        encoder.field("name", "a|b")
        encoder.field("double", 1.5)
        encoder.field("float", Float(2.5))
        
        #expect(
            encoder.identity ==
            "4:flag=true|5:count=-7|4:name=3:a|b|6:double=3ff8000000000000|5:float=40200000"
        )
    }
    
    @Test
    func cacheIdentityEncoderPreservesExactFloatingPointIdentity() {
        var positiveZero = CacheIdentityEncoder()
        positiveZero.field("value", 0.0)
        
        var negativeZero = CacheIdentityEncoder()
        negativeZero.field("value", -0.0)
        
        #expect(positiveZero.identity != negativeZero.identity)
    }
    
    @Test
    func cacheIdentityEncoderDistinguishesNestedAndOptionalValues() {
        let nested = IdentityValue(value: 42)
        
        var someEncoder = CacheIdentityEncoder()
        someEncoder.field("nested", nested)
        someEncoder.optional("optional", nested)
        
        var noneEncoder = CacheIdentityEncoder()
        noneEncoder.field("nested", nested)
        noneEncoder.optional("optional", Optional<IdentityValue>.none)
        
        #expect(someEncoder.identity != noneEncoder.identity)
        #expect(someEncoder.identity.contains("being:6:nested"))
        #expect(someEncoder.identity.contains("8:optional=some"))
        #expect(noneEncoder.identity.contains("8:optional=none"))
    }
    
    @Test
    func cacheIdentityEncoderEncodesCacheIdentifiableArraysInOrder() {
        let first = [IdentityValue(value: 1), IdentityValue(value: 2)]
        let second = [IdentityValue(value: 2), IdentityValue(value: 1)]
        
        var firstEncoder = CacheIdentityEncoder()
        firstEncoder.field("values", first)
        
        var secondEncoder = CacheIdentityEncoder()
        secondEncoder.field("values", second)
        
        #expect(firstEncoder.identity != secondEncoder.identity)
    }
    
    @Test
    func doubleArrayIdentityDependsOnCountAndOrder() {
        var firstEncoder = CacheIdentityEncoder()
        [1.0, 2.0].encodeCacheIdentity(into: &firstEncoder)
        
        var secondEncoder = CacheIdentityEncoder()
        [2.0, 1.0].encodeCacheIdentity(into: &secondEncoder)
        
        var shorterEncoder = CacheIdentityEncoder()
        [1.0].encodeCacheIdentity(into: &shorterEncoder)
        
        #expect(firstEncoder.identity != secondEncoder.identity)
        #expect(firstEncoder.identity != shorterEncoder.identity)
    }
    
    @Test
    func integerArrayIdentityDependsOnCountAndOrder() {
        var firstEncoder = CacheIdentityEncoder()
        [1, 2].encodeCacheIdentity(into: &firstEncoder)
        
        var secondEncoder = CacheIdentityEncoder()
        [2, 1].encodeCacheIdentity(into: &secondEncoder)
        
        #expect(firstEncoder.identity != secondEncoder.identity)
    }
    
    @Test
    func persistentCacheHashHasStableGoldenValues() {
        #expect(
            PersistentCacheHash.digest("") ==
            "cbf29ce48422232584222325cbf29ce4"
        )
        #expect(
            PersistentCacheHash.digest("hello") ==
            "a430d84680aabd0bb488351e7eb8cbd4"
        )
        #expect(PersistentCacheHash.digest("hello").count == 32)
    }
    
    @Test
    func cachedEntryDescriptorIsDeterministic() {
        let entry = TestEntry(input: .init(value: 42))
        let first = entry.cacheDescriptor
        let second = entry.cacheDescriptor
        
        #expect(first.key == second.key)
        #expect(first.canonicalIdentity == second.canonicalIdentity)
        #expect(first.key.namespace == TestEntry.namespace)
        #expect(first.key.version == TestEntry.cacheVersion)
        #expect(first.key.digest == PersistentCacheHash.digest(first.canonicalIdentity))
    }
    
    @Test
    func cachedEntryDescriptorChangesWithInputNamespaceAndVersion() {
        let base = TestEntry(input: .init(value: 1)).cacheDescriptor
        let differentInput = TestEntry(input: .init(value: 2)).cacheDescriptor
        let differentVersion = VersionedTestEntry(input: .init(value: 1)).cacheDescriptor
        let differentNamespace = NamespacedTestEntry(input: .init(value: 1)).cacheDescriptor
        
        #expect(base.key != differentInput.key)
        #expect(base.key != differentVersion.key)
        #expect(base.key != differentNamespace.key)
        #expect(base.canonicalIdentity != differentInput.canonicalIdentity)
        #expect(base.canonicalIdentity != differentVersion.canonicalIdentity)
        #expect(base.canonicalIdentity != differentNamespace.canonicalIdentity)
    }
    
    @Test
    func cacheKeyContributesAllFieldsToIdentity() {
        let key = CacheKey(namespace: "example", version: 3, digest: "abcdef")
        var encoder = CacheIdentityEncoder()
        encoder.field("source", key)
        
        #expect(encoder.identity.contains("9:namespace=7:example"))
        #expect(encoder.identity.contains("7:version=3"))
        #expect(encoder.identity.contains("6:digest=6:abcdef"))
    }
    
    @Test
    func cacheMetadataPreservesProvenance() {
        let input = IdentityValue(value: 7)
        let key = CacheKey(namespace: "example", version: 2, digest: "deadbeef")
        let metadata = CacheMetadata(
            formatVersion: 1,
            namespace: "example",
            calculationVersion: 2,
            key: key,
            canonicalIdentity: "identity",
            input: input
        )
        
        #expect(metadata.formatVersion == 1)
        #expect(metadata.namespace == "example")
        #expect(metadata.calculationVersion == 2)
        #expect(metadata.key == key)
        #expect(metadata.canonicalIdentity == "identity")
        #expect(metadata.input == input)
    }
    
    @Test
    func cacheStoreValueStoresMissAndReusesHit() throws {
        let cache = MemoryCacheStore()
        let entry = TestEntry(input: .init(value: 9))
        var calculations = 0
        
        let first = try cache.value(for: entry) {
            calculations += 1
            return "computed"
        }
        
        let second = try cache.value(for: entry) {
            calculations += 1
            return "recomputed"
        }
        
        #expect(first == "computed")
        #expect(second == "computed")
        #expect(calculations == 1)
        #expect(cache.storeCount == 1)
    }
    
    @Test
    func cacheStoreSeparatesEntriesByDescriptor() throws {
        let cache = MemoryCacheStore()
        let first = TestEntry(input: .init(value: 1))
        let second = TestEntry(input: .init(value: 2))
        
        try cache.store("first", for: first)
        
        #expect(try cache.load(first) == "first")
        #expect(try cache.load(second) == nil)
    }
}
