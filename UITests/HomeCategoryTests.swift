import XCTest
final class HomeCategoryTests:XCTestCase {
    private func assertAligned(_ app:XCUIApplication) {
        let names = ["推荐","热门","排行榜","直播","番剧"]
        let buttons = names.map { app.buttons["home.category.\($0)"] }
        XCTAssertTrue(buttons[0].waitForExistence(timeout:10))
        let frames = buttons.map(\.frame)
        for frame in frames {
            XCTAssertGreaterThan(frame.width,40)
            XCTAssertEqual(frame.width,frames[0].width,accuracy:0.5)
            XCTAssertEqual(frame.height,frames[0].height,accuracy:0.5)
            XCTAssertEqual(frame.midY,frames[0].midY,accuracy:0.5)
        }
        for i in 1..<frames.count { XCTAssertEqual(frames[i].minX-frames[i-1].maxX,4,accuracy:0.5) }
    }
    func testAllFiveCategoriesHaveEqualBoxesInLightDarkAndNarrowLayout() {
        let app = XCUIApplication()
        for appearance in ["light","dark"] {
            app.launchArguments = ["-appearance",appearance];app.launch()
            assertAligned(app)
            let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "CategoryBoxes-\(appearance)";shot.lifetime = .keepAlways;add(shot)
            app.terminate()
        }
        app.launchArguments = ["--regression-fixtures"];app.launch()
        app.buttons["窄屏分类测试"].tap();assertAligned(app)
        let narrow = XCTAttachment(screenshot:app.screenshot());narrow.name = "CategoryBoxes-320pt";narrow.lifetime = .keepAlways;add(narrow)
    }
    func testBangumiEntryLoadsPagesAndSeasonDetails() {
        let app = XCUIApplication();app.launchArguments = ["--catalog-fixture"];app.launch()
        XCTAssertTrue(app.buttons["home.category.番剧"].waitForExistence(timeout:10));app.buttons["home.category.番剧"].tap()
        XCTAssertTrue(app.buttons["catalog.item.1"].waitForExistence(timeout:5));app.buttons["catalog.item.1"].tap()
        XCTAssertTrue(app.staticTexts["详情加载成功"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["1  第一话"].exists)
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["加载更多"].tap()
        XCTAssertTrue(app.buttons["catalog.item.2"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["加载更多"].exists)
    }
}
