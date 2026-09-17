#if DEBUG
import SwiftUI
import AVKit

// Deterministic video and reply data for simulator regression tests only.
struct RegressionFixtureRoot:View {
    var body:some View {
        NavigationStack {
            List {
                NavigationLink("窄屏分类测试") { HomeCategoryBar(tabs:NavigationOptions.top,selected:"推荐",select:{ _ in }).frame(width:288).padding(.horizontal,16).frame(maxWidth:.infinity).navigationTitle("窄屏分类测试") }
                NavigationLink("播放器测试") { PlayerRegressionFixture() }
                NavigationLink("评论测试") { CommentThreadView(oid:"123",root:Self.root,loader:Self.replies) }
            }.navigationTitle("回归测试")
        }
    }
    static var root:BiliComment { BiliComment(JSON(["rpid":"1","rcount":21,"member":["uname":"顶楼作者"],"content":["message":"这是顶楼评论"]])) }
    static func replies(_ path:String,_ params:[String:String]) async throws -> JSON {
        let page = Int(params["pn"] ?? "1") ?? 1
        var replies:[[String:Any]] = []
        let count = page == 1 ? 20:1
        for i in 0..<count {
            let message = page == 2 ? "这是回复的回复":"楼内回复 \(i+1)"
            let id = String((page-1)*20+i+2)
            let parent = page == 2 ? "2":"1"
            let row:[String:Any] = ["rpid":id,"root":"1","parent":parent,"member":["uname":"回复用户"],"content":["message":message]]
            replies.append(row)
        }
        return JSON(["page":["count":21],"replies":replies])
    }
}
struct PlayerRegressionFixture:View {
    @State private var player = AVPlayer()
    @State private var released = false
    @State private var frames = 0
    @State private var output = AVPlayerItemVideoOutput(pixelBufferAttributes:nil)
    var body:some View {
        VStack {
            NativePlayer(player:player,onRelease:{ released = true;player.pause();player.replaceCurrentItem(with:nil) }).frame(height:260)
            Text(released ? "媒体已释放":"媒体仍加载").accessibilityIdentifier("fixture.lifetime")
            Text("\(frames)").accessibilityIdentifier("fixture.frames")
            Spacer()
        }.navigationTitle("播放器测试")
        .onReceive(NotificationCenter.default.publisher(for:.AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,item === player.currentItem else { return }
            player.seek(to:.zero);player.play()
        }
        .task {
            if player.currentItem == nil, let url = Bundle.main.url(forResource:"regression-video",withExtension:"mp4") {
                let item = AVPlayerItem(url:url)
                player.replaceCurrentItem(with:item)
                player.play()
            }
            while !Task.isCancelled {
                if let item = player.currentItem {
                    if !item.outputs.contains(where:{ $0 === output }) { item.add(output) }
                    let time = output.itemTime(forHostTime:CACurrentMediaTime())
                    if output.copyPixelBuffer(forItemTime:time,itemTimeForDisplay:nil) != nil { frames += 1 }
                }
                try? await Task.sleep(for:.milliseconds(200))
            }
        }
    }
}
enum CatalogFixture {
    static func request(_ path:String,_ params:[String:String]) async throws -> JSON {
        if path == "/pgc/season/index/result" {
            guard params["type"] == "1",params["st"] == "1" else { throw BiliError(message:"请求错误（-400）") }
            let page = params["page"] ?? "1"
            return JSON(["has_next":page == "1" ? 1:0,"list":[["season_id":page,"title":"测试番剧 \(page)","index_show":"全 1 话"]]])
        }
        if path == "/pgc/view/web/season" { return JSON(["title":"测试番剧详情","evaluate":"详情加载成功","episodes":[["id":100,"cid":200,"title":"1","long_title":"第一话"]]]) }
        throw BiliError(message:"非预期的测试请求")
    }
}
#endif
