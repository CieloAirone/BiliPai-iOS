import XCTest
@testable import BiliPai
final class DanmakuTests: XCTestCase {
    func testDecodeProtobufComment() throws {
        let text = Array("测试".utf8)
        let element: [UInt8] = [8,1,16,232,7,24,1,40,255,255,255,7,58,UInt8(text.count)] + text
        let result = try Proto.danmaku(Data([10,UInt8(element.count)] + element))
        XCTAssertEqual(result.count,1); XCTAssertEqual(result[0].text,"测试"); XCTAssertEqual(result[0].time,1); XCTAssertEqual(result[0].color,0xffffff)
    }
    func testRejectTruncatedAndOverflowVarints() {
        XCTAssertThrowsError(try Proto.fields(Data([10,100,1])))
        XCTAssertThrowsError(try Proto.fields(Data([8] + Array(repeating: 255, count: 10))))
        XCTAssertThrowsError(try Proto.fields(Data([0])))
    }
}
