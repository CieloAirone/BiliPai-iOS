import SwiftUI

@MainActor @Observable final class FollowingPages {
    typealias Fetch = (String,[String:String]) async throws -> JSON
    private let fetch:Fetch
    var items:[JSON] = []
    var loading = false
    var error = ""
    var ended = false
    var total = 0
    private var page = 0
    private var generation = UUID()
    init(fetch:@escaping Fetch = { path,params in try await BiliAPI.shared.request(path,params) }) { self.fetch = fetch }
    func load(mid:String,reset:Bool = false) async {
        if reset { generation = UUID();items = [];page = 0;ended = false;loading = false;total = 0;error = "" }
        guard !mid.isEmpty,!loading,!ended else { return }
        let requestID = generation
        loading = true;error = ""
        defer { if requestID == generation { loading = false } }
        do {
            let next = page+1
            let data = try await fetch("/x/relation/followings",["vmid":mid,"pn":String(next),"ps":"50","order_type":""])
            try Task.checkCancellation()
            guard generation == requestID else { return }
            let rows = data["list"].array.filter { !$0["mid"].string.isEmpty }
            var seen = Set<String>()
            items = (items+rows).filter { seen.insert($0["mid"].string).inserted }
            page = next;total = data["total"].int
            ended = rows.isEmpty || (total > 0 ? next*50 >= total:rows.count < 50)
        } catch { if requestID == generation && !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
struct FollowingsView:View {
    @Environment(Session.self) private var session
    @State private var pages = FollowingPages()
    var body:some View {
        List {
            if !session.loggedIn {
                ContentUnavailableView("登录后查看我的关注",systemImage:"person.2")
                NavigationLink("登录账号") { LoginView() }
            } else {
                Section(pages.total > 0 ? "已关注 \(pages.total) 人":"我的关注") {
                    ForEach(pages.items,id:\.followingID) { user in
                        NavigationLink { WebScreen(url:URL(string:"https://space.bilibili.com/\(user.followingID)")!,title:user["uname"].string) } label: {
                            HStack(spacing:12) {
                                Cover(url:user["face"].string).frame(width:48,height:48).clipShape(Circle())
                                VStack(alignment:.leading,spacing:5) {
                                    Text(user["uname"].string).font(.body.weight(.medium))
                                    Text(user["sign"].string).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }.padding(.vertical,4)
                        }
                    }
                }
                if pages.loading { ProgressView("加载关注列表") }
                if !pages.error.isEmpty { Text(pages.error).foregroundStyle(.red);Button("重试") { Task { await pages.load(mid:session.mid) } } }
                else if !pages.loading && !pages.ended { Button("加载更多") { Task { await pages.load(mid:session.mid) } } }
                else if !pages.loading && pages.items.isEmpty { Text("暂无关注").foregroundStyle(.secondary) }
            }
        }.navigationTitle("我的关注").navigationBarTitleDisplayMode(.inline)
            .task(id:session.mid) { await pages.load(mid:session.mid,reset:true) }
            .refreshable { await pages.load(mid:session.mid,reset:true) }
    }
}
extension JSON { var followingID:String { self["mid"].string } }
