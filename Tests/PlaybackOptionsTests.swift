import XCTest
@testable import BiliPai
final class PlaybackOptionsTests:XCTestCase {
    func testNetworkQualityAndSaverPrecedence() {
        let name = UUID().uuidString
        let store = UserDefaults(suiteName:name)!
        defer { store.removePersistentDomain(forName:name) }
        store.register(defaults:Preferences.defaults)
        store.set(120,forKey:"quality");store.set(64,forKey:"mobileQuality")
        XCTAssertEqual(PlaybackOptions.quality(cellular:false,store:store),120)
        XCTAssertEqual(PlaybackOptions.quality(cellular:true,store:store),64)
        store.set(true,forKey:"autoHighestQuality")
        XCTAssertEqual(PlaybackOptions.quality(cellular:true,store:store),127)
        store.set("cellular",forKey:"dataSaver")
        XCTAssertEqual(PlaybackOptions.quality(cellular:true,store:store),32)
        XCTAssertEqual(PlaybackOptions.quality(cellular:false,store:store),127)
        store.set("always",forKey:"dataSaver")
        XCTAssertEqual(PlaybackOptions.quality(cellular:false,store:store),32)
        store.set(1.25,forKey:"defaultSpeed");store.set(1.75,forKey:"lastSpeed")
        XCTAssertEqual(PlaybackOptions.speed(store:store),1.25)
        store.set(true,forKey:"rememberSpeed")
        XCTAssertEqual(PlaybackOptions.speed(store:store),1.75)
    }
    func testCompletionAndNavigationValidation() {
        let pages = [JSON(["cid":"1"]),JSON(["cid":"2"])]
        XCTAssertEqual(PlaybackOptions.nextCID(current:"1",pages:pages,behavior:"auto"),"2")
        XCTAssertNil(PlaybackOptions.nextCID(current:"2",pages:pages,behavior:"auto"))
        XCTAssertNil(PlaybackOptions.nextCID(current:"1",pages:pages,behavior:"pause"))
        XCTAssertTrue(NavigationOptions.validTop("直播,推荐"))
        XCTAssertFalse(NavigationOptions.validTop("直播"))
        XCTAssertFalse(NavigationOptions.validTop("推荐,推荐"))
        XCTAssertTrue(NavigationOptions.validBottom("4,0,2,1,3"))
        XCTAssertFalse(NavigationOptions.validBottom("0,0,1,2,3"))
    }
    func testCacheScheduleAndNewBackupValidation() throws {
        let now = Date(timeIntervalSince1970:1000000)
        XCTAssertFalse(CacheMaintenance.shouldClear(days:0,last:nil,now:now))
        XCTAssertFalse(CacheMaintenance.shouldClear(days:7,last:now.addingTimeInterval(-86400),now:now))
        XCTAssertTrue(CacheMaintenance.shouldClear(days:7,last:now.addingTimeInterval(-8*86400),now:now))
        for values:[String:Any] in [["topTabs":"热门"],["customAccent":"FFFFFFF"],["mobileQuality":999],["cacheLimit":999999],["audioQuality":1]] {
            let data = try JSONSerialization.data(withJSONObject:["format":"bilipai-ios-settings","version":1,"values":values])
            XCTAssertThrowsError(try Preferences.validate(data))
        }
    }
}
