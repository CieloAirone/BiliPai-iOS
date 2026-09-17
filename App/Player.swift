import SwiftUI
import AVKit
import MediaPlayer

@MainActor @Observable final class Playback {
    let player = AVPlayer()
    var error = ""
    var subtitleError = ""
    var loading = false
    var title = ""
    var bridge: HLSBridge?
    var status: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    var onFinished: (() -> Void)?
    private var playbackID = ""
    func open(bvid: String, cid: String, title: String, episodeID: String? = nil) async {
        let requestedID = "\(bvid).\(cid).\(episodeID ?? "")"
        if playbackID == requestedID && player.currentItem != nil { return }
        loading = true; error = ""; subtitleError = ""; self.title = title
        defer { loading = false }
        do {
            async let subtitleRequest = SubtitleService.tracks(bvid:bvid,cid:cid)
            let data: JSON
            let preferred = PlaybackOptions.quality(cellular:NetworkState.shared.cellular)
            if let episodeID {
                data = try await BiliAPI.shared.request("/pgc/player/web/playurl", ["ep_id":episodeID,"cid":cid,"qn":String(preferred),"fnval":"4048","fourk":"1"])
            } else {
                data = try await BiliAPI.shared.request("/x/player/wbi/playurl", ["bvid":bvid,"cid":cid,"qn":String(preferred),"fnval":"4048","fnver":"0","fourk":"1"], signed: true)
            }
            var subtitles:[BiliSubtitle] = []
            do { subtitles = try await subtitleRequest }
            catch { if !Task.isCancelled && UserDefaults.standard.string(forKey:"subtitleAuto") != "off" { subtitleError = "字幕暂不可用：" + error.localizedDescription } }
            let url: URL
            bridge?.stop(); bridge = nil
            let dashVideos = data["dash"]["video"].array.filter { $0["codecs"].string.hasPrefix("avc1") }.sorted { $0["id"].int > $1["id"].int }
            if let selected = dashVideos.first(where: { $0["id"].int <= preferred }) ?? dashVideos.last {
                async let videoTrack = DASHTrack.load(selected)
                let audioChoices = data["dash"]["audio"].array.filter { $0["codecs"].string.hasPrefix("mp4a") }.sorted { $0["bandwidth"].int > $1["bandwidth"].int }
                let audioQuality = UserDefaults.standard.integer(forKey:"audioQuality")
                let selectedAudio = audioChoices.first(where: { $0["id"].int <= audioQuality }) ?? audioChoices.last
                let audioTrack: DASHTrack?
                if let selectedAudio { audioTrack = try await DASHTrack.load(selectedAudio) } else { audioTrack = nil }
                let localBridge = HLSBridge(video: try await videoTrack, audio: audioTrack, subtitles:subtitles)
                bridge = localBridge; url = try await localBridge.start()
            } else if data["durl"].array.count == 1, let source = data["durl"].array.first,
                      let sourceURL = URL(string: source["url"].string.replacingOccurrences(of: "http://", with: "https://")) {
                url = sourceURL
            } else {
                throw BiliError(message: "当前播放源没有受支持的 AVC / MP4 格式，请使用网页播放入口。")
            }
            try Task.checkCancellation()
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options:UserDefaults.standard.bool(forKey:"audioFocus") ? []:[.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": ["Referer":"https://www.bilibili.com/","User-Agent":"Mozilla/5.0"]])
            let item = AVPlayerItem(asset: asset)
            status = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                if item.status == .failed { Task { @MainActor in self?.error = item.error?.localizedDescription ?? "播放失败" } }
            }
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            endObserver = NotificationCenter.default.addObserver(forName:.AVPlayerItemDidPlayToEndTime,object:item,queue:.main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if UserDefaults.standard.string(forKey:"completion") == "loop" {
                        await self.player.seek(to:.zero);self.player.playImmediately(atRate:PlaybackOptions.speed())
                    } else { self.onFinished?() }
                }
            }
            rateObservation = player.observe(\.rate,options:[.new]) { player,_ in
                let rate = player.rate
                if (0.5...2).contains(rate) && UserDefaults.standard.bool(forKey:"rememberSpeed") { UserDefaults.standard.set(Double(rate),forKey:"lastSpeed") }
            }
            player.replaceCurrentItem(with: item)
            playbackID = requestedID
            player.appliesMediaSelectionCriteriaAutomatically = false
            if !subtitles.isEmpty,bridge != nil {
                do {
                    if let group = try await asset.loadMediaSelectionGroup(for:.legible) {
                        let preferred = SubtitlePolicy.preferred(subtitles,mode:UserDefaults.standard.string(forKey:"subtitleAuto") ?? "off",muted:player.isMuted || player.volume == 0)
                        item.select(preferred.flatMap { $0.option(in:group) },in:group)
                    }
                } catch { subtitleError = "字幕暂不可用：" + error.localizedDescription }
            }
            try Task.checkCancellation()
            guard player.currentItem === item else { return }
            let saved = UserDefaults.standard.double(forKey: "position.\(bvid).\(cid)")
            if saved > 0 && UserDefaults.standard.bool(forKey:"rememberPosition") && !UserDefaults.standard.bool(forKey:"privacyMode") { await player.seek(to: CMTime(seconds: saved, preferredTimescale: 600)) }
            if UserDefaults.standard.bool(forKey:"autoplay") || UserDefaults.standard.bool(forKey:"autoFullscreen") { player.playImmediately(atRate:PlaybackOptions.speed()) }
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
    func stop(bvid: String, cid: String) {
        let time = player.currentTime().seconds
        if time.isFinite && UserDefaults.standard.bool(forKey:"rememberPosition") && !UserDefaults.standard.bool(forKey:"privacyMode") { UserDefaults.standard.set(time, forKey: "position.\(bvid).\(cid)") }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver);self.endObserver = nil };rateObservation = nil
        player.pause(); player.replaceCurrentItem(with: nil); status = nil; bridge?.stop(); bridge = nil; playbackID = ""
    }
}
// AVKit can hide the SwiftUI page during full-screen presentation. That is not
// navigation teardown. Release the media only when the represented controller is
// detached, and defer even that cleanup while AVKit owns a full-screen/PiP session.
@MainActor
struct NativePlayer: UIViewControllerRepresentable {
    @AppStorage("pip") private var pip = true
    @AppStorage("backgroundPlayback") private var background = true
    let player: AVPlayer
    var onRelease: () -> Void = {}

