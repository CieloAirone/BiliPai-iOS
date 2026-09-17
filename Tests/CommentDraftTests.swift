import XCTest
@testable import BiliPai
final class CommentDraftTests:XCTestCase {
    func testTopLevelAndNestedReplyTargets() {
        let root = BiliComment(JSON(["rpid":"10","root":0]))
        let nested = BiliComment(JSON(["rpid":"12","root":"10","parent":"11"]))
        XCTAssertEqual(CommentDraft.topLevel.parameters(oid:"123",message:"test")["root"],"0")
        let topReply = CommentDraft.reply(to:root).parameters(oid:"123",message:"test")
        XCTAssertEqual(topReply["root"],"10");XCTAssertEqual(topReply["parent"],"10")
        let nestedReply = CommentDraft.reply(to:nested).parameters(oid:"123",message:"test")
        XCTAssertEqual(nestedReply["root"],"10");XCTAssertEqual(nestedReply["parent"],"12")
    }
}
