import XCTest
@testable import BiliPai

final class CoreTests: XCTestCase {
    func testWBISigningReferenceVector() throws {
        let result = try WBI.sign(["foo":"114","bar":"514","baz":"1919810"], img:"7cd084941338484aae1ad9425b84077c", sub:"4932caff0ff746eab6f01bf08b70ac45", timestamp:1702204169)
        XCTAssertEqual(result["w_rid"], "6149fdadf571698ca7e6a567265cd0ee")
    }
    func testSigningSanitizesAndEncodes() throws {
        let result = try WBI.sign(["keyword":"a b!'()*中文"], img:String(repeating:"a",count:32), sub:String(repeating:"b",count:32), timestamp:1)
        XCTAssertEqual(result["keyword"], "a b中文")
        XCTAssertEqual(WBI.query(["q":"a b&中"]), "q=a%20b%26%E4%B8%AD")
    }
    func testRejectInvalidKeys() { XCTAssertThrowsError(try WBI.sign([:], img:"", sub:"", timestamp:0)) }
    func testSearchVideoNormalization() {
        let v = Video(JSON(["bvid":"BV123", "title":"<em class=\"keyword\">标题</em>","pic":"//i0.hdslb.com/a.jpg","author":"作者","play":123]))
        XCTAssertEqual(v.id,"BV123"); XCTAssertEqual(v.title,"标题"); XCTAssertEqual(v.cover,"https://i0.hdslb.com/a.jpg"); XCTAssertEqual(v.views,123)
    }
    func testHistoryVideoNormalization() {
        let v = Video(JSON(["history":["bvid":"BVhistory"],"cover":"https://example.org/a","author_name":"UP"])); XCTAssertEqual(v.id,"BVhistory"); XCTAssertEqual(v.author,"UP")
    }
    func testFullscreenOrientationUsesPresentationAspect() {
        XCTAssertEqual(VideoPlayerSurface.orientation(for: CGSize(width: 1920, height: 1080)), .landscapeRight)
        XCTAssertEqual(VideoPlayerSurface.orientation(for: CGSize(width: 1080, height: 1920)), .portrait)
        XCTAssertEqual(VideoPlayerSurface.orientation(for: .zero), .portrait)
    }
}
