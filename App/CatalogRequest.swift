import Foundation

enum CatalogRequest {
    static func bangumi(page:Int) -> [String:String] {
        // ApiClient.kt#getBangumiIndex supplies both st and type. Omitting type
        // consistently returns application error -400 from the public endpoint.
        ["season_type":"1","st":"1","type":"1","page":String(max(1,page)),"pagesize":"20","order":"3","sort":"0"]
    }
    static func hasNext(_ result:JSON) -> Bool {
        guard !result["list"].array.isEmpty else { return false }
        return result["has_next"].int == 1
    }
}
