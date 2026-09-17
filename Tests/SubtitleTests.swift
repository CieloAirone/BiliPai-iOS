import XCTest
import AVFoundation
@testable import BiliPai
final class SubtitleTests:XCTestCase {
    func testCueConversionEscapesMarkupAndSkipsInvalidTiming() throws {
        let data = try JSONSerialization.data(withJSONObject:["body":[["from":1.25,"to":3.5,"content":"你好 <字幕> & test"],["from":-1,"to":2,"content":"invalid"]]])
        let text = String(data:try WebVTT.convert(data),encoding:.utf8)!
        XCTAssertTrue(text.contains("00:00:01.250 --> 00:00:03.500"))
        XCTAssertTrue(text.contains("你好 &lt;字幕&gt; &amp; test"));XCTAssertFalse(text.contains("invalid"))
    }
    func testSubtitlePreferencesAndTrustedURLs() throws {
        let human = try XCTUnwrap(BiliSubtitle.parse(JSON(["id":1,"lan":"zh-CN","lan_doc":"中文","subtitle_url":"//aisubtitle.hdslb.com/subtitle/a.json"])))
        let ai = try XCTUnwrap(BiliSubtitle.parse(JSON(["id":2,"lan":"ai-zh","lan_doc":"中文 AI","subtitle_url":"https://aisubtitle.hdslb.com/subtitle/b.json"])))
        XCTAssertNil(BiliSubtitle.parse(JSON(["subtitle_url":"https://evil.example/subtitle/a"])))
        XCTAssertNil(SubtitlePolicy.preferred([human],mode:"off",muted:false))
        XCTAssertNil(SubtitlePolicy.preferred([ai],mode:"withoutAI",muted:true))
        XCTAssertNil(SubtitlePolicy.preferred([ai],mode:"auto",muted:false))
        XCTAssertEqual(SubtitlePolicy.preferred([ai],mode:"auto",muted:true)?.id,ai.id)
        XCTAssertEqual(SubtitlePolicy.preferred([ai,human],mode:"withoutAI",muted:false)?.id,human.id)
    }
    @MainActor func testNativePlayerDiscoversAndSelectsWebVTTTrack() async throws {
        let bundle = Bundle(for:Self.self)
        let data = try Data(contentsOf:XCTUnwrap(bundle.url(forResource:"video",withExtension:"mp4")))
        let track = DASHTrack(url:URL(fileURLWithPath:"/unused"),initialization:try ByteSpan("0-782"),segments:try SIDX.parse(data.subdata(in:783..<871),absoluteOffset:783),bandwidth:100000,codecs:"avc1.64000b")
        var resources:[String:HLSResource] = [:]
        let videoPath = track.install(name:"video",token:"fixture",resources:&resources)
        for key in Array(resources.keys) {
            if let range = resources[key]?.range { resources[key] = HLSResource(data:data.subdata(in:Int(range.start)..<Int(range.end+1)),mime:"video/mp4") }
        }
        let subtitle = BiliSubtitle(id:"1",name:"中文",language:"zh-CN",isAI:false,url:nil,inlineVTT:Data("WEBVTT\n\n00:00:00.000 --> 00:00:04.000\n字幕回归测试\n\n".utf8))
        let path = subtitle.install(index:0,token:"fixture",duration:4,resources:&resources)
        let ai = BiliSubtitle(id:"2",name:"中文 AI",language:"zh-CN",isAI:true,url:nil,inlineVTT:Data("WEBVTT\n\n00:00:00.000 --> 00:00:04.000\nAI 回归测试\n\n".utf8))
        let aiPath = ai.install(index:1,token:"fixture",duration:4,resources:&resources)
        let master = "#EXTM3U\n#EXT-X-VERSION:7\n" + ai.mediaLine(path:aiPath) + "\n" + subtitle.mediaLine(path:path) + "\n#EXT-X-STREAM-INF:BANDWIDTH=100000,CODECS=\"avc1.64000b\",SUBTITLES=\"subtitles\"\n\(videoPath)\n"
        resources["/fixture/master.m3u8"] = HLSResource(data:Data(master.utf8),mime:"application/vnd.apple.mpegurl")
        let bridge = HLSBridge(resources:resources,token:"fixture");defer { bridge.stop() }
        let asset = AVURLAsset(url:try await bridge.start())
        let loadedGroup = try await asset.loadMediaSelectionGroup(for:.legible)
        let group = try XCTUnwrap(loadedGroup)
        XCTAssertEqual(group.options.count,2)
        let preferred = try XCTUnwrap(SubtitlePolicy.preferred([ai,subtitle],mode:"withoutAI",muted:false))
        let option = try XCTUnwrap(preferred.option(in:group))
        let item = AVPlayerItem(asset:asset)
        let collector = SubtitleCollector()
        let output = AVPlayerItemLegibleOutput()
        output.setDelegate(collector,queue:.main);item.add(output)
        let player = AVPlayer(playerItem:item);player.appliesMediaSelectionCriteriaAutomatically = false
        item.select(option,in:group);player.play()
        defer { player.pause();player.replaceCurrentItem(with:nil) }
        for _ in 0..<50 {
            if player.currentTime().seconds > 1 && collector.strings.contains(where:{ $0.contains("字幕回归测试") }) { break }
            try await Task.sleep(for:.milliseconds(200))
        }
        XCTAssertTrue(collector.strings.contains(where:{ $0.contains("字幕回归测试") }))
        XCTAssertGreaterThan(player.currentTime().seconds,1)
        XCTAssertEqual(item.currentMediaSelection.selectedMediaOption(in:group),option)
    }
}

private final class SubtitleCollector:NSObject,AVPlayerItemLegibleOutputPushDelegate {
    var strings:[String] = []
    func legibleOutput(_ output:AVPlayerItemLegibleOutput,didOutputAttributedStrings strings:[NSAttributedString],nativeSampleBuffers:[Any],forItemTime itemTime:CMTime) {
        self.strings += strings.map(\.string)
    }
}
