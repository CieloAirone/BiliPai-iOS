import XCTest
@testable import BiliPai
final class FavoriteTests:XCTestCase {
    func testSaveOnlyChangedFolders() {
        let params = FavoriteChanges.parameters(aid:"123",original:["1","2"],selected:["2","3"])
        XCTAssertEqual(params["rid"],"123");XCTAssertEqual(params["type"],"2")
        XCTAssertEqual(params["add_media_ids"],"3");XCTAssertEqual(params["del_media_ids"],"1")
    }
}
