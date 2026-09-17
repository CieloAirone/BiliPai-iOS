import Foundation
import CryptoKit

// API paths and WBI permutation ported from jay3-yy/BiliPai, d9470b1.
struct JSON: @unchecked Sendable {
    let raw: Any
    init(_ raw: Any = NSNull()) { self.raw = raw }
    subscript(_ key: String) -> JSON { JSON((raw as? [String: Any])?[key] ?? NSNull()) }
    var string: String { (raw as? String) ?? (raw as? NSNumber)?.stringValue ?? "" }
    var int: Int { (raw as? NSNumber)?.intValue ?? Int(string) ?? 0 }
    var array: [JSON] { (raw as? [Any] ?? []).map(JSON.init) }
}
struct BiliError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
enum WBI {
    static let permutation = [46,47,18,2,53,8,23,32,15,50,10,31,58,3,45,35,27,43,5,49,33,9,42,19,29,28,14,39,12,38,41,13,37,48,7,16,24,55,40,61,26,17,0,1,60,51,30,4,22,25,54,21,56,59,6,63,57,62,11,36,20,34,44,52]
    static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")) ?? ""
    }
    static func query(_ values: [String: String]) -> String {
        values.keys.sorted().map { "\(encode($0))=\(encode(values[$0]!))" }.joined(separator: "&")
    }
    static func sign(_ values: [String: String], img: String, sub: String, timestamp: Int) throws -> [String: String] {
        let characters = Array(img + sub)
        guard characters.count == 64 else { throw BiliError(message: "WBI 密钥无效") }
        let key = String(permutation.prefix(32).map { characters[$0] })
        var params = values.mapValues { String($0.filter { !"!'()*".contains($0) }) }
        params["wts"] = String(timestamp)
        params["w_rid"] = Insecure.MD5.hash(data: Data((query(params) + key).utf8)).map { String(format: "%02x", $0) }.joined()
        return params
    }
}
actor BiliAPI {
    static let shared = BiliAPI()
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 25
        c.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0", "Referer": "https://www.bilibili.com/"]
        return URLSession(configuration: c)
    }()
    func request(_ path: String, _ params: [String: String] = [:], post: Bool = false, signed: Bool = false) async throws -> JSON {
        var values = params
        if signed {
            let nav = try await request("/x/web-interface/nav")
            func key(_ url: String) -> String { URL(string: url)?.deletingPathExtension().lastPathComponent ?? "" }
            values = try WBI.sign(values, img: key(nav["wbi_img"]["img_url"].string), sub: key(nav["wbi_img"]["sub_url"].string), timestamp: Int(Date().timeIntervalSince1970))
        }
        if post {
            let csrf = HTTPCookieStorage.shared.cookies?.first { $0.name == "bili_jct" && $0.domain.hasSuffix("bilibili.com") }?.value ?? ""
            guard !csrf.isEmpty else { throw BiliError(message: "请先登录账号") }
            values["csrf"] = csrf
        }
        let base = path.hasPrefix("https://") ? path : "https://api.bilibili.com" + path
        guard let url = URL(string: base + (post || values.isEmpty ? "" : "?" + WBI.query(values))) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        if post { request.httpMethod = "POST"; request.httpBody = Data(WBI.query(values).utf8); request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw BiliError(message: "网络请求失败，请稍后重试") }
        let root = JSON(try JSONSerialization.jsonObject(with: data))
        let guestNav = path == "/x/web-interface/nav" && root["code"].int == -101
        guard root["code"].int == 0 || guestNav else { throw BiliError(message: "\(root["message"].string)（\(root["code"].int)）") }
        return root["data"].raw is NSNull ? root["result"] : root["data"]
    }
}
struct Video: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var cover: String
    var author: String
    var views: Int
    init(_ json: JSON) {
        id = json["bvid"].string
        if id.isEmpty { id = json["history"]["bvid"].string }
        title = json["title"].string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        cover = json["pic"].string.isEmpty ? json["cover"].string : json["pic"].string
        if cover.hasPrefix("//") { cover = "https:" + cover }
        cover = cover.replacingOccurrences(of: "http://", with: "https://")
        author = json["owner"]["name"].string
        if author.isEmpty { author = json["author"].string }
        if author.isEmpty { author = json["author_name"].string }
        views = json["stat"]["view"].int
        if views == 0 { views = json["play"].int }
    }
}
