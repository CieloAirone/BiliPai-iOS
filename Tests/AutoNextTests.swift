import XCTest
@testable import BiliPai
final class AutoNextTests:XCTestCase {
    func testNextVideoOnlyAfterFinalPart() {
        let pages = [JSON(["cid":"1"]),JSON(["cid":"2"])]
        XCTAssertEqual(PlaybackOptions.nextCID(current:"1",pages:pages,behavior:"auto"),"2")
        XCTAssertNil(PlaybackOptions.nextCID(current:"2",pages:pages,behavior:"auto"))
        XCTAssertNil(PlaybackOptions.nextCID(current:"1",pages:pages,behavior:"pause"))
    }
}
