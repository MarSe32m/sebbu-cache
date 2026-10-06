// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public enum PersistentCacheHash {
    public static func digest(_ string: String) -> String {
        let a = fnv1a(string.utf8, seed: 0xcbf29ce484222325)
        let b = fnv1a(string.utf8, seed: 0x84222325cbf29ce4)
        return hex(a) + hex(b)
    }
    
    private static func fnv1a<S: Sequence>(
        _ bytes: S, seed: UInt64
    ) -> UInt64 where S.Element == UInt8 {
        bytes.reduce(seed) { ($0 ^ UInt64($1)) &* 0x100000001b3 }
    }
    
    private static func hex(_ value: UInt64) -> String {
        let text = String(value, radix: 16)
        return String(repeating: "0", count: 16 - text.count) + text
    }
}
