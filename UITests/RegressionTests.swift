import XCTest
final class RegressionTests:XCTestCase {
    func testNativeFullscreenKeepsVideoFramesAndReturnsInline() {
        let app = XCUIApplication();app.launchArguments = ["--regression-fixtures"];app.launch()
        app.buttons["播放器测试"].tap()
        let frames = app.staticTexts["fixture.frames"]
        let playing = NSPredicate { _,_ in (Int(frames.label) ?? 0) > 2 }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:playing,object:nil)],timeout:15),.completed)
        let fullscreen = app.buttons.matching(NSPredicate(format:"label CONTAINS[c] 'full' OR label CONTAINS '全屏'")).firstMatch
        XCTAssertTrue(fullscreen.waitForExistence(timeout:5),app.debugDescription)
        fullscreen.tap()
        let pause = app.buttons.matching(NSPredicate(format:"label CONTAINS[c] 'pause' OR label CONTAINS '暂停'")).firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout:5),app.debugDescription)
        let screenshot = XCTAttachment(screenshot:app.screenshot());screenshot.name = "NativeFullscreenVideo";screenshot.lifetime = .keepAlways;add(screenshot)
        let close = app.buttons.matching(NSPredicate(format:"label CONTAINS[c] 'full' OR label == 'Done' OR label == 'Close' OR label CONTAINS '退出全屏' OR label == '完成'")).firstMatch
        XCTAssertTrue(close.exists,app.debugDescription);close.tap()
        XCTAssertTrue(app.staticTexts["媒体仍加载"].waitForExistence(timeout:5))
        let before = Int(frames.label) ?? 0
        let advancing = NSPredicate { _,_ in (Int(frames.label) ?? 0) > before + 2 }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:advancing,object:nil)],timeout:10),.completed)
        let inline = XCTAttachment(screenshot:app.screenshot());inline.name = "VideoAfterFullscreen";inline.lifetime = .keepAlways;add(inline)
    }
    func testReplyPaginationAndParentQuote() {
        let app = XCUIApplication();app.launchArguments = ["--regression-fixtures"];app.launch()
        app.buttons["评论测试"].tap()
        XCTAssertTrue(app.staticTexts["全部回复 · 已加载 20 条"].waitForExistence(timeout:5))
        let more = app.buttons["加载更多回复"]
        for _ in 0..<18 { if more.isHittable { break };app.swipeUp() }
        XCTAssertTrue(more.isHittable);more.tap()
        for _ in 0..<4 { if app.staticTexts["这是回复的回复"].isHittable { break };app.swipeUp() }
        XCTAssertTrue(app.staticTexts["这是回复的回复"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["回复 @回复用户"].exists)
        XCTAssertFalse(more.exists)
        let screenshot = XCTAttachment(screenshot:app.screenshot());screenshot.name = "CommentReplyParent";screenshot.lifetime = .keepAlways;add(screenshot)
    }
}
