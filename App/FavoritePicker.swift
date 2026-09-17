import SwiftUI

enum FavoriteChanges {
    static func parameters(aid:String,original:Set<String>,selected:Set<String>) -> [String:String] {
        ["rid":aid,"type":"2","add_media_ids":selected.subtracting(original).sorted().joined(separator:","),"del_media_ids":original.subtracting(selected).sorted().joined(separator:",")]
    }
}
struct FavoritePicker:View {
    let aid:String
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var folders:[JSON] = []
    @State private var original:Set<String> = []
    @State private var selected:Set<String> = []
    @State private var loading = false
    @State private var loaded = false
    @State private var saving = false
    @State private var error = ""
    var body:some View {
        NavigationStack {
            List {
                if !session.loggedIn { NavigationLink("登录后收藏") { LoginView() } }
                ForEach(folders,id:\.rawID) { folder in
                    Toggle(isOn:Binding(get:{ selected.contains(folder.rawID) },set:{ if $0 { selected.insert(folder.rawID) } else { selected.remove(folder.rawID) } })) {
                        VStack(alignment:.leading,spacing:4) { Text(folder["title"].string);Text("\(folder["media_count"].int) 个内容").font(.caption).foregroundStyle(.secondary) }
                    }.disabled(saving)
                }
                if loading { ProgressView("加载收藏夹") }
                if !error.isEmpty { Text(error).foregroundStyle(.red);if !loaded { Button("重试") { Task { await load() } } } }
                if loaded && folders.isEmpty { Text("暂无收藏夹，请先创建收藏夹").foregroundStyle(.secondary) }
            }.navigationTitle("收藏到").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) { Button("取消") { dismiss() }.disabled(saving) }
                    ToolbarItem(placement:.confirmationAction) { Button(saving ? "保存中":"完成") { Task { await save() } }.disabled(!loaded || saving || loading || !session.loggedIn) }
                }.interactiveDismissDisabled(saving)
                .task(id:session.mid) { await load() }
        }
    }
    private func load() async {
        folders = [];original = [];selected = [];loaded = false;error = ""
        guard session.loggedIn else { return }
        loading = true;defer { loading = false }
        let account = session.mid
        do {
            let data = try await BiliAPI.shared.request("/x/v3/fav/folder/created/list-all",["up_mid":account,"rid":aid,"type":"2"])
            try Task.checkCancellation();guard session.mid == account else { return }
            folders = data["list"].array.filter { !$0.rawID.isEmpty }
            original = Set(folders.filter { $0["fav_state"].int == 1 }.map(\.rawID));selected = original;loaded = true
        } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
    }
    private func save() async {
        guard !saving,loaded else { return }
        if original == selected { dismiss();return }
        saving = true;error = "";defer { saving = false }
        do {
            _ = try await BiliAPI.shared.request("/x/v3/fav/resource/deal",FavoriteChanges.parameters(aid:aid,original:original,selected:selected),post:true)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
