import Foundation

struct BiliSubtitle:Identifiable {
    let id:String
    let name:String
    let language:String
    let isAI:Bool
    let url:URL?
    var inlineVTT:Data? = nil

    static func parse(_ value:JSON) -> BiliSubtitle? {
        var raw = value["subtitle_url"].string.trimmingCharacters(in:.whitespacesAndNewlines)
        if raw.hasPrefix("//") { raw = "https:" + raw }
        raw = raw.replacingOccurrences(of:"http://",with:"https://")
        guard let url = URL(string:raw),let host = url.host?.lowercased(),url.scheme == "https",
              ["hdslb.com","bilibili.com"].contains(where:{ host == $0 || host.hasSuffix("."+$0) }),
              url.path.lowercased().contains("subtitle") else { return nil }
        let language = value["lan"].string
        let name = value["lan_doc"].string.isEmpty ? language:value["lan_doc"].string
        let ai = value["ai_status"].int > 0 || value["ai_type"].int > 0 || language.hasPrefix("ai-") || ["ai","自动","机翻","机器"].contains(where:name.lowercased().contains)
        let id = value["id_str"].string.isEmpty ? value["id"].string:value["id_str"].string
        return BiliSubtitle(id:id.isEmpty ? language:id,name:name,language:language.replacingOccurrences(of:"ai-",with:""),isAI:ai,url:url)
    }
    func install(index:Int,token:String,duration:Double,resources:inout [String:HLSResource]) -> String {
        let prefix = "/\(token)/subtitle/\(index)"
        resources[prefix+".vtt"] = HLSResource(data:inlineVTT,mime:"text/vtt",subtitleURL:url)
        let length = max(1,duration)
        let playlist = ["#EXTM3U","#EXT-X-VERSION:7","#EXT-X-TARGETDURATION:\(Int(ceil(length)))","#EXT-X-MEDIA-SEQUENCE:0","#EXT-X-PLAYLIST-TYPE:VOD",String(format:"#EXTINF:%.3f,",locale:Locale(identifier:"en_US_POSIX"),length),prefix+".vtt","#EXT-X-ENDLIST"].joined(separator:"\n")+"\n"
        resources[prefix+".m3u8"] = HLSResource(data:Data(playlist.utf8),mime:"application/vnd.apple.mpegurl")
        return prefix+".m3u8"
    }
    static func attribute(_ value:String) -> String { value.replacingOccurrences(of:"\"",with:"'").components(separatedBy:.newlines).joined(separator:" ") }
}
enum SubtitlePolicy {
    static func preferred(_ tracks:[BiliSubtitle],mode:String,muted:Bool) -> BiliSubtitle? {
        if mode == "off" { return nil }
        let available = mode == "withoutAI" || (mode == "auto" && !muted) ? tracks.filter { !$0.isAI }:tracks
        return available.first(where:{ $0.language.hasPrefix("zh") }) ?? available.first
    }
}
enum WebVTT {
    static func timestamp(_ seconds:Double) -> String {
        let ms = Int((seconds*1000).rounded())
        return String(format:"%02d:%02d:%02d.%03d",ms/3600000,(ms/60000)%60,(ms/1000)%60,ms%1000)
    }
    static func convert(_ data:Data) throws -> Data {
        let root = JSON(try JSONSerialization.jsonObject(with:data))
        guard root["body"].raw is [Any] else { throw BiliError(message:"字幕内容格式无效") }
        var lines = ["WEBVTT","X-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:0",""]
        for cue in root["body"].array {
            guard let start = Double(cue["from"].string),let end = Double(cue["to"].string),start.isFinite,end.isFinite,start >= 0,end > start,end < 864000 else { continue }
            let text = cue["content"].string.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;").components(separatedBy:.newlines).filter { !$0.isEmpty }.joined(separator:"\n")
            guard !text.isEmpty else { continue }
            lines += ["\(timestamp(start)) --> \(timestamp(end))",text,""]
        }
        return Data((lines.joined(separator:"\n")+"\n").utf8)
    }
}
private final class SubtitleRedirectPolicy:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?) -> Void) { completionHandler(nil) }
}
enum SubtitleService {
    static func tracks(bvid:String,cid:String) async throws -> [BiliSubtitle] {
        try await withThrowingTaskGroup(of:[BiliSubtitle].self) { group in
            group.addTask { try await metadata(bvid:bvid,cid:cid) }
            group.addTask { try await Task.sleep(for:.seconds(4));throw URLError(.timedOut) }
            defer { group.cancelAll() }
            return try await group.next() ?? []
        }
    }
    private static func metadata(bvid:String,cid:String) async throws -> [BiliSubtitle] {
        let data = try await BiliAPI.shared.request("/x/player/wbi/v2",["bvid":bvid,"cid":cid],signed:true)
        var seen = Set<String>()
        return data["subtitle"]["subtitles"].array.compactMap(BiliSubtitle.parse).filter { seen.insert($0.id).inserted }
    }
    static func vtt(url:URL) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false;configuration.httpCookieStorage = nil;configuration.urlCredentialStorage = nil
        let session = URLSession(configuration:configuration,delegate:SubtitleRedirectPolicy(),delegateQueue:nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url:url,timeoutInterval:15)
        request.setValue("https://www.bilibili.com/",forHTTPHeaderField:"Referer")
        let (stream,response) = try await session.bytes(for:request)
        guard let response = response as? HTTPURLResponse,response.statusCode == 200 else { throw BiliError(message:"字幕下载失败") }
        var data = Data()
        for try await byte in stream { guard data.count < 4*1024*1024 else { throw BiliError(message:"字幕文件过大") };data.append(byte) }
        return try WebVTT.convert(data)
    }
}
