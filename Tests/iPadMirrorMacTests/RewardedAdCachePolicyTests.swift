import XCTest
import iPadMirrorShared

final class RewardedAdCachePolicyTests: XCTestCase {
    private let loadedAt = Date(timeIntervalSince1970: 1_000_000)

    func testFreshAdCanBeUsedBeforeRefreshBoundary() {
        XCTAssertTrue(RewardedAdCachePolicy.isFresh(loadedAt: loadedAt, now: loadedAt))
        XCTAssertTrue(RewardedAdCachePolicy.isFresh(
            loadedAt: loadedAt,
            now: loadedAt.addingTimeInterval(RewardedAdCachePolicy.maximumAge - 1)
        ))
    }

    func testExpiredAdIsRefreshedBeforeFreeHourEnds() {
        XCTAssertFalse(RewardedAdCachePolicy.isFresh(
            loadedAt: loadedAt,
            now: loadedAt.addingTimeInterval(RewardedAdCachePolicy.maximumAge)
        ))
        XCTAssertFalse(RewardedAdCachePolicy.isFresh(
            loadedAt: loadedAt,
            now: loadedAt.addingTimeInterval(60 * 60)
        ))
    }

    func testMissingTimestampAndBackwardClockRequireReload() {
        XCTAssertFalse(RewardedAdCachePolicy.isFresh(loadedAt: nil, now: loadedAt))
        XCTAssertFalse(RewardedAdCachePolicy.isFresh(
            loadedAt: loadedAt,
            now: loadedAt.addingTimeInterval(-1)
        ))
    }
}
