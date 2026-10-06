// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public struct CacheMetadata<Input: Codable>: Codable, Sendable where Input: Sendable {
    public let formatVersion: Int
    public let namespace: String
    public let calculationVersion: Int
    public let key: CacheKey
    public let canonicalIdentity: String
    public let input: Input
    
    public init(
        formatVersion: Int,
        namespace: String,
        calculationVersion: Int,
        key: CacheKey,
        canonicalIdentity: String,
        input: Input
    ) {
        self.formatVersion = formatVersion
        self.namespace = namespace
        self.calculationVersion = calculationVersion
        self.key = key
        self.canonicalIdentity = canonicalIdentity
        self.input = input
    }
}
