import XCTest
@testable import BiliPai
@MainActor final class FollowingTests:XCTestCase {
    func testPaginationRetryAndAccountReset() async {
        var fail = true
        let pages = FollowingPages { path,params in
            XCTAssertEqual(path,"/x/relation/followings")
            if fail { fail = false;throw URLError(.notConnectedToInternet) }
            let page = Int(params["pn"]!)!
            let rows = (0..<(page == 1 ? 50:1)).map { ["mid":String((page-1)*50+$0+1),"uname":"UP"] }
            return JSON(["list":rows,"total":51])
        }
        await pages.load(mid:"123",reset:true);XCTAssertFalse(pages.error.isEmpty)
        await pages.load(mid:"123");XCTAssertEqual(pages.items.count,50);XCTAssertFalse(pages.ended)
        await pages.load(mid:"123");XCTAssertEqual(pages.items.count,51);XCTAssertTrue(pages.ended)
        await pages.load(mid:"",reset:true);XCTAssertTrue(pages.items.isEmpty);XCTAssertEqual(pages.total,0)
    }
}
