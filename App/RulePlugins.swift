import SwiftUI
import UniformTypeIdentifiers

struct RulePlugin: Identifiable {
    let id: String
    let name: String
    let description: String
    let type: String
    let raw: String
    let rules: [JSON]
    static func parse(_ data: Data) throws -> RulePlugin {
        guard data.count <= 128 * 1024, let raw = String(data:data,encoding:.utf8) else { throw BiliError(message:"插件文件过大或编码无效") }
        let root = JSON(try JSONSerialization.jsonObject(with:data))
        guard !root["id"].string.isEmpty, root["id"].string.count <= 128, !root["name"].string.isEmpty,
              ["feed","danmaku"].contains(root["type"].string), !root["rules"].array.isEmpty, root["rules"].array.count <= 100 else { throw BiliError(message:"插件缺少 id、名称、类型或规则") }
        for rule in root["rules"].array {
            guard rule["action"].string == "hide" else { throw BiliError(message:"当前支持 hide 过滤规则；此插件包含尚未移植的动作") }
            try validate(rule["condition"].raw is NSNull ? rule : rule["condition"],type:root["type"].string,depth:0)
        }
        return RulePlugin(id:root["id"].string,name:root["name"].string,description:root["description"].string,type:root["type"].string,raw:raw,rules:root["rules"].array)
    }
    private static func validate(_ condition: JSON,type:String,depth:Int) throws {
        guard depth < 8 else { throw BiliError(message:"规则嵌套过深") }
        for group in ["and","or"] where !(condition[group].raw is NSNull) {
            guard !condition[group].array.isEmpty, condition[group].array.count <= 32 else { throw BiliError(message:"复合规则数量无效") }
            for child in condition[group].array { try validate(child,type:type,depth:depth+1) };return
        }
        let allowed = type == "feed" ? ["title","owner.name","stat.view"] : ["content","type"]
        guard allowed.contains(condition["field"].string) else { throw BiliError(message:"尚未支持规则字段：\(condition["field"].string)") }
        guard ["eq","ne","lt","le","gt","ge","contains","startsWith","endsWith","in"].contains(condition["op"].string), !(condition["value"].raw is NSNull) else { throw BiliError(message:"尚未支持或无效的规则操作符：\(condition["op"].string)") }
    }
    func hides(_ fields: [String:JSON]) -> Bool {
        rules.contains { Self.matches($0["condition"].raw is NSNull ? $0 : $0["condition"],fields:fields) }
    }
    private static func matches(_ c:JSON,fields:[String:JSON]) -> Bool {
        if !(c["and"].raw is NSNull) { return c["and"].array.allSatisfy { matches($0,fields:fields) } }
        if !(c["or"].raw is NSNull) { return c["or"].array.contains { matches($0,fields:fields) } }
        guard let actual = fields[c["field"].string] else { return false }
        let expected = c["value"]
        switch c["op"].string {
        case "eq":return actual.string == expected.string
        case "ne":return actual.string != expected.string
        case "contains":return actual.string.contains(expected.string)
        case "startsWith":return actual.string.hasPrefix(expected.string)
        case "endsWith":return actual.string.hasSuffix(expected.string)
        case "in":return expected.array.contains { $0.string == actual.string }
        default:
            guard let a = Double(actual.string), let b = Double(expected.string) else { return false }
            switch c["op"].string { case "lt":return a < b;case "le":return a <= b;case "gt":return a > b;case "ge":return a >= b;default:return false }
        }
    }
}
enum RulePlugins {
    static func decode(_ string:String) -> [RulePlugin] {
        guard let strings = try? JSONDecoder().decode([String].self,from:Data(string.utf8)) else { return [] }
        return strings.compactMap { try? RulePlugin.parse(Data($0.utf8)) }
    }
    static func encode(_ plugins:[RulePlugin]) -> String { String(data:(try? JSONEncoder().encode(plugins.map(\.raw))) ?? Data(),encoding:.utf8) ?? "[]" }
}
struct PluginPreferences: View {
    @AppStorage("rulePlugins") private var stored = "[]"
    @AppStorage("disabledPlugins") private var disabled = ""
    @State private var importing = false
    @State private var pending: RulePlugin?
    @State private var message = ""
    private var plugins: [RulePlugin] { RulePlugins.decode(stored) }
    var body: some View {
        List {
            Section("内置过滤") { NavigationLink("推荐关键词过滤") { FilterPreferences() };NavigationLink("弹幕过滤与显示") { DanmakuPreferences() } }
            Section("JSON / .bp 规则插件") {
                Button("从文件导入插件") { importing = true }
                ForEach(plugins) { plugin in
                    VStack(alignment:.leading,spacing:6) {
                        Toggle(plugin.name,isOn:Binding(get:{ !Preferences.lines(disabled).contains(plugin.id) },set:{ enabled in
                            var ids = Set(Preferences.lines(disabled));if enabled { ids.remove(plugin.id) } else { ids.insert(plugin.id) };disabled = ids.sorted().joined(separator:"\n")
                        }))
                        Text(plugin.description).font(.caption).foregroundStyle(.secondary)
                        Text(plugin.type == "feed" ? "推荐流过滤":"弹幕过滤").font(.caption2).foregroundStyle(.secondary)
                    }.swipeActions { Button("删除",role:.destructive) { stored = RulePlugins.encode(plugins.filter { $0.id != plugin.id }) } }
                }
            }
            Section { Text("支持原版 JSON 的标题、作者、播放量、弹幕内容/类型过滤，以及 AND/OR 组合。含未支持字段、正则或高亮动作的文件会明确拒绝，不会静默忽略规则。").font(.caption).foregroundStyle(.secondary) }
        }
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json,.data]) { result in
            do { let url = try result.get();let access = url.startAccessingSecurityScopedResource();defer { if access { url.stopAccessingSecurityScopedResource() } };pending = try RulePlugin.parse(Data(contentsOf:url)) } catch { message = error.localizedDescription }
        }
        .sheet(item:$pending) { plugin in
            NavigationStack {
                List {
                    Text(plugin.name).font(.title2);Text(plugin.description)
                    Text("\(plugin.rules.count) 条过滤规则")
                    Text(plugin.raw).font(.system(.caption,design:.monospaced)).textSelection(.enabled)
                    Button("安装并启用") {
                        if plugins.filter({ $0.id != plugin.id }).count >= 20 { message = "最多安装 20 个规则插件";pending = nil;return }
                        stored = RulePlugins.encode(plugins.filter { $0.id != plugin.id } + [plugin]);disabled = Preferences.lines(disabled).filter { $0 != plugin.id }.joined(separator:"\n");pending = nil
                    }
                }.navigationTitle("预览规则").toolbar { Button("取消") { pending = nil } }
            }
        }
        .alert("插件",isPresented:Binding(get:{ !message.isEmpty },set:{ if !$0 { message = "" } })) { Button("好") { message = "" } } message:{ Text(message) }
    }
}
