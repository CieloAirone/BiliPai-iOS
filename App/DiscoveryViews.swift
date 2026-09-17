import SwiftUI

struct DynamicView: View {
    @AppStorage("incrementalDynamicRefresh") private var incremental = false
    @AppStorage("dynamicLayout") private var layout = "list"
    @Environment(Session.self) private var session
    @State private var items: [JSON] = []
    @State private var offset = ""
    @State private var more = true
    @State private var busy = false
    @State private var error = ""
    var body: some View {
        ScrollView {
            if !session.loggedIn { ContentUnavailableView("登录后查看关注动态", systemImage: "person.crop.circle"); NavigationLink("登录") { LoginView() } }
            LazyVGrid(columns:layout == "grid" ? [GridItem(.adaptive(minimum:280),alignment:.top)]:[GridItem(.flexible())],alignment:.leading,spacing:20) {
                ForEach(items, id: \.rawID) { item in
                    DynamicCard(item: item)
                }
                if busy { ProgressView().frame(maxWidth: .infinity) }
                if !error.isEmpty { FailureView(message: error) { Task { await load(reset: true) } } }
                if session.loggedIn && !busy && more { Button("加载更多") { Task { await load(reset: false) } } }
            }.padding()
        }.navigationTitle("动态").task(id: session.revision) { items = [];offset = "";more = true;if session.loggedIn { await load(reset: true) } }
            .refreshable { await load(reset: true) }
    }
    private func load(reset: Bool) async {
        guard !busy else { return }; busy = true; error = ""; defer { busy = false }
        do {
            let data = try await BiliAPI.shared.request("/x/polymer/web-dynamic/v1/feed/all", ["type":"all","offset":reset ? "" : offset])
            let preserve = reset && incremental && !items.isEmpty
            let fetched = data["items"].array
            let candidate = preserve ? fetched.filter { row in !items.contains(where:{ $0.rawID == row.rawID }) } + items : (reset ? []:items) + fetched
            var seen = Set<String>();items = candidate.filter { !$0.rawID.isEmpty && seen.insert($0.rawID).inserted }
            if !preserve { offset = data["offset"].string;more = data["has_more"].int == 1 }
        } catch { self.error = error.localizedDescription }
    }
}
struct DynamicCard: View {
    let item: JSON
    private var content: JSON { item["modules"]["module_dynamic"] }
    private var author: JSON { item["modules"]["module_author"] }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Cover(url: author["face"].string).frame(width: 38, height: 38).clipShape(Circle()); Text(author["name"].string).font(.headline); Spacer(); Text(author["pub_time"].string).font(.caption).foregroundStyle(.secondary) }
            Text(content["desc"]["text"].string)
            if !content["major"]["archive"]["bvid"].string.isEmpty {
                let archive = content["major"]["archive"]
                NavigationLink { VideoDetailView(video: Video(archive)) } label: { VideoCard(video: Video(archive)) }.buttonStyle(.plain)
            }
            ForEach(Array(content["major"]["draw"]["items"].array.enumerated()), id: \.offset) { _, picture in
                Cover(url: picture["src"].string).frame(height: 220).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            }
            NavigationLink("查看完整动态") { WebScreen(url: URL(string: "https://t.bilibili.com/\(item["id_str"].string)")!, title: "动态详情") }.font(.caption)
        }.padding().background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct DiscoveryView: View {
    var body: some View {
        List {
            Section("内容") {
                NavigationLink { CatalogView(live: false) } label: { Label("番剧", systemImage: "sparkles.tv") }
                NavigationLink { CatalogView(live: true) } label: { Label("直播", systemImage: "dot.radiowaves.left.and.right") }
                NavigationLink { FeedView(mode: "排行榜").navigationTitle("排行榜") } label: { Label("排行榜", systemImage: "chart.bar") }
                NavigationLink { SearchView() } label: { Label("搜索", systemImage: "magnifyingglass") }
            }
        }.navigationTitle("发现")
    }
}
