import XCTest
@testable import iPadMirrorShared

final class BroadcastActivityTests: XCTestCase {
    func testActivityTracksLivePausedStoppedAndExpiredHeartbeat() {
        let suite = "test.broadcast.activity.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        defer { store.removePersistentDomain(forName: suite) }
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(BroadcastSharedSettings.activity(now: now, store: store), .idle)
        BroadcastSharedSettings.writeActivity(.broadcasting, now: now, store: store)
        XCTAssertEqual(BroadcastSharedSettings.activity(now: now.addingTimeInterval(2), store: store), .broadcasting)
        BroadcastSharedSettings.writeActivity(.paused, now: now.addingTimeInterval(3), store: store)
        XCTAssertEqual(BroadcastSharedSettings.activity(now: now.addingTimeInterval(4), store: store), .paused)
        XCTAssertEqual(BroadcastSharedSettings.activity(now: now.addingTimeInterval(12), store: store), .idle)
        BroadcastSharedSettings.writeActivity(.idle, now: now.addingTimeInterval(13), store: store)
        XCTAssertEqual(BroadcastSharedSettings.activity(now: now.addingTimeInterval(14), store: store), .idle)
    }

    func testFutureOrMissingHeartbeatDoesNotClaimLiveBroadcast() {
        let suite = "test.broadcast.activity.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        defer { store.removePersistentDomain(forName: suite) }
        let now = Date(timeIntervalSince1970: 1_000_000)
        store.set("broadcasting", forKey: "broadcastActivity")
        XCTAssertEqual(BroadcastSharedSettings.activity(now: now, store: store), .idle)
        BroadcastSharedSettings.writeActivity(.broadcasting, now: now.addingTimeInterval(5), store: store)
        XCTAssertEqual(BroadcastSharedSettings.activity(now: now, store: store), .idle)
    }
}
