import SwiftUI
import AVKit
import MediaPlayer

struct VideoPlayerSurface:View {
    let player:AVPlayer
    var onRelease:() -> Void = {}
    @AppStorage("autoFullscreen") private var enabled = false
    @State private var entered = false
    @State private var showing = false
    @State private var orientation: UIDeviceOrientation = .portrait
    var body:some View {
        NativePlayer(player:player,onRelease:onRelease)
            .task {
                guard enabled,!entered else { return }
                while !Task.isCancelled && !entered {
                    if player.currentItem?.status == .readyToPlay {
                        entered = true
                        let size = player.currentItem?.presentationSize ?? .zero
                        orientation = size.width > size.height ? .landscapeRight : .portrait
                        showing = true
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
                    BrightnessVolumeOverlay(player: player)
                    Button { showing = false } label: {
                        Image(systemName:"xmark").font(.system(size:20,weight:.semibold)).foregroundStyle(.white)
                            .frame(width:44,height:44).background(.black.opacity(0.5),in:Circle())
                    }.accessibilityLabel("退出自动全屏").padding(16)
                }.statusBarHidden().onAppear { applyOrientation(orientation) }
                    .onDisappear { applyOrientation(.portrait) }
            }
    }

    private func applyOrientation(_ value: UIDeviceOrientation) {
        guard value == .landscapeRight || value == .portrait else { return }
        UIDevice.current.setValue(value.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }
}

/// Full-screen player gesture zones: left adjusts screen brightness, right adjusts media volume.
private struct BrightnessVolumeOverlay: View {
    let player: AVPlayer
    @State private var start: CGFloat = 0
    @State private var value: CGFloat = 0
    var body: some View {
        GeometryReader { proxy in
            HStack(spacing:0) {
                zone(isBrightness:true, width:proxy.size.width/2)
                zone(isBrightness:false, width:proxy.size.width/2)
            }.ignoresSafeArea()
        }.allowsHitTesting(true)
    }
    private func zone(isBrightness: Bool, width: CGFloat) -> some View {
        Color.clear.frame(width:width).contentShape(Rectangle()).gesture(
            DragGesture(minimumDistance:8).onChanged { drag in
                if value == 0 { value = isBrightness ? UIScreen.main.brightness : CGFloat(player.volume); start = drag.startLocation.y }
                let delta = (start - drag.location.y) / 260
                let next = min(1,max(0,value + delta))
                if isBrightness { UIScreen.main.brightness = next } else { player.volume = Float(next) }
            }.onEnded { _ in value = 0 }
        ).accessibilityLabel(isBrightness ? "左侧上下滑动调整亮度":"右侧上下滑动调整音量")
    }
}
