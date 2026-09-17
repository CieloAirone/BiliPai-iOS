import SwiftUI
import AVKit

struct VideoPlayerSurface:View {
    let player:AVPlayer
    var onRelease:() -> Void = {}
    @AppStorage("autoFullscreen") private var enabled = false
    @State private var entered = false
    @State private var showing = false
    var body:some View {
        NativePlayer(player:player,onRelease:onRelease)
            .task {
                guard enabled,!entered else { return }
                while !Task.isCancelled && !entered {
                    if player.currentItem?.status == .readyToPlay {
                        entered = true;showing = true
                        player.playImmediately(atRate:PlaybackOptions.speed())
                        break
                    }
                    do { try await Task.sleep(for:.milliseconds(100)) } catch { return }
                }
            }
            .fullScreenCover(isPresented:$showing) {
                ZStack(alignment:.topLeading) {
                    Color.black.ignoresSafeArea()
                    NativePlayer(player:player).ignoresSafeArea()
                    Button { showing = false } label: {
                        Image(systemName:"xmark").font(.system(size:20,weight:.semibold)).foregroundStyle(.white)
                            .frame(width:44,height:44).background(.black.opacity(0.5),in:Circle())
                    }.accessibilityLabel("退出自动全屏").padding(16)
                }.statusBarHidden()
            }
    }
}
