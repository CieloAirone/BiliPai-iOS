#if DEBUG
import SwiftUI
import AVKit

// Deterministic video and reply data for simulator regression tests only.
struct RegressionFixtureRoot:View {
    var body:some View {
        NavigationStack {
            List {
                NavigationLink("空间测试") { SpaceView(mid:"123",request:SpaceFixture.request) }
                NavigationLink("卡片比例测试") { VideoCardFixture() }
                NavigationLink("窄屏分类测试") { HomeCategoryBar(tabs:NavigationOptions.top,selected:"推荐",select:{ _ in }).frame(width:288).padding(.horizontal,16).frame(maxWidth:.infinity).navigationTitle("窄屏分类测试") }
                NavigationLink("竖屏播放器测试") { PlayerRegressionFixture(portrait:true) }
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
    var portrait = false
    @State private var player = AVPlayer()
    @State private var released = false
    @State private var frames = 0
    @State private var output = AVPlayerItemVideoOutput(pixelBufferAttributes:nil)
    var body:some View {
        VStack {
            VideoPlayerSurface(player:player,onRelease:{ released = true;player.pause();player.replaceCurrentItem(with:nil) }).frame(height:260)
            Text(released ? "媒体已释放":"媒体仍加载").accessibilityIdentifier("fixture.lifetime")
            Text("\(frames)").accessibilityIdentifier("fixture.frames")
            Spacer()
        }.navigationTitle("播放器测试")
        .onReceive(NotificationCenter.default.publisher(for:.AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,item === player.currentItem else { return }
            player.seek(to:.zero);player.play()
        }
        .task {
            if player.currentItem == nil, let url = Bundle.main.url(forResource:portrait ? "regression-portrait":"regression-video",withExtension:"mp4") {
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
enum SpaceFixture {
    static func request(_ path:String,_ params:[String:String],_ signed:Bool) async throws -> JSON {
        switch path {
        case "/x/space/wbi/acc/info":return JSON(["name":"测试 UP 主","sign":"空间资料加载成功"])
        case "/x/relation/stat":return JSON(["following":12,"follower":34])
        case "/x/space/wbi/arc/search":return JSON(["list":["vlist":[["bvid":"BVfixture","title":"空间投稿测试","length":"12:34"]]],"page":["count":1]])
        case "/x/polymer/web-dynamic/v1/feed/space":return JSON(["items":[["id_str":"1","modules":["module_author":["name":"测试 UP 主"],"module_dynamic":["desc":["text":"空间动态加载成功"]]]]],"has_more":0])
        default:throw BiliError(message:"非预期空间请求")
        }
    }
}
struct VideoCardFixture:View {
    @AppStorage("coverRatio") private var ratio = "16:10"
    var body:some View {
        VStack {
            Picker("封面比例",selection:$ratio) { ForEach(["16:9","4:3","16:10"],id:\.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
            HStack(alignment:.top,spacing:14) {
                VideoCard(video:Video(JSON(["bvid":"1","title":"用于检查两列卡片标题、时长和封面尺寸","author":"测试作者","duration":125,"play":10000])))
                VideoCard(video:Video(JSON(["bvid":"2","title":"短标题","author":"测试作者","duration":3661,"play":200])))
            }
            Spacer()
        }.padding().navigationTitle("卡片比例测试")
    }
}
#endif
