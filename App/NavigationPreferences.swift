import SwiftUI

enum NavigationOptions {
    static let top = ["推荐","热门","排行榜","直播","番剧"]
    static func validTop(_ value:String) -> Bool {
        let items = value.components(separatedBy:",")
        return items.contains("推荐") && items.count == Set(items).count && items.allSatisfy(top.contains)
    }
    static func validBottom(_ value:String) -> Bool {
        let items = value.components(separatedBy:",")
        return items.count == 5 && Set(items) == Set(["0","1","2","3","4"])
    }
    static func topItems(_ value:String) -> [String] { validTop(value) ? value.components(separatedBy:","):top }
    static func bottomItems(_ value:String) -> [Int] { validBottom(value) ? value.components(separatedBy:",").compactMap(Int.init):[0,1,2,3,4] }
}
struct TopTabPreferences:View {
    @AppStorage("topTabs") private var saved = "推荐,热门,排行榜,直播,番剧"
    @AppStorage("defaultFeed") private var defaultFeed = "推荐"
    private var items:[String] { NavigationOptions.topItems(saved) }
    var body:some View {
        List {
            Section("已显示（拖动可排序）") {
                ForEach(items,id:\.self) { item in
                    HStack { Text(item);Spacer();if item == "推荐" { Text("固定").font(.caption).foregroundStyle(.secondary) } else { Button("隐藏") { update(items.filter { $0 != item }) }.buttonStyle(.borderless) } }
                }.onMove { source,destination in var values = items;values.move(fromOffsets:source,toOffset:destination);update(values) }
            }
            Section("可用标签") { ForEach(NavigationOptions.top.filter { !items.contains($0) },id:\.self) { item in Button("添加\(item)") { update(items + [item]) } } }
        }.environment(\.editMode,.constant(.active)).navigationTitle("顶部标签管理").navigationBarTitleDisplayMode(.inline)
    }
    private func update(_ values:[String]) { saved = values.joined(separator:",");if !values.contains(defaultFeed) { defaultFeed = "推荐" } }
}
struct BottomOrderPreferences:View {
    @AppStorage("bottomOrder") private var saved = "0,1,2,3,4"
    private let names = ["推荐","动态","历史","听视频","我的"]
    var body:some View {
        List {
            Section("长按拖动可调整显示顺序") {
                ForEach(NavigationOptions.bottomItems(saved),id:\.self) { item in Text(names[item]) }
                    .onMove { source,destination in var items = NavigationOptions.bottomItems(saved);items.move(fromOffsets:source,toOffset:destination);saved = items.map(String.init).joined(separator:",") }
            }
        }.environment(\.editMode,.constant(.active)).navigationTitle("底栏顺序").navigationBarTitleDisplayMode(.inline)
    }
}
