import SwiftUI
import Network

@MainActor @Observable final class NetworkState {
    static let shared = NetworkState()
    private let monitor = NWPathMonitor()
    var cellular = false
    private init() {
        monitor.pathUpdateHandler = { path in
            let cellular = path.usesInterfaceType(.cellular) || path.isExpensive
            Task { @MainActor in self.cellular = cellular }
        }
        monitor.start(queue:DispatchQueue(label:"BiliPai.network"))
    }
}
enum PlaybackOptions {
    static func quality(cellular:Bool, store:UserDefaults = .standard) -> Int {
        let saver = store.string(forKey:"dataSaver") ?? "off"
        if saver == "always" || (saver == "cellular" && cellular) { return 32 }
        if store.bool(forKey:"autoHighestQuality") { return 127 }
        let value = store.integer(forKey:cellular ? "mobileQuality":"quality")
        return value == 0 ? (cellular ? 64:80):value
    }
    static func speed(store:UserDefaults = .standard) -> Float {
        let value = store.double(forKey:store.bool(forKey:"rememberSpeed") ? "lastSpeed":"defaultSpeed")
        return Float((0.5...2).contains(value) ? value:1)
    }
    static func nextCID(current:String,pages:[JSON],behavior:String) -> String? {
        guard behavior == "auto",let index = pages.firstIndex(where: { $0["cid"].string == current }), index + 1 < pages.count else { return nil }
        return pages[index+1]["cid"].string
    }
}
extension String {
    var matchesHexColor:Bool { count == 6 && allSatisfy { $0.isHexDigit && $0.isASCII } }
}
extension Color {
    init(hex:String) {
        let value = UInt64(hex,radix:16) ?? 0x007AFF
        self.init(red:Double((value >> 16) & 255)/255,green:Double((value >> 8) & 255)/255,blue:Double(value & 255)/255)
    }
    var hexRGB:String {
        var r:CGFloat = 0,g:CGFloat = 0,b:CGFloat = 0,a:CGFloat = 0
        UIColor(self).getRed(&r,green:&g,blue:&b,alpha:&a)
        return String(format:"%02X%02X%02X",Int(r*255),Int(g*255),Int(b*255))
    }
}
