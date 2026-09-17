import SwiftUI
import AVKit

struct CatalogView: View {
    let live: Bool
    @State private var items: [JSON] = []
    @State private var page = 0
    @State private var busy = false
    @State private var more = true
    @State private var error = ""
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 20) {
                ForEach(items, id: \.catalogID) { item in
                    NavigationLink {
                        if live { LiveRoomView(room: item) } else { SeasonView(seasonID: item["season_id"].string) }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Cover(url: item["cover"].string).frame(height: live ? 105:210).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                            Text(item["title"].string).font(.subheadline.weight(.medium)).lineLimit(2)
                            Text(live ? item["uname"].string : item["index_show"].string).font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                }
            }.padding()
            if busy { ProgressView() }
            if !error.isEmpty { FailureView(message: error) { Task { await load(reset: true) } } }
            if !busy && more { Button("加载更多") { Task { await load(reset: false) } }.padding() }
        }.navigationTitle(live ? "直播":"番剧").task { await load(reset: true) }.refreshable { await load(reset: true) }
    }
    private func load(reset: Bool) async {
        guard !busy else { return }; busy = true; error = ""; defer { busy = false }
        do {
            let next = reset ? 1 : page + 1
            let result: JSON
            if live { result = try await BiliAPI.shared.request("https://api.live.bilibili.com/room/v3/area/getRoomList", ["parent_area_id":"0","area_id":"0","page":String(next),"page_size":"30","sort_type":"online"]) }
            else { result = try await BiliAPI.shared.request("/pgc/season/index/result", ["season_type":"1","st":"1","page":String(next),"pagesize":"20","order":"3","sort":"0"]) }
            let rows = result["list"].array; var seen = Set<String>()
            items = ((reset ? [] : items) + rows).filter { !$0.catalogID.isEmpty && seen.insert($0.catalogID).inserted }; page = next; more = !rows.isEmpty
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
extension JSON {
    var catalogID: String { self["season_id"].string.isEmpty ? self["roomid"].string : self["season_id"].string }
}
struct LiveRoomView: View {
    let room: JSON
    @State private var player = AVPlayer()
    @State private var error = ""
    @State private var loading = false
    var body: some View {
        ScrollView {
            NativePlayer(player: player, onRelease: { player.pause(); player.replaceCurrentItem(with: nil) }).frame(height: 240)
            VStack(alignment: .leading, spacing: 18) {
                Text(room["title"].string).font(.title3.bold()); Text(room["uname"].string).foregroundStyle(.secondary)
                if loading { ProgressView("连接直播间") }
                if !error.isEmpty { Text(error).foregroundStyle(.red); Button("重新连接") { Task { await load() } } }
                NavigationLink("直播间互动 · 网页") { WebScreen(url: URL(string: "https://live.bilibili.com/\(room["roomid"].string)")!, title: "直播互动") }
            }.padding()
        }.navigationBarTitleDisplayMode(.inline).task { if player.currentItem == nil { await load() } }
    }
    private func load() async {
        loading = true; error = ""; defer { loading = false }
        do {
            let result = try await BiliAPI.shared.request("https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo", ["room_id":room["roomid"].string,"protocol":"1","format":"1,2","codec":"0","qn":"150","platform":"web","ptype":"8"])
            var address = ""
            for stream in result["playurl_info"]["playurl"]["stream"].array {
                for format in stream["format"].array {
                    for codec in format["codec"].array {
                        if let host = codec["url_info"].array.first { address = host["host"].string + codec["base_url"].string + host["extra"].string; break }
                    }
                    if !address.isEmpty { break }
                }
                if !address.isEmpty { break }
            }
            guard !address.isEmpty, let url = URL(string: address) else { throw BiliError(message: "直播间未开播或暂无可用 HLS 播放源") }
            try Task.checkCancellation()
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback); try AVAudioSession.sharedInstance().setActive(true)
            player.replaceCurrentItem(with: AVPlayerItem(asset: AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey":["Referer":"https://live.bilibili.com/"]]))); player.play()
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
struct SeasonView: View {
    let seasonID: String
    @State private var data = JSON()
    @State private var error = ""
    var body: some View {
        List {
            Section {
                Text(data["title"].string).font(.title2.bold())
                Text(data["evaluate"].string).font(.subheadline).foregroundStyle(.secondary)
            }
            Section("选集") {
                ForEach(data["episodes"].array, id: \.rawID) { episode in
                    NavigationLink("\(episode["title"].string)  \(episode["long_title"].string)") { EpisodeView(episode: episode) }
                }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }.navigationTitle("番剧详情").navigationBarTitleDisplayMode(.inline).task {
            do { data = try await BiliAPI.shared.request("/pgc/view/web/season", ["season_id":seasonID]) }
            catch { self.error = error.localizedDescription }
        }
    }
}
struct EpisodeView: View {
    let episode: JSON
    @State private var playback = Playback()
    var body: some View {
        VStack(spacing: 20) {
            NativePlayer(player: playback.player, onRelease: { playback.stop(bvid: episode["bvid"].string, cid: episode["cid"].string) }).frame(height: 240)
            Text(episode["long_title"].string).font(.headline)
            if playback.loading { ProgressView() }
            if !playback.error.isEmpty { Text(playback.error).font(.footnote).foregroundStyle(.red).padding() }
            NavigationLink("使用网页播放") { WebScreen(url: URL(string:"https://www.bilibili.com/bangumi/play/ep\(episode["id"].string)")!, title:"番剧播放") }
            Spacer()
        }.navigationBarTitleDisplayMode(.inline).task {
            await playback.open(bvid: episode["bvid"].string, cid: episode["cid"].string, title: episode["long_title"].string, episodeID: episode["id"].string)
        }
    }
}
