import XCTest
@testable import BiliPai
final class VideoPresentationTests:XCTestCase {
    func testDurationAcrossVideoAndSpacePayloads() {
        XCTAssertEqual(Video(JSON(["duration":3661])).duration,"1:01:01")
        XCTAssertEqual(Video(JSON(["length":"12:34"])).duration,"12:34")
        XCTAssertNil(Video(JSON(["duration":0])).duration)
        XCTAssertNil(VideoPresentation.duration("not:time"))
    }
    func testOlderSavedVideoDecodesWithoutDuration() throws {
        let data = Data(#"{"id":"BV1","title":"旧视频","cover":"","author":"UP","views":1}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(Video.self,from:data).duration)
    }
}
