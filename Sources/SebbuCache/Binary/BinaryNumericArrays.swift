// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

import ComplexModule
import RealModule

public extension BinaryEncoder {
    @inlinable
    mutating func append(_ value: Complex<Float>) {
        let (real, imaginary) = value.rawStorage
        append(real)
        append(imaginary)
    }

    @inlinable
    mutating func append(_ value: Complex<Double>) {
        let (real, imaginary) = value.rawStorage
        append(real)
        append(imaginary)
    }

    @inlinable
    mutating func append(_ values: [Float]) {
        append(UInt64(values.count))
        appendPayload(values)
    }

    /// Writes only the elements, for schemas that already encode the shape.
    @inlinable
    mutating func appendPayload(_ values: [Float]) {
        appendElements(values, copyNative: BinaryWireFormat.canCopyFloat) { $0.append($1) }
    }

    @inlinable
    mutating func append(_ values: [Double]) {
        append(UInt64(values.count))
        appendPayload(values)
    }

    /// Writes only the elements, for schemas that already encode the shape.
    @inlinable
    mutating func appendPayload(_ values: [Double]) {
        appendElements(values, copyNative: BinaryWireFormat.canCopyDouble) { $0.append($1) }
    }

    @inlinable
    mutating func append(_ values: [Complex<Float>]) {
        append(UInt64(values.count))
        appendPayload(values)
    }

    /// Writes only the elements, for schemas that already encode the shape.
    @inlinable
    mutating func appendPayload(_ values: [Complex<Float>]) {
        appendElements(values, copyNative: BinaryWireFormat.canCopyComplexFloat) { $0.append($1) }
    }

    @inlinable
    mutating func append(_ values: [Complex<Double>]) {
        append(UInt64(values.count))
        appendPayload(values)
    }

    /// Writes only the elements, for schemas that already encode the shape.
    @inlinable
    mutating func appendPayload(_ values: [Complex<Double>]) {
        appendElements(values, copyNative: BinaryWireFormat.canCopyComplexDouble) { $0.append($1) }
    }
}

public extension BinaryDecoder {
    @inlinable
    mutating func read() throws -> Complex<Float> {
        let real: Float = try read()
        return Complex(real, try read())
    }

    @inlinable
    mutating func read() throws -> Complex<Double> {
        let real: Double = try read()
        return Complex(real, try read())
    }

    @inlinable
    mutating func readArray() throws -> [Float] {
        try readArray(count: readCount())
    }

    /// Reads exactly `count` elements without consuming an array length prefix.
    @inlinable
    mutating func readArray(count: Int) throws -> [Float] {
        try readElements(count: count, width: 4, copyNative: BinaryWireFormat.canCopyFloat) { try $0.read() }
    }

    @inlinable
    mutating func readArray() throws -> [Double] {
        try readArray(count: readCount())
    }

    /// Reads exactly `count` elements without consuming an array length prefix.
    @inlinable
    mutating func readArray(count: Int) throws -> [Double] {
        try readElements(count: count, width: 8, copyNative: BinaryWireFormat.canCopyDouble) { try $0.read() }
    }

    @inlinable
    mutating func readArray() throws -> [Complex<Float>] {
        try readArray(count: readCount())
    }

    /// Reads exactly `count` elements without consuming an array length prefix.
    @inlinable
    mutating func readArray(count: Int) throws -> [Complex<Float>] {
        try readElements(count: count, width: 8, copyNative: BinaryWireFormat.canCopyComplexFloat) { try $0.read() }
    }

    @inlinable
    mutating func readArray() throws -> [Complex<Double>] {
        try readArray(count: readCount())
    }

    /// Reads exactly `count` elements without consuming an array length prefix.
    @inlinable
    mutating func readArray(count: Int) throws -> [Complex<Double>] {
        try readElements(count: count, width: 16, copyNative: BinaryWireFormat.canCopyComplexDouble) { try $0.read() }
    }
}
