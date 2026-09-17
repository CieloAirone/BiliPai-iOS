import SwiftUI

// Explicit URLSession configuration prevents account cookies from reaching a backup server.
final class BackupTransport: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func transfer(endpoint: String, username: String, password: String, body: Data?) async throws -> Data {
        guard let url = URL(string:endpoint), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil, url.fragment == nil else { throw BiliError(message:"请输入完整的 HTTPS 备份文件地址，账号密码请填写在下方。") }
        var request = URLRequest(url:url,timeoutInterval:30)
        request.httpMethod = body == nil ? "GET":"PUT"
        request.httpBody = body
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        if !username.isEmpty { request.setValue("Basic " + Data((username + ":" + password).utf8).base64EncodedString(),forHTTPHeaderField:"Authorization") }
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false; config.urlCredentialStorage = nil
        let session = URLSession(configuration:config,delegate:self,delegateQueue:nil)
        defer { session.invalidateAndCancel() }
        let (stream,response) = try await session.bytes(for:request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            if (300..<400).contains(http.statusCode) { throw BiliError(message:"服务器要求跳转，请使用最终的文件地址。") }
            throw BiliError(message:"WebDAV 请求失败（HTTP \(http.statusCode)）")
        }
        var result = Data()
        for try await byte in stream {
            guard result.count < 256 * 1024 else { throw BiliError(message:"备份文件超过大小限制") }
            result.append(byte)
        }
        return result
    }
}
struct WebDAVSettings: View {
    @State private var endpoint = ""
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var overwrite = false
    @State private var pending: [String:Any]?
    @State private var message = ""
    var body: some View {
        Form {
            Section("WebDAV 云备份") {
                TextField("https://服务器/目录/BiliPai.json",text:$endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("用户名",text:$username).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("密码或应用专用密码",text:$password)
                Text("填写完整的备份文件地址，目录须已存在。凭证仅在此页面内存中使用，不写入备份。").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("备份到服务器") { overwrite = true }.disabled(busy || endpoint.isEmpty)
                Button("从服务器恢复") { Task { await download() } }.disabled(busy || endpoint.isEmpty)
                if busy { ProgressView("正在传输") }
            }
        }.navigationTitle("WebDAV 云备份").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("覆盖服务器上的同名备份文件？",isPresented:$overwrite,titleVisibility:.visible) { Button("上传备份") { Task { await upload() } } }
        .confirmationDialog("使用云端备份替换对应设置？",isPresented:Binding(get:{ pending != nil },set:{ if !$0 { pending = nil } }),titleVisibility:.visible) { Button("恢复设置") { if let pending { Preferences.restore(pending) };pending = nil;message = "设置已恢复" } }
        .alert("WebDAV",isPresented:Binding(get:{ !message.isEmpty },set:{ if !$0 { message = "" } })) { Button("好") { message = "" } } message: { Text(message) }
    }
    private func upload() async {
        busy = true;defer { busy = false }
        do { _ = try await BackupTransport().transfer(endpoint:endpoint,username:username,password:password,body:Preferences.export());message = "备份完成" }
        catch { message = error.localizedDescription }
    }
    private func download() async {
        busy = true;defer { busy = false }
        do { let data = try await BackupTransport().transfer(endpoint:endpoint,username:username,password:password,body:nil); pending = try Preferences.validate(data) }
        catch { message = error.localizedDescription }
    }
}
