// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

import ComplexModule
import RealModule
import Testing

@testable import SebbuCache

private let header: [UInt8] = [0x53, 0x42, 0x43, 0x42, 1, 0, 0, 0]
private enum State: Int16 {
    case ready = -2
    case done = 0x1234
}

private struct Sample: BinaryCodable, Equatable {
    let number: Int
    let label: String
    init(_ n: Int, _ s: String) {
        number = n
        label = s
    }
    init(from decoder: inout BinaryDecoder) throws {
        number = try decoder.read()
        label = try decoder.read()
    }
    func encode(into encoder: inout BinaryEncoder) {
        encoder.append(number)
        encoder.append(label)
    }
}

private struct Empty: BinaryCodable {
    init() {}
    init(from decoder: inout BinaryDecoder) {}
    func encode(into encoder: inout BinaryEncoder) {}
}

private enum TestError: Error, Equatable {
    case stop
}

private enum AlsoBinary: UInt8, BinaryCodable {
    case on = 0xad
    init(from decoder: inout BinaryDecoder) throws { throw TestError.stop }
    func encode(into encoder: inout BinaryEncoder) throws { throw TestError.stop }
}

private struct Failing: BinaryCodable {
    init() {}
    init(from decoder: inout BinaryDecoder) throws {
        throw TestError.stop
    }
    
    func encode(into encoder: inout BinaryEncoder) throws {
        throw TestError.stop
    }
}

private func checkInteger<T: FixedWidthInteger>(_ type: T.Type) throws {
    let extremes: [T] = [.min, 0, 1, .max]
    var e = BinaryEncoder()
    for n in extremes { e.append(n) }
    for values in [[], [.max], extremes] as [[T]] { e.append(values) }
    var d = try BinaryDecoder(bytes: e.packBytes())
    for n in extremes {
        let read: T = try d.read()
        #expect(read == n)
    }
    for values in [[], [.max], extremes] as [[T]] {
        let read: [T] = try d.readArray()
        #expect(read == values)
    }
    try d.validateEndOfData()
}

@Suite
struct BinaryResultCodecTests {
    @Test
    func integers() throws {
        try checkInteger(Int8.self)
        try checkInteger(UInt8.self)
        try checkInteger(Int16.self)
        try checkInteger(UInt16.self)
        try checkInteger(Int32.self)
        try checkInteger(UInt32.self)
        try checkInteger(Int64.self)
        try checkInteger(UInt64.self)
        try checkInteger(Int128.self)
        try checkInteger(UInt128.self)
        try checkInteger(Int.self)
        try checkInteger(UInt.self)
    }

    @Test
    func byteFixtureAndUnalignedFields() throws {
        var e = BinaryEncoder()
        e.append(false)
        e.append(true)
        e.append(Int8(-3))
        e.append(Int32(-2))
        e.append(UInt16(0x1234))
        e.append(Int(-2))
        e.append(UInt(0x0102))
        e.append(State.ready)
        e.append([State.done, .ready])
        e.append(Float(-0.0))
        e.append(Double(1))
        e.append("λ")
        e.append([true, false, true])
        e.append([Float(1), Float(-2)])
        
        var fixture = header
        fixture += [0, 1, 0xfd, 0xfe, 0xff, 0xff, 0xff, 0x34, 0x12]
        fixture += [0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 2, 1, 0, 0, 0, 0, 0, 0]
        fixture += [0xfe, 0xff, 2, 0, 0, 0, 0, 0, 0, 0, 0x34, 0x12, 0xfe, 0xff]
        fixture += [0, 0, 0, 0x80, 0, 0, 0, 0, 0, 0, 0xf0, 0x3f]
        fixture += [2, 0, 0, 0, 0, 0, 0, 0, 0xce, 0xbb, 3, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1]
        fixture += [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x80, 0x3f, 0, 0, 0, 0xc0]
        #expect(e.packBytes() == fixture)
        
        var d = try BinaryDecoder(bytes: fixture)
        let booleans: [Bool] = [try d.read(), try d.read()]
        #expect(booleans == [false, true])
        #expect(try d.read() as Int8 == -3)
        #expect(try d.read() as Int32 == -2)
        #expect(try d.read() as UInt16 == 0x1234)
        #expect(try d.read() as Int == -2)
        #expect(try d.read() as UInt == 0x0102)
        #expect(try d.read() as State == .ready)
        #expect(try d.readArray() as [State] == [.done, .ready])
        #expect((try d.read() as Float).bitPattern == 0x8000_0000)
        #expect((try d.read() as Double).bitPattern == 0x3ff0_0000_0000_0000)
        #expect(try d.read() as String == "λ")
        #expect(try d.readArray() as [Bool] == [true, false, true])
        #expect((try d.readArray() as [Float]).map(\.bitPattern) == [0x3f80_0000, 0xc000_0000])
        try d.validateEndOfData()
    }

