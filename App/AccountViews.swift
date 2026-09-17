import SwiftUI
import CoreImage.CIFilterBuiltins

struct ProfileView: View {
    @Environment(Session.self) private var session
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Cover(url: session.avatar).frame(width: 60, height: 60).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 6) { Text(session.name).font(.title3.bold()); Text(session.loggedIn ? "UID \(session.mid)" : "登录后同步你的 B 站内容").font(.caption).foregroundStyle(.secondary) }
                }.padding(.vertical, 8)
                if !session.loggedIn { NavigationLink("登录账号") { LoginView() } }
            }
            Section {
                NavigationLink { HistoryView() } label: { Label("历史记录", systemImage: "clock") }
                NavigationLink { FeedView(mode: "稍后再看").navigationTitle("稍后再看") } label: { Label("稍后再看", systemImage: "text.badge.plus") }
                NavigationLink { FavoritesView() } label: { Label("我的收藏", systemImage: "star") }
                if session.loggedIn {
                    NavigationLink { WebScreen(url: URL(string: "https://space.bilibili.com/\(session.mid)")!, title: "我的空间") } label: { Label("我的空间 · 网页", systemImage: "person.crop.rectangle") }
                }
                NavigationLink { WebScreen(url: URL(string: "https://message.bilibili.com/")!, title: "消息") } label: { Label("消息 · 网页", systemImage: "envelope") }
            }
            Section { NavigationLink { SettingsView() } label: { Label("设置", systemImage: "gearshape") } }
            if session.loggedIn { Section { Button("退出登录", role: .destructive) { session.logout() } } }
        }.navigationTitle("我的").refreshable { await session.refresh() }
    }
}
struct LoginView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var cookie = ""
    @State private var qrURL = ""
    @State private var qrKey = ""
    @State private var message = ""
    @State private var attempt = 0
    @State private var busy = false
    private var qrImage: UIImage? {
        guard !qrURL.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(qrURL.utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
    var body: some View {
        Form {
            Section("使用哔哩哔哩 App 扫码") {
                if let image = qrImage { Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(height: 220).frame(maxWidth: .infinity).padding().background(.white) }
                else { ProgressView("正在生成二维码") }
                Text(message).font(.footnote)
                Button("刷新二维码") { attempt += 1 }
            }
            Section("Cookie 导入") {
                SecureField("SESSDATA=…; bili_jct=…; DedeUserID=…", text: $cookie).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("登录") { Task { await importSession() } }.disabled(cookie.isEmpty || busy)
                Text("凭证只保存到本机钥匙串，用于访问 B 站接口。请勿将凭证分享给他人。").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("登录").task(id: attempt) { await pollQR() }
    }
    private func importSession() async {
        busy = true; defer { busy = false }
        do { try session.importCookie(cookie); cookie = ""; await session.refresh(); if session.loggedIn { dismiss() } else { message = "凭证无效或已过期" } }
        catch { message = error.localizedDescription }
    }
    private func pollQR() async {
        do {
            qrURL = ""; message = "请扫描二维码"
            let qr = try await BiliAPI.shared.request("https://passport.bilibili.com/x/passport-login/web/qrcode/generate")
            qrURL = qr["url"].string; qrKey = qr["qrcode_key"].string
            for _ in 0..<90 {
                try await Task.sleep(for: .seconds(2))
                let result = try await BiliAPI.shared.request("https://passport.bilibili.com/x/passport-login/web/qrcode/poll", ["qrcode_key":qrKey])
                switch result["code"].int {
                case 0:
                    // The poll response sets cookies; the redirect query supplies an additional fallback.
                    if let parts = URLComponents(string: result["url"].string)?.queryItems {
                        try session.importCookie(parts.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "; "))
                    } else { try session.persist() }
                    await session.refresh()
                    if session.loggedIn { dismiss() } else { message = "登录状态未生效，请刷新二维码" }
                    return
                case 86038: message = "二维码已过期，请刷新"; return
                case 86090: message = "已扫码，请在哔哩哔哩 App 确认"
                default: message = "等待扫码"
                }
            }
            message = "二维码已过期，请刷新"
        } catch { if !Task.isCancelled { message = error.localizedDescription } }
    }
}
struct HistoryView: View {
    @State private var items: [Video] = []
    @State private var cursor = JSON()
    @State private var error = ""
    @State private var busy = false
    @State private var ended = false
    var body: some View {
        ScrollView {
            VideoGrid(videos: items)
            if busy { ProgressView() }
            if !error.isEmpty { FailureView(message: error) { Task { await load(reset: true) } } }
            if !busy && !ended { Button("加载更多") { Task { await load(reset: false) } }.padding() }
        }.navigationTitle("历史记录").task { await load(reset: true) }.refreshable { await load(reset: true) }
    }
    private func load(reset: Bool) async {
        guard !busy else { return }; busy = true; error = ""; defer { busy = false }
        do {
            var params = ["ps":"30","type":"archive"]
            if !reset { params["max"] = cursor["max"].string; params["view_at"] = cursor["view_at"].string; params["business"] = cursor["business"].string }
            let data = try await BiliAPI.shared.request("/x/web-interface/history/cursor", params)
            let next = data["list"].array.map(Video.init).filter { !$0.id.isEmpty }
            var seen = Set<String>(); items = ((reset ? [] : items) + next).filter { seen.insert($0.id).inserted }; cursor = data["cursor"]; ended = data["list"].array.isEmpty
        } catch { self.error = error.localizedDescription }
    }
}
struct FavoritesView: View {
    @Environment(Session.self) private var session
    @State private var folders: [JSON] = []
    @State private var error = ""
    var body: some View {
        List {
            ForEach(folders, id: \.rawID) { folder in NavigationLink(folder["title"].string) { FavoriteVideosView(folderID: folder["id"].string, title: folder["title"].string) } }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }.navigationTitle("我的收藏").task(id: session.revision) {
            do { let data = try await BiliAPI.shared.request("/x/v3/fav/folder/created/list-all", ["up_mid":session.mid]); folders = data["list"].array } catch { self.error = error.localizedDescription }
        }
    }
}
struct FavoriteVideosView: View {
    let folderID: String
    let title: String
    @State private var items: [Video] = []
    @State private var page = 0
    @State private var more = true
    @State private var busy = false
    @State private var error = ""
    var body: some View {
        ScrollView { VideoGrid(videos: items); if busy { ProgressView() }; if !error.isEmpty { Text(error).foregroundStyle(.red) }; if more && !busy { Button("加载更多") { Task { await load() } }.padding() } }
            .navigationTitle(title).task { if page == 0 { await load() } }
    }
    private func load() async {
        guard !busy else { return }; busy = true; error = ""; defer { busy = false }
        do {
            let data = try await BiliAPI.shared.request("/x/v3/fav/resource/list", ["media_id":folderID,"pn":String(page + 1),"ps":"20"])
            let rows = data["medias"].array.map(Video.init).filter { !$0.id.isEmpty }; var seen = Set<String>()
            items = (items + rows).filter { seen.insert($0.id).inserted }; page += 1; more = data["has_more"].int == 1
        } catch { self.error = error.localizedDescription }
    }
}
