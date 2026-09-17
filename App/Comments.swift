import SwiftUI

struct BiliComment: Identifiable {
    let id: String
    let rootID: String
    let parentID: String
    let mid: String
    let user: String
    let avatar: String
    let message: String
    let likes: Int
    let replyCount: Int
    let time: Date
    let previews: [BiliComment]
    init(_ value:JSON, includePreviews:Bool = true) {
        id = value["rpid_str"].string.isEmpty ? value["rpid"].string : value["rpid_str"].string
        rootID = value["root_str"].string.isEmpty ? value["root"].string : value["root_str"].string
        parentID = value["parent_str"].string.isEmpty ? value["parent"].string : value["parent_str"].string
        mid = value["member"]["mid"].string
        user = value["member"]["uname"].string
        avatar = value["member"]["avatar"].string
        message = value["content"]["message"].string
        likes = value["like"].int
        replyCount = max(value["rcount"].int,value["count"].int)
        time = Date(timeIntervalSince1970:Double(value["ctime"].int))
        previews = includePreviews ? value["replies"].array.map { BiliComment($0,includePreviews:false) } : []
    }
}
@MainActor @Observable final class CommentPages {
    typealias Fetch = (String,[String:String]) async throws -> JSON
    private let fetch: Fetch
    var items: [BiliComment] = []
    var total = 0
    var page = 0
    var loading = false
    var end = false
    var error = ""
    private var generation = UUID()
    init(fetch: @escaping Fetch = { path,params in try await BiliAPI.shared.request(path,params) }) { self.fetch = fetch }
    func load(oid:String,root:String? = nil,sort:Int = 2,reset:Bool = false) async {
        guard !oid.isEmpty else { return }
        if reset { generation = UUID();items = [];page = 0;end = false;loading = false }
        guard !loading, !end else { return }
        let requestGeneration = generation
        loading = true;error = ""
        defer { if generation == requestGeneration { loading = false } }
        do {
            let next = page + 1
            var params = ["oid":oid,"type":"1","pn":String(next),"ps":"20"]
            let path: String
            if let root { params["root"] = root;path = "/x/v2/reply/reply" }
            else { params["sort"] = String(sort);path = "/x/v2/reply" }
            let data = try await fetch(path,params)
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }
            let replies = data["replies"].array.map { BiliComment($0) }.filter { !$0.id.isEmpty }
            var pinned:[BiliComment] = []
            if root == nil && next == 1 {
                pinned = ["upper","admin","vote"].map { BiliComment(data["top"][$0]) }.filter { !$0.id.isEmpty }
            }
            var seen = Set<String>()
            items = (items + pinned + replies).filter { seen.insert($0.id).inserted }
            total = data["page"]["count"].int
            page = next
            end = replies.isEmpty || (total > 0 ? next * 20 >= total : replies.count < 20)
        } catch { if generation == requestGeneration && !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
struct CommentRow: View {
    let comment: BiliComment
    var replyingTo: BiliComment? = nil
    var reply:(() -> Void)? = nil
    var body: some View {
        HStack(alignment:.top,spacing:12) {
            if !comment.mid.isEmpty {
                NavigationLink { SpaceView(mid:comment.mid,initialName:comment.user) } label: { Cover(url:comment.avatar).frame(width:34,height:34).clipShape(Circle()) }.accessibilityLabel("查看 \(comment.user) 的空间")
            } else { Cover(url:comment.avatar).frame(width:34,height:34).clipShape(Circle()) }
            VStack(alignment:.leading,spacing:8) {
                HStack { Text(comment.user).font(.subheadline.weight(.medium)).foregroundStyle(.secondary);Spacer();Label(String(comment.likes),systemImage:"hand.thumbsup").font(.caption).foregroundStyle(.secondary) }
                if let replyingTo {
                    VStack(alignment:.leading,spacing:4) { Text("回复 @\(replyingTo.user)").font(.caption.weight(.medium));Text(replyingTo.message).font(.caption).lineLimit(3) }
                        .padding(8).frame(maxWidth:.infinity,alignment:.leading).background(Color.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:8))
                } else if comment.parentID != "0" && !comment.parentID.isEmpty && comment.parentID != comment.rootID {
                    Text("回复楼内评论").font(.caption).foregroundStyle(.secondary)
                }
                CopyableText(text:comment.message).font(.subheadline).fixedSize(horizontal:false,vertical:true)
                HStack { Text(comment.time,style:.date).font(.caption2).foregroundStyle(.tertiary);if let reply { Button("回复",action:reply).font(.caption) } }
            }
        }.padding(.vertical,8)
    }
}
struct CommentSection: View {
    let oid:String
    @State private var pages = CommentPages()
    @State private var draft:CommentDraft?
    @AppStorage("commentSort") private var sort = 2
    @AppStorage("commentPreviewCount") private var previewCount = 3
    var body: some View {
        LazyVStack(alignment:.leading,spacing:12) {
            HStack {
                Text(pages.total > 0 ? "评论 \(pages.total)":"评论").font(.headline)
                Spacer()
                Picker("评论排序",selection:$sort) { Text("最热").tag(2);Text("最新").tag(0) }.pickerStyle(.segmented).frame(width:150)
            }
            Button("发表评论") { draft = .topLevel }
            ForEach(pages.items) { comment in
                VStack(alignment:.leading,spacing:4) {
                    CommentRow(comment:comment,reply:{ draft = .reply(to:comment) })
                    if comment.replyCount > 0 || !comment.previews.isEmpty {
                        NavigationLink {
                            CommentThreadView(oid:oid,root:comment)
                        } label: {
                            CommentPreview(oid:oid,comment:comment,limit:previewCount)
                        }.buttonStyle(.plain).accessibilityIdentifier("comment.replies.\(comment.id)")
                    }
                }
                Divider()
            }
            if pages.loading { ProgressView("加载评论").frame(maxWidth:.infinity) }
            if !pages.error.isEmpty { Text(pages.error).font(.footnote).foregroundStyle(.red);Button("重新加载评论") { Task { await pages.load(oid:oid,sort:sort) } } }
            else if !pages.loading && !pages.end { Button("加载更多评论") { Task { await pages.load(oid:oid,sort:sort) } }.frame(maxWidth:.infinity).padding() }
            else if pages.items.isEmpty && !pages.loading { Text("暂无评论").foregroundStyle(.secondary) }
        }.task(id:"\(oid).\(sort)") { await pages.load(oid:oid,sort:sort,reset:true) }
            .sheet(item:$draft) { value in CommentComposer(oid:oid,draft:value) { Task { await pages.load(oid:oid,sort:sort,reset:true) } } }
    }
}
struct CommentThreadView: View {
    let oid:String
    let root:BiliComment
    @State private var pages:CommentPages
    @State private var draft:CommentDraft?
    init(oid:String,root:BiliComment,loader:@escaping CommentPages.Fetch = { path,params in try await BiliAPI.shared.request(path,params) }) {
        self.oid = oid;self.root = root;_pages = State(initialValue:CommentPages(fetch:loader))
    }
    @AppStorage("showReplyLoadedCount") private var showLoaded = true
    private var loaded: [String:BiliComment] {
        var result = [root.id:root]
        for comment in root.previews + pages.items { result[comment.id] = comment }
        return result
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:12) {
                CommentRow(comment:root,reply:{ draft = .reply(to:root) })
                Divider()
                Text(showLoaded ? "全部回复 · 已加载 \(pages.items.count) 条":"全部回复 \(max(root.replyCount,pages.total)) 条").font(.headline)
                ForEach(pages.items) { reply in
                    VStack(alignment:.leading,spacing:12) {
                        CommentRow(comment:reply,replyingTo:reply.parentID != root.id ? loaded[reply.parentID]:nil,reply:{ draft = .reply(to:reply) })
                        Divider()
                    }
                }
                VStack(alignment:.leading,spacing:12) {
                    if pages.loading { ProgressView("加载回复").frame(maxWidth:.infinity) }
                    if !pages.error.isEmpty { Text(pages.error).foregroundStyle(.red);Button("重试") { Task { await pages.load(oid:oid,root:root.id) } } }
                    else if !pages.loading && !pages.end { Button("加载更多回复") { Task { await pages.load(oid:oid,root:root.id) } }.frame(maxWidth:.infinity).padding() }
                    else if pages.items.isEmpty && !pages.loading { Text("暂无可见回复").foregroundStyle(.secondary) }
                }
            }.padding()
        }.navigationTitle("评论回复").navigationBarTitleDisplayMode(.inline)
            .task { if pages.page == 0 { await pages.load(oid:oid,root:root.id) } }
            .refreshable { await pages.load(oid:oid,root:root.id,reset:true) }
            .sheet(item:$draft) { value in CommentComposer(oid:oid,draft:value) { Task { await pages.load(oid:oid,root:root.id,reset:true) } } }
    }
}

