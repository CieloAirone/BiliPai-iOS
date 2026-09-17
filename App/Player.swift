import SwiftUI
import AVKit
import MediaPlayer

@MainActor @Observable final class Playback {
    let player = AVPlayer()
    var error = ""
    var loading = false
    var title = ""
    var bridge: HLSBridge?
    var status: NSKeyValueObservation?
    func open(bvid: String, cid: String, title: String, episodeID: String? = nil) async {
        loading = true; error = ""; self.title = title
        defer { loading = false }
        do {
            let data: JSON
            if let episodeID {
                data = try await BiliAPI.shared.request("/pgc/player/web/playurl", ["ep_id":episodeID,"cid":cid,"qn":String(UserDefaults.standard.integer(forKey:"quality") == 0 ? 80 : UserDefaults.standard.integer(forKey:"quality")),"fnval":"4048","fourk":"1"])
            } else {
                data = try await BiliAPI.shared.request("/x/player/wbi/playurl", ["bvid":bvid,"cid":cid,"qn":String(UserDefaults.standard.integer(forKey:"quality") == 0 ? 80 : UserDefaults.standard.integer(forKey:"quality")),"fnval":"4048","fnver":"0","fourk":"1"], signed: true)
            }
            let url: URL
            bridge?.stop(); bridge = nil
            let dashVideos = data["dash"]["video"].array.filter { $0["codecs"].string.hasPrefix("avc1") }.sorted { $0["id"].int > $1["id"].int }
            let preferred = UserDefaults.standard.integer(forKey:"quality")
            if let selected = dashVideos.first(where: { $0["id"].int <= preferred }) ?? dashVideos.last {
                async let videoTrack = DASHTrack.load(selected)
                let selectedAudio = data["dash"]["audio"].array.filter { $0["codecs"].string.hasPrefix("mp4a") }.max { $0["bandwidth"].int < $1["bandwidth"].int }
                let audioTrack: DASHTrack?
                if let selectedAudio { audioTrack = try await DASHTrack.load(selectedAudio) } else { audioTrack = nil }
                let localBridge = HLSBridge(video: try await videoTrack, audio: audioTrack)
                bridge = localBridge; url = try await localBridge.start()
            } else if data["durl"].array.count == 1, let source = data["durl"].array.first,
                      let sourceURL = URL(string: source["url"].string.replacingOccurrences(of: "http://", with: "https://")) {
                url = sourceURL
            } else {
                throw BiliError(message: "当前播放源没有受支持的 AVC / MP4 格式，请使用网页播放入口。")
            }
            try Task.checkCancellation()
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": ["Referer":"https://www.bilibili.com/","User-Agent":"Mozilla/5.0"]])
            let item = AVPlayerItem(asset: asset)
            status = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                if item.status == .failed { Task { @MainActor in self?.error = item.error?.localizedDescription ?? "播放失败" } }
            }
            player.replaceCurrentItem(with: item)
            let saved = UserDefaults.standard.double(forKey: "position.\(bvid).\(cid)")
            if saved > 0 && UserDefaults.standard.bool(forKey:"rememberPosition") && !UserDefaults.standard.bool(forKey:"privacyMode") { await player.seek(to: CMTime(seconds: saved, preferredTimescale: 600)) }
            if UserDefaults.standard.bool(forKey:"autoplay") { player.playImmediately(atRate:Float(UserDefaults.standard.double(forKey:"defaultSpeed"))) }
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
    func stop(bvid: String, cid: String) {
        let time = player.currentTime().seconds
        if time.isFinite && UserDefaults.standard.bool(forKey:"rememberPosition") && !UserDefaults.standard.bool(forKey:"privacyMode") { UserDefaults.standard.set(time, forKey: "position.\(bvid).\(cid)") }
        player.pause(); player.replaceCurrentItem(with: nil); status = nil; bridge?.stop(); bridge = nil
    }
}
struct NativePlayer: UIViewControllerRepresentable {
    @AppStorage("pip") private var pip = true
    @AppStorage("backgroundPlayback") private var background = true
    final class Coordinator {
        var token: NSObjectProtocol?
        var background = true
        init(player:AVPlayer) {
            token = NotificationCenter.default.addObserver(forName:UIApplication.didEnterBackgroundNotification,object:nil,queue:.main) { [weak self, weak player] _ in
                if self?.background == false { player?.pause() }
            }
        }
        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }
    func makeCoordinator() -> Coordinator { Coordinator(player:player) }
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController(); vc.player = player
        vc.allowsPictureInPicturePlayback = pip; vc.canStartPictureInPictureAutomaticallyFromInline = pip
        context.coordinator.background = background
        vc.updatesNowPlayingInfoCenter = true
        return vc
    }
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) { uiViewController.player = player; uiViewController.allowsPictureInPicturePlayback = pip; uiViewController.canStartPictureInPictureAutomaticallyFromInline = pip; context.coordinator.background = background }
}
struct VideoDetailView: View {
    let video: Video
    @State private var playback = Playback()
    @State private var detail = JSON()
    @State private var comments: [JSON] = []
    @State private var cid = ""
    @State private var message = ""
    @State private var liked = false
    @State private var busy = false
    @State private var coinConfirmation = false
    @State private var speed: Float = Float(UserDefaults.standard.double(forKey:"defaultSpeed"))
    @AppStorage("danmakuEnabled") private var danmakuEnabled = true
    var body: some View {
        ScrollView {
            NativePlayer(player: playback.player).frame(height: 235).background(.black)
                .overlay { if danmakuEnabled && !cid.isEmpty { DanmakuOverlay(player: playback.player, cid: cid) } }
            if playback.loading { ProgressView("正在加载视频") }
            if !playback.error.isEmpty { Text(playback.error).font(.footnote).foregroundStyle(.red).padding() }
            VStack(alignment: .leading, spacing: 18) {
                Text(video.title).font(.title3.bold())
                HStack { Text(video.author).foregroundStyle(.secondary); Spacer(); Text(video.id).font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 24) {
                    Button { Task { await action("/x/web-interface/archive/like", ["bvid":video.id,"like":liked ? "2":"1"]) { liked.toggle() } } } label: { Label("点赞", systemImage: liked ? "hand.thumbsup.fill":"hand.thumbsup") }
                    Button { coinConfirmation = true } label: { Label("投币", systemImage: "circle") }
                    Button { Task { await action("/x/v2/history/toview/add", ["bvid":video.id]) {} } } label: { Image(systemName: "text.badge.plus") }.accessibilityLabel("稍后再看")
                    ShareLink(item: URL(string: "https://www.bilibili.com/video/\(video.id)")!) { Image(systemName: "square.and.arrow.up") }
                }.buttonStyle(.borderless).disabled(busy)
                Toggle("弹幕", isOn: $danmakuEnabled)
                Picker("播放速度", selection: $speed) { ForEach([Float(0.5),1,1.25,1.5,2], id: \.self) { Text(String(format: "%g×", $0)).tag($0) } }.pickerStyle(.segmented)
                    .onChange(of: speed) { _, value in playback.player.rate = value }
                if detail["pages"].array.count > 1 {
                    Picker("分集", selection: $cid) { ForEach(detail["pages"].array, id: \.rawID) { item in Text(item["part"].string).tag(item["cid"].string) } }
                }
                Text(detail["desc"].string).font(.subheadline).foregroundStyle(.secondary)
                NavigationLink("网页播放 / 完整互动") { WebScreen(url: URL(string: "https://www.bilibili.com/video/\(video.id)")!, title: video.title) }
                Text("评论").font(.headline)
                ForEach(comments, id: \.rawID) { comment in
                    VStack(alignment: .leading, spacing: 8) { Text(comment["member"]["uname"].string).font(.caption).foregroundStyle(.secondary); Text(comment["content"]["message"].string).font(.subheadline) }; Divider()
                }
            }.padding()
        }.navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: Binding(get: { !message.isEmpty }, set: { if !$0 { message = "" } })) { Button("好") { message = "" } } message: { Text(message) }
        .confirmationDialog("为视频投 1 枚硬币？", isPresented: $coinConfirmation, titleVisibility: .visible) {
            Button("投 1 枚硬币") { Task { await action("/x/web-interface/coin/add", ["bvid":video.id,"multiply":"1"]) {} } }
        }
        .task {
            do {
                detail = try await BiliAPI.shared.request("/x/web-interface/view", ["bvid":video.id]); cid = detail["cid"].string
                let replies = try await BiliAPI.shared.request("/x/v2/reply", ["type":"1","oid":detail["aid"].string,"sort":"2","pn":"1"])
                comments = replies["replies"].array
            } catch { if !Task.isCancelled { message = error.localizedDescription } }
        }
        .task(id: cid) { if !cid.isEmpty { await playback.open(bvid: video.id, cid: cid, title: video.title) } }
        .onChange(of: cid) { old, _ in if !old.isEmpty { playback.stop(bvid: video.id, cid: old) } }
        .onDisappear { playback.stop(bvid: video.id, cid: cid) }
    }
    private func action(_ path: String, _ params: [String: String], success: () -> Void) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { _ = try await BiliAPI.shared.request(path, params, post: true); success(); message = "操作成功" } catch { message = error.localizedDescription }
    }
}
extension JSON {
    var rawID: String { [self["rpid"].string,self["cid"].string,self["id_str"].string,self["id"].string].first { !$0.isEmpty } ?? "" }
}
