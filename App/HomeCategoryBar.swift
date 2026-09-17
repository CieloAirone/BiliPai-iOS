import SwiftUI

enum HomeCatalogRoute:String,Hashable { case live,bangumi }

// All entries use the same Button, exact cell width and common font size.
// Navigation destinations are presented by the parent instead of mixing link
// sizing with selection-button sizing in this row.
struct HomeCategoryBar:View {
    let tabs:[String]
    let selected:String
    let select:(String) -> Void
    @ScaledMetric(relativeTo:.subheadline) private var textSize:CGFloat = 16
    @ScaledMetric(relativeTo:.subheadline) private var rowHeight:CGFloat = 44
    var body:some View {
        GeometryReader { geometry in
            let count = max(1,tabs.count)
            let width = max(0,(geometry.size.width - CGFloat(count-1)*4)/CGFloat(count))
            // Shrink the whole row together on narrow screens, never only 排行榜.
            let commonSize = min(textSize,max(1,(width-8)/3))
            HStack(spacing:4) {
                ForEach(tabs,id:\.self) { tab in
                    Button { select(tab) } label: {
                        Text(verbatim:tab)
                            .font(.system(size:commonSize,weight:.medium))
                            .tracking(0).lineLimit(1)
                            .foregroundStyle(tab == selected ? Preferences.tint:Color.secondary)
                            .frame(width:width,height:rowHeight,alignment:.center)
                            .background {
                                if tab == selected { Capsule().fill(Preferences.tint.opacity(0.12)).padding(.vertical,4) }
                            }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .frame(width:width,height:rowHeight)
                        .accessibilityIdentifier("home.category.\(tab)")
                }
            }
        }.frame(height:rowHeight)
    }
}
