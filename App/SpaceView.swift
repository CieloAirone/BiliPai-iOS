import SwiftUI

@MainActor @Observable final class SpacePages {
    typealias Fetch = (String,[String:String],Bool) async throws -> JSON
    private let fetch:Fetch
    private var generation = UUID()
    private var page = 0
    private var offset = ""
    var videos:[Video] = []
    var dynamics:[JSON] = []
    var loading = false
    var ended = false
    var error = ""
    init(fetch:@escaping Fetch = { path,params,signed in try await BiliAPI.shared.request(path,params,signed:signed) }) { self.fetch = fetch }
    func load(mid:String,tab:String,order:String,reset:Bool = false) async {
        if reset { generation = UUID();page = 0;offset = "";videos = [];dynamics = [];loading = false;ended = false;error = "" }
        guard !mid.isEmpty,!loading,!ended else { return }
        let requestID = generation
        loading = true;error = ""
        defer { if generation == requestID { loading = false } }
        do {
            if tab == "投稿" {
                let next = page+1
                let data = try await fetch("/x/space/wbi/arc/search",["mid":mid,"pn":String(next),"ps":"30","order":order,"tid":"0","keyword":""],true)
                try Task.checkCancellation()
                guard generation == requestID else { return }
                let rows = data["list"]["vlist"].array.map(Video.init).filter { !$0.id.isEmpty }
                var seen = Set<String>()
                videos = (videos+rows).filter { seen.insert($0.id).inserted }
                page = next
                let count = data["page"]["count"].int
                ended = rows.isEmpty || (count > 0 ? next*30 >= count:rows.count < 30)
            } else {
                let previous = offset
                let data = try await fetch("/x/polymer/web-dynamic/v1/feed/space",["host_mid":mid,"offset":offset,"timezone_offset":"-480"],false)
                try Task.checkCancellation()
                guard generation == requestID else { return }
                var seen = Set<String>()
                dynamics = (dynamics+data["items"].array).filter { !$0.rawID.isEmpty && seen.insert($0.rawID).inserted }
                offset = data["offset"].string
                ended = data["has_more"].int != 1 || offset.isEmpty || offset == previous
            }
        } catch { if generation == requestID && !Task.isCancelled { self.error = error.localizedDescription } }
    }
}

struct SpaceView:View {
    let mid:String
    var initialName = "UP 主空间"
    @Environment(Session.self) private var session
    @State private var profile = JSON()
    @State private var stats = JSON()
    @State private var pages = SpacePages()
    @State private var tab = "投稿"
    @State private var order = "pubdate"
    @State private var profileError = ""
    @State private var relationError = ""
    @State private var following:Bool?
    @State private var changing = false
    @State private var confirmUnfollow = false
    private var identity:String { "\(mid)|\(tab)|\(order)|\(session.revision)" }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                header
                if !profileError.isEmpty { FailureView(message:profileError) { Task { await loadProfile() } } }
                Picker("空间内容",selection:$tab) { Text("投稿").tag("投稿");Text("动态").tag("动态") }.pickerStyle(.segmented)
                if tab == "投稿" {
                    Picker("投稿排序",selection:$order) { Text("最新发布").tag("pubdate");Text("最多播放").tag("click");Text("最多收藏").tag("stow") }.pickerStyle(.segmented)
                    VideoGrid(videos:pages.videos)
                } else {
                    LazyVStack(spacing:16) { ForEach(pages.dynamics,id:\.rawID) { DynamicCard(item:$0) } }
                }
                if pages.loading { ProgressView("加载空间内容").frame(maxWidth:.infinity) }
                if !pages.error.isEmpty { FailureView(message:pages.error) { Task { await loadContent() } } }
                else if !pages.loading && !pages.ended { Button("加载更多") { Task { await loadContent() } }.frame(maxWidth:.infinity) }
                else if !pages.loading && pages.videos.isEmpty && pages.dynamics.isEmpty { ContentUnavailableView("暂无\(tab)",systemImage:tab == "投稿" ? "play.rectangle":"text.bubble") }
            }.padding()
        }.navigationTitle(profile["name"].string.isEmpty ? initialName:profile["name"].string).navigationBarTitleDisplayMode(.inline)
            .task(id:"\(mid)|\(session.revision)") { await loadProfile() }
            .task(id:identity) { await loadContent(reset:true) }
            .refreshable { await loadProfile();await loadContent(reset:true) }
            .confirmationDialog("取消关注这位 UP 主？",isPresented:$confirmUnfollow,titleVisibility:.visible) { Button("取消关注",role:.destructive) { Task { await modifyFollow(false) } } }
    }
    private var header:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:14) {
                Cover(url:profile["face"].string).frame(width:64,height:64).clipShape(Circle())
                VStack(alignment:.leading,spacing:5) {
                    Text(profile["name"].string.isEmpty ? initialName:profile["name"].string).font(.title3.bold())
                    Text("UID \(mid)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if mid != session.mid {
                    if !session.loggedIn { NavigationLink("登录后关注") { LoginView() } }
                    else if let following {
                        Button(following ? "已关注":"关注") { if following { confirmUnfollow = true } else { Task { await modifyFollow(true) } } }.buttonStyle(.bordered).disabled(changing)
                    }
                }
            }
            if !profile["sign"].string.isEmpty { Text(profile["sign"].string).font(.subheadline).foregroundStyle(.secondary) }
            HStack(spacing:24) {
                Text("关注 \(stats["following"].string.isEmpty ? "—":stats["following"].string)")
                Text("粉丝 \(stats["follower"].string.isEmpty ? "—":stats["follower"].string)")
            }.font(.subheadline)
            if !relationError.isEmpty { Text(relationError).font(.caption).foregroundStyle(.red);Button("重试关注状态") { Task { await loadRelation() } } }
        }
    }
    private func loadContent(reset:Bool = false) async { await pages.load(mid:mid,tab:tab,order:order,reset:reset) }
    private func loadProfile() async {
        profileError = ""
        do {
            let data = try await BiliAPI.shared.request("/x/space/wbi/acc/info",["mid":mid],signed:true)
            try Task.checkCancellation();profile = data
        } catch { if !Task.isCancelled { profileError = error.localizedDescription } }
        do { let data = try await BiliAPI.shared.request("/x/relation/stat",["vmid":mid]);try Task.checkCancellation();stats = data }
        catch { if !Task.isCancelled { profileError += "\n"+error.localizedDescription } }
        await loadRelation()
    }
    private func loadRelation() async {
        following = nil;relationError = ""
        guard session.loggedIn,mid != session.mid else { return }
        let account = session.mid
        do {
            let data = try await BiliAPI.shared.request("/x/relation",["fid":mid])
            try Task.checkCancellation();guard session.mid == account else { return }
            following = [2,6].contains(data["attribute"].int)
        } catch { if !Task.isCancelled && session.mid == account { relationError = error.localizedDescription } }
    }
    private func modifyFollow(_ follow:Bool) async {
        guard !changing else { return };changing = true;defer { changing = false }
        relationError = ""
        do {
            _ = try await BiliAPI.shared.request("/x/relation/modify",["fid":mid,"act":follow ? "1":"2","re_src":"11"],post:true)
            following = follow
        } catch { relationError = error.localizedDescription }
    }
}
