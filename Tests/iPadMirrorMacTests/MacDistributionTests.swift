import XCTest
@testable import iPadMirrorMac

final class MacDistributionTests: XCTestCase {
    func testStoreCopyUsesKoreanAndEnglishFallback() {
        XCTAssertEqual(MacStoreCopy.text("한국어", "English", language: "ko-KR"), "한국어")
        XCTAssertEqual(MacStoreCopy.text("한국어", "English", language: "en-US"), "English")
        XCTAssertEqual(MacStoreCopy.text("한국어", "English", language: "fr-FR"), "English")
    }
    func testCompiledTransportScope() {
        #if IPADMIRROR_MAC_APP_STORE
        XCTAssertTrue(MacDistribution.isNetworkOnly)
        let device = BonjourBrowser.Device(name: "QA iPad", host: "qa.local", port: 12346)
        XCTAssertEqual(device.transport, .network)
        #else
        XCTAssertFalse(MacDistribution.isNetworkOnly)
        #endif
    }
}
