import SwiftUI

@main struct BiliPaiApp: App {
    init() { Preferences.register(); CacheMaintenance.apply(); _ = NetworkState.shared }
    @State private var session = Session()
    @AppStorage("accent") private var accent = "blue"
    @AppStorage("customAccent") private var customAccent = "007AFF"
    @AppStorage("fontScale") private var fontScale = 1.0
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("appearance") private var appearance = "system"
    var body: some Scene {
        WindowGroup {
            appRoot.environment(session).tint(Preferences.tint)
                .environment(\.dynamicTypeSize, fontScale < 0.95 ? .small : fontScale < 1.05 ? .large : fontScale < 1.2 ? .xLarge : .xxxLarge)
                .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
                .onChange(of: accent) { _, _ in }.onChange(of: customAccent) { _, _ in }
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .task { await session.refresh() }
        }
    }
    @ViewBuilder private var appRoot:some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--regression-fixtures") { RegressionFixtureRoot() } else { RootView() }
        #else
        RootView()
        #endif
    }

}
struct RootView: View {
    @AppStorage("showDynamicTab") private var dynamic = true
    @AppStorage("showHistoryTab") private var history = true
    @AppStorage("showListenTab") private var listen = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("bottomOrder") private var order = "0,1,2,3,4"
    @State private var tab = 0
    var body: some View {
        TabView(selection:$tab) {
            ForEach(NavigationOptions.bottomItems(order),id:\.self) { item in
                switch item {
                case 0: NavigationStack { HomeView() }.tabItem { Label("推荐",systemImage:"house.fill") }.tag(0)
                case 1: if dynamic { NavigationStack { DynamicView() }.tabItem { Label("动态",systemImage:"bolt.horizontal.circle") }.tag(1) }
                case 2: if history { NavigationStack { PrivacyGate { HistoryView() } }.tabItem { Label("历史",systemImage:"clock.arrow.circlepath") }.tag(2) }
                case 3: if listen { NavigationStack { ListenView() }.tabItem { Label("听视频",systemImage:"headphones") }.tag(3) }
                default: NavigationStack { ProfileView() }.tabItem { Label("我的",systemImage:"person.crop.circle") }.tag(4)
                }
            }
        }.onChange(of: tab) { _, _ in if haptics { UISelectionFeedbackGenerator().selectionChanged() } }
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
    @AppStorage("showAuthor") private var showAuthor = true
    let video: Video
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Cover(url: video.cover).frame(height: 108).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            Text(video.title).font(.subheadline.weight(.medium)).lineLimit(2).frame(height: 40, alignment: .topLeading)
            if showAuthor { Text(video.author).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
        }.contentShape(Rectangle())
    }
}
struct VideoGrid: View {
    @AppStorage("gridColumns") private var columns = 0
    @AppStorage("cardWidth") private var width = 155.0
    @AppStorage("filterEnabled") private var filtering = false
    @AppStorage("filterKeywords") private var keywords = ""
    @AppStorage("blockedAuthors") private var authors = ""
    @AppStorage("rulePlugins") private var rulePlugins = "[]"
    @AppStorage("disabledPlugins") private var disabledPlugins = ""
    private var visible: [Video] {
        let plugins = RulePlugins.decode(rulePlugins).filter { $0.type == "feed" && !Preferences.lines(disabledPlugins).contains($0.id) }
        return videos.filter { video in
            let fields = ["title":JSON(video.title),"owner.name":JSON(video.author),"stat.view":JSON(video.views)]
            return !Preferences.lines(authors).contains(video.author) && (!filtering || !Preferences.lines(keywords).contains(where:video.title.localizedCaseInsensitiveContains)) && !plugins.contains { $0.hides(fields) }
        }
    }
    let videos: [Video]
    var body: some View {
        LazyVGrid(columns: columns == 0 ? [GridItem(.adaptive(minimum: width), spacing: 14)] : Array(repeating:GridItem(.flexible(),spacing:14),count:columns), spacing: 22) {
            ForEach(visible) { video in NavigationLink { VideoDetailView(video: video) } label: { VideoCard(video: video) }.buttonStyle(.plain) }
        }.padding()
    }
}
struct HomeView: View {
    @Environment(Session.self) private var session
    @AppStorage("defaultFeed") private var category = "推荐"
    @AppStorage("topTabs") private var topTabs = "推荐,热门,排行榜,直播,番剧"
    @State private var catalogRoute:HomeCatalogRoute?
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                NavigationLink { ProfileView() } label: { Cover(url: session.avatar).frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 10)) }.accessibilityLabel("个人中心")
                NavigationLink { SearchView() } label: {
                    HStack { Image(systemName: "magnifyingglass"); Text("搜索视频、UP主…").font(.subheadline); Spacer() }.foregroundStyle(.secondary).padding(10).background(.thinMaterial, in: Capsule())
                }.accessibilityLabel("搜索")
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape").frame(width: 36, height: 36) }.accessibilityLabel("设置")
            }.padding(.horizontal)
            HomeCategoryBar(tabs:NavigationOptions.topItems(topTabs),selected:category) { tab in
                if tab == "直播" { catalogRoute = .live }
                else if tab == "番剧" { catalogRoute = .bangumi }
                else { category = tab }
            }.padding(.horizontal,16)
            FeedView(mode: category).id(category)
        }.toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item:$catalogRoute) { route in
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--catalog-fixture") { CatalogView(live:route == .live,request:CatalogFixture.request) }
                else { CatalogView(live:route == .live) }
                #else
                CatalogView(live:route == .live)
                #endif
            }
    }
}
struct FeedView: View {
    @AppStorage("heroCard") private var hero = true
    @AppStorage("feedCount") private var count = 20
    let mode: String
    @State private var videos: [Video] = []
    @State private var error = ""
    @State private var loading = false
    @State private var page = 1
    @State private var ended = false
    var body: some View {
        ScrollView {
            if videos.isEmpty && !error.isEmpty { FailureView(message: error) { Task { await load(reset: true) } } }
            if mode == "推荐" && hero, let first = videos.first(where: { Preferences.accepts($0) }) {
                NavigationLink { VideoDetailView(video: first) } label: {
                    Cover(url: first.cover).frame(height: 210).clipped()
                        .overlay(alignment: .bottomLeading) { Text(first.title).font(.headline).foregroundStyle(.white).lineLimit(2).padding().frame(maxWidth: .infinity, alignment: .leading).background(.linearGradient(colors: [.clear,.black.opacity(0.8)], startPoint: .top, endPoint: .bottom)) }
                        .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
                }.buttonStyle(.plain)
                VideoGrid(videos: videos.filter { $0.id != first.id })
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
            if mode == "推荐" { data = try await BiliAPI.shared.request("/x/web-interface/wbi/index/top/feed/rcmd", ["ps":String(count),"fresh_idx":String(next),"fresh_type":"3"], signed: true) }
            else if mode == "排行榜" { data = try await BiliAPI.shared.request("/x/web-interface/ranking/v2", ["rid":"0","type":"all"]) }
            else if mode == "稍后再看" { data = try await BiliAPI.shared.request("/x/v2/history/toview") }
            else { data = try await BiliAPI.shared.request("/x/web-interface/popular", ["pn":String(next),"ps":String(count)]) }
            let items = (mode == "推荐" ? data["item"] : data["list"]).array.map(Video.init).filter { !$0.id.isEmpty }
            var seen = Set<String>(); videos = ((reset ? [] : videos) + items).filter { seen.insert($0.id).inserted }
            page = next; ended = items.isEmpty || ["排行榜","稍后再看"].contains(mode)
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
struct SearchView: View {
    @AppStorage("privacyMode") private var privacy = false
    @State private var text = ""
    @State private var query = ""
    @State private var videos: [Video] = []
    @State private var error = ""
    @State private var loading = false
    @State private var page = 1
    @State private var end = false
    @AppStorage("searchHistory") private var historyData = "[]"
    private var history: [String] { if privacy { return [] }; return (try? JSONDecoder().decode([String].self, from: Data(historyData.utf8))) ?? [] }
    var body: some View {
        ScrollView {
            if query.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Text("搜索历史").font(.headline)
                    ForEach(history, id: \.self) { term in Button(term) { text = term; query = term } }
                    if !history.isEmpty { Button("清除历史", role: .destructive) { historyData = "[]" } }
                }.frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            VideoGrid(videos: videos)
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
            if !privacy { let saved = [query] + history.filter { $0 != query }; historyData = String(data: try JSONEncoder().encode(Array(saved.prefix(20))), encoding: .utf8) ?? "[]" }
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
