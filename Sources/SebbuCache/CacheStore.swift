// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public protocol CacheStore: Sendable {
    func load<C: CachedEntry>(_ entry: C) throws -> C.Result?
    func store<C: CachedEntry>(_ result: C.Result, for entry: C) throws
}

extension CacheStore {
    public func value<C: CachedEntry>(for entry: C, calculate: () throws -> C.Result) throws -> C.Result {
        if let cached = try load(entry) { return cached }
        let result = try calculate()
        try store(result, for: entry)
        return result
    }
}
