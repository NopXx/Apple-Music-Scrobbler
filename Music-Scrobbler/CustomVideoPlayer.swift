
import SwiftUI
import AVKit

struct CustomVideoPlayer: NSViewRepresentable {
    var player: AVPlayer?

    func makeNSView(context: Context) -> NSView {
        let view = PlayerNSView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? PlayerNSView else { return }
        view.player = player
    }
}

// We create a custom NSView to host the AVPlayerLayer
class PlayerNSView: NSView {
    private let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        layer?.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspectFill
    }

    var player: AVPlayer? {
        get {
            playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}