    @MainActor final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var token: NSObjectProtocol?
        var background = true
        private var presentationRetention:Coordinator?
        private func updatePresentationRetention() { presentationRetention = lifetime.fullScreen || lifetime.pictureInPicture ? self:nil }
        let lifetime: PlayerControllerLifetime
        init(player: AVPlayer, onRelease: @escaping () -> Void) {
            lifetime = PlayerControllerLifetime(onRelease: onRelease)
            super.init()
            token = NotificationCenter.default.addObserver(forName:UIApplication.didEnterBackgroundNotification,object:nil,queue:.main) { [weak self, weak player] _ in
                if self?.background == false { player?.pause() }
            }
        }
        func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            lifetime.fullScreen = true;updatePresentationRetention()
            coordinator.animate(alongsideTransition: nil) { [weak self] transition in
                if transition.isCancelled { self?.lifetime.fullScreen = false; self?.lifetime.releaseIfDetached();self?.updatePresentationRetention() }
            }
        }
        func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            coordinator.animate(alongsideTransition: nil) { [weak self] transition in
                guard !transition.isCancelled else { return }
                self?.lifetime.fullScreen = false
                self?.lifetime.releaseIfDetached();self?.updatePresentationRetention()
            }
        }
        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) { lifetime.pictureInPicture = true;updatePresentationRetention() }
        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) { lifetime.pictureInPicture = false; lifetime.releaseIfDetached();updatePresentationRetention() }
        func playerViewController(_ playerViewController: AVPlayerViewController, failedToStartPictureInPictureWithError error: Error) { lifetime.pictureInPicture = false; lifetime.releaseIfDetached();updatePresentationRetention() }
        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }
    func makeCoordinator() -> Coordinator { Coordinator(player: player, onRelease: onRelease) }
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.delegate = context.coordinator
        vc.allowsPictureInPicturePlayback = pip
        vc.canStartPictureInPictureAutomaticallyFromInline = pip
        vc.updatesNowPlayingInfoCenter = true
        context.coordinator.background = background
        return vc
    }
    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        // Reassigning the player during a presentation transition is unnecessary.
        if vc.player !== player { vc.player = player }
        vc.allowsPictureInPicturePlayback = pip
        vc.canStartPictureInPictureAutomaticallyFromInline = pip
        context.coordinator.background = background
        context.coordinator.lifetime.onRelease = onRelease
    }
    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.lifetime.detach()
    }
}
@MainActor
final class PlayerControllerLifetime {
    var fullScreen = false
    var pictureInPicture = false
    private(set) var detached = false
    private(set) var released = false
    var onRelease: () -> Void
    init(onRelease: @escaping () -> Void) { self.onRelease = onRelease }
    func detach() { detached = true; releaseIfDetached() }
    func releaseIfDetached() {
        guard detached, !fullScreen, !pictureInPicture, !released else { return }
        released = true
        onRelease()
    }
}
struct VideoDetailView: View {
    let video: Video
    @State private var playback = Playback()
    @State private var detail = JSON()
    @State private var cid = ""
    @State private var message = ""
    @State private var liked = false
    @State private var busy = false
    @State private var coinConfirmation = false
    @State private var speed: Float = PlaybackOptions.speed()
    @AppStorage("danmakuEnabled") private var danmakuEnabled = true
    @State private var descriptionExpanded = UserDefaults.standard.bool(forKey:"expandDescription")
    var body: some View {
        ScrollView {
            VideoPlayerSurface(player: playback.player, onRelease: { playback.onFinished = nil;playback.stop(bvid: video.id, cid: cid) }).frame(height: 235).background(.black)
                .overlay { if danmakuEnabled && !cid.isEmpty { DanmakuOverlay(player: playback.player, cid: cid) } }
            if playback.loading { ProgressView("正在加载视频") }
            if !playback.error.isEmpty { Text(playback.error).font(.footnote).foregroundStyle(.red).padding() }
            VStack(alignment: .leading, spacing: 18) {
                CopyableText(text:video.title).font(.title3.bold())
                HStack { Text(video.author).foregroundStyle(.secondary); Spacer(); Text(video.id).font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 24) {
                    Button { Task { await action("/x/web-interface/archive/like", ["bvid":video.id,"like":liked ? "2":"1"]) { liked.toggle() } } } label: { Label("点赞", systemImage: liked ? "hand.thumbsup.fill":"hand.thumbsup") }
                    Button { coinConfirmation = true } label: { Label("投币", systemImage: "circle") }
                    Button { Task { await action("/x/v2/history/toview/add", ["bvid":video.id]) {} } } label: { Image(systemName: "text.badge.plus") }.accessibilityLabel("稍后再看")
                    ShareLink(item: URL(string: "https://www.bilibili.com/video/\(video.id)")!) { Image(systemName: "square.and.arrow.up") }
                }.buttonStyle(.borderless).disabled(busy)
                if !playback.subtitleError.isEmpty { Text(playback.subtitleError).font(.caption).foregroundStyle(.secondary) }
                Toggle("弹幕", isOn: $danmakuEnabled)
                Picker("播放速度", selection: $speed) { ForEach([Float(0.5),1,1.25,1.5,2], id: \.self) { Text(String(format: "%g×", $0)).tag($0) } }.pickerStyle(.segmented)
                    .onChange(of: speed) { _, value in playback.player.rate = value }
                if detail["pages"].array.count > 1 {
                    Picker("分集", selection: $cid) { ForEach(detail["pages"].array, id: \.rawID) { item in Text(item["part"].string).tag(item["cid"].string) } }
                }
                DisclosureGroup("视频简介",isExpanded:$descriptionExpanded) { CopyableText(text:detail["desc"].string).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading) }
                NavigationLink("网页播放 / 完整互动") { WebScreen(url: URL(string: "https://www.bilibili.com/video/\(video.id)")!, title: video.title) }
                if !detail["aid"].string.isEmpty { CommentSection(oid:detail["aid"].string) }
            }.padding()
        }.navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: Binding(get: { !message.isEmpty }, set: { if !$0 { message = "" } })) { Button("好") { message = "" } } message: { Text(message) }
        .confirmationDialog("为视频投 1 枚硬币？", isPresented: $coinConfirmation, titleVisibility: .visible) {
            Button("投 1 枚硬币") { Task { await action("/x/web-interface/coin/add", ["bvid":video.id,"multiply":"1"]) {} } }
        }
        .task {
            guard cid.isEmpty else { return }
            do {
                detail = try await BiliAPI.shared.request("/x/web-interface/view", ["bvid":video.id]); cid = detail["cid"].string
                playback.onFinished = {
                    if let next = PlaybackOptions.nextCID(current:cid,pages:detail["pages"].array,behavior:UserDefaults.standard.string(forKey:"completion") ?? "auto") { cid = next }
                }

            } catch { if !Task.isCancelled { message = error.localizedDescription } }
        }
        .task(id: cid) { if !cid.isEmpty { await playback.open(bvid: video.id, cid: cid, title: video.title) } }
        .onChange(of: cid) { old, _ in if !old.isEmpty { playback.stop(bvid: video.id, cid: old) } }
    }
    private func action(_ path: String, _ params: [String: String], success: () -> Void) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { _ = try await BiliAPI.shared.request(path, params, post: true); success(); message = "操作成功" } catch { message = error.localizedDescription }
    }
}
extension JSON {
    var rawID: String { [self["rpid"].string,self["cid"].string,self["id_str"].string,self["id"].string].first { !$0.isEmpty } ?? "" }
}
