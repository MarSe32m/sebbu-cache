// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public struct CacheKey: Hashable, Codable, Sendable {
    public let namespace: String
    public let version: Int
    public let digest: String
    
    public init(namespace: String, version: Int, digest: String) {
        self.namespace = namespace
        self.version = version
        self.digest = digest
    }
}

extension CacheKey: CacheIdentifiable {
    public func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder) {
        encoder.field("namespace", namespace)
        encoder.field("version", version)
        encoder.field("digest", digest)
    }
}
