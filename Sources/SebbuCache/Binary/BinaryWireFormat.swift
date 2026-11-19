// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

import ComplexModule
import RealModule

@usableFromInline
enum BinaryWireFormat {
    @usableFromInline
    static let magic = Array("SBCB".utf8)
    
    @usableFromInline
    static let version: UInt16 = 1
    
    @usableFromInline
    static let header = magic + [UInt8(truncatingIfNeeded: version), UInt8(version >> 8), 0, 0]

    @inlinable
    static func integerWidth<T: FixedWidthInteger>(_ type: T.Type) -> Int {
        if type == Int.self || type == UInt.self { return 8 }
        return T.bitWidth / 8 + (T.bitWidth.isMultiple(of: 8) ? 0 : 1)
    }

    @inlinable
    static func packedLittleEndian<T>(_ type: T.Type, width: Int) -> Bool {
        #if _endian(little)
        return MemoryLayout<T>.size == width && MemoryLayout<T>.stride == width
        #else
        return false
        #endif
    }

    // FixedWidthInteger permits user-defined storage, including nontrivial fields.
    @inlinable
    static func canCopyInteger<T: FixedWidthInteger>(_ type: T.Type) -> Bool {
        let standard =
            type == Int8.self || type == UInt8.self
            || type == Int16.self || type == UInt16.self
            || type == Int32.self || type == UInt32.self
            || type == Int64.self || type == UInt64.self
            || type == Int128.self || type == UInt128.self
            || type == Int.self || type == UInt.self
        return standard && packedLittleEndian(type, width: integerWidth(type))
    }

    @usableFromInline
    static let canCopyFloat = packedLittleEndian(Float.self, width: 4)
    
    @usableFromInline
    static let canCopyDouble = packedLittleEndian(Double.self, width: 8)

    @usableFromInline
    static let canCopyComplexFloat = checkComplexLayout(
        Complex(Float(bitPattern: 0x3f12_3456), Float(bitPattern: 0xc065_4321)),
        component: Float.self, width: 4, real: UInt32(0x3f12_3456), imaginary: 0xc065_4321
    )
    
    @usableFromInline
    static let canCopyComplexDouble = checkComplexLayout(
        Complex(Double(bitPattern: 0x3ff1_2345_6789_abcd), Double(bitPattern: 0xc001_fedc_ba98_7654)),
        component: Double.self, width: 8, real: UInt64(0x3ff1_2345_6789_abcd), imaginary: 0xc001_fedc_ba98_7654
    )

    // Swift Numerics 1.x's @frozen Complex stores two scalar fields. Check the
    // actual specialization's packing, alignment, component order and byte order
    // before treating an array of those trivial values as an interleaved buffer.
    @inlinable
    internal static func checkComplexLayout<Element, Component, Word: FixedWidthInteger & BitwiseCopyable>(
        _ sample: Element, component: Component.Type, width: Int, real: Word, imaginary: Word
    ) -> Bool {
        guard packedLittleEndian(Component.self, width: width),
            packedLittleEndian(Element.self, width: 2 * width),
            MemoryLayout<Element>.alignment == MemoryLayout<Component>.alignment
        else { return false }
        return withUnsafeBytes(of: sample) { bytes in
            bytes.loadUnaligned(as: Word.self) == real
                && bytes.loadUnaligned(fromByteOffset: width, as: Word.self) == imaginary
        }
    }
}