struct CommentPreview:View {
    let oid:String
    let comment:BiliComment
    let limit:Int
    @State private var additional:[BiliComment] = []
    private var replies:[BiliComment] { additional.isEmpty ? comment.previews:additional }
    var body:some View {
        VStack(alignment:.leading,spacing:7) {
            ForEach(replies.prefix(max(0,limit))) { reply in
                (Text(reply.user + "：").fontWeight(.medium) + Text(reply.message)).font(.caption).lineLimit(2).foregroundStyle(.secondary)
            }
            Text("查看全部 \(max(comment.replyCount,comment.previews.count)) 条回复 ›").font(.subheadline.weight(.medium)).foregroundStyle(.tint)
        }.frame(maxWidth:.infinity,alignment:.leading).padding(12).background(Color.secondary.opacity(0.07),in:RoundedRectangle(cornerRadius:10))
            .task(id:limit) {
                guard limit > comment.previews.count,comment.replyCount > comment.previews.count else { return }
                do {
                    let data = try await BiliAPI.shared.request("/x/v2/reply/reply",["oid":oid,"type":"1","root":comment.id,"pn":"1","ps":String(min(20,limit))])
                    try Task.checkCancellation()
                    var seen = Set<String>()
                    additional = data["replies"].array.map { BiliComment($0) }.filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
                } catch { /* The full thread retains its explicit retry UI. */ }
            }
    }
}
