import SwiftUI

@main struct BiliPaiApp: App {
    @State private var session = Session()
    @AppStorage("appearance") private var appearance = "system"
    var body: some Scene {
        WindowGroup {
            RootView().environment(session).tint(.blue)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .task { await session.refresh() }
        }
    }
}
struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("推荐", systemImage: "house.fill") }
            NavigationStack { DynamicView() }.tabItem { Label("动态", systemImage: "bolt.horizontal.circle") }
            NavigationStack { HistoryView() }.tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
            NavigationStack { ListenView() }.tabItem { Label("听视频", systemImage: "headphones") }
            NavigationStack { ProfileView() }.tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
    }
}
struct FailureView: View {
    let message: String
    var retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("暂时无法加载", systemImage: "wifi.exclamationmark")
        } description: { Text(message) } actions: { Button("重试", action: retry).buttonStyle(.borderedProminent) }
    }
}
struct Cover: View {
    let url: String
    var body: some View {
        AsyncImage(url: URL(string: url)) { image in image.resizable().scaledToFill() }
        placeholder: { Rectangle().fill(Color.secondary.opacity(0.1)).overlay(Image(systemName: "play.rectangle").foregroundStyle(.secondary)) }
    }
}
struct VideoCard: View {
    let video: Video
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Cover(url: video.cover).frame(height: 108).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            Text(video.title).font(.subheadline.weight(.medium)).lineLimit(2).frame(height: 40, alignment: .topLeading)
            Text(video.author).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }.contentShape(Rectangle())
    }
}
struct VideoGrid: View {
    let videos: [Video]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 22) {
            ForEach(videos) { video in NavigationLink { VideoDetailView(video: video) } label: { VideoCard(video: video) }.buttonStyle(.plain) }
        }.padding()
    }
}
struct HomeView: View {
    @Environment(Session.self) private var session
    @State private var category = "推荐"
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                NavigationLink { ProfileView() } label: { Cover(url: session.avatar).frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 10)) }.accessibilityLabel("个人中心")
                NavigationLink { SearchView() } label: {
                    HStack { Image(systemName: "magnifyingglass"); Text("搜索视频、UP主…").font(.subheadline); Spacer() }.foregroundStyle(.secondary).padding(10).background(.thinMaterial, in: Capsule())
                }.accessibilityLabel("搜索")
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape").frame(width: 36, height: 36) }.accessibilityLabel("设置")
            }.padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["推荐","热门","排行榜"], id: \.self) { tab in
                        Button(tab) { category = tab }.font(.subheadline.weight(category == tab ? .bold:.regular)).padding(.horizontal, 18).padding(.vertical, 9).background(category == tab ? Color.blue.opacity(0.12):Color.clear, in: Capsule())
                    }
                    NavigationLink("直播") { CatalogView(live: true) }.padding(9)
                    NavigationLink("番剧") { CatalogView(live: false) }.padding(9)
                }.padding(.horizontal)
            }
            FeedView(mode: category).id(category)
        }.toolbar(.hidden, for: .navigationBar)
    }
}
struct FeedView: View {
    let mode: String
    @State private var videos: [Video] = []
    @State private var error = ""
    @State private var loading = false
    @State private var page = 1
    @State private var ended = false
    var body: some View {
        ScrollView {
            if videos.isEmpty && !error.isEmpty { FailureView(message: error) { Task { await load(reset: true) } } }
            if mode == "推荐", let first = videos.first {
                NavigationLink { VideoDetailView(video: first) } label: {
                    Cover(url: first.cover).frame(height: 210).clipped()
                        .overlay(alignment: .bottomLeading) { Text(first.title).font(.headline).foregroundStyle(.white).lineLimit(2).padding().frame(maxWidth: .infinity, alignment: .leading).background(.linearGradient(colors: [.clear,.black.opacity(0.8)], startPoint: .top, endPoint: .bottom)) }
                        .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
                }.buttonStyle(.plain)
                VideoGrid(videos: Array(videos.dropFirst()))
            } else { VideoGrid(videos: videos) }
            if loading { ProgressView().padding() }
            else if !ended && !videos.isEmpty { Button("加载更多") { Task { await load(reset: false) } }.padding() }
            if !videos.isEmpty && !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red).padding() }
        }.refreshable { await load(reset: true) }.task { if videos.isEmpty { await load(reset: true) } }
    }
    private func load(reset: Bool) async {
        guard !loading else { return }; loading = true; error = ""; defer { loading = false }
        let next = reset ? 1 : page + 1
        do {
            let data: JSON
            if mode == "推荐" { data = try await BiliAPI.shared.request("/x/web-interface/wbi/index/top/feed/rcmd", ["ps":"20","fresh_idx":String(next),"fresh_type":"3"], signed: true) }
            else if mode == "排行榜" { data = try await BiliAPI.shared.request("/x/web-interface/ranking/v2", ["rid":"0","type":"all"]) }
            else if mode == "稍后再看" { data = try await BiliAPI.shared.request("/x/v2/history/toview") }
            else { data = try await BiliAPI.shared.request("/x/web-interface/popular", ["pn":String(next),"ps":"20"]) }
            let items = (mode == "推荐" ? data["item"] : data["list"]).array.map(Video.init).filter { !$0.id.isEmpty }
            var seen = Set<String>(); videos = ((reset ? [] : videos) + items).filter { seen.insert($0.id).inserted }
            page = next; ended = items.isEmpty || ["排行榜","稍后再看"].contains(mode)
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
struct SearchView: View {
    @State private var text = ""
    @State private var query = ""
    @State private var videos: [Video] = []
    @State private var error = ""
    @State private var loading = false
    @State private var page = 1
    @State private var end = false
    @AppStorage("searchHistory") private var historyData = "[]"
    private var history: [String] { (try? JSONDecoder().decode([String].self, from: Data(historyData.utf8))) ?? [] }
    var body: some View {
        ScrollView {
            if query.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Text("搜索历史").font(.headline)
                    ForEach(history, id: \.self) { term in Button(term) { text = term; query = term } }
                    if !history.isEmpty { Button("清除历史", role: .destructive) { historyData = "[]" } }
                }.frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            if mode == "推荐", let first = videos.first {
                NavigationLink { VideoDetailView(video: first) } label: {
                    Cover(url: first.cover).frame(height: 210).clipped()
                        .overlay(alignment: .bottomLeading) { Text(first.title).font(.headline).foregroundStyle(.white).lineLimit(2).padding().frame(maxWidth: .infinity, alignment: .leading).background(.linearGradient(colors: [.clear,.black.opacity(0.8)], startPoint: .top, endPoint: .bottom)) }
                        .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
                }.buttonStyle(.plain)
                VideoGrid(videos: Array(videos.dropFirst()))
            } else { VideoGrid(videos: videos) }
            if loading { ProgressView() }
            if !error.isEmpty { FailureView(message: error) { Task { await search(reset: true) } } }
            if !loading && !videos.isEmpty && !end { Button("加载更多") { Task { await search(reset: false) } }.padding() }
            if !query.isEmpty && !loading && error.isEmpty && videos.isEmpty { ContentUnavailableView.search(text: query) }
        }.navigationTitle("搜索").searchable(text: $text, prompt: "搜索视频")
        .onSubmit(of: .search) { query = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        .task(id: query) { await search(reset: true) }
    }
    private func search(reset: Bool) async {
        guard !query.isEmpty else { return }
        loading = true; error = ""; defer { loading = false }
        if reset { videos = []; page = 1 }
        do {
            let p = reset ? 1 : page + 1
            let result = try await BiliAPI.shared.request("/x/web-interface/wbi/search/type", ["search_type":"video","keyword":query,"page":String(p)], signed: true)
            try Task.checkCancellation()
            let items = result["result"].array.map(Video.init).filter { !$0.id.isEmpty }
            var seen = Set<String>(); videos = (videos + items).filter { seen.insert($0.id).inserted }; page = p; end = items.isEmpty
            let saved = [query] + history.filter { $0 != query }; historyData = String(data: try JSONEncoder().encode(Array(saved.prefix(20))), encoding: .utf8) ?? "[]"
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
