import Foundation
import Observation
import Security

@MainActor @Observable final class Session {
    var name = "未登录"
    var mid = ""
    var avatar = ""
    var revision = 0
    var loggedIn: Bool { !mid.isEmpty }
    init() { restore() }
    private let service = "fun.caservice.bilipai.cookies"
    func refresh() async {
        do {
            let nav = try await BiliAPI.shared.request("/x/web-interface/nav")
            mid = nav["isLogin"].int == 1 ? nav["mid"].string : ""
            name = mid.isEmpty ? "未登录" : nav["uname"].string
            avatar = nav["face"].string
        } catch { mid = ""; name = "未登录" }
        revision += 1
    }
    func persist() throws {
        let cookies = (HTTPCookieStorage.shared.cookies ?? []).filter { $0.domain == "bilibili.com" || $0.domain.hasSuffix(".bilibili.com") }
        let rows: [[String: Any]] = cookies.map { c in ["name":c.name,"value":c.value,"domain":c.domain,"path":c.path,"expires":c.expiresDate?.timeIntervalSince1970 ?? Date().addingTimeInterval(86400 * 30).timeIntervalSince1970] }
        let data = try JSONSerialization.data(withJSONObject: rows)
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"session"]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String:data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw BiliError(message: "无法安全保存登录状态") }; return
        }
        guard status == errSecSuccess else { throw BiliError(message: "无法更新登录状态") }
    }
    private func restore() {
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"session",kSecReturnData as String:true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        for row in rows {
            let expires = Date(timeIntervalSince1970: row["expires"] as? Double ?? 0)
            guard expires > Date() else { continue }
            if let c = HTTPCookie(properties: [.name:row["name"] ?? "",.value:row["value"] ?? "",.domain:row["domain"] ?? "",.path:row["path"] ?? "/",.secure:"TRUE",.expires:expires]) { HTTPCookieStorage.shared.setCookie(c) }
        }
    }
    func importCookie(_ text: String) throws {
        for part in text.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pair.count == 2, ["SESSDATA","bili_jct","DedeUserID","buvid3","buvid4"].contains(pair[0]) else { continue }
            if let c = HTTPCookie(properties: [.name:pair[0],.value:pair[1],.domain:".bilibili.com",.path:"/",.secure:"TRUE",.expires:Date().addingTimeInterval(86400 * 30)]) { HTTPCookieStorage.shared.setCookie(c) }
        }
        try persist()
    }
    func logout() {
        for c in HTTPCookieStorage.shared.cookies ?? [] where c.domain == "bilibili.com" || c.domain.hasSuffix(".bilibili.com") { HTTPCookieStorage.shared.deleteCookie(c) }
        SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service] as CFDictionary)
        mid = ""; name = "未登录"; avatar = ""; revision += 1
    }
}
