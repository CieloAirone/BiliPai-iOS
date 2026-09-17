import XCTest
@testable import BiliPai
@MainActor
final class CommentTests:XCTestCase {
    func testReplyThreadPaginationUsesRootAndPreservesReplyParents() async {
        var requests:[[String:String]] = []
        let pages = CommentPages { path,params in
            XCTAssertEqual(path,"/x/v2/reply/reply");requests.append(params)
            let page = Int(params["pn"]!)!
            let rows = (0..<(page == 1 ? 20:1)).map { i -> [String:Any] in
                ["rpid_str":String((page-1)*20+i+2),"root_str":"1","parent_str":page == 2 ? "2":"1","member":["uname":"用户"],"content":["message":"回复"]]
            }
            return JSON(["page":["count":21],"replies":rows])
        }
        await pages.load(oid:"123",root:"1")
        XCTAssertEqual(pages.items.count,20);XCTAssertFalse(pages.end)
        await pages.load(oid:"123",root:"1")
        XCTAssertEqual(pages.items.count,21);XCTAssertTrue(pages.end)
        XCTAssertEqual(pages.items.last?.parentID,"2");XCTAssertEqual(requests.last?["pn"],"2");XCTAssertEqual(requests.first?["root"],"1")
    }
    func testPinnedCommentDeduplicatedAndFailureCanRetry() async {
        var count = 0
        let root:[String:Any] = ["rpid":1,"rcount":8,"member":["uname":"作者"],"content":["message":"顶楼"],"replies":[["rpid":2,"parent":1,"root":1,"content":["message":"预览"]]]]
        let pages = CommentPages { _,_ in
            count += 1;if count == 1 { throw URLError(.notConnectedToInternet) }
            return JSON(["top":["upper":root],"replies":[root],"page":["count":1]])
        }
        await pages.load(oid:"123");XCTAssertFalse(pages.error.isEmpty);XCTAssertEqual(pages.page,0)
        await pages.load(oid:"123");XCTAssertEqual(pages.items.count,1);XCTAssertEqual(pages.items.first?.previews.first?.parentID,"1");XCTAssertTrue(pages.error.isEmpty)
    }
}
