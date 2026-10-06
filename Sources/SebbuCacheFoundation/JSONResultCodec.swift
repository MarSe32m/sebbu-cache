// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SebbuCache

public enum JSONResultCodec<Value: Codable & Sendable>: ResultCodec {
    public static var fileExtension: String { "json" }
    
    public static func encode(_ value: Value) throws -> [UInt8] {
        Array(try JSONEncoder().encode(value))
    }
    
    public static func decode(_ bytes: [UInt8]) throws -> Value {
        try JSONDecoder().decode(Value.self, from: Data(bytes))
    }
}
