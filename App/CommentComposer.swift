import SwiftUI

struct CommentDraft:Identifiable {
    let id = UUID()
    let root:String
    let parent:String
    let recipient:String
    static let topLevel = CommentDraft(root:"0",parent:"0",recipient:"")
    static func reply(to comment:BiliComment) -> CommentDraft {
        CommentDraft(root:comment.rootID.isEmpty || comment.rootID == "0" ? comment.id:comment.rootID,parent:comment.id,recipient:comment.user)
    }
    func parameters(oid:String,message:String) -> [String:String] {
        ["oid":oid,"type":"1","message":message,"plat":"1","root":root,"parent":parent]
    }
}
struct CommentComposer:View {
    let oid:String
    let draft:CommentDraft
    var onSent:() -> Void
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var error = ""
    @State private var sending = false
    var body:some View {
        NavigationStack {
            Form {
                if !session.loggedIn { NavigationLink("登录后发表评论") { LoginView() } }
                Section(draft.recipient.isEmpty ? "发表评论":"回复 @\(draft.recipient)") {
                    TextEditor(text:$message).frame(minHeight:160).accessibilityLabel("评论内容").disabled(sending)
                }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
                if sending { ProgressView("正在发送") }
            }.navigationTitle("发表评论").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) { Button("取消") { dismiss() }.disabled(sending) }
                    ToolbarItem(placement:.confirmationAction) { Button("发送") { Task { await send() } }.disabled(sending || !session.loggedIn || message.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }
                }.interactiveDismissDisabled(sending)
        }
    }
    private func send() async {
        guard !sending else { return };sending = true;error = "";defer { sending = false }
        do {
            _ = try await BiliAPI.shared.request("/x/v2/reply/add",draft.parameters(oid:oid,message:message),post:true)
            onSent();dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
