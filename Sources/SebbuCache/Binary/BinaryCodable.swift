// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public protocol BinaryEncodable: Sendable {
    func encode(into encoder: inout BinaryEncoder) throws
}

public protocol BinaryDecodable: Sendable {
    init(from decoder: inout BinaryDecoder) throws
}

public typealias BinaryCodable = BinaryEncodable & BinaryDecodable

public enum BinaryDecodingError: Error, Equatable, Sendable {
    case invalidHeader
    case unsupportedVersion(UInt16)
    case unsupportedFlags(UInt16)
    case unexpectedEndOfData
    case invalidBoolean(UInt8)
    case invalidUTF8
    case invalidEnumeration
    case invalidLength
    case integerOutOfRange
    case trailingData
}