    @Test
    func stringsAndNestedValues() throws {
        let strings = ["", "a\0b", "e\u{301}", "ää / 🧑🏽‍🔬"]
        let samples = [Sample(12, strings[2]), Sample(-9, strings[3])]
        var e = BinaryEncoder()
        for s in strings { e.append(s) }
        try e.append(samples[0])
        try e.append(samples)
        e.append([Bool]())
        e.append([State]())
        var d = try BinaryDecoder(bytes: e.packBytes())
        for s in strings { #expect(Array((try d.read() as String).utf8) == Array(s.utf8)) }
        #expect(try d.read() as Sample == samples[0])
        #expect(try d.readArray(maximumCount: 2) as [Sample] == samples)
        #expect((try d.readArray() as [Bool]).isEmpty)
        #expect((try d.readArray() as [State]).isEmpty)
        try d.validateEndOfData()
        let bytes = try BinaryResultCodec.encode(samples[1])
        #expect(try BinaryResultCodec.encode(samples[1]) == bytes)
        #expect(try BinaryResultCodec<Sample>.decode(bytes) == samples[1])
        #expect(try BinaryResultCodec.encode(Empty()) == header)
        #expect(throws: TestError.stop) { try BinaryResultCodec.encode(Failing()) }
        #expect(throws: TestError.stop) { try BinaryResultCodec<Failing>.decode(header) }
    }

    @Test
    func floatingPointAndComplexBits() throws {
        let f: [UInt32] = [
            0, 0x8000_0000, 0x3f80_0000, 0xc020_0000, 1,
            0x7f80_0000, 0xff80_0000, 0x7fc1_2345, 0xff80_0001,
        ]
        let g: [UInt64] = [
            0, 0x8000_0000_0000_0000, 0x3ff0_0000_0000_0000, 0xc004_0000_0000_0000,
            1, 0x7ff0_0000_0000_0000, 0xfff0_0000_0000_0000,
            0x7ff8_0000_1234_5678, 0xfff0_0000_0000_0001,
        ]
        let floats = f.map(Float.init(bitPattern:))
        let doubles = g.map(Double.init(bitPattern:))
        let cf = zip(floats, floats.reversed()).map { Complex($0, $1) }
        let cd = zip(doubles, doubles.reversed()).map { Complex($0, $1) }
        var e = BinaryEncoder()
        e.append(true)  // All subsequent scalar and array bodies are unaligned.
        for i in f.indices {
            e.append(floats[i])
            e.append(doubles[i])
            e.append(cf[i])
            e.append(cd[i])
        }
        e.append([Float]())
        e.append([Double]())
        e.append([Complex<Float>]())
        e.append([Complex<Double>]())
        e.append(floats)
        e.append(doubles)
        e.append(cf)
        e.append(cd)
        var d = try BinaryDecoder(bytes: e.packBytes())
        #expect(try d.read() as Bool)
        for i in f.indices {
            #expect((try d.read() as Float).bitPattern == f[i])
            #expect((try d.read() as Double).bitPattern == g[i])
            let a: Complex<Float> = try d.read()
            let b: Complex<Double> = try d.read()
            #expect(a.rawStorage.x.bitPattern == f[i])
            #expect(a.rawStorage.y.bitPattern == f[f.count - 1 - i])
            #expect(b.rawStorage.x.bitPattern == g[i])
            #expect(b.rawStorage.y.bitPattern == g[g.count - 1 - i])
        }
        #expect((try d.readArray() as [Float]).isEmpty)
        #expect((try d.readArray() as [Double]).isEmpty)
        #expect((try d.readArray() as [Complex<Float>]).isEmpty)
        #expect((try d.readArray() as [Complex<Double>]).isEmpty)
        #expect((try d.readArray() as [Float]).map(\.bitPattern) == f)
        #expect((try d.readArray() as [Double]).map(\.bitPattern) == g)
        let a: [Complex<Float>] = try d.readArray()
        let b: [Complex<Double>] = try d.readArray()
        #expect(a.map { $0.rawStorage.x.bitPattern } == f)
        #expect(a.map { $0.rawStorage.y.bitPattern } == f.reversed())
        #expect(b.map { $0.rawStorage.x.bitPattern } == g)
        #expect(b.map { $0.rawStorage.y.bitPattern } == g.reversed())
        try d.validateEndOfData()
    }

    @Test func nativeAndPortableComplexPayloadsMatchFixture() throws {
        let z = Complex(Float(bitPattern: 0x8000_0000), Float(bitPattern: 0x7fc1_2345))
        let bytes = header + [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x80, 0x45, 0x23, 0xc1, 0x7f]
        var normal = BinaryEncoder()
        normal.append([z])
        #expect(normal.packBytes() == bytes)
        var portable = BinaryEncoder()
        portable.append(UInt64(1))
        portable.appendElements([z], copyNative: false) { $0.append($1) }
        #expect(portable.packBytes() == bytes)
        var d = try BinaryDecoder(bytes: bytes)
        let count = try d.readCount()
        let values: [Complex<Float>] = try d.readElements(count: count, width: 8, copyNative: false) { try $0.read() }
        #expect(values[0].rawStorage.x.bitPattern == 0x8000_0000)
        #expect(values[0].rawStorage.y.bitPattern == 0x7fc1_2345)
        try d.validateEndOfData()
    }

    @Test
    func dualConformanceUsesRawValueInWireOverloads() throws {
        var encoder = BinaryEncoder()
        encoder.append(AlsoBinary.on)
        encoder.append([AlsoBinary.on])
        let bytes = encoder.packBytes()
        #expect(bytes == header + [0xad, 1, 0, 0, 0, 0, 0, 0, 0, 0xad])
        var decoder = try BinaryDecoder(bytes: bytes)
        #expect(try decoder.read() as AlsoBinary == .on)
        #expect(try decoder.readArray() as [AlsoBinary] == [.on])
        try decoder.validateEndOfData()
    }

    @Test
    func interleavedComplexDoubleFixture() throws {
        let values = [Complex(Double(bitPattern: 0xfff0_0000_0000_0017), -0.0), Complex(1, -2)]
        var encoder = BinaryEncoder()
        encoder.append(values)
        var fixture = header + [2, 0, 0, 0, 0, 0, 0, 0]
        fixture += [0x17, 0, 0, 0, 0, 0, 0xf0, 0xff, 0, 0, 0, 0, 0, 0, 0, 0x80]
        fixture += [0, 0, 0, 0, 0, 0, 0xf0, 0x3f, 0, 0, 0, 0, 0, 0, 0, 0xc0]
        #expect(encoder.packBytes() == fixture)
        var decoder = try BinaryDecoder(bytes: fixture)
        let read: [Complex<Double>] = try decoder.readArray()
        #expect(read.map { $0.rawStorage.x.bitPattern } == values.map { $0.rawStorage.x.bitPattern })
        #expect(read.map { $0.rawStorage.y.bitPattern } == values.map { $0.rawStorage.y.bitPattern })
        try decoder.validateEndOfData()
    }

    @Test
    func millionElementBuffers() throws {
        let count = 1_000_000
        let repeated = Array(repeating: Double(bitPattern: 0xfff8_0000_0000_0042), count: count)
        let ramp = (0..<count).map(Int32.init)
        let complex = ramp.map { Complex(Double($0), -Double($0)) }
        var e = BinaryEncoder()
        e.append(repeated)
        e.append(ramp)
        e.append(complex)
        let bytes = e.packBytes()
        #expect(bytes.count == 32 + count * 28)
        var d = try BinaryDecoder(bytes: bytes)
        let a: [Double] = try d.readArray()
        let b: [Int32] = try d.readArray()
        let c: [Complex<Double>] = try d.readArray()
        #expect(a.count == count && a.allSatisfy { $0.bitPattern == 0xfff8_0000_0000_0042 })
        #expect(b == ramp)
        #expect(
            c.count == count
                && zip(c, complex).allSatisfy { x, y in
                    x.rawStorage.x.bitPattern == y.rawStorage.x.bitPattern
                        && x.rawStorage.y.bitPattern == y.rawStorage.y.bitPattern
                })
        try d.validateEndOfData()
    }
}

