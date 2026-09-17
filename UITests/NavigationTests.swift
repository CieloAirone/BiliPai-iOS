import XCTest
final class NavigationTests: XCTestCase {
    func testNativeNavigationAndThemeSettings() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["推荐"].waitForExistence(timeout: 15))
        let home = XCTAttachment(screenshot: app.screenshot()); home.name = "Home"; home.lifetime = .keepAlways; add(home)
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["历史记录"].waitForExistence(timeout: 5))
        let profile = XCTAttachment(screenshot: app.screenshot()); profile.name = "Profile"; profile.lifetime = .keepAlways; add(profile)
        app.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["外观与主题"].exists)
        app.buttons["settings.外观与主题"].tap();app.buttons["外观设置"].tap()
        XCTAssertTrue(app.staticTexts["主题模式"].waitForExistence(timeout:5))
        app.navigationBars.buttons.element(boundBy:0).tap();app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["settings.播放与画质"].tap();app.buttons["播放器设置"].tap()
        let toggle = app.switches["settings.autoplay"]
        XCTAssertTrue(toggle.waitForExistence(timeout:5))
        let previous = toggle.value as? String
        toggle.coordinate(withNormalizedOffset:CGVector(dx:0.93,dy:0.5)).tap()
        let changed = NSPredicate { _, _ in (toggle.value as? String) != previous }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:changed,object:nil)],timeout:3),.completed)
        let playback = XCTAttachment(screenshot:app.screenshot());playback.name = "PlaybackSettings";playback.lifetime = .keepAlways;add(playback)
        app.terminate();app.launch()
        app.tabBars.buttons["我的"].tap();app.buttons["设置"].tap();app.buttons["settings.播放与画质"].tap();app.buttons["播放器设置"].tap()
        XCTAssertNotEqual(app.switches["settings.autoplay"].value as? String,previous)
        app.switches["settings.autoplay"].coordinate(withNormalizedOffset:CGVector(dx:0.93,dy:0.5)).tap()
        app.navigationBars.buttons.element(boundBy:0).tap();app.navigationBars.buttons.element(boundBy:0).tap()
        let settings = XCTAttachment(screenshot: app.screenshot()); settings.name = "Settings"; settings.lifetime = .keepAlways; add(settings)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["听视频"].tap()
        XCTAssertTrue(app.navigationBars["听视频"].waitForExistence(timeout: 5))
    }
    func testSettingsSearchOpensBackupAndDanmaku() {
        let app = XCUIApplication();app.launchArguments += ["-appearance", "dark"];app.launch()
        XCTAssertTrue(app.tabBars.buttons["推荐"].waitForExistence(timeout:15))
        let darkHome = XCTAttachment(screenshot:app.screenshot());darkHome.name = "HomeDark";darkHome.lifetime = .keepAlways;add(darkHome)
        app.tabBars.buttons["我的"].tap();app.buttons["设置"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();search.typeText("WebDAV")
        app.buttons["settings.存储与备份"].tap()
        XCTAssertTrue(app.buttons["WebDAV 云备份"].waitForExistence(timeout:5))
        app.buttons["WebDAV 云备份"].tap()
        XCTAssertTrue(app.secureTextFields["密码或应用专用密码"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["备份到服务器"].isEnabled)
        let backup = XCTAttachment(screenshot:app.screenshot());backup.name = "WebDAVSettings";backup.lifetime = .keepAlways;add(backup)
    }

}
