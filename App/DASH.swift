import Foundation
import Network

// ISO BMFF SegmentBase -> on-device HLS. Media never leaves the device for conversion.
struct ByteSpan: Equatable {
    let start: UInt64
    let end: UInt64
    var length: UInt64 { end - start + 1 }
    init(_ value: String) throws {
        let parts = value.split(separator: "-")
        guard parts.count == 2, let a = UInt64(parts[0]), let b = UInt64(parts[1]), b >= a else { throw BiliError(message: "无效的媒体字节范围") }
        start = a; end = b
    }
    init(start: UInt64, length: UInt64) throws {
        guard length > 0, start <= UInt64.max - length else { throw BiliError(message: "媒体字节范围溢出") }
        self.start = start; end = start + length - 1
    }
}
struct MediaSegment {
    let range: ByteSpan
    let duration: Double
}
enum SIDX {
    static func parse(_ data: Data, absoluteOffset: UInt64) throws -> [MediaSegment] {
        let bytes = [UInt8](data)
        func uint(_ offset: Int, _ size: Int) throws -> UInt64 {
            guard offset >= 0, offset + size <= bytes.count else { throw BiliError(message: "不完整的 SIDX 索引") }
            return bytes[offset..<(offset + size)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        }
        var box = 0
        while box + 8 <= bytes.count {
            let length = Int(try uint(box, 4))
            guard length >= 8, box + length <= bytes.count else { throw BiliError(message: "无效的 MP4 索引块") }
            if String(bytes: bytes[(box + 4)..<(box + 8)], encoding: .ascii) != "sidx" { box += length; continue }
            let version = try uint(box + 8, 1)
            guard version <= 1 else { throw BiliError(message: "不支持的 SIDX 版本") }
            let scale = try uint(box + 16, 4)
            guard scale > 0 else { throw BiliError(message: "无效媒体时间刻度") }
            let size = version == 0 ? 4 : 8
            let firstOffset = try uint(box + 20 + size, size)
            let countPosition = box + 20 + size * 2 + 2
            let count = Int(try uint(countPosition, 2))
            guard count > 0, countPosition + 2 + count * 12 <= box + length else { throw BiliError(message: "无效分段数量") }
            guard absoluteOffset <= UInt64.max - UInt64(box + length), firstOffset <= UInt64.max - absoluteOffset - UInt64(box + length) else { throw BiliError(message: "媒体索引溢出") }
            var cursor = absoluteOffset + UInt64(box + length) + firstOffset
            var result: [MediaSegment] = []
            for i in 0..<count {
                let pos = countPosition + 2 + i * 12
                let reference = try uint(pos, 4)
                guard reference & 0x80000000 == 0 else { throw BiliError(message: "暂不支持嵌套媒体索引") }
                let span = try ByteSpan(start: cursor, length: reference & 0x7fffffff)
                let duration = Double(try uint(pos + 4, 4)) / Double(scale)
                guard duration > 0 else { throw BiliError(message: "无效分段时长") }
                result.append(MediaSegment(range: span, duration: duration)); cursor = span.end + 1
            }
            return result
        }
        throw BiliError(message: "播放源未包含 SIDX 索引")
    }
}
struct HLSResource {
    var data: Data?
    var remote: URL?
    var range: ByteSpan?
    var mime: String
}
struct DASHTrack {
    let url: URL
    let initialization: ByteSpan
    let segments: [MediaSegment]
    let bandwidth: Int
    let codecs: String
    static func load(_ json: JSON) async throws -> DASHTrack {
        let source = json["baseUrl"].string.isEmpty ? json["base_url"].string : json["baseUrl"].string
        guard let url = URL(string: source.replacingOccurrences(of: "http://", with: "https://")), url.scheme == "https" else { throw URLError(.badURL) }
        let camel = json["SegmentBase"]
        let snake = json["segment_base"]
        let initialization = try ByteSpan(camel["Initialization"].string.isEmpty ? snake["initialization"].string : camel["Initialization"].string)
        let index = try ByteSpan(camel["indexRange"].string.isEmpty ? snake["index_range"].string : camel["indexRange"].string)
        let data = try await MediaFetch.bytes(url: url, range: index)
        return DASHTrack(url: url, initialization: initialization, segments: try SIDX.parse(data, absoluteOffset: index.start), bandwidth: json["bandwidth"].int, codecs: json["codecs"].string)
    }
    func install(name: String, token: String, resources: inout [String: HLSResource]) -> String {
        let prefix = "/\(token)/\(name)"
        resources[prefix + "/init.mp4"] = HLSResource(remote: url, range: initialization, mime: "video/mp4")
        var lines = ["#EXTM3U", "#EXT-X-VERSION:7", "#EXT-X-TARGETDURATION:\(Int(ceil(segments.map(\.duration).max() ?? 10)))", "#EXT-X-MEDIA-SEQUENCE:0", "#EXT-X-PLAYLIST-TYPE:VOD", "#EXT-X-MAP:URI=\"\(prefix)/init.mp4\""]
        for (index, segment) in segments.enumerated() {
            let path = prefix + "/\(index).m4s"
            resources[path] = HLSResource(remote: url, range: segment.range, mime: "video/iso.segment")
            lines.append(String(format: "#EXTINF:%.6f,", locale: Locale(identifier: "en_US_POSIX"), segment.duration)); lines.append(path)
        }
        lines.append("#EXT-X-ENDLIST")
        let playlist = prefix + "/index.m3u8"
        resources[playlist] = HLSResource(data: Data(lines.joined(separator: "\n").utf8), mime: "application/vnd.apple.mpegurl")
        return playlist
    }
}
enum MediaFetch {
    static func bytes(url: URL, range: ByteSpan) async throws -> Data {
        guard range.length <= 32 * 1024 * 1024 else { throw BiliError(message: "媒体分段超过安全缓冲限制") }
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.setValue("bytes=\(range.start)-\(range.end)", forHTTPHeaderField: "Range")
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (stream, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 206,
              http.value(forHTTPHeaderField: "Content-Range")?.hasPrefix("bytes \(range.start)-\(range.end)/") == true else { throw BiliError(message: "CDN 未返回请求的媒体分段") }
        var data = Data(); data.reserveCapacity(Int(range.length))
        for try await byte in stream {
            guard data.count < Int(range.length) else { throw BiliError(message: "CDN 分段长度异常") }
            data.append(byte)
        }
        guard data.count == Int(range.length) else { throw BiliError(message: "媒体分段下载不完整") }
        return data
    }
}
private final class ListenerCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !completed else { return false }; completed = true; return true
    }
}
final class HLSBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label: "bilipai.hls")
    private var listener: NWListener?
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var connections: [UUID: NWConnection] = [:]
    private let resources: [String: HLSResource]
    private let token: String
    init(resources: [String: HLSResource], token: String) {
        self.resources = resources; self.token = token
    }
    init(video: DASHTrack, audio: DASHTrack?) {
        token = UUID().uuidString
        var map: [String: HLSResource] = [:]
        let videoPath = video.install(name: "video", token: token, resources: &map)
        var lines = ["#EXTM3U", "#EXT-X-VERSION:7"]
        var audioAttribute = ""
        var codecs = video.codecs
        if let audio {
            let path = audio.install(name: "audio", token: token, resources: &map)
            lines.append("#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"Audio\",DEFAULT=YES,AUTOSELECT=YES,URI=\"\(path)\"")
            audioAttribute = ",AUDIO=\"audio\""; codecs += "," + audio.codecs
        }
        lines.append("#EXT-X-STREAM-INF:BANDWIDTH=\(max(1, video.bandwidth + (audio?.bandwidth ?? 0))),CODECS=\"\(codecs)\"\(audioAttribute)")
        lines.append(videoPath)
        map["/\(token)/master.m3u8"] = HLSResource(data: Data(lines.joined(separator: "\n").utf8), mime: "application/vnd.apple.mpegurl")
        resources = map
    }
    func start() async throws -> URL {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        return try await withCheckedThrowingContinuation { continuation in
            let completion = ListenerCompletion()
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    guard completion.claim() else { return }
                    listener.stateUpdateHandler = nil
                    guard let self, let port = listener.port, let url = URL(string: "http://127.0.0.1:\(port.rawValue)/\(self.token)/master.m3u8") else { continuation.resume(throwing: URLError(.badURL)); return }
                    continuation.resume(returning: url)
                case .failed(let error): if completion.claim() { continuation.resume(throwing: error) }
                case .cancelled: if completion.claim() { continuation.resume(throwing: CancellationError()) }
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }
    func stop() {
        queue.async { [self] in
            listener?.stateUpdateHandler = nil; listener?.cancel(); listener = nil
            tasks.values.forEach { $0.cancel() }; tasks.removeAll()
            connections.values.forEach { $0.cancel() }; connections.removeAll()
        }
    }
    private func accept(_ connection: NWConnection) {
        let id = UUID(); connections[id] = connection
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 45) { [weak self, weak connection] in
            self?.tasks.removeValue(forKey: id)?.cancel(); self?.connections.removeValue(forKey: id); connection?.cancel()
        }
        receive(connection, id: id, buffer: Data())
    }
    private func receive(_ connection: NWConnection, id: UUID, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var buffer = buffer; if let data { buffer.append(data) }
            guard buffer.count <= 16384 else { self.respond(connection, id: id, status: 400, data: Data(), mime: "text/plain"); return }
            guard let text = String(data: buffer, encoding: .utf8), text.contains("\r\n\r\n") else {
                if complete || error != nil { connection.cancel(); self.connections.removeValue(forKey: id) }
                else { self.receive(connection, id: id, buffer: buffer) }; return
            }
            let parts = text.components(separatedBy: "\r\n")[0].split(separator: " ")
            guard parts.count == 3, ["GET","HEAD"].contains(String(parts[0])), let resource = self.resources[String(parts[1])] else { self.respond(connection, id: id, status: 404, data: Data(), mime: "text/plain"); return }
            let head = parts[0] == "HEAD"
            self.tasks[id] = Task { [weak self] in
                do {
                    let data: Data
                    if let inline = resource.data { data = inline }
                    else if let url = resource.remote, let range = resource.range { data = try await MediaFetch.bytes(url: url, range: range) }
                    else { throw URLError(.badURL) }
                    self?.queue.async { self?.respond(connection, id: id, status: 200, data: data, mime: resource.mime, head: head) }
                } catch { self?.queue.async { self?.respond(connection, id: id, status: 502, data: Data(), mime: "text/plain") } }
            }
        }
    }
    private func respond(_ connection: NWConnection, id: UUID, status: Int, data: Data, mime: String, head: Bool = false) {
        var response = Data("HTTP/1.1 \(status) \(status == 200 ? "OK" : "Error")\r\nContent-Type: \(mime)\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n".utf8)
        if !head { response.append(data) }
        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            connection.cancel(); self?.tasks.removeValue(forKey: id); self?.connections.removeValue(forKey: id)
        })
    }
}
