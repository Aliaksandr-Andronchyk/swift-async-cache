import Foundation

/// A value stored in the cache together with the metadata needed to evict it.
private struct Entry<Value> {
    let value: Value
    let expiresAt: Date
    let cost: Int
}

/// Thread-safe async/await cache with per-entry TTL and a total memory budget.
///
/// Eviction happens lazily: expired entries are dropped on access, and when a
/// new entry would push the total cost over `costLimit`, the oldest entries
/// (by insertion order) are evicted until there is room.
public actor AsyncCache<Key: Hashable, Value> {
    private var storage: [Key: Entry<Value>] = [:]
    private var order: [Key] = []
    private var totalCost: Int = 0

    private let defaultTTL: TimeInterval
    private let costLimit: Int
    private let clock: () -> Date

    /// - Parameters:
    ///   - defaultTTL: how long an entry stays valid when no TTL is given at insertion.
    ///   - costLimit: maximum sum of entry costs (e.g. bytes) allowed at once.
    ///   - clock: injectable time source, defaults to the system clock.
    public init(
        defaultTTL: TimeInterval,
        costLimit: Int,
        clock: @escaping () -> Date = Date.init
    ) {
        self.defaultTTL = defaultTTL
        self.costLimit = costLimit
        self.clock = clock
    }

    /// Number of live (non-expired) entries currently stored.
    public var count: Int {
        let now = clock()
        return storage.values.filter { $0.expiresAt > now }.count
    }

    /// Sum of costs of all currently stored entries.
    public var currentCost: Int {
        totalCost
    }

    /// Stores `value` for `key` with an optional TTL and cost override.
    public func set(_ value: Value, for key: Key, ttl: TimeInterval? = nil, cost: Int = 1) {
        removeExpired()

        if let existing = storage.removeValue(forKey: key) {
            totalCost -= existing.cost
            order.removeAll { $0 == key }
        }

        let expiresAt = clock().addingTimeInterval(ttl ?? defaultTTL)
        storage[key] = Entry(value: value, expiresAt: expiresAt, cost: cost)
        order.append(key)
        totalCost += cost

        evictIfNeeded()
    }

    /// Returns the cached value for `key`, or `nil` if missing or expired.
    public func value(for key: Key) -> Value? {
        guard let entry = storage[key] else { return nil }
        if entry.expiresAt <= clock() {
            remove(key)
            return nil
        }
        return entry.value
    }

    /// Returns the cached value for `key`, computing and storing it via `resolve` on a miss.
    public func value(
        for key: Key,
        ttl: TimeInterval? = nil,
        cost: Int = 1,
        resolve: () async throws -> Value
    ) async rethrows -> Value {
        if let hit = value(for: key) {
            return hit
        }
        let resolved = try await resolve()
        set(resolved, for: key, ttl: ttl, cost: cost)
        return resolved
    }

    /// Removes a single entry.
    public func remove(_ key: Key) {
        guard let entry = storage.removeValue(forKey: key) else { return }
        totalCost -= entry.cost
        order.removeAll { $0 == key }
    }

    /// Removes everything.
    public func removeAll() {
        storage.removeAll()
        order.removeAll()
        totalCost = 0
    }

    private func removeExpired() {
        let now = clock()
        let expiredKeys = storage.filter { $0.value.expiresAt <= now }.map(\.key)
        for key in expiredKeys {
            remove(key)
        }
    }

    private func evictIfNeeded() {
        while totalCost > costLimit, !order.isEmpty {
            let oldest = order.removeFirst()
            if let entry = storage.removeValue(forKey: oldest) {
                totalCost -= entry.cost
            }
        }
    }
}
