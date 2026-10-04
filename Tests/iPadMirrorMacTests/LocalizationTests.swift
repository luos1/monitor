import XCTest
import iPadMirrorShared

@MainActor
final class LocalizationTests: XCTestCase {
    func testKoreanVariantsAndEnglishFallbackPolicy() {
        for code in ["ko", "ko-KR"] {
            XCTAssertEqual(MirrorL10n.language(for: code), "ko")
            XCTAssertEqual(MirrorL10n.text("시작하기", language: code), "시작하기")
        }
        for code in ["en", "en-US", "ja", "fr-FR"] {
            XCTAssertEqual(MirrorL10n.language(for: code), "en")
            XCTAssertEqual(MirrorL10n.text("시작하기", language: code), "Get Started")
            XCTAssertEqual(MirrorL10n.text("무료 동반 앱", language: code), "Free Companion App")
        }
    }

    func testTimeAndErrorMessagesUseSelectedLanguage() {
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 3720, lifetimeUnlocked: false, language: "ko-KR"), "1시간 2분")
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 3720, lifetimeUnlocked: false, language: "en"), "1 hr 2 min")
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 45, lifetimeUnlocked: true, language: "ja"), "Unlimited")
        XCTAssertEqual(MirrorL10n.format("USB 연결 실패: {0}", "Disconnected", language: "fr"), "USB connection failed: Disconnected")
        XCTAssertEqual(MirrorL10n.text("구매 복원", language: "en"), "Restore Purchases")
    }
}
