import XCTest
@testable import AsyncCache

final class AsyncCacheTests: XCTestCase {
    func testSetAndGetReturnsStoredValue() async {
        let cache = AsyncCache<String, Int>(defaultTTL: 60, costLimit: 100)
        await cache.set(42, for: "a")
        let value = await cache.value(for: "a")
        XCTAssertEqual(value, 42)
    }

    func testMissingKeyReturnsNil() async {
        let cache = AsyncCache<String, Int>(defaultTTL: 60, costLimit: 100)
        let value = await cache.value(for: "missing")
        XCTAssertNil(value)
    }

    func testEntryExpiresAfterTTL() async {
        var now = Date(timeIntervalSince1970: 0)
        let cache = AsyncCache<String, Int>(defaultTTL: 10, costLimit: 100, clock: { now })
        await cache.set(1, for: "a")
        now = now.addingTimeInterval(11)
        let value = await cache.value(for: "a")
        XCTAssertNil(value)
    }

    func testPerEntryTTLOverridesDefault() async {
        var now = Date(timeIntervalSince1970: 0)
        let cache = AsyncCache<String, Int>(defaultTTL: 100, costLimit: 100, clock: { now })
        await cache.set(1, for: "short", ttl: 5)
        now = now.addingTimeInterval(6)
        let value = await cache.value(for: "short")
        XCTAssertNil(value)
    }

    func testEvictsOldestWhenCostLimitExceeded() async {
        let cache = AsyncCache<String, Int>(defaultTTL: 60, costLimit: 10)
        await cache.set(1, for: "a", cost: 4)
        await cache.set(2, for: "b", cost: 4)
        await cache.set(3, for: "c", cost: 4)

        let a = await cache.value(for: "a")
        let b = await cache.value(for: "b")
        let c = await cache.value(for: "c")

        XCTAssertNil(a)
        XCTAssertEqual(b, 2)
        XCTAssertEqual(c, 3)
    }

    func testCurrentCostTracksStoredEntries() async {
        let cache = AsyncCache<String, Int>(defaultTTL: 60, costLimit: 100)
        await cache.set(1, for: "a", cost: 3)
        await cache.set(2, for: "b", cost: 5)
        let cost = await cache.currentCost
        XCTAssertEqual(cost, 8)
    }

    func testOverwritingKeyReplacesCostNotAdds() async {
        let cache = AsyncCache<String, Int>(defaultTTL: 60, costLimit: 100)
        await cache.set(1, for: "a", cost: 3)
        await cache.set(2, for: "a", cost: 7)
        let cost = await cache.currentCost
        let value = await cache.value(for: "a")
        XCTAssertEqual(cost, 7)
        XCTAssertEqual(value, 2)
    }

    func testRemoveDeletesEntry() async {
        let cache = AsyncCache<String, Int>(defaultTTL: 60, costLimit: 100)
        await cache.set(1, for: "a")
        await cache.remove("a")
        let value = await cache.value(for: "a")
        XCTAssertNil(value)
    }

    func testRemoveAllClearsEverything() async {
        let cache = AsyncCache<String, Int>(defaultTTL: 60, costLimit: 100)
        await cache.set(1, for: "a")
        await cache.set(2, for: "b")
        await cache.removeAll()
        let count = await cache.count
        let cost = await cache.currentCost
        XCTAssertEqual(count, 0)
        XCTAssertEqual(cost, 0)
    }

    func testValueForKeyResolveComputesOnceOnMiss() async {
        let cache = AsyncCache<String, Int>(defaultTTL: 60, costLimit: 100)
        var calls = 0
        let first = await cache.value(for: "a") {
            calls += 1
            return 99
        }
        let second = await cache.value(for: "a") {
            calls += 1
            return 100
        }
        XCTAssertEqual(first, 99)
        XCTAssertEqual(second, 99)
        XCTAssertEqual(calls, 1)
    }

    func testCountReflectsLiveEntries() async {
        let cache = AsyncCache<String, Int>(defaultTTL: 60, costLimit: 100)
        await cache.set(1, for: "a")
        await cache.set(2, for: "b")
        let count = await cache.count
        XCTAssertEqual(count, 2)
    }

    func testCountExcludesExpiredEntries() async {
        var now = Date(timeIntervalSince1970: 0)
        let cache = AsyncCache<String, Int>(defaultTTL: 10, costLimit: 100, clock: { now })
        await cache.set(1, for: "a")
        now = now.addingTimeInterval(11)
        let count = await cache.count
        XCTAssertEqual(count, 0)
    }

    func testCurrentCostExcludesExpiredEntries() async {
        var now = Date(timeIntervalSince1970: 0)
        let cache = AsyncCache<String, Int>(defaultTTL: 10, costLimit: 100, clock: { now })
        await cache.set(1, for: "a", cost: 5)
        now = now.addingTimeInterval(11)
        let cost = await cache.currentCost
        XCTAssertEqual(cost, 0)
    }
}
