import XCTest
@testable import BiliPai
final class PreferencesTests: XCTestCase {
    func testBackupExcludesCredentialsAndHistory() throws {
        let name = "settings-test-" + UUID().uuidString
        let store = UserDefaults(suiteName:name)!; defer { store.removePersistentDomain(forName:name) }
        store.set("secret",forKey:"SESSDATA");store.set("private query",forKey:"searchHistory");store.set(123,forKey:"position.BV.1")
        store.set(1.5,forKey:"defaultSpeed")
        let data = try Preferences.export(store:store)
        let text = String(data:data,encoding:.utf8)!
        XCTAssertFalse(text.contains("secret"));XCTAssertFalse(text.contains("private query"));XCTAssertFalse(text.contains("position.BV"))
        let values = try Preferences.validate(data);XCTAssertEqual(values["defaultSpeed"] as? Double,1.5)
    }
    func testRejectInvalidBackupBeforeApplying() throws {
        for values: [String:Any] in [["defaultSpeed":99],["autoplay":"true"],["SESSDATA":"secret"],["gridColumns":1.5],["appearance":"invalid"]] {
            let data = try JSONSerialization.data(withJSONObject:["format":"bilipai-ios-settings","version":1,"values":values])
            XCTAssertThrowsError(try Preferences.validate(data))
        }
    }
    func testFilterAndHistoryClearingPreserveSettings() {
        let name = "settings-test-" + UUID().uuidString
        let store = UserDefaults(suiteName:name)!;defer { store.removePersistentDomain(forName:name) }
        store.set(true,forKey:"filterEnabled");store.set("广告\nSpam",forKey:"filterKeywords")
        XCTAssertFalse(Preferences.accepts(Video(JSON(["title":"SPAM video","bvid":"BV1"])),store:store))
        XCTAssertTrue(Preferences.accepts(Video(JSON(["title":"正常视频","bvid":"BV2"])),store:store))
        store.set("private",forKey:"searchHistory");store.set(42,forKey:"position.BV2.3");store.set("pink",forKey:"accent")
        Preferences.clearPrivateHistory(store:store)
        XCTAssertNil(store.object(forKey:"searchHistory"));XCTAssertNil(store.object(forKey:"position.BV2.3"));XCTAssertEqual(store.string(forKey:"accent"),"pink")
    }
}