@Suite
struct MalformedBinaryTests {
    @Test
    func invalidHeadersAndTrailingData() throws {
        for length in 0..<8 {
            #expect(throws: BinaryDecodingError.unexpectedEndOfData) {
                try BinaryDecoder(bytes: Array(header.prefix(length)))
            }
        }
        for index in 0..<4 {
            var bytes = header
            bytes[index] ^= 0xff
            #expect(throws: BinaryDecodingError.invalidHeader) { try BinaryDecoder(bytes: bytes) }
        }
        #expect(throws: BinaryDecodingError.unsupportedVersion(0x0102)) {
            try BinaryDecoder(bytes: Array(header.prefix(4)) + [2, 1, 0, 0])
        }
        #expect(throws: BinaryDecodingError.unsupportedFlags(0x8001)) {
            try BinaryDecoder(bytes: Array(header.prefix(6)) + [1, 0x80])
        }
        #expect(throws: BinaryDecodingError.trailingData) { try BinaryResultCodec<Empty>.decode(header + [0]) }

        let bytes = try BinaryResultCodec.encode(Sample(-12, "London – München"))
        for end in header.count..<bytes.count {
            #expect(throws: BinaryDecodingError.unexpectedEndOfData) {
                try BinaryResultCodec<Sample>.decode(Array(bytes.prefix(end)))
            }
        }
    }

    @Test
    func invalidScalarAndArrayElements() {
        #expect(throws: BinaryDecodingError.invalidBoolean(2)) {
            var d = try BinaryDecoder(bytes: header + [2])
            _ = try d.read() as Bool
        }
        #expect(throws: BinaryDecodingError.invalidBoolean(255)) {
            var d = try BinaryDecoder(bytes: header + [2, 0, 0, 0, 0, 0, 0, 0, 1, 255])
            _ = try d.readArray() as [Bool]
        }
        #expect(throws: BinaryDecodingError.invalidEnumeration) {
            var d = try BinaryDecoder(bytes: header + [9, 0])
            _ = try d.read() as State
        }
        #expect(throws: BinaryDecodingError.invalidEnumeration) {
            var d = try BinaryDecoder(bytes: header + [2, 0, 0, 0, 0, 0, 0, 0, 0xfe, 0xff, 3, 0])
            _ = try d.readArray() as [State]
        }
        #expect(throws: BinaryDecodingError.invalidUTF8) {
            var d = try BinaryDecoder(bytes: header + [2, 0, 0, 0, 0, 0, 0, 0, 0xc0, 0xaf])
            _ = try d.read() as String
        }
        #expect(throws: BinaryDecodingError.unexpectedEndOfData) {
            var d = try BinaryDecoder(bytes: header + [4, 0, 0, 0, 0, 0, 0, 0, 65])
            _ = try d.read() as String
        }
    }

    @Test
    func lengthsAndLimits() {
        #expect(throws: BinaryDecodingError.invalidLength) {
            var d = try BinaryDecoder(bytes: header + Array(repeating: 255, count: 8))
            _ = try d.readArray() as [UInt8]
        }
        #expect(throws: BinaryDecodingError.invalidLength) {
            var e = BinaryEncoder()
            e.append(UInt64(Int.max / 16 + 1))
            var d = try BinaryDecoder(bytes: e.packBytes())
            _ = try d.readArray() as [Complex<Double>]
        }
        #expect(throws: BinaryDecodingError.unexpectedEndOfData) {
            var e = BinaryEncoder()
            e.append(UInt64(100_000_000))
            var d = try BinaryDecoder(bytes: e.packBytes())
            _ = try d.readArray() as [Float]
        }
        #expect(throws: BinaryDecodingError.invalidLength) {
            var d = try BinaryDecoder(bytes: header + [2, 0, 0, 0, 0, 0, 0, 0, 1, 2], maximumCollectionCount: 1)
            _ = try d.readArray() as [UInt8]
        }
        #expect(throws: BinaryDecodingError.invalidLength) {
            var d = try BinaryDecoder(bytes: header, maximumCollectionCount: 1)
            _ = try d.readArray(count: 2) as [Double]
        }
        #expect(throws: BinaryDecodingError.invalidLength) {
            var d = try BinaryDecoder(bytes: header)
            _ = try d.readArray(count: -1) as [Double]
        }
        #expect(throws: BinaryDecodingError.invalidLength) {
            var e = BinaryEncoder()
            e.append(UInt64(1_000_000))
            var d = try BinaryDecoder(bytes: e.packBytes())
            _ = try d.readArray(maximumCount: 100) as [Empty]
        }
    }

    @Test
    func portableMachineIntegers() throws {
        // Exercise narrowing on this host using the same checked path as a 32-bit Int/UInt.
        var encoder = BinaryEncoder()
        encoder.append(Int64(Int32.min))
        encoder.append(Int64(Int32.max) + 1)
        encoder.append(UInt64(UInt32.max))
        encoder.append(UInt64(UInt32.max) + 1)
        var decoder = try BinaryDecoder(bytes: encoder.packBytes())
        let signed: Int32 = try decoder.readMachineInteger(from: Int64.self)
        #expect(signed == .min)
        #expect(throws: BinaryDecodingError.integerOutOfRange) {
            _ = try decoder.readMachineInteger(from: Int64.self) as Int32
        }
        let unsigned: UInt32 = try decoder.readMachineInteger(from: UInt64.self)
        #expect(unsigned == .max)
        #expect(throws: BinaryDecodingError.integerOutOfRange) {
            _ = try decoder.readMachineInteger(from: UInt64.self) as UInt32
        }
        try decoder.validateEndOfData()
    }
}
