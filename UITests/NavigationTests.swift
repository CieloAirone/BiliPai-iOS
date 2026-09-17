import XCTest
final class NavigationTests: XCTestCase {
    func testNativeNavigationAndThemeSettings() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["推荐"].waitForExistence(timeout: 15))
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["历史记录"].waitForExistence(timeout: 5))
        let profile = XCTAttachment(screenshot: app.screenshot()); profile.name = "Profile"; profile.lifetime = .keepAlways; add(profile)
        app.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["主题"].exists)
        let settings = XCTAttachment(screenshot: app.screenshot()); settings.name = "Settings"; settings.lifetime = .keepAlways; add(settings)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["听视频"].tap()
        XCTAssertTrue(app.navigationBars["听视频"].waitForExistence(timeout: 5))
    }
}
