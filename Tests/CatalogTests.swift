import XCTest
@testable import BiliPai
final class CatalogTests:XCTestCase {
    func testIndexRequiredParametersAndPaginationEnd() {
        let query = CatalogRequest.bangumi(page:2)
        XCTAssertEqual(query["type"],"1");XCTAssertEqual(query["st"],query["season_type"]);XCTAssertEqual(query["page"],"2")
        XCTAssertTrue(CatalogRequest.hasNext(JSON(["list":[["season_id":1]],"has_next":1])))
        XCTAssertFalse(CatalogRequest.hasNext(JSON(["list":[["season_id":1]],"has_next":0])))
        XCTAssertFalse(CatalogRequest.hasNext(JSON(["list":[],"has_next":1])))
    }
}
