import XCTest

@MainActor
final class StoreScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testKoreanScreensAndPurchaseOptions() { capture(language: "ko-KR", korean: true) }
    func testEnglishScreensAndPurchaseOptions() { capture(language: "en-US", korean: false) }
    func testKoreanHome() { capture(language: "ko-KR", korean: true, homeOnly: true) }
    func testEnglishHome() { capture(language: "en-US", korean: false, homeOnly: true) }
    func testJapaneseFallsBackToEnglish() { capture(language: "ja-JP", korean: false, homeOnly: true) }
    func testFrenchFallsBackToEnglish() { capture(language: "fr-FR", korean: false, homeOnly: true) }

    private func capture(language: String, korean: Bool, homeOnly: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-ScreenshotDemo", "-SkipAds", "-ResetScreenshotOnboarding", "-AppleLanguages", "(\(language))", "-AppleLocale", korean ? "ko_KR" : "en_US"]
        app.launch()
        var capturedGuide = false
        let start = app.buttons[korean ? "시작하기" : "Get Started"]
        if start.waitForExistence(timeout: 3) {
            if !homeOnly {
                attach("\(language)-01-guide")
                capturedGuide = true
            }
            start.tap()
        }
        let upgrade = app.buttons[korean ? "광고 연장 / 영구 사용" : "Add Time / Lifetime Access"]
        XCTAssertTrue(upgrade.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["••••-••••"].exists, "Pairing code must be hidden in store screenshots.")
        let sender = korean ? "이 기기는 화면을 보내는 역할입니다. Mac 앱이 함께 켜져 있어야 미러링이 보입니다." : "This device sends the screen. Keep the companion Mac app open to receive it."
        XCTAssertTrue(app.staticTexts[sender].exists, "Sender description must work for iPhone as well as iPad.")
        let window = app.windows.firstMatch
        if window.frame.width < 600 {
            XCTAssertTrue(upgrade.isHittable)
            XCTAssertLessThanOrEqual(upgrade.frame.maxY, window.frame.maxY - 20, "Phone home must show the entire Add Time button.")
        }
        if !korean { assertNoKorean(in: app) }
        if homeOnly {
            attach("\(language)-fallback-home")
            app.terminate()
            return
        }
        attach("\(language)-02-home")
        if !capturedGuide {
            let guide = app.buttons[korean ? "사용법 다시 보기" : "Show Instructions"]
            guide.tap()
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            attach("\(language)-01-guide")
            start.tap()
            XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
        }
        upgrade.tap()
        XCTAssertTrue(app.buttons[korean ? "구매 복원" : "Restore Purchases"].waitForExistence(timeout: 5))
        let lifetime = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", korean ? "영구 사용 " : "Lifetime Access ")).firstMatch
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: lifetime)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 12), .completed, "Local StoreKit purchase options must load before capture.")
        if !korean { assertNoKorean(in: app) }
        attach("\(language)-03-purchases")
        app.terminate()
    }

    private func assertNoKorean(in app: XCUIApplication) {
        let labels = app.staticTexts.allElementsBoundByIndex.map(\.label) + app.buttons.allElementsBoundByIndex.map(\.label)
        for label in labels {
            XCTAssertNil(label.range(of: "[가-힣]", options: .regularExpression), "Unexpected Korean UI: \(label)")
        }
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
