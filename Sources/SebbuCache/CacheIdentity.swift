// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public protocol CacheIdentifiable: Sendable {
    func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder)
}

public struct CacheIdentityEncoder: Sendable {
    private var fields: [String] = []
    
    public var identity: String {
        fields.joined(separator: "|")
    }
    
    public init() {}
    
    public mutating func field(_ name: String, _ value: Bool) {
        append(name: name, value: value ? "true" : "false")
    }
    
    public mutating func field<T: BinaryInteger>(_ name: String, _ value: T) {
        append(name: name, value: String(value))
    }
    
    public mutating func field(_ name: String, _ value: String) {
        // We length prefix here to avoid ambiguity if the value contains separators etc.
        append(name: name, value: "\(value.utf8.count):\(value)")
    }
    
    public mutating func field(_ name: String, _ value: Double) {
        append(name: name, value: String(value.bitPattern, radix: 16))
    }
    
    public mutating func field(_ name: String, _ value: Float) {
        append(name: name, value: String(value.bitPattern, radix: 16))
    }
    
    public mutating func field<T: CacheIdentifiable>(
        _ name: String, _ value: T
    ) {
        fields.append("being:\(name.utf8.count):\(name)")
        value.encodeCacheIdentity(into: &self)
        fields.append("end:\(name.utf8.count):\(name)")
    }
    
    public mutating func optional<T: CacheIdentifiable>(
        _ name: String, _ value: T?
    ) {
        switch value {
            case .none:
                append(name: name, value: "none")
            case .some(let value):
                append(name: name, value: "some")
                field(name, value)
        }
    }
    
    private mutating func append(name: String, value: String) {
        fields.append("\(name.utf8.count):\(name)=\(value)")
    }
}

extension Array: CacheIdentifiable where Element: CacheIdentifiable & Sendable {
    public func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder) {
        encoder.field("count", self.count)
        for (index, element) in enumerated() {
            encoder.field("\(index)", element)
        }
    }
}

public extension Array<Double> {
    func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder) {
        encoder.field("count", self.count)
        for (index, element) in enumerated() {
            encoder.field("\(index)", element)
        }
    }
}

public extension Array<BinaryInteger> {
    func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder) {
        encoder.field("count", self.count)
        for (index, element) in enumerated() {
            encoder.field("\(index)", element)
        }
    }
}
