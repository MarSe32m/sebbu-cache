// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public enum BinaryResultCodec<Value: BinaryCodable & Sendable>: ResultCodec {
    @inlinable
    public static func encode(_ value: Value) throws -> [UInt8] {
        var encoder = BinaryEncoder()
        try value.encode(into: &encoder)
        return encoder.packBytes()
    }

    @inlinable
    public static func decode(_ bytes: [UInt8]) throws -> Value {
        var decoder = try BinaryDecoder(bytes: bytes)
        let value = try Value(from: &decoder)
        try decoder.validateEndOfData()
        return value
    }
}
