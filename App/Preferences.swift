import SwiftUI
import UniformTypeIdentifiers
import CoreFoundation

// Only settings with a runtime consumer belong in this allowlist.
enum Preferences {
    static let defaults: [String: Any] = [
        "autoHighestQuality":false, "mobileQuality":64, "audioQuality":30280, "dataSaver":"off",
        "rememberSpeed":false, "lastSpeed":1.0, "audioFocus":true, "completion":"auto",
        "expandDescription":false, "copyText":false, "customAccent":"007AFF",
        "topTabs":"推荐,热门,排行榜,直播,番剧", "bottomOrder":"0,1,2,3,4",
        "privateAuthentication":false, "cacheDays":0, "cacheLimit":256,
        "commentSort":2, "commentPreviewCount":3, "appearance":"system", "accent":"blue", "fontScale":1.0,
        "autoplay":true, "rememberPosition":true, "quality":80, "defaultSpeed":1.0,
        "pip":true, "backgroundPlayback":true,
        "danmakuEnabled":true, "dmOpacity":0.85, "dmFontSize":15.0, "dmDuration":7.0,
        "dmLimit":36, "dmArea":0.5, "dmScroll":true, "dmTop":true, "dmBottom":true,
        "dmKeywords":"", "gridColumns":0, "cardWidth":155.0, "showAuthor":true,
        "heroCard":true, "feedCount":20, "defaultFeed":"推荐",
        "showDynamicTab":true, "showHistoryTab":true, "showListenTab":true,
        "haptics":true, "reduceMotion":false, "privacyMode":false,
        "rulePlugins":"[]", "disabledPlugins":"", "filterEnabled":false, "filterKeywords":"", "blockedAuthors":""
    ]
    static func register() { UserDefaults.standard.register(defaults: defaults) }
    static func lines(_ value: String) -> [String] { value.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
    static func accepts(_ video: Video, store: UserDefaults = .standard) -> Bool {
        let disabled = lines(store.string(forKey:"disabledPlugins") ?? "")
        let fields = ["title":JSON(video.title),"owner.name":JSON(video.author),"stat.view":JSON(video.views)]
        if RulePlugins.decode(store.string(forKey:"rulePlugins") ?? "[]").contains(where: { $0.type == "feed" && !disabled.contains($0.id) && $0.hides(fields) }) { return false }
        if lines(store.string(forKey:"blockedAuthors") ?? "").contains(video.author) { return false }
        guard store.bool(forKey:"filterEnabled") else { return true }
        return !lines(store.string(forKey:"filterKeywords") ?? "").contains { video.title.localizedCaseInsensitiveContains($0) }
    }
    static func export(store: UserDefaults = .standard) throws -> Data {
        let values = defaults.mapValues { $0 }
        let snapshot = Dictionary(uniqueKeysWithValues: values.map { ($0.key, store.object(forKey:$0.key) ?? $0.value) })
        return try JSONSerialization.data(withJSONObject:["format":"bilipai-ios-settings", "version":1,"values":snapshot],options:[.prettyPrinted,.sortedKeys])
    }
    static func validate(_ data: Data) throws -> [String: Any] {
        guard data.count <= 256 * 1024,
              let root = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              root["format"] as? String == "bilipai-ios-settings", root["version"] as? Int == 1,
              let values = root["values"] as? [String:Any] else { throw BiliError(message:"不是支持的 iOS 设置备份文件") }
        let ranges: [String:ClosedRange<Double>] = ["cacheDays":0...30,"cacheLimit":64...1024,"lastSpeed":0.5...2,"commentPreviewCount":0...5,"fontScale":0.8...1.4,"defaultSpeed":0.5...2,"dmOpacity":0.1...1,"dmFontSize":10...30,"dmDuration":3...15,"dmLimit":6...100,"dmArea":0.25...1,"gridColumns":0...4,"cardWidth":120...260,"feedCount":10...50]
        let enums: [String:[String]] = ["completion":["auto","pause","loop"],"dataSaver":["off","cellular","always"],"appearance":["system","light","dark"],"accent":["blue","pink","green","purple","orange","custom"],"defaultFeed":["推荐","热门","排行榜"]]
        var validated: [String:Any] = [:]
        for (key,value) in values {
            guard let expected = defaults[key] else { throw BiliError(message:"备份包含未知设置：\(key)") }
            if let string = expected as? String {
                _ = string
                guard let text = value as? String, text.count <= (key == "rulePlugins" ? 180000 : 16000) else { throw BiliError(message:"设置文本格式无效：\(key)") }
                if key == "customAccent", !text.matchesHexColor { throw BiliError(message:"颜色格式无效") }
                if key == "topTabs", !NavigationOptions.validTop(text) { throw BiliError(message:"顶部标签无效") }
                if key == "bottomOrder", !NavigationOptions.validBottom(text) { throw BiliError(message:"底栏顺序无效") }
                if key == "rulePlugins" {
                    let plugins = try JSONDecoder().decode([String].self,from:Data(text.utf8))
                    guard plugins.count <= 20 else { throw BiliError(message:"插件数量超过限制") }
                    for raw in plugins { _ = try RulePlugin.parse(Data(raw.utf8)) }
                }
                if let options = enums[key], !options.contains(text) { throw BiliError(message:"设置选项无效：\(key)") }
            } else {
                guard let number = value as? NSNumber, let expectedNumber = expected as? NSNumber else { throw BiliError(message:"设置数值格式无效：\(key)") }
                let isBool = CFGetTypeID(number) == CFBooleanGetTypeID()
                guard isBool == (CFGetTypeID(expectedNumber) == CFBooleanGetTypeID()) else { throw BiliError(message:"设置类型错误：\(key)") }
                if !isBool {
                    guard number.doubleValue.isFinite else { throw BiliError(message:"设置数值无效") }
                    if let range = ranges[key], !range.contains(number.doubleValue) { throw BiliError(message:"设置数值超出范围：\(key)") }
                    if ["quality","mobileQuality","audioQuality","cacheDays","cacheLimit","gridColumns","feedCount","dmLimit","commentSort","commentPreviewCount"].contains(key), number.doubleValue.rounded() != number.doubleValue { throw BiliError(message:"设置必须为整数") }
                    if key == "audioQuality", ![30216,30232,30280].contains(number.intValue) { throw BiliError(message:"音质选项无效") }
                    if key == "commentSort", ![0,2].contains(number.intValue) { throw BiliError(message:"评论排序无效") }
                    if ["quality","mobileQuality"].contains(key), ![16,32,64,80,112,116,120].contains(number.intValue) { throw BiliError(message:"画质选项无效") }
                }
            }
            validated[key] = value
        }
        return validated
    }
    static func restore(_ values: [String:Any], store: UserDefaults = .standard) { for (key,value) in values where defaults[key] != nil { store.set(value,forKey:key) } }
    static func clearPrivateHistory(store: UserDefaults = .standard) {
        store.removeObject(forKey:"searchHistory")
        for key in store.dictionaryRepresentation().keys where key.hasPrefix("position.") { store.removeObject(forKey:key) }
    }
    static var tint: Color {
        switch UserDefaults.standard.string(forKey:"accent") {
        case "custom": return Color(hex:UserDefaults.standard.string(forKey:"customAccent") ?? "007AFF")
        case "pink": return Color(red:0.98,green:0.45,blue:0.60)
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        default:return .blue
        }
    }
}
struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:data) }
}
