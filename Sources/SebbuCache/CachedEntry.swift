// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public protocol CachedEntry: Sendable {
    associatedtype Input: CacheIdentifiable & Codable & Sendable
    associatedtype Result: Sendable
    
    associatedtype Codec: ResultCodec where Codec.Value == Result
    
    static var namespace: String { get }
    
    /// Cache version.
    ///
    /// Increment when the meaning of the entry / computation changes.
    static var cacheVersion: Int { get }
    
    var input: Input { get }
}

public struct CacheDescriptor: Sendable {
    public let key: CacheKey
    public let canonicalIdentity: String
}

public extension CachedEntry {
    var cacheDescriptor: CacheDescriptor {
        var encoder = CacheIdentityEncoder()
        encoder.field("namespace", Self.namespace)
        encoder.field("version", Self.cacheVersion)
        encoder.field("input", input)
        
        let identity = encoder.identity
        
        return CacheDescriptor(
            key: CacheKey(
                namespace: Self.namespace,
                version: Self.cacheVersion,
                digest: PersistentCacheHash.digest(identity)
            ),
            canonicalIdentity: identity
        )
    }
}
