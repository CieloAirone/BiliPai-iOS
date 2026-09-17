import XCTest
@testable import BiliPai

final class MediaTests: XCTestCase {
    private func index(version: UInt8 = 0, nested: Bool = false) -> Data {
        var data = Data()
        func append(_ value: UInt64, bytes: Int) { for i in (0..<bytes).reversed() { data.append(UInt8((value >> (i * 8)) & 255)) } }
        append(version == 0 ? 56 : 64, bytes: 4); data.append(contentsOf: "sidx".utf8)
        append(UInt64(version) << 24, bytes: 4); append(1, bytes: 4); append(1000, bytes: 4)
        append(0, bytes: version == 0 ? 4:8); append(10, bytes: version == 0 ? 4:8)
        append(0, bytes: 2); append(2, bytes: 2)
        append(nested ? 0x80000064:100, bytes: 4); append(2500, bytes: 4); append(0, bytes: 4)
        append(200, bytes: 4); append(3000, bytes: 4); append(0, bytes: 4)
        return data
    }
    func testSIDXV0OffsetsAndDuration() throws {
        let parts = try SIDX.parse(index(), absoluteOffset: 1000)
        XCTAssertEqual(parts.count,2)
        XCTAssertEqual(parts[0].range.start,1066); XCTAssertEqual(parts[0].range.end,1165)
        XCTAssertEqual(parts[1].range.start,1166); XCTAssertEqual(parts[1].range.length,200)
        XCTAssertEqual(parts[0].duration,2.5)
    }
    func testSIDXV1Offsets() throws { XCTAssertEqual(try SIDX.parse(index(version: 1), absoluteOffset: 1000)[0].range.start,1074) }
    func testRejectTruncationAndNestedIndexes() {
        XCTAssertThrowsError(try SIDX.parse(index().prefix(20), absoluteOffset: 0))
        XCTAssertThrowsError(try SIDX.parse(index(nested: true), absoluteOffset: 0))
    }
    func testByteRangeValidation() throws {
        XCTAssertEqual(try ByteSpan("100-199").length,100)
        XCTAssertThrowsError(try ByteSpan("200-100")); XCTAssertThrowsError(try ByteSpan(start: UInt64.max, length: 10))
    }
    func testHLSPlaylistIncludesAllSegmentsAndInitialization() throws {
        let track = DASHTrack(url: URL(string:"https://example.org/video.m4s")!, initialization: try ByteSpan("0-999"), segments: try SIDX.parse(index(), absoluteOffset:1000), bandwidth:100000, codecs:"avc1.640028")
        var resources: [String:HLSResource] = [:]
        let path = track.install(name:"video",token:"test",resources:&resources)
        let playlist = String(data:try XCTUnwrap(resources[path]?.data),encoding:.utf8)!
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-MAP:URI=\"/test/video/init.mp4\""))
        XCTAssertTrue(playlist.contains("#EXT-X-ENDLIST")); XCTAssertEqual(resources.count,4)
    }
}
