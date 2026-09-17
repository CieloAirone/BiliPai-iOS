import XCTest
import AVFoundation
@testable import BiliPai

final class PlaybackTests: XCTestCase {
    @MainActor
    func testDASHBridgePlaysAudioAndVideoOnSimulator() async throws {
        let bundle = Bundle(for: Self.self)
        var resources: [String: HLSResource] = [:]
        func install(_ name: String, initEnd: UInt64, indexStart: Int, indexLength: Int, codec: String) throws -> String {
            let url = try XCTUnwrap(bundle.url(forResource:name, withExtension:"mp4"))
            let data = try Data(contentsOf:url)
            let segments = try SIDX.parse(data.subdata(in:indexStart..<(indexStart + indexLength)), absoluteOffset:UInt64(indexStart))
            let track = DASHTrack(url:url, initialization:try ByteSpan(start:0,length:initEnd + 1), segments:segments, bandwidth:100000, codecs:codec)
            let path = track.install(name:name,token:"fixture",resources:&resources)
            for key in Array(resources.keys) where key.hasPrefix("/fixture/\(name)/") {
                guard let range = resources[key]?.range else { continue }
                resources[key] = HLSResource(data:data.subdata(in:Int(range.start)..<Int(range.end + 1)),mime:"video/mp4")
            }
            return path
        }
        let video = try install("video",initEnd:782,indexStart:783,indexLength:88,codec:"avc1.64000b")
        let audio = try install("audio",initEnd:732,indexStart:733,indexLength:52,codec:"mp4a.40.2")
        let master = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Audio",DEFAULT=YES,AUTOSELECT=YES,URI="\(audio)"
        #EXT-X-STREAM-INF:BANDWIDTH=200000,CODECS="avc1.64000b,mp4a.40.2",AUDIO="audio"
        \(video)
        """
        resources["/fixture/master.m3u8"] = HLSResource(data:Data(master.utf8),mime:"application/vnd.apple.mpegurl")
        let bridge = HLSBridge(resources:resources,token:"fixture")
        defer { bridge.stop() }
        let url = try await bridge.start()
        let item = AVPlayerItem(url:url)
        let player = AVPlayer(playerItem:item)
        defer { player.pause(); player.replaceCurrentItem(with:nil) }
        player.play()
        for _ in 0..<100 {
            if item.status == .failed { XCTFail(item.error?.localizedDescription ?? "Player failed"); return }
            if player.currentTime().seconds > 1 {
                XCTAssertEqual(item.status,.readyToPlay)
                XCTAssertGreaterThan(item.presentationSize.width,0)
                return
            }
            try await Task.sleep(for:.milliseconds(200))
        }
        XCTFail("HLS playback did not advance: \(item.error?.localizedDescription ?? "no player error")")
    }
}
