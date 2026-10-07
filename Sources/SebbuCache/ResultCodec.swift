// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public protocol ResultCodec: Sendable {
    associatedtype Value: Sendable
    static func encode(_ value: Value) throws -> [UInt8]
    static func decode(_ bytes: [UInt8]) throws -> Value
}
