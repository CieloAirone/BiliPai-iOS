import SwiftUI
import UniformTypeIdentifiers
import CoreFoundation

// Titles and order match upstream SettingsRootCategoryPolicy.kt.
enum SettingCategory: String, CaseIterable, Identifiable {
    case appearance = "外观与主题", playback = "播放与画质", home = "首页与推荐", navigation = "导航与交互", privacy = "隐私与权限", storage = "存储与备份", plugins = "插件与扩展", about = "系统与关于"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .appearance: return "调整界面风格、颜色、字体、大小和图标"
        case .playback: return "设置清晰度、倍速、字幕、小窗和全屏操作"
        case .home:return "调整首页卡片、推荐内容和动态页面"
        case .navigation:return "管理底栏、顶部入口、页面动画和振动反馈"
        case .privacy:return "管理历史记录、系统权限和已屏蔽的 UP 主"
        case .storage:return "管理下载位置、缓存、设置迁移和云备份"
        case .plugins:return "管理已安装插件和可选扩展功能"
        case .about:return "排查问题、检查更新并查看应用信息"
        }
    }
    var symbol: String {
        switch self {
        case .appearance:return "paintpalette.fill"
        case .playback:return "play.rectangle.fill"
        case .home:return "house.fill"
        case .navigation:return "hand.tap.fill"
        case .privacy:return "lock.shield.fill"
        case .storage:return "externaldrive.fill"
        case .plugins:return "puzzlepiece.extension.fill"
        case .about:return "info.circle.fill"
        }
    }
    var keywords: String {
        switch self {
        case .appearance:return "主题 明暗 颜色 字体 显示大小"
        case .playback:return "画质 倍速 自动播放 进度 弹幕 透明度 字号 速度 屏蔽 画中画 后台"
        case .home:return "卡片 网格 列数 作者 刷新 推荐"
        case .navigation:return "底栏 动态 历史 听视频 动画 触感"
        case .privacy:return "无痕 搜索历史 播放记录 黑名单 权限"
        case .storage:return "缓存 分享 导入 导出 备份 恢复 WebDAV"
        case .plugins:return "规则 过滤 关键词 推荐"
        case .about:return "版本 更新 许可 日志 源码"
        }
    }
}
struct SettingsView: View {
    @State private var query = ""
    var body: some View {
        List {
            ForEach(SettingCategory.allCases.filter { query.isEmpty || ($0.rawValue + $0.subtitle + $0.keywords).localizedCaseInsensitiveContains(query) }) { category in
                NavigationLink { SettingsCategoryView(category:category) } label: {
                    HStack(spacing:14) {
                        Image(systemName:category.symbol).font(.system(size:18)).foregroundStyle(.secondary).frame(width:26,height:30)
                        VStack(alignment:.leading,spacing:5) { Text(category.rawValue).font(.body.weight(.medium)); Text(category.subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                    }.padding(.vertical,4)
                }.accessibilityIdentifier("settings.\(category.id)").listRowSeparator(.hidden)
            }
        }.listStyle(.plain).toolbar(.hidden,for:.tabBar).navigationTitle("设置").navigationBarTitleDisplayMode(.inline).searchable(text:$query,placement:.navigationBarDrawer(displayMode:.always),prompt:"搜索设置功能")
    }
}
struct SettingsCategoryView: View {
    let category: SettingCategory
    var body: some View {
        Group {
            switch category {
            case .appearance: AppearancePreferences()
            case .playback: PlaybackPreferences()
            case .home: HomePreferences()
            case .navigation: NavigationPreferences()
            case .privacy: PrivacyPreferences()
            case .storage: StoragePreferences()
            case .plugins: PluginPreferences()
            case .about: AboutPreferences()
            }
        }.navigationTitle(category.rawValue).navigationBarTitleDisplayMode(.inline)
    }
}
struct AppearancePreferences: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("accent") private var accent = "blue"
    @AppStorage("fontScale") private var fontScale = 1.0
    var body: some View {
        Form {
            Section("界面与主题") {
                Picker("主题模式",selection:$appearance) { Text("跟随系统").tag("system");Text("浅色模式").tag("light");Text("深色模式").tag("dark") }.accessibilityIdentifier("settings.appearance.mode")
                Picker("主题颜色",selection:$accent) { Text("iOS 蓝色").tag("blue");Text("樱花粉").tag("pink");Text("薄荷绿").tag("green");Text("紫色").tag("purple");Text("橙色").tag("orange") }
            }
            Section("字体与显示大小") {
                SliderRow(title:"字体缩放",value:$fontScale,range:0.8...1.4,step:0.1,suffix:"×")
                Text("预览：BiliPai 让内容成为主角").font(.body)
            }
            Section("应用图标") { HStack { Image(uiImage:UIImage(named:"AppIcon60x60") ?? UIImage()).resizable().frame(width:48,height:48).clipShape(RoundedRectangle(cornerRadius:10));Text("蓝雪女仆 · 无留白") };Text("深色图标由 iOS 18 及以上的主屏幕外观控制。").font(.caption).foregroundStyle(.secondary) }
        }
    }
}
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let suffix: String
    var body: some View { VStack(alignment:.leading) { HStack { Text(title);Spacer();Text(String(format:"%.1f",value)+suffix).foregroundStyle(.secondary).monospacedDigit() };Slider(value:$value,in:range,step:step).accessibilityLabel(title) } }
}
struct PlaybackPreferences: View {
    @AppStorage("autoplay") private var autoplay = true
    @AppStorage("rememberPosition") private var remember = true
    @AppStorage("quality") private var quality = 80
    @AppStorage("defaultSpeed") private var speed = 1.0
    @AppStorage("pip") private var pip = true
    @AppStorage("backgroundPlayback") private var background = true
    var body: some View {
        Form {
            Section("播放与画质") {
                Picker("默认画质",selection:$quality) { Text("360P").tag(16);Text("480P").tag(32);Text("720P").tag(64);Text("1080P").tag(80);Text("1080P 高码率").tag(112);Text("1080P60").tag(116);Text("4K").tag(120) }
                Text("按账号和视频权限选择不高于目标的可用 AVC 画质；设置不会解锁会员权限。").font(.caption).foregroundStyle(.secondary)
                Picker("默认倍速",selection:$speed) { ForEach([0.5,0.75,1,1.25,1.5,2],id:\.self) { Text(String(format:"%g×",$0)).tag($0) } }
                Toggle("自动播放",isOn:$autoplay).accessibilityIdentifier("settings.autoplay")
                Toggle("记忆播放进度",isOn:$remember)
            }
            Section("小窗与后台") { Toggle("画中画",isOn:$pip);Toggle("后台播放",isOn:$background) }
            Section { NavigationLink("弹幕设置") { DanmakuPreferences() } }
        }
    }
}
struct DanmakuPreferences: View {
    @AppStorage("danmakuEnabled") private var enabled = true
    @AppStorage("dmOpacity") private var opacity = 0.85
    @AppStorage("dmFontSize") private var fontSize = 15.0
    @AppStorage("dmDuration") private var duration = 7.0
    @AppStorage("dmArea") private var area = 0.5
    @AppStorage("dmLimit") private var limit = 36
    @AppStorage("dmScroll") private var scroll = true
    @AppStorage("dmTop") private var top = true
    @AppStorage("dmBottom") private var bottom = true
    @AppStorage("dmKeywords") private var keywords = ""
    var body: some View {
        Form {
            Section { Toggle("显示弹幕",isOn:$enabled) }
            Section("显示") {
                SliderRow(title:"不透明度",value:$opacity,range:0.1...1,step:0.05,suffix:"")
                SliderRow(title:"字号",value:$fontSize,range:10...30,step:1,suffix:"")
                SliderRow(title:"经过屏幕时间",value:$duration,range:3...15,step:1,suffix:" 秒")
                SliderRow(title:"显示区域",value:$area,range:0.25...1,step:0.25,suffix:"")
                Stepper("同屏上限：\(limit)",value:$limit,in:6...100,step:2)
            }
            Section("弹幕类型") { Toggle("滚动弹幕",isOn:$scroll);Toggle("顶部弹幕",isOn:$top);Toggle("底部弹幕",isOn:$bottom) }
            Section("屏蔽关键词 · 每行一个") { TextEditor(text:$keywords).frame(minHeight:120).autocorrectionDisabled() }
        }.navigationTitle("弹幕设置").navigationBarTitleDisplayMode(.inline)
    }
}
struct HomePreferences: View {
    @AppStorage("gridColumns") private var columns = 0
    @AppStorage("cardWidth") private var width = 155.0
    @AppStorage("showAuthor") private var author = true
    @AppStorage("heroCard") private var hero = true
    @AppStorage("feedCount") private var count = 20
    @AppStorage("defaultFeed") private var feed = "推荐"
    var body: some View {
        Form {
            Section("首页展示") {
                Picker("默认首页",selection:$feed) { ForEach(["推荐","热门","排行榜"],id:\.self) { Text($0) } }
                Toggle("首页大卡片",isOn:$hero)
                Picker("网格列数",selection:$columns) { Text("自动").tag(0);ForEach(1...4,id:\.self) { Text("\($0) 列").tag($0) } }
                if columns == 0 { SliderRow(title:"推荐流卡片宽度",value:$width,range:120...260,step:10,suffix:"") }
                Toggle("UP主名称",isOn:$author)
            }
            Section("推荐流") { Stepper("每次刷新数量：\(count)",value:$count,in:10...50,step:10);Text("刷新后生效。").font(.caption).foregroundStyle(.secondary) }
        }
    }
}
struct NavigationPreferences: View {
    @AppStorage("showDynamicTab") private var dynamic = true
    @AppStorage("showHistoryTab") private var history = true
    @AppStorage("showListenTab") private var listen = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("reduceMotion") private var reduce = false
    var body: some View {
        Form {
            Section("底栏项目") { Toggle("动态",isOn:$dynamic);Toggle("历史",isOn:$history);Toggle("听视频",isOn:$listen);Text("推荐和我的始终保留，设置入口不会被隐藏。").font(.caption).foregroundStyle(.secondary) }
            Section("交互") { Toggle("触感反馈",isOn:$haptics);Toggle("减少动态效果",isOn:$reduce) }
        }
    }
}
struct PrivacyPreferences: View {
    @AppStorage("privacyMode") private var privacy = false
    @AppStorage("blockedAuthors") private var authors = ""
    @State private var clear = false
    var body: some View {
        Form {
            Section { Toggle("隐私无痕",isOn:$privacy);Text("不保存或读取本地搜索历史与播放位置；此选项不会清除 B 站服务器已有的历史记录。").font(.caption).foregroundStyle(.secondary) }
            Section("历史记录") { Button("清除本地搜索和播放记录",role:.destructive) { clear = true } }
            Section("已屏蔽的 UP 主 · 每行一个完整名称") { TextEditor(text:$authors).frame(minHeight:110).autocorrectionDisabled();Text("在视频列表中隐藏匹配作者，不修改 B 站账号黑名单。").font(.caption).foregroundStyle(.secondary) }
            Section("权限管理") { Link("打开系统权限设置",destination:URL(string:UIApplication.openSettingsURLString)!);Text("相册、通知等权限仅在对应能力使用时请求。").font(.caption).foregroundStyle(.secondary) }
        }.confirmationDialog("清除本地搜索和播放记录？",isPresented:$clear,titleVisibility:.visible) { Button("清除",role:.destructive) { Preferences.clearPrivateHistory() } }
    }
}
struct StoragePreferences: View {
    @State private var exporting = false
    @State private var importing = false
    @State private var document = SettingsDocument(data:Data())
    @State private var pending: [String:Any]?
    @State private var message = ""
    @State private var cacheSize = 0
    @State private var clear = false
    var body: some View {
        Form {
            Section("缓存") {
                LabeledContent("网络缓存",value:ByteCountFormatter.string(fromByteCount:Int64(cacheSize),countStyle:.file))
                Button("清除缓存",role:.destructive) { clear = true }
            }
            Section("云备份") { NavigationLink("WebDAV 云备份") { WebDAVSettings() } }
            Section("设置分享") {
                Button("导出设置") { do { document = SettingsDocument(data:try Preferences.export());exporting = true } catch { message = error.localizedDescription } }
                Button("从文件导入设置") { importing = true }
                Text("仅包含界面、播放和过滤规则，不包含账号凭证、Cookie、搜索记录或播放历史。").font(.caption).foregroundStyle(.secondary)
            }
        }.onAppear { cacheSize = URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage }
        .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"BiliPai-iOS-settings") { result in if case .failure(let error) = result { message = error.localizedDescription } }
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json]) { result in
            do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource();defer { if access { url.stopAccessingSecurityScopedResource() } };pending = try Preferences.validate(Data(contentsOf:url)) } catch { message = error.localizedDescription }
        }
        .confirmationDialog("替换备份中包含的设置？",isPresented:Binding(get:{ pending != nil },set:{ if !$0 { pending = nil } }),titleVisibility:.visible) { Button("导入设置") { if let pending { Preferences.restore(pending) };pending = nil } }
        .confirmationDialog("清除网络缓存？",isPresented:$clear,titleVisibility:.visible) { Button("清除",role:.destructive) { URLCache.shared.removeAllCachedResponses();cacheSize = 0 } }
        .alert("提示",isPresented:Binding(get:{ !message.isEmpty },set:{ if !$0 { message = "" } })) { Button("好") { message = "" } } message:{ Text(message) }
    }
}
struct FilterPreferences: View {
    @AppStorage("filterEnabled") private var enabled = false
    @AppStorage("filterKeywords") private var keywords = ""
    var body: some View {
        Form {
            Section("推荐流过滤") { Toggle("启用关键词过滤",isOn:$enabled);Text("标题命中任一关键词的视频会从原生视频列表隐藏。").font(.caption).foregroundStyle(.secondary) }
            Section("规则 · 每行一个关键词") { TextEditor(text:$keywords).frame(minHeight:180).autocorrectionDisabled() }
        }
    }
}
struct AboutPreferences: View {
    var body: some View {
        Form {
            Section("版本") {
                LabeledContent("BiliPai iOS",value:"\(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? ""))")
                Link("检查更新",destination:URL(string:"https://github.com/CieloAirone/BiliPai-iOS/releases/latest")!)
                Link("查看更新日志",destination:URL(string:"https://github.com/CieloAirone/BiliPai-iOS/releases")!)
            }
            Section("开源与支持") {
                Link("原版开源主页",destination:URL(string:"https://github.com/jay3-yy/BiliPai")!)
                Link("iOS 开源主页",destination:URL(string:"https://github.com/CieloAirone/BiliPai-iOS")!)
                Link("开源许可证",destination:URL(string:"https://github.com/CieloAirone/BiliPai-iOS/blob/main/LICENSE")!)
                Link("反馈问题",destination:URL(string:"https://github.com/CieloAirone/BiliPai-iOS/issues")!)
                Text("非原作者官方 iOS 发行版。本软件不提供任何担保。").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
