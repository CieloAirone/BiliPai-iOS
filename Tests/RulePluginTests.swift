import XCTest
@testable import BiliPai
final class RulePluginTests:XCTestCase {
    func testOriginalCompoundRuleFormat() throws {
        let raw = #"{"id":"test","name":"低播放广告","type":"feed","rules":[{"condition":{"and":[{"field":"stat.view","op":"lt","value":1000},{"field":"title","op":"contains","value":"广告"}]},"action":"hide"}]}"#
        let plugin = try RulePlugin.parse(Data(raw.utf8))
        XCTAssertTrue(plugin.hides(["title":JSON("广告视频"),"stat.view":JSON(50)]))
        XCTAssertFalse(plugin.hides(["title":JSON("广告视频"),"stat.view":JSON(2000)]))
        XCTAssertFalse(plugin.hides(["title":JSON("正常视频"),"stat.view":JSON(50)]))
    }
    func testUnsupportedRulesRejected() {
        let raw = #"{"id":"test","name":"bad","type":"feed","rules":[{"field":"duration","op":"lt","value":50,"action":"hide"}]}"#
        XCTAssertThrowsError(try RulePlugin.parse(Data(raw.utf8)))
    }
}
