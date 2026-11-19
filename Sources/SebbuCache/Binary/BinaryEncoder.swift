// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public struct BinaryEncoder: Sendable {
    @usableFromInline
    internal var bytes: [UInt8]

    @inlinable
    public init() {
        bytes = Array(repeating: 0, count: BinaryWireFormat.header.count)
    }

    @inlinable
    public mutating func append(_ value: Bool) {
        bytes.append(value ? 1 : 0)
    }

    @inlinable
    public mutating func append<T: FixedWidthInteger>(_ value: T) {
        // Conversion selects the on-disk word, independently of T's object representation.
        switch BinaryWireFormat.integerWidth(T.self) {
        case 1: bytes.append(UInt8(truncatingIfNeeded: value))
        case 2: appendWord(UInt16(truncatingIfNeeded: value))
        case 4: appendWord(UInt32(truncatingIfNeeded: value))
        case 8: appendWord(UInt64(truncatingIfNeeded: value))
        case 16: appendWord(UInt128(truncatingIfNeeded: value))
        default:
            for i in 0..<BinaryWireFormat.integerWidth(T.self) {
                bytes.append(UInt8(truncatingIfNeeded: value >> (i * 8)))
            }
        }
    }

    @inlinable
    internal mutating func appendWord<W: FixedWidthInteger & BitwiseCopyable>(_ value: W) {
        withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
    }

    @inlinable
    public mutating func append<T: RawRepresentable>(_ value: T) where T.RawValue: FixedWidthInteger {
        append(value.rawValue)
    }

    @inlinable
    public mutating func append(_ value: Double) {
        appendWord(value.bitPattern)
    }
    
    @inlinable
    public mutating func append(_ value: Float) {
        appendWord(value.bitPattern)
    }

    @inlinable
    public mutating func append(_ value: String) {
        appendLengthPrefixedBytes(value.utf8)
    }

    @inlinable
    package mutating func appendLengthPrefixedBytes<C: Collection>(_ source: C) where C.Element == UInt8 {
        append(UInt64(source.count))
        bytes.append(contentsOf: source)
    }

    // Prefer the wire overload when e.g. an integer-backed enum is also BinaryEncodable.
    @_disfavoredOverload
    @inlinable
    public mutating func append<T: BinaryEncodable>(_ value: T) throws {
        try value.encode(into: &self)
    }

    @inlinable
    public mutating func append(_ values: [Bool]) {
        append(UInt64(values.count))
        bytes.append(addingCapacity: values.count) { output in
            for value in values { output.append(value ? 1 : 0) }
        }
    }

    @inlinable
    public mutating func append<T: FixedWidthInteger>(_ values: [T]) {
        append(UInt64(values.count))
        appendElements(values, copyNative: BinaryWireFormat.canCopyInteger(T.self)) { $0.append($1) }
    }

    @inlinable
    public mutating func append<T: RawRepresentable>(_ values: [T]) where T.RawValue: FixedWidthInteger {
        append(UInt64(values.count))
        for value in values { append(value.rawValue) }
    }

    @_disfavoredOverload
    @inlinable
    public mutating func append<T: BinaryEncodable>(_ values: [T]) throws {
        append(UInt64(values.count))
        for value in values { try value.encode(into: &self) }
    }

    // Only called with copyNative == true for verified trivial representations.
    // Array.append(contentsOf:) receives a contiguous, exactly sized byte collection.
    @inlinable
    mutating func appendElements<T>(
        _ values: [T], copyNative: Bool, encode: (inout Self, T) -> Void
    ) {
        if copyNative {
            values.withUnsafeBufferPointer { bytes.append(contentsOf: UnsafeRawBufferPointer($0)) }
        } else {
            for value in values { encode(&self, value) }
        }
    }

    @inlinable
    public consuming func packBytes() -> [UInt8] {
        bytes.replaceSubrange(0..<BinaryWireFormat.header.count, with: BinaryWireFormat.header)
        return bytes
    }
}
