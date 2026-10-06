// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SebbuCache
import SebbuDeflate
import SebbuDeflateFoundation

public enum FileCacheStoreError: Error, Equatable, Sendable {
    case invalidResultFileExtension(String)
    case cacheKeyCollision(CacheKey)
}

public struct FileCacheStore: CacheStore {
    public static let metadataFormatVersion = 1
    public let rootDirectory: String
    
    public static var defaultRootDirectory: String {
        URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        .appending(path: ".sebbu-cache", directoryHint: .isDirectory)
        .path
    }

    public init(
        rootDirectory: String = Self.defaultRootDirectory
    ) {
        self.rootDirectory = rootDirectory
    }

    public func load<C: CachedEntry>(_ entry: C) throws -> C.Result? {
        let descriptor = entry.cacheDescriptor
        let paths = try paths(
            for: descriptor.key,
            resultFileExtension: C.Codec.fileExtension
        )
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: paths.metadata.path) else {
            return nil
        }

        let metadataData = try Data(contentsOf: paths.metadata)
        let metadata = try JSONDecoder().decode(
            CacheMetadata<C.Input>.self,
            from: metadataData
        )

        guard metadata.formatVersion == Self.metadataFormatVersion,
              metadata.namespace == C.namespace,
              metadata.calculationVersion == C.cacheVersion,
              metadata.key == descriptor.key,
              metadata.canonicalIdentity == descriptor.canonicalIdentity else {
            return nil
        }

        guard fileManager.fileExists(atPath: paths.result.path) else {
            return nil
        }

        let resultData = try Data(compressedContentsOf: paths.result)
        return try C.Codec.decode(Array(resultData))
    }

    public func store<C: CachedEntry>(_ result: C.Result, for entry: C) throws {
        let descriptor = entry.cacheDescriptor
        let paths = try paths(
            for: descriptor.key,
            resultFileExtension: C.Codec.fileExtension
        )
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: paths.metadata.path) {
            let data = try Data(contentsOf: paths.metadata)
            let header = try JSONDecoder().decode(
                CacheMetadataHeader.self,
                from: data
            )

            guard header.canonicalIdentity == descriptor.canonicalIdentity else {
                throw FileCacheStoreError.cacheKeyCollision(descriptor.key)
            }
        }

        try fileManager.createDirectory(
            at: paths.directory,
            withIntermediateDirectories: true
        )

        let resultData = Data(try C.Codec.encode(result))
        try resultData.writeCompressed(to: paths.result, options: .atomic)

        let metadata = CacheMetadata(
            formatVersion: Self.metadataFormatVersion,
            namespace: C.namespace,
            calculationVersion: C.cacheVersion,
            key: descriptor.key,
            canonicalIdentity: descriptor.canonicalIdentity,
            input: entry.input
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadataData = try encoder.encode(metadata)

        // Publish metadata last. An interrupted write therefore behaves as a cache miss.
        try metadataData.write(to: paths.metadata, options: .atomic)
    }

    private func paths(
        for key: CacheKey,
        resultFileExtension: String
    ) throws -> EntryPaths {
        guard isValidFileExtension(resultFileExtension) else {
            throw FileCacheStoreError.invalidResultFileExtension(
                resultFileExtension
            )
        }

        let root = URL(fileURLWithPath: rootDirectory, isDirectory: true)
        let namespace = PersistentCacheHash.digest(key.namespace)
        let prefix = String(key.digest.prefix(2))

        let directory = root
            .appendingPathComponent(namespace, isDirectory: true)
            .appendingPathComponent("v\(key.version)", isDirectory: true)
            .appendingPathComponent(prefix, isDirectory: true)
            .appendingPathComponent(key.digest, isDirectory: true)

        return EntryPaths(
            directory: directory,
            metadata: directory.appendingPathComponent(
                "metadata.json",
                isDirectory: false
            ),
            result: directory.appendingPathComponent(
                "result.\(resultFileExtension)",
                isDirectory: false
            )
        )
    }

    private func isValidFileExtension(_ fileExtension: String) -> Bool {
        guard !fileExtension.isEmpty,
              fileExtension != ".",
              fileExtension != ".." else {
            return false
        }

        return !fileExtension.contains("/") &&
               !fileExtension.contains("\\")
    }
}

private struct EntryPaths {
    let directory: URL
    let metadata: URL
    let result: URL
}

private struct CacheMetadataHeader: Decodable {
    let canonicalIdentity: String
}

private extension Data {
    func writeCompressed(to: URL, options: Data.WritingOptions) throws {
        var compressed = try DeflateCompressor.compress(format: .gzip, level: .best, bytes: self)
        compressed.append(contentsOf: repeatElement(0, count: MemoryLayout<Int>.size))
        do {
            var bytes = compressed.mutableBytes
            bytes.storeBytes(of: self.count, toByteOffset: bytes.byteCount - 8, as: Int.self)
        }
        try compressed.write(to: to, options: .atomic)
    }
    
    init(compressedContentsOf path: URL, options: Data.ReadingOptions = []) throws {
        let compressed = try Data(contentsOf: path, options: options)
        let dataSize: Int
        do {
            let bytes = compressed.bytes
            dataSize = bytes.load(fromByteOffset: compressed.count - 8, as: Int.self)
        }
        self = try DeflateDecompressor.decompress(format: .gzip, bytes: compressed, exactSize: dataSize)
    }
}
