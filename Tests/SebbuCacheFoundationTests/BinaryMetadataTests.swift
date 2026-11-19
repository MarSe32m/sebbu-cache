// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

import Foundation
import SebbuCacheFoundation
import Testing

private struct Metadata: Codable, Equatable, Sendable {
    let labels: [String: Int]
    let name: String
}

private struct FramedResult: BinaryCodable {
    let metadata: Metadata
    let samples: [Double]

    init(metadata: Metadata, samples: [Double]) {
        self.metadata = metadata
        self.samples = samples
    }
    init(from decoder: inout BinaryDecoder) throws {
        metadata = try decoder.readCodable()
        samples = try decoder.readArray()
    }
    func encode(into encoder: inout BinaryEncoder) throws {
        try encoder.appendCodable(metadata)
        encoder.append(samples)
    }
}

private struct BinaryEntry: CachedEntry {
    struct Input: Codable, CacheIdentifiable {
        let id: Int
        func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder) { encoder.field("id", id) }
    }
    static let namespace = "tests/binary-file-cache"
    static let cacheVersion = 1
    typealias Codec = BinaryResultCodec<FramedResult>
    let input: Input
}

@Suite
struct BinaryMetadataTests {
    @Test func gzipStoreRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileCacheStore(rootDirectory: root.path)
        let entry = BinaryEntry(input: .init(id: 2))
        let value = FramedResult(
            metadata: Metadata(labels: ["cav": 1], name: "LP"),
            samples: [-0.0, .infinity, Double(bitPattern: 0x7ff8_0000_0000_0123)])
        try store.store(value, for: entry)
        let stored = try store.load(entry)
        let read = try #require(stored)
        #expect(read.metadata == value.metadata)
        #expect(read.samples.map(\.bitPattern) == value.samples.map(\.bitPattern))
    }

    @Test func sortedKeysAndFraming() throws {
        let x = FramedResult(metadata: Metadata(labels: ["z": 1, "a": 2], name: "A/B"), samples: [-0.0, .nan])
        let y = FramedResult(metadata: Metadata(labels: ["a": 2, "z": 1], name: "A/B"), samples: x.samples)
        let encoded = try BinaryResultCodec.encode(x)
        #expect(try BinaryResultCodec.encode(y) == encoded)
        let json = Array(#"{"labels":{"a":2,"z":1},"name":"A/B"}"#.utf8)
        #expect(encoded[8..<16].elementsEqual([UInt8(json.count), 0, 0, 0, 0, 0, 0, 0]))
        #expect(encoded[16..<16 + json.count].elementsEqual(json))
        let decoded = try BinaryResultCodec<FramedResult>.decode(encoded)
        #expect(decoded.metadata == x.metadata)
        #expect(decoded.samples.map(\.bitPattern) == x.samples.map(\.bitPattern))
    }

    @Test func invalidMetadata() throws {
        var e = BinaryEncoder()
        e.append([UInt8]("{}".utf8))
        #expect(throws: DecodingError.self) {
            var d = try BinaryDecoder(bytes: e.packBytes())
            _ = try d.readCodable() as Metadata
        }
        #expect(throws: BinaryDecodingError.unexpectedEndOfData) {
            var d = try BinaryDecoder(bytes: Array(e.packBytes().dropLast()))
            _ = try d.readCodable() as Metadata
        }
        #expect(throws: EncodingError.self) {
            var encoder = BinaryEncoder()
            try encoder.appendCodable(Double.nan)
        }
    }
}
