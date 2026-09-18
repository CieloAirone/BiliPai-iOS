import XCTest
final class RegressionTests:XCTestCase {
    func testAutomaticFullscreenAndReturnWithoutReopening() {
        let app = XCUIApplication();app.launchArguments = ["--regression-fixtures","-autoFullscreen","YES"];app.launch()
        app.buttons["播放器测试"].tap()
        let close = app.buttons["退出自动全屏"]
        if !close.waitForExistence(timeout:5) { app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap() }
        XCTAssertTrue(close.waitForExistence(timeout:5),app.debugDescription)
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "AutomaticFullscreen";shot.lifetime = .keepAlways;add(shot)
        close.tap()
        XCTAssertTrue(app.staticTexts["媒体仍加载"].waitForExistence(timeout:5))
        let frames = app.staticTexts["fixture.frames"]
        let before = Int(frames.label) ?? 0
        let advancing = NSPredicate { _,_ in (Int(frames.label) ?? 0) > before+5 }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:advancing,object:nil)],timeout:10),.completed)
        XCTAssertTrue(app.navigationBars["播放器测试"].exists)
    }

    func testAutomaticFullscreenHasLeftBrightnessAndRightVolumeZonesWithHUD() {
        let app = XCUIApplication(); app.launchArguments = ["--regression-fixtures","-autoFullscreen","YES"]; app.launch()
        app.buttons["播放器测试"].tap()
        XCTAssertTrue(app.buttons["退出自动全屏"].waitForExistence(timeout: 8), app.debugDescription)
        // The overlay is explicitly two equal zones. Swipe in each half and
        // require the corresponding live percentage HUD immediately.
        let frame = app.windows.firstMatch.frame
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.68)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.32)), withVelocity: .default, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.staticTexts.matching(identifier: "player.hud.亮度").firstMatch.waitForExistence(timeout: 1), app.debugDescription)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.68)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.32)), withVelocity: .default, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.staticTexts.matching(identifier: "player.hud.音量").firstMatch.waitForExistence(timeout: 1), app.debugDescription)
        _ = frame // keep the intended full-screen coordinate reference explicit
    }

    func testNativeFullscreenKeepsVideoFramesAndReturnsInline() {
        let app = XCUIApplication();app.launchArguments = ["--regression-fixtures"];app.launch()
        app.buttons["播放器测试"].tap()
        let frames = app.staticTexts["fixture.frames"]
        let playing = NSPredicate { _,_ in (Int(frames.label) ?? 0) > 2 }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:playing,object:nil)],timeout:15),.completed)
        let fullscreen = app.buttons.matching(NSPredicate(format:"label CONTAINS[c] 'full' OR label CONTAINS '全屏'")).firstMatch
        if !fullscreen.exists { app.otherElements["Video"].firstMatch.tap() }
        XCTAssertTrue(fullscreen.waitForExistence(timeout:5),app.debugDescription)
        fullscreen.tap()
        let pause = app.buttons.matching(NSPredicate(format:"label CONTAINS[c] 'pause' OR label CONTAINS '暂停'")).firstMatch
        if !pause.exists { app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap() }
        XCTAssertTrue(pause.waitForExistence(timeout:5),app.debugDescription)
        XCTAssertFalse(app.navigationBars["播放器测试"].exists)
        let screenshot = XCTAttachment(screenshot:app.screenshot());screenshot.name = "NativeFullscreenVideo";screenshot.lifetime = .keepAlways;add(screenshot)
        let close = app.buttons.matching(NSPredicate(format:"label CONTAINS[c] 'full' OR label CONTAINS[c] 'done' OR label CONTAINS[c] 'close' OR label CONTAINS[c] 'minimize' OR label CONTAINS '退出全屏' OR label == '完成'")).firstMatch
        if !close.exists { app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap() }
        XCTAssertTrue(close.waitForExistence(timeout:2),app.debugDescription);close.tap()
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
