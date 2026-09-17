import SwiftUI
import LocalAuthentication

struct PrivacyGate<Content:View>:View {
    @AppStorage("privateAuthentication") private var enabled = false
    @Environment(\.scenePhase) private var phase
    @State private var unlocked = false
    @State private var authenticating = false
    @State private var error = ""
    @ViewBuilder var content: () -> Content
    var body:some View {
        Group {
            if !enabled || unlocked { content() }
            else {
                ContentUnavailableView {
                    Label("隐私内容已锁定",systemImage:"lock.shield")
                } description: { Text(error.isEmpty ? "验证身份后查看历史与收藏":error) }
                actions: { Button("验证身份") { Task { await authenticate() } }.disabled(authenticating) }
            }
        }.task { if enabled && !unlocked { await authenticate() } }
            .onChange(of:phase) { _,new in if new == .background { unlocked = false } }
            .onChange(of:enabled) { _,_ in unlocked = false }
    }
    private func authenticate() async {
        guard !authenticating else { return }
        authenticating = true;defer { authenticating = false }
        let context = LAContext()
        do { unlocked = try await context.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"查看 BiliPai 的历史记录与收藏");error = "" }
        catch { self.error = error.localizedDescription }
    }
}
enum CacheMaintenance {
    static func shouldClear(days:Int,last:Date?,now:Date = Date()) -> Bool {
        days > 0 && (last == nil || now.timeIntervalSince(last!) >= Double(days)*86400)
    }
    static func apply(store:UserDefaults = .standard,cache:URLCache = .shared,now:Date = Date()) {
        let limit = store.integer(forKey:"cacheLimit")
        cache.diskCapacity = max(64,min(limit == 0 ? 256:limit,1024))*1024*1024
        let days = store.integer(forKey:"cacheDays")
        if shouldClear(days:days,last:store.object(forKey:"cacheLastClear") as? Date,now:now) {
            cache.removeAllCachedResponses();store.set(now,forKey:"cacheLastClear")
        }
    }
}
struct CopyableText:View {
    let text:String
    @AppStorage("copyText") private var enabled = false
    @State private var copied = false
    var body:some View {
        Text(text).textSelection(.enabled)
            .onTapGesture { if enabled { UIPasteboard.general.string = text;copied = true } }
            .alert("已复制",isPresented:$copied) { Button("好",role:.cancel) {} }
    }
}
