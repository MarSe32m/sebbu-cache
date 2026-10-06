# sebbu-cache

A small, reusable Swift caching library for deterministic computations.

`sebbu-cache` separates the description of *what makes a result reusable* from *where that result is stored*. The core `SebbuCache` target has no Foundation dependency. It defines cache identities, keys, entries, codecs and the `CacheStore` abstraction. If you want a ready-made filesystem cache, `SebbuCacheFoundation` provides `FileCacheStore` and `JSONResultCodec`.

This design is intended for scientific and other computation-heavy projects where a result may be expensive to reproduce and where cache validity should be explicit and inspectable.

## Targets

### `SebbuCache`

Foundation-free core functionality:

- `CacheIdentifiable` and `CacheIdentityEncoder` for deterministic cache identities.
- `CachedEntry` for declaring a cacheable computation and its result type.
- `CacheKey` and `CacheDescriptor` for stable lookup keys.
- `ResultCodec` for controlling result serialization.
- `CacheStore` for pluggable storage backends.
- `CacheMetadata` for storing provenance alongside cached data.

Depend on this target if you want to provide your own storage backend or avoid Foundation entirely.

### `SebbuCacheFoundation`

Foundation-based conveniences:

- `FileCacheStore` for persistent on-disk caching.
- `JSONResultCodec` for `Codable` results.

`FileCacheStore()` uses `.sebbu-cache` in the current working directory by default. Add it to your project's `.gitignore`:

```gitignore
.sebbu-cache/
```

## Installation

Add the package to your Swift package dependencies:

```swift
.package(
    url: "https://github.com/MarSe32m/sebbu-cache",
    from: "0.1.0"
)
```

Then depend on only the target you need:

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "SebbuCache", package: "sebbu-cache")
    ]
)
```

or for the filesystem implementation:

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "SebbuCacheFoundation", package: "sebbu-cache")
    ]
)
```

`SebbuCacheFoundation` reuses the core cache abstractions, so applications using `FileCacheStore` will generally import both modules:

```swift
import SebbuCache
import SebbuCacheFoundation
```

## Basic usage

A cached computation consists of three pieces:

1. an input that defines the cache identity,
2. a `CachedEntry` describing the computation,
3. a `ResultCodec` describing how the result is serialized.

For example:

```swift
import SebbuCache
import SebbuCacheFoundation

struct SimulationInput: CacheIdentifiable, Codable, Sendable {
    let coupling: Double
    let samples: Int

    func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder) {
        encoder.field("coupling", coupling)
        encoder.field("samples", samples)
    }
}

struct SimulationResult: Codable, Sendable {
    let mean: Double
    let variance: Double
}

struct Simulation: CachedEntry {
    static let namespace = "example/simulation"
    static let cacheVersion = 1

    typealias Codec = JSONResultCodec<SimulationResult>

    let input: SimulationInput
}

let cache = FileCacheStore()
let simulation = Simulation(
    input: SimulationInput(coupling: 0.25, samples: 10_000)
)

let result = try cache.value(for: simulation) {
    // Perform the expensive calculation only on a cache miss.
    SimulationResult(mean: 1.0, variance: 0.05)
}
```

The first call computes and stores the result. A later call with the same cache identity loads it instead.

## Cache identities

`CacheIdentifiable` is deliberately explicit. Only values encoded into the `CacheIdentityEncoder` affect whether two computations are considered equivalent.

```swift
struct SomeConfiguration: CacheIdentifiable, Codable, Sendable {
    let tolerance: Double
    let maximumIterations: Int
    let workerCount: Int

    func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder) {
        encoder.field("tolerance", tolerance)
        encoder.field("maximumIterations", maximumIterations)

        // workerCount is intentionally omitted: it changes execution,
        // but not the numerical computation being cached.
    }
}
```

This is useful when execution details such as thread count, batching etc. should not invalidate otherwise identical cached results.

Floating-point values are encoded using their exact IEEE-754 bit patterns, avoiding locale- or formatting-dependent identities.

Nested `CacheIdentifiable` values and arrays can also contribute to an identity:

```swift
encoder.field("solver", solver)
encoder.field("energies", energies)
```

## Namespaces and cache versions

Each `CachedEntry` declares a namespace and cache version:

```swift
static let namespace = "my-project/calculation-type-1"
static let cacheVersion = 1
```

The namespace separates conceptually different computations. Increment `cacheVersion` whenever the meaning, algorithm or observable represented by an entry changes in a way that makes existing cached results invalid.

Do not use source-control revisions as automatic cache versions unless every code change should invalidate the cache. Cache-version changes are intended to be deliberate.

## Derived cached computations

`CacheKey` itself is `CacheIdentifiable`, so one cached computation can depend on another without repeating all of the upstream parameters:

```swift
struct SpectrumInput: CacheIdentifiable, Codable, Sendable {
    let correlation: CacheKey
    let frequencyPoints: Int

    func encodeCacheIdentity(into encoder: inout CacheIdentityEncoder) {
        encoder.field("correlation", correlation)
        encoder.field("frequencyPoints", frequencyPoints)
    }
}
```

This makes it straightforward to build cached computation graphs such as:

```text
simulation -> correlation -> spectrum -> derived observable
```

Changing only the spectrum settings can then reuse the expensive cached correlation.

## Custom result codecs

A codec converts a result to and from bytes:

```swift
public protocol ResultCodec: Sendable {
    associatedtype Value: Sendable

    static var fileExtension: String { get }
    static func encode(_ value: Value) throws -> [UInt8]
    static func decode(_ bytes: [UInt8]) throws -> Value
}
```

This keeps storage format independent of cache identity. Large numerical results can use a compact binary codec while smaller `Codable` values can use `JSONResultCodec` from `SebbuCacheFoundation`.

## Custom cache stores

The core library does not require Foundation or filesystem access. A custom backend only needs to implement:

```swift
public protocol CacheStore: Sendable {
    func load<C: CachedEntry>(_ entry: C) throws -> C.Result?
    func store<C: CachedEntry>(_ result: C.Result, for entry: C) throws
}
```

For example, an application could provide an in-memory cache, database-backed cache, remote object store, or platform-specific implementation while keeping the same `CachedEntry` definitions.

The convenience method

```swift
try cache.value(for: entry) {
    computeResult()
}
```

performs the usual load-or-compute-and-store flow for every `CacheStore` implementation.

## `FileCacheStore`

`FileCacheStore` stores metadata and encoded results on disk. By default its root is:

```text
<current working directory>/.sebbu-cache/
```

A custom location can be supplied explicitly:

```swift
let cache = FileCacheStore(rootDirectory: "/scratch/my-project-cache")
```

The store validates the full canonical identity in addition to using a short persistent digest for lookup, so a digest collision does not silently return an unrelated cached result.

## Design goals

SebbuCache aims to keep caching:

- **explicit** — cache validity is defined by the computation's input identity,
- **deterministic** — persistent keys do not use Swift's randomly seeded `Hasher`,
- **modular** — the core target is independent of Foundation and storage policy,
- **typed** — entries determine their input, result and codec types,
- **extensible** — new calculations and storage backends do not require changes to the cache core.

## License

SebbuCache is available under the MIT License. See `LICENSE` for details.
