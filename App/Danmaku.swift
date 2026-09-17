import SwiftUI
import AVFoundation

struct Danmaku: Identifiable, Equatable {
    let id: Int
    let time: Double
    let mode: Int
    let color: Int
    let text: String
}
enum Proto {
    struct Field { let number: Int; let integer: UInt64?; let bytes: Data? }
    static func fields(_ data: Data) throws -> [Field] {
        let bytes = [UInt8](data); var cursor = 0; var result: [Field] = []
        func varint() throws -> UInt64 {
            var value: UInt64 = 0
            for shift in stride(from: 0, through: 63, by: 7) {
                guard cursor < bytes.count else { throw BiliError(message: "弹幕数据不完整") }
                let byte = bytes[cursor]; cursor += 1
                guard shift != 63 || byte <= 1 else { throw BiliError(message: "弹幕数字溢出") }
                value |= UInt64(byte & 127) << shift
                if byte & 128 == 0 { return value }
            }
            throw BiliError(message: "弹幕数字无效")
        }
        while cursor < bytes.count {
            let tag = try varint(); let number = Int(tag >> 3)
            guard number > 0 else { throw BiliError(message: "弹幕字段无效") }
            switch tag & 7 {
            case 0: result.append(Field(number: number, integer: try varint(), bytes: nil))
            case 2:
                let length = try varint()
                guard length <= UInt64(bytes.count - cursor) else { throw BiliError(message: "弹幕长度无效") }
                result.append(Field(number: number, integer: nil, bytes: Data(bytes[cursor..<(cursor + Int(length))]))); cursor += Int(length)
            case 1, 5:
                let count = tag & 7 == 1 ? 8 : 4
                guard cursor + count <= bytes.count else { throw BiliError(message: "弹幕字段不完整") }; cursor += count
            default: throw BiliError(message: "不支持的弹幕字段")
            }
        }
        return result
    }
    static func danmaku(_ data: Data) throws -> [Danmaku] {
        try fields(data).filter { $0.number == 1 }.compactMap { field in
            guard let bytes = field.bytes else { return nil }
            let values = try fields(bytes)
            func number(_ key: Int) -> Int { Int(clamping: values.first { $0.number == key }?.integer ?? 0) }
            let text = values.first { $0.number == 7 }?.bytes.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            guard !text.isEmpty, [1,2,3,4,5,6].contains(number(3)) else { return nil }
            return Danmaku(id: number(1), time: Double(number(2)) / 1000, mode: number(3), color: number(5), text: String(text.prefix(160)))
        }.sorted { $0.time < $1.time }
    }
}
actor DanmakuStore {
    private var cache: [String: [Danmaku]] = [:]
    func segment(cid: String, index: Int) async throws -> [Danmaku] {
        let key = "\(cid).\(index)"
        if let items = cache[key] { return items }
        guard let url = URL(string: "https://api.bilibili.com/x/v2/dm/web/seg.so?type=1&oid=\(cid)&segment_index=\(index)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url); request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 8 * 1024 * 1024 else { throw BiliError(message: "弹幕加载失败") }
        let items = try Proto.danmaku(data)
        if cache.count > 8 { cache.removeAll() }
        cache[key] = items; return items
    }
}
struct DanmakuOverlay: View {
    @AppStorage("dmOpacity") private var opacity = 1.0
    @AppStorage("dmFontSize") private var fontSize = 15.0
    @AppStorage("dmDuration") private var duration = 7.0
    @AppStorage("dmLimit") private var limit = 36
    @AppStorage("dmArea") private var area = 1.0
    @AppStorage("dmScroll") private var scroll = true
    @AppStorage("dmTop") private var top = true
    @AppStorage("dmBottom") private var bottom = true
    @AppStorage("dmKeywords") private var keywords = ""
    let player: AVPlayer
    let cid: String
    @State private var items: [Danmaku] = []
    @State private var store = DanmakuStore()
    @State private var segmentIndex = 1
    @State private var failure = ""
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            Canvas { context, size in
                draw(context:context,size:size)
            }
        }.opacity(opacity).clipped().allowsHitTesting(false).accessibilityHidden(true)
        .overlay(alignment: .topTrailing) { if !failure.isEmpty { Text("弹幕暂不可用").font(.caption2).padding(4).background(.black.opacity(0.5)).foregroundStyle(.white) } }
        .task(id: cid) {
            items = []; segmentIndex = 0
            while !Task.isCancelled {
                let time = player.currentTime().seconds
                let next = time.isFinite ? max(1, Int(time / 360) + 1) : 1
                if next != segmentIndex {
                    do {
                        let current = try await store.segment(cid: cid, index: next)
                        let previous = next > 1 ? try await store.segment(cid: cid, index: next - 1) : []
                        try Task.checkCancellation(); items = previous + current; segmentIndex = next; failure = ""
                    } catch { if !Task.isCancelled { failure = error.localizedDescription; segmentIndex = next } }
                }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
    private func draw(context:GraphicsContext,size:CGSize) {
                let current = player.currentTime().seconds
                guard current.isFinite else { return }
                // Quantize each lane to one entry per 2 seconds to keep a bounded draw budget.
                var low = 0; var high = items.count
                while low < high {
                    let mid = (low + high) / 2
                    if items[mid].time <= current { low = mid + 1 } else { high = mid }
                }
                let active = items[max(0, low - limit)..<low].filter { current - $0.time < duration }
                var occupied = Set<Int>()
                for item in active {
                    if Preferences.lines(keywords).contains(where:item.text.localizedCaseInsensitiveContains) { continue }
                    if item.mode == 4 && !bottom || item.mode == 5 && !top || [1,2,3,6].contains(item.mode) && !scroll { continue }
                    let rows = max(1,Int((size.height * CGFloat(area) - 40) / CGFloat(fontSize + 9)))
                    let lane = abs(item.id % rows)
                    let slot = lane * 100000 + Int(item.time / 2)
                    guard occupied.insert(slot).inserted else { continue }
                    let color = Color(red: Double((item.color >> 16) & 255)/255, green: Double((item.color >> 8) & 255)/255, blue: Double(item.color & 255)/255)
                    let text = Text(item.text).font(.system(size: CGFloat(fontSize), weight: .semibold)).foregroundColor(color)
                    let resolved = context.resolve(text)
                    let width = resolved.measure(in: CGSize(width: 1600, height: 30)).width
                    let progress = CGFloat((current - item.time) / duration)
                    var x = size.width - progress * (size.width + width)
                    var y = CGFloat(lane) * CGFloat(fontSize + 9) + 20
                    if item.mode == 4 { x = (size.width - width)/2; y = size.height * CGFloat(area) - 40 - CGFloat(lane % 2) * 24 }
                    if item.mode == 5 { x = (size.width - width)/2; y = 20 + CGFloat(lane % 2) * 24 }
                    if item.mode == 6 { x = -width + progress * (size.width + width) }
                    var shadow = context; shadow.addFilter(.shadow(color: .black.opacity(0.9), radius: 1)); shadow.draw(resolved, at: CGPoint(x: x, y: y), anchor: .topLeading)
                }
    }

}
