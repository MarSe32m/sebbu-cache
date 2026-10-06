// Copyright (c) 2026 Sebastian Toivonen
// SPDX-License-Identifier: MIT

public struct FileCacheStore: CacheStore {
    public let rootDirectory: String
    
    public init(rootDirectory: String) {
        self.rootDirectory = rootDirectory
    }
    
    public func load<C: CachedEntry>(_ entry: C) throws -> C.Result? {
        let input = entry.input
        let key = entry.cacheDescriptor.key
        //TODO: Load the data from disk using above
        return try C.Codec.decode([])
    }
    
    public func store<C: CachedEntry>(_ result: C.Result, for entry: C) throws {
        fatalError()
    }
}
