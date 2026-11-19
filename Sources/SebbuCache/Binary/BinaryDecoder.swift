// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public struct BinaryDecoder: Sendable {
    @usableFromInline
    internal let bytes: [UInt8]
    @usableFromInline
    internal var offset: Int
    @usableFromInline
    internal let maximumCollectionCount: Int

    /// The optional limit applies to array elements and length-prefixed byte strings.
    @inlinable
    public init(bytes: [UInt8], maximumCollectionCount: Int = .max) throws {
        guard maximumCollectionCount >= 0 else {
            throw BinaryDecodingError.invalidLength
        }
        guard bytes.count >= BinaryWireFormat.header.count else {
            throw BinaryDecodingError.unexpectedEndOfData
        }
        guard bytes.starts(with: BinaryWireFormat.magic) else {
            throw BinaryDecodingError.invalidHeader
        }
        self.bytes = bytes
        self.maximumCollectionCount = maximumCollectionCount
        offset = BinaryWireFormat.magic.count
        let version: UInt16 = try readWord()
        guard version == BinaryWireFormat.version else {
            throw BinaryDecodingError.unsupportedVersion(version)
        }
        let flags: UInt16 = try readWord()
        guard flags == 0 else {
            throw BinaryDecodingError.unsupportedFlags(flags)
        }
    }

    @inlinable
    internal mutating func take(_ count: Int) throws -> Range<Int> {
        guard count >= 0 else { throw BinaryDecodingError.invalidLength }
        guard count <= bytes.count - offset else { throw BinaryDecodingError.unexpectedEndOfData }
        let start = offset
        offset += count
        return start..<offset
    }

    @inlinable
    internal mutating func readWord<W: FixedWidthInteger & ConvertibleFromBytes>() throws -> W {
        let start = try take(W.bitWidth / 8).lowerBound
        return W(littleEndian: bytes.span.bytes.load(fromByteOffset: start, as: W.self))
    }

    // Host-sized integers have a 64-bit wire word, even when the destination is narrower.
    @inlinable
    internal mutating func readMachineInteger<T: FixedWidthInteger, Word: FixedWidthInteger & ConvertibleFromBytes>(
        from wire: Word.Type
    ) throws -> T {
        let value: Word = try readWord()
        guard let result = T(exactly: value) else { throw BinaryDecodingError.integerOutOfRange }
        return result
    }

    @inlinable
    public mutating func read<T: FixedWidthInteger>() throws -> T {
        if T.self == Int.self { return try readMachineInteger(from: Int64.self) }
        if T.self == UInt.self { return try readMachineInteger(from: UInt64.self) }
        let width = BinaryWireFormat.integerWidth(T.self)
        switch width {
        case 1: return T(truncatingIfNeeded: try readWord() as UInt8)
        case 2: return T(truncatingIfNeeded: try readWord() as UInt16)
        case 4: return T(truncatingIfNeeded: try readWord() as UInt32)
        case 8: return T(truncatingIfNeeded: try readWord() as UInt64)
        case 16: return T(truncatingIfNeeded: try readWord() as UInt128)
        default:
            let range = try take(width)
            var value: T = 0
            for (i, byte) in bytes[range].enumerated() {
                value |= T(truncatingIfNeeded: byte) << (i * 8)
            }
            return value
        }
    }

    @inlinable
    public mutating func read() throws -> Bool {
        let byte: UInt8 = try readWord()
        switch byte {
        case 0: return false
        case 1: return true
        default: throw BinaryDecodingError.invalidBoolean(byte)
        }
    }

    @inlinable
    public mutating func read() throws -> Double {
        Double(bitPattern: try readWord())
    }
    
    @inlinable
    public mutating func read() throws -> Float {
        Float(bitPattern: try readWord())
    }

    @inlinable
    public mutating func read<T: RawRepresentable>() throws -> T where T.RawValue: FixedWidthInteger {
        guard let value = T(rawValue: try read()) else { throw BinaryDecodingError.invalidEnumeration }
        return value
    }

    @inlinable
    public mutating func read() throws -> String {
        guard let value = String(validating: try readLengthPrefixedBytes(), as: UTF8.self) else {
            throw BinaryDecodingError.invalidUTF8
        }
        return value
    }

    @_disfavoredOverload
    @inlinable
    public mutating func read<T: BinaryDecodable>() throws -> T {
        try T(from: &self)
    }

    @inlinable
    mutating func readCount() throws -> Int {
        let encoded: UInt64 = try readWord()
        guard let count = Int(exactly: encoded), count <= maximumCollectionCount else {
            throw BinaryDecodingError.invalidLength
        }
        return count
    }

    @inlinable
    package mutating func readLengthPrefixedBytes() throws -> ArraySlice<UInt8> {
        let count = try readCount()
        let range = try take(count)
        return bytes[range]
    }

    @inlinable
    public mutating func readArray() throws -> [Bool] {
        let count = try readCount()
        return try readElements(count: count, width: 1, copyNative: false) { try $0.read() }
    }

    
    @inlinable
    public mutating func readArray<T: FixedWidthInteger>() throws -> [T] {
        let count = try readCount()
        return try readElements(
            count: count, width: BinaryWireFormat.integerWidth(T.self),
            copyNative: BinaryWireFormat.canCopyInteger(T.self)
        ) { try $0.read() }
    }

    @inlinable
    public mutating func readArray<T: RawRepresentable>() throws -> [T] where T.RawValue: FixedWidthInteger {
        let count = try readCount()
        return try readElements(
            count: count, width: BinaryWireFormat.integerWidth(T.RawValue.self),
            copyNative: false
        ) { try $0.read() }
    }

    /// A schema-specific bound is required because a custom value can occupy zero wire bytes.
    /// Grow only as values decode, never reserve storage from this prefix alone.
    @inlinable
    public mutating func readArray<T: BinaryDecodable>(maximumCount: Int) throws -> [T] {
        let count = try readCount()
        guard count <= maximumCount, !count.multipliedReportingOverflow(by: MemoryLayout<T>.stride).overflow else {
            throw BinaryDecodingError.invalidLength
        }
        var result: [T] = []
        for _ in 0..<count { result.append(try T(from: &self)) }
        return result
    }

    @inlinable
    mutating func readElements<T>(
        count: Int, width: Int, copyNative: Bool, decode: (inout Self) throws -> T
    ) throws -> [T] {
        guard count >= 0, count <= maximumCollectionCount else { throw BinaryDecodingError.invalidLength }
        let (size, overflow) = count.multipliedReportingOverflow(by: width)
        guard !overflow, !count.multipliedReportingOverflow(by: MemoryLayout<T>.stride).overflow else {
            throw BinaryDecodingError.invalidLength
        }
        guard size <= bytes.count - offset else { throw BinaryDecodingError.unexpectedEndOfData }
        if copyNative {
            let range = try take(size)
            // Destination is aligned typed storage. The source need only be byte-aligned.
            return Array(unsafeUninitializedCapacity: count) { output, initializedCount in
                if count > 0 {
                    bytes.withUnsafeBytes { raw in
                        UnsafeMutableRawBufferPointer(output).copyMemory(
                            from: UnsafeRawBufferPointer(rebasing: raw[range]))
                    }
                }
                initializedCount = count
            }
        }
        return try Array(capacity: count) { output in
            for _ in 0..<count { output.append(try decode(&self)) }
        }
    }

    @inlinable
    public func validateEndOfData() throws {
        guard offset == bytes.count else { throw BinaryDecodingError.trailingData }
    }
}
