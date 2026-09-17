import XCTest
import AVKit
@testable import BiliPai

@MainActor
final class PlayerLifecycleTests: XCTestCase {
    func testFullScreenTransitionDoesNotReleaseMedia() {
        let player = AVPlayer(playerItem:AVPlayerItem(url:URL(string:"https://example.org/test.mp4")!))
        let item = player.currentItem
        var cleanups = 0
        let lifetime = PlayerControllerLifetime { cleanups += 1; player.replaceCurrentItem(with:nil) }
        lifetime.fullScreen = true
        lifetime.releaseIfDetached()
        XCTAssertTrue(player.currentItem === item)
        lifetime.fullScreen = false
        lifetime.releaseIfDetached()
        XCTAssertTrue(player.currentItem === item)
        XCTAssertEqual(cleanups,0)
        lifetime.detach()
        XCTAssertNil(player.currentItem);XCTAssertEqual(cleanups,1)
        lifetime.detach();XCTAssertEqual(cleanups,1)
    }
    func testDetachedFullScreenAndPiPWaitForBothPresentations() {
        var cleanups = 0
        let lifetime = PlayerControllerLifetime { cleanups += 1 }
        lifetime.fullScreen = true; lifetime.pictureInPicture = true
        lifetime.detach();XCTAssertEqual(cleanups,0)
        lifetime.fullScreen = false;lifetime.releaseIfDetached();XCTAssertEqual(cleanups,0)
        lifetime.pictureInPicture = false;lifetime.releaseIfDetached();XCTAssertEqual(cleanups,1)
    }
}
