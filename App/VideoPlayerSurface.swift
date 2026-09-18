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
    static func orientation(for size: CGSize) -> UIDeviceOrientation {
        size.width > size.height ? .landscapeRight : .portrait
    }
    var body:some View {
        NativePlayer(player:player,onRelease:onRelease)
            .task {
                guard enabled,!entered else { return }
                while !Task.isCancelled && !entered {
                    if player.currentItem?.status == .readyToPlay {
                        let size = player.currentItem?.presentationSize ?? .zero
                        // AVPlayer reports .zero briefly after readyToPlay. Wait for
                        // the first real presentation size so portrait clips do not
                        // get presented as portrait by default and landscape clips
                        // do not remain in portrait.
                        if size.width > 10 && size.height > 10 {
                            entered = true
                            orientation = Self.orientation(for: size)
                            showing = true
                            player.playImmediately(atRate:PlaybackOptions.speed())
                            break
                        }
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
        let mask: UIInterfaceOrientationMask = value == .landscapeRight ? .landscapeRight : .portrait
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        if #available(iOS 16.0, *) { scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
    }
}

/// Full-screen player gesture zones: left adjusts screen brightness, right adjusts media volume.
private struct BrightnessVolumeOverlay: View {
    let player: AVPlayer
    @State private var startY: CGFloat?
    @State private var startValue: CGFloat = 0
    @State private var hud: HUD?

    private struct HUD: Equatable {
        let title: String
        let value: CGFloat
        let symbol: String
    }
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HStack(spacing: 0) {
                    zone(isBrightness: true, width: proxy.size.width / 2)
                    zone(isBrightness: false, width: proxy.size.width / 2)
                }
                if let hud {
                    VStack(spacing: 8) {
                        Image(systemName: hud.symbol).font(.system(size: 28, weight: .semibold))
                        Text("\(hud.title) \(Int((hud.value * 100).rounded()))%")
                            .font(.headline.monospacedDigit())
                            .accessibilityIdentifier("player.hud.\(hud.title)")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 18)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }.ignoresSafeArea()
        }.allowsHitTesting(true)
    }
    private func zone(isBrightness: Bool, width: CGFloat) -> some View {
        Color.clear.frame(width:width).contentShape(Rectangle()).gesture(
            DragGesture(minimumDistance: 8).onChanged { drag in
                if startY == nil {
                    startY = drag.startLocation.y
                    startValue = isBrightness ? UIScreen.main.brightness : CGFloat(player.volume)
                }
                let delta = ((startY ?? drag.startLocation.y) - drag.location.y) / 260
                let next = min(1, max(0, startValue + delta))
                if isBrightness { UIScreen.main.brightness = next } else { player.volume = Float(next) }
                withAnimation(.easeOut(duration: 0.12)) {
                    hud = HUD(title: isBrightness ? "亮度" : "音量", value: next,
                              symbol: isBrightness ? "sun.max.fill" : (next == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill"))
                }
            }.onEnded { _ in
                startY = nil
                Task { try? await Task.sleep(for: .milliseconds(650)); await MainActor.run { withAnimation { hud = nil } } }
            }
        ).accessibilityLabel(isBrightness ? "左侧上下滑动调整亮度":"右侧上下滑动调整音量")
    }
}
