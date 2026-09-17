import SwiftUI

struct ListenView: View {
    @State private var playback = Playback()
    @State private var queue: [Video] = []
    @State private var selected: Video?
    @State private var cid = ""
    @State private var error = ""
    @State private var selectionID = ""
    var body: some View {
        VStack(spacing: 18) {
            if let selected {
                Cover(url: selected.cover).frame(width: 190, height: 190).clipShape(Circle()).overlay(Circle().stroke(.thinMaterial, lineWidth: 16)).padding(.top, 24)
                Text(selected.title).font(.headline).multilineTextAlignment(.center).lineLimit(2).padding(.horizontal)
                Text(selected.author).foregroundStyle(.secondary)
                NativePlayer(player: playback.player, onRelease: { playback.stop(bvid: selected.id, cid: cid) }).frame(height: 75)
                HStack(spacing: 40) {
                    Button { skip(-1) } label: { Image(systemName:"backward.end.fill") }.accessibilityLabel("上一首")
                    Button { playback.player.play() } label: { Image(systemName:"play.fill") }.accessibilityLabel("播放")
                    Button { playback.player.pause() } label: { Image(systemName:"pause.fill") }.accessibilityLabel("暂停")
                    Button { skip(1) } label: { Image(systemName:"forward.end.fill") }.accessibilityLabel("下一首")
                }.font(.title2)
            }
            if playback.loading { ProgressView("准备音频") }
            if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal) }
            if !playback.error.isEmpty { Text(playback.error).font(.footnote).foregroundStyle(.red).padding(.horizontal) }
            List {
                Section("稍后再看 · 播放列表") {
                    ForEach(queue) { video in
                        Button { selectionID = video.id } label: {
                            HStack { Cover(url: video.cover).frame(width: 65, height: 42).clipped().clipShape(RoundedRectangle(cornerRadius: 6)); Text(video.title).lineLimit(2); if selected?.id == video.id { Image(systemName:"speaker.wave.2.fill") } }
                        }.foregroundStyle(.primary)
                    }
                    if queue.isEmpty && error.isEmpty { Text("登录后，将视频加入稍后再看即可在这里播放。").foregroundStyle(.secondary) }
                }
            }.refreshable { await load() }
        }.navigationTitle("听视频").navigationBarTitleDisplayMode(.inline).task { await load() }
        .task(id: selectionID) {
            guard let video = queue.first(where: { $0.id == selectionID }) else { return }
            if selected?.id == video.id && playback.player.currentItem != nil { return }
            if let old = selected { playback.stop(bvid: old.id, cid: cid) }
            selected = video
            do { let data = try await BiliAPI.shared.request("/x/web-interface/view", ["bvid":video.id]); cid = data["cid"].string; await playback.open(bvid:video.id,cid:cid,title:video.title) }
            catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
    private func load() async {
        error = ""
        do { let data = try await BiliAPI.shared.request("/x/v2/history/toview"); queue = data["list"].array.map(Video.init).filter { !$0.id.isEmpty } }
        catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
    private func skip(_ direction: Int) {
        guard !queue.isEmpty else { return }
        let index = queue.firstIndex(where: { $0.id == selected?.id }) ?? 0
        selectionID = queue[(index + direction + queue.count) % queue.count].id
    }
}
