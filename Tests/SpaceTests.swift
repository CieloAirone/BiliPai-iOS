import XCTest
@testable import BiliPai
@MainActor final class SpaceTests:XCTestCase {
    func testVideoPaginationRetryAndSortReset() async {
        var fail = true
        let pages = SpacePages { path,params,signed in
            XCTAssertEqual(path,"/x/space/wbi/arc/search");XCTAssertTrue(signed)
            XCTAssertEqual(params["mid"],"123")
            if fail { fail = false;throw URLError(.notConnectedToInternet) }
            let page = Int(params["pn"]!)!
            let rows = (0..<(page == 1 ? 30:1)).map { ["bvid":"BV\((page-1)*30+$0)","title":"投稿"] }
            return JSON(["list":["vlist":rows],"page":["count":31]])
        }
        await pages.load(mid:"123",tab:"投稿",order:"pubdate",reset:true)
        XCTAssertFalse(pages.error.isEmpty)
        await pages.load(mid:"123",tab:"投稿",order:"pubdate")
        XCTAssertEqual(pages.videos.count,30);XCTAssertFalse(pages.ended)
        await pages.load(mid:"123",tab:"投稿",order:"pubdate")
        XCTAssertEqual(pages.videos.count,31);XCTAssertTrue(pages.ended)
        await pages.load(mid:"123",tab:"投稿",order:"click",reset:true)
        XCTAssertEqual(pages.videos.count,30);XCTAssertTrue(pages.error.isEmpty)
    }
    func testDynamicDeduplicationAndStalledCursor() async {
        var calls = 0
        let pages = SpacePages { path,params,signed in
            calls += 1
            XCTAssertEqual(path,"/x/polymer/web-dynamic/v1/feed/space");XCTAssertFalse(signed)
            XCTAssertEqual(params["host_mid"],"123")
            XCTAssertEqual(params["offset"],calls == 1 ? "":"cursor")
            return JSON(["items":[["id_str":"one"],["id_str":"one"]],"offset":"cursor","has_more":1])
        }
        await pages.load(mid:"123",tab:"动态",order:"pubdate",reset:true)
        XCTAssertEqual(pages.dynamics.count,1);XCTAssertFalse(pages.ended)
        await pages.load(mid:"123",tab:"动态",order:"pubdate")
        XCTAssertTrue(pages.ended);XCTAssertEqual(pages.dynamics.count,1)
        await pages.load(mid:"",tab:"动态",order:"pubdate",reset:true)
        XCTAssertTrue(pages.dynamics.isEmpty)
    }
}
