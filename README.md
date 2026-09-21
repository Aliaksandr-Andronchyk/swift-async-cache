# AsyncCache

A type-safe, actor-based async/await cache for Swift with per-entry TTL and a
total memory (cost) limit.

## What it does

- `AsyncCache<Key, Value>` is a Swift `actor`, so it is safe to use from
  concurrent tasks without extra locking.
- Every entry has a time-to-live: expired entries are dropped lazily on
  access.
- Every entry has a `cost` (defaults to 1, but you can pass entry size in
  bytes or anything else). When the total cost exceeds `costLimit`, the
  oldest entries are evicted until it fits.
- `value(for:ttl:cost:resolve:)` gives you a cache-or-compute helper: on a
  miss it awaits `resolve()`, stores the result, and returns it.

## Usage

```swift
import AsyncCache

let cache = AsyncCache<String, Data>(defaultTTL: 60, costLimit: 10_000_000)

// simple set/get
await cache.set(someData, for: "key", cost: someData.count)
let cached = await cache.value(for: "key")

// cache-or-compute
let data = await cache.value(for: "key", cost: 1024) {
    try await fetchFromNetwork()
}
```

## Run tests

```bash
swift test
```

This package was written and reviewed without access to a local Swift
toolchain (no `swift` binary on the build machine); the tests were written to
`XCTest`/SPM conventions but have not been compiled here – run `swift test`
on a machine with Xcode or the Swift toolchain installed before relying on
this in production.
