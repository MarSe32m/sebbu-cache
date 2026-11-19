// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

import SebbuCache

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public extension BinaryEncoder {
    /// Embed small metadata. For reproducible output, encode unordered collections in a stable order.
    @inlinable
    mutating func appendCodable<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        appendLengthPrefixedBytes(try encoder.encode(value))
    }
}

public extension BinaryDecoder {
    @inlinable
    mutating func readCodable<T: Decodable>() throws -> T {
        try JSONDecoder().decode(T.self, from: Data(try readLengthPrefixedBytes()))
    }
}
