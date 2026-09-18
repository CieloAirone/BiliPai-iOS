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
        case .playback:return "画质 倍速 自动播放 进度 弹幕 透明度 字号 速度 屏蔽 画中画 后台 评论 回复 无线 移动 网络 省流量 音质 播完"
        case .home:return "卡片 网格 列数 作者 刷新 推荐"
        case .navigation:return "底栏 动态 历史 听视频 动画 触感 顶部标签 排序 文字复制"
        case .privacy:return "无痕 搜索历史 播放记录 黑名单 权限 隐私验证 人脸 指纹"
        case .storage:return "缓存 分享 导入 导出 备份 恢复 WebDAV"
        case .plugins:return "规则 过滤 关键词 推荐"
        case .about:return "版本 更新 许可 日志 源码"
        }
    }
}
struct SettingsView: View {
    @ScaledMetric(relativeTo:.body) private var titleSize = 16.0
    @ScaledMetric(relativeTo:.caption) private var subtitleSize = 12.0
    @State private var query = ""
    private let colors:[Color] = [.blue,.pink,.orange,.purple,.green,.cyan,.indigo,.gray]
    private var categories:[SettingCategory] { SettingCategory.allCases.filter { query.isEmpty || ($0.rawValue+$0.subtitle+$0.keywords).localizedCaseInsensitiveContains(query) } }
    var body: some View {
        ScrollView {
            VStack(spacing:0) {
                ForEach(categories) { category in
                    NavigationLink { SettingsCategoryView(category:category) } label: {
                        HStack(spacing:14) {
                            Image(systemName:category.symbol).font(.system(size:20)).foregroundStyle(.white)
                                .frame(width:36,height:36).background(colors[SettingCategory.allCases.firstIndex(of:category) ?? 0],in:RoundedRectangle(cornerRadius:10))
                            VStack(alignment:.leading,spacing:2) {
                                Text(category.rawValue).font(.system(size:titleSize,weight:.medium)).foregroundStyle(.primary)
                                Text(category.subtitle).font(.system(size:subtitleSize)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                            }.frame(maxWidth:.infinity,alignment:.leading)
                            Image(systemName:"chevron.right").font(.system(size:14)).foregroundStyle(.tertiary)
                        }.padding(.horizontal,16).padding(.vertical,12).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("settings.\(category.id)")
                    if category != categories.last { Divider().padding(.leading,66) }
                }
            }.background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:14)).padding(16)
        }.background(Color(uiColor:.systemGroupedBackground)).toolbar(.hidden,for:.tabBar)
            .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .searchable(text:$query,placement:.navigationBarDrawer(displayMode:.always),prompt:"搜索设置功能")
    }
}
struct SettingsCategoryView: View {
    let category: SettingCategory
    var body: some View {
        Group {
            switch category {
            case .appearance:
                Form { Section("外观与主题") { NavigationLink("外观设置") { AppearancePreferences().navigationTitle("外观设置").navigationBarTitleDisplayMode(.inline) } } }
            case .playback:
                Form {
                    Section("播放与画质") { NavigationLink("播放器设置") { PlaybackPreferences().navigationTitle("播放器设置").navigationBarTitleDisplayMode(.inline) } }
                    Section("互动与评论") { NavigationLink("互动、评论与内容预览") { CommentPreferences() } }
                }
            case .home: HomeCategoryPreferences()
            case .navigation:
                Form {
                    Section("导航") { NavigationLink("导航与标签") { NavigationPreferences().navigationTitle("导航与标签").navigationBarTitleDisplayMode(.inline) } }
                    Section("交互与动效") { NavigationLink("动效与触感") { InteractionPreferences() } }
                }
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
    @AppStorage("customAccent") private var customAccent = "007AFF"
    @State private var hexInput = ""
    @AppStorage("fontScale") private var fontScale = 1.0
    var body: some View {
        Form {
            Section("界面与主题") {
                Picker("主题模式",selection:$appearance) { Text("跟随系统").tag("system");Text("浅色模式").tag("light");Text("深色模式").tag("dark") }.accessibilityIdentifier("settings.appearance.mode")
                Picker("主题颜色",selection:$accent) { Text("iOS 蓝色").tag("blue");Text("樱花粉").tag("pink");Text("薄荷绿").tag("green");Text("紫色").tag("purple");Text("橙色").tag("orange");Text("自定义").tag("custom") }
            }
            Section("自定义主题颜色") {
                ColorPicker("主题色",selection:Binding(get:{ Color(hex:customAccent) },set:{ customAccent = $0.hexRGB;accent = "custom" }),supportsOpacity:false)
                HStack {
                    Text("HEX")
                    TextField("007AFF",text:$hexInput).textInputAutocapitalization(.characters).autocorrectionDisabled().onSubmit { applyHex() }
                    Button("应用") { applyHex() }.disabled(!hexInput.replacingOccurrences(of:"#",with:"").matchesHexColor)
                }.onAppear { hexInput = customAccent }.onChange(of:customAccent) { _,value in hexInput = value }
            }
            Section("字体与显示大小") {
                SliderRow(title:"字体缩放",value:$fontScale,range:0.8...1.4,step:0.1,suffix:"×")
                Text("预览：BiliPai 让内容成为主角").font(.body)
            }
            Section("应用图标") { HStack { Image(uiImage:UIImage(named:"AppIcon60x60") ?? UIImage()).resizable().frame(width:48,height:48).clipShape(RoundedRectangle(cornerRadius:10));Text("蓝雪女仆 · 无留白") };Text("深色图标由 iOS 18 及以上的主屏幕外观控制。").font(.caption).foregroundStyle(.secondary) }
        }
    }
    private func applyHex() {
        let value = hexInput.replacingOccurrences(of:"#",with:"").uppercased()
        if value.matchesHexColor { customAccent = value;accent = "custom" }
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
    @AppStorage("autoFullscreen") private var autoFullscreen = false
    @AppStorage("autoHighestQuality") private var highest = false
    @AppStorage("mobileQuality") private var mobileQuality = 64
    @AppStorage("audioQuality") private var audioQuality = 30280
    @AppStorage("dataSaver") private var dataSaver = "off"
    @AppStorage("rememberSpeed") private var rememberSpeed = false
    @AppStorage("audioFocus") private var audioFocus = true
    @AppStorage("completion") private var completion = "auto"
    @AppStorage("autoNextVideo") private var autoNextVideo = true
    @AppStorage("autoplay") private var autoplay = true
    @AppStorage("rememberPosition") private var remember = true
    @AppStorage("quality") private var quality = 80
    @AppStorage("defaultSpeed") private var speed = 1.0
    @AppStorage("pip") private var pip = true
    @AppStorage("backgroundPlayback") private var background = true
    var body: some View {
        Form {
            Section("播放行为") {
                Toggle("进入视频自动全屏播放",isOn:$autoFullscreen).accessibilityIdentifier("settings.autoFullscreen")
                Text("开启后进入视频会自动播放并全屏；手动退出全屏后不会再次自动弹出。听视频不受影响。").font(.caption).foregroundStyle(.secondary)
                Toggle("进入视频自动播放",isOn:$autoplay).accessibilityIdentifier("settings.autoplay")
                Toggle("记忆播放进度",isOn:$remember)
                Toggle("记忆上次播放速度",isOn:$rememberSpeed)
                Picker("默认播放速度",selection:$speed) { ForEach([0.5,0.75,1,1.25,1.5,2],id:\.self) { Text(String(format:"%g×",$0)).tag($0) } }.disabled(rememberSpeed)
                Picker("视频播完后",selection:$completion) { Text("自动").tag("auto");Text("暂停").tag("pause");Text("单集循环").tag("loop") }
                Toggle("播放完自动播放下一个视频",isOn:$autoNextVideo)
                Text("在首页、搜索、动态、历史和收藏列表中进入视频时生效；单独打开的视频不会猜测下一个内容。").font(.caption).foregroundStyle(.secondary)
                Text("自动：分 P 视频继续下一集，普通单视频播完暂停。").font(.caption).foregroundStyle(.secondary)
            }
            Section("网络与画质") {
                Toggle("自动最高画质",isOn:$highest)
                QualityPicker(title:"无线网络默认画质",selection:$quality).disabled(highest)
                QualityPicker(title:"移动网络默认画质",selection:$mobileQuality).disabled(highest)
                Picker("默认音质",selection:$audioQuality) { Text("64K").tag(30216);Text("132K").tag(30232);Text("192K").tag(30280) }
                Text("使用账号权限范围内可播放的 AVC 视频与 AAC 音频。").font(.caption).foregroundStyle(.secondary)
            }
            Section("省流量模式") {
                Picker("省流量模式",selection:$dataSaver) { Text("关闭").tag("off");Text("仅移动网络").tag("cellular");Text("始终开启").tag("always") }
                Text("启用时将新视频限制为最高 480P，优先于自动最高画质。").font(.caption).foregroundStyle(.secondary)
            }
            Section("小窗与后台") { Toggle("画中画",isOn:$pip);Toggle("后台播放",isOn:$background);Toggle("播放时暂停其他应用的声音",isOn:$audioFocus) }
            Section { NavigationLink("弹幕设置") { DanmakuPreferences() } }

        }
    }
}
struct QualityPicker:View {
    let title:String
    @Binding var selection:Int
    var body:some View {
        Picker(title,selection:$selection) { Text("360P").tag(16);Text("480P").tag(32);Text("720P").tag(64);Text("1080P").tag(80);Text("1080P 高码率").tag(112);Text("1080P60").tag(116);Text("4K").tag(120) }
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
    @AppStorage("coverRatio") private var coverRatio = "16:10"
    @AppStorage("durationStyle") private var durationStyle = "outside"
    @AppStorage("compactStats") private var compactStats = false
    @AppStorage("fullCardTitle") private var fullTitle = false
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
                Picker("卡片封面比例",selection:$coverRatio) { ForEach(["16:9","4:3","16:10"],id:\.self) { Text($0).tag($0) } }
                Picker("首页视频时长",selection:$durationStyle) { Text("封面外").tag("outside");Text("封面内无底色").tag("overlay");Text("隐藏").tag("hidden") }
                Toggle("统计信息贴封面（紧凑）",isOn:$compactStats)
                Toggle("完整卡片展示",isOn:$fullTitle)
            }
            Section("推荐流") { Stepper("每次刷新数量：\(count)",value:$count,in:10...50,step:10);Text("刷新后生效。").font(.caption).foregroundStyle(.secondary) }
        }
    }
}
struct NavigationPreferences: View {
    @AppStorage("showDynamicTab") private var dynamic = true
    @AppStorage("showHistoryTab") private var history = true
    @AppStorage("showListenTab") private var listen = true
    var body: some View {
        Form {
            Section("底栏项目") { Toggle("动态",isOn:$dynamic);Toggle("历史",isOn:$history);Toggle("听视频",isOn:$listen);Text("推荐和我的始终保留，设置入口不会被隐藏。").font(.caption).foregroundStyle(.secondary) }
            Section("导航与标签") {
                NavigationLink("顶部标签管理") { TopTabPreferences() }
                NavigationLink("底栏顺序") { BottomOrderPreferences() }
            }

        }
    }
}
struct PrivacyPreferences: View {
    @AppStorage("privacyMode") private var privacy = false
    @AppStorage("privateAuthentication") private var authentication = false
    @AppStorage("blockedAuthors") private var authors = ""
    @State private var clear = false
    var body: some View {
        Form {
            Section { Toggle("不记录历史",isOn:$privacy);Toggle("进入隐私内容时验证",isOn:$authentication);Text("不保存或读取本地搜索历史与播放位置；此选项不会清除 B 站服务器已有的历史记录。").font(.caption).foregroundStyle(.secondary) }
            Section("历史记录") { Button("清除本地搜索和播放记录",role:.destructive) { clear = true } }
            Section("已屏蔽的 UP 主 · 每行一个完整名称") { TextEditor(text:$authors).frame(minHeight:110).autocorrectionDisabled();Text("在视频列表中隐藏匹配作者，不修改 B 站账号黑名单。").font(.caption).foregroundStyle(.secondary) }
            Section("权限管理") { Link("打开系统权限设置",destination:URL(string:UIApplication.openSettingsURLString)!);Text("相册、通知等权限仅在对应能力使用时请求。").font(.caption).foregroundStyle(.secondary) }
        }.confirmationDialog("清除本地搜索和播放记录？",isPresented:$clear,titleVisibility:.visible) { Button("清除",role:.destructive) { Preferences.clearPrivateHistory() } }
    }
}
struct StoragePreferences: View {
    @AppStorage("cacheDays") private var cacheDays = 0
    @AppStorage("cacheLimit") private var cacheLimit = 256
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
                Picker("自动清理缓存",selection:$cacheDays) { Text("关闭").tag(0);Text("每天").tag(1);Text("每周").tag(7);Text("每月").tag(30) }
                Picker("缓存容量上限",selection:$cacheLimit) { ForEach([64,128,256,512,1024],id:\.self) { Text("\($0) MB").tag($0) } }
                Text("在应用启动时清理可重新下载的网络缓存。").font(.caption).foregroundStyle(.secondary)
            }
            Section("云备份") { NavigationLink("WebDAV 云备份") { WebDAVSettings() } }
            Section("设置分享") {
                Button("导出设置") { do { document = SettingsDocument(data:try Preferences.export());exporting = true } catch { message = error.localizedDescription } }
                Button("从文件导入设置") { importing = true }
                Text("仅包含界面、播放和过滤规则，不包含账号凭证、Cookie、搜索记录或播放历史。").font(.caption).foregroundStyle(.secondary)
            }
        }.onAppear { cacheSize = URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage }.onChange(of:cacheLimit) { _,_ in CacheMaintenance.apply() }
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

struct CommentPreferences:View {
    @AppStorage("subtitleAuto") private var subtitleAuto = "off"
    @AppStorage("commentSort") private var sort = 2
    @AppStorage("commentPreviewCount") private var previewCount = 3
    @AppStorage("showReplyLoadedCount") private var loadedCount = true
    @AppStorage("expandDescription") private var expanded = false
    var body:some View {
        Form {
            Section("内容预览") {
                Toggle("默认展开视频简介",isOn:$expanded)
                Picker("自动启用字幕",selection:$subtitleAuto) { Text("关闭").tag("off");Text("开启").tag("on");Text("仅非 AI 字幕").tag("withoutAI");Text("自动").tag("auto") }
                Text("新视频优先选择中文字幕。自动模式在播放器静音时允许 AI 字幕；播放中可在原生播放器的字幕菜单切换。").font(.caption).foregroundStyle(.secondary)
            }
            Section("互动与评论") {
                Picker("评论排序",selection:$sort) { Text("最热").tag(2);Text("最新").tag(0) }
                Picker("评论回复预览",selection:$previewCount) { ForEach([3,5,8,10],id:\.self) { Text("\($0)条").tag($0) } }
                Toggle("楼中楼已加载数量",isOn:$loadedCount)
            }
        }.navigationTitle("互动、评论与内容预览").navigationBarTitleDisplayMode(.inline)
    }
}
struct InteractionPreferences:View {
    @AppStorage("haptics") private var haptics = true
    @AppStorage("reduceMotion") private var reduce = false
    @AppStorage("copyText") private var copyText = false
    var body:some View {
        Form { Section("动效与触感") { Toggle("触感反馈",isOn:$haptics);Toggle("减少动态效果",isOn:$reduce);Toggle("点按文字复制",isOn:$copyText);Text("点按视频标题、简介与评论文字复制内容。").font(.caption).foregroundStyle(.secondary) } }
            .navigationTitle("动效与触感").navigationBarTitleDisplayMode(.inline)
    }
}
struct HomeCategoryPreferences:View {
    @AppStorage("feedCount") private var count = 20
    @AppStorage("incrementalDynamicRefresh") private var incremental = false
    @AppStorage("dynamicLayout") private var layout = "list"
    var body:some View {
        Form {
            Section("首页展示") { NavigationLink("首页样式与推荐卡片") { HomePreferences().navigationTitle("首页样式与推荐卡片").navigationBarTitleDisplayMode(.inline) } }
            Section("推荐流与动态") {
                Toggle("刷新时保留当前列表",isOn:$incremental)
                Text("下拉刷新只把新动态加到顶部，不重新排列已看到的内容。").font(.caption).foregroundStyle(.secondary)
                Picker("动态页面布局",selection:$layout) { Text("列表").tag("list");Text("网格").tag("grid") }
                Stepper("首页刷新数量：\(count)",value:$count,in:10...50,step:10)
            }
        }
    }
}
