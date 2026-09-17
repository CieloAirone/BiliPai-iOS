import XCTest
final class SpaceUITests:XCTestCase {
    func testNativeSpaceSwitchesPostsAndDynamics() {
        let app = XCUIApplication();app.launchArguments = ["--regression-fixtures"];app.launch()
        app.buttons["空间测试"].tap()
        XCTAssertTrue(app.staticTexts["空间资料加载成功"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["空间投稿测试"].exists)
        app.segmentedControls.buttons["动态"].tap()
        XCTAssertTrue(app.staticTexts["空间动态加载成功"].waitForExistence(timeout:5))
        app.segmentedControls.buttons["投稿"].tap()
        XCTAssertTrue(app.staticTexts["空间投稿测试"].waitForExistence(timeout:5))
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "NativeSpace";shot.lifetime = .keepAlways;add(shot)
    }
    func testCardRatiosAndDurationRendering() {
        let app = XCUIApplication();app.launchArguments = ["--regression-fixtures","-durationStyle","outside","-compactStats","NO"];app.launch()
        app.buttons["卡片比例测试"].tap()
        XCTAssertTrue(app.staticTexts["2:05"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["1:01:01"].exists)
        for ratio in ["16:9","4:3","16:10"] {
            app.segmentedControls.buttons[ratio].tap()
            let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "VideoCards-\(ratio.replacingOccurrences(of:":",with:"x"))";shot.lifetime = .keepAlways;add(shot)
        }
    }
}
