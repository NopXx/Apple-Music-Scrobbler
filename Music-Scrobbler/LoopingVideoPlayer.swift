
import SwiftUI
import AVKit

struct LoopingVideoPlayer: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var loopObserver: Any?

    var body: some View {
        CustomVideoPlayer(player: player)
            .onAppear {
                // We need to create a new player for each appearance
                // to ensure it works correctly across view reloads.
                let item = AVPlayerItem(url: videoURL)
                let newPlayer = AVPlayer(playerItem: item)
                newPlayer.actionAtItemEnd = .none

                self.loopObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { _ in
                    newPlayer.seek(to: .zero)
                    newPlayer.play()
                }
                
                self.player = newPlayer
                self.player?.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
                if let observer = loopObserver {
                    NotificationCenter.default.removeObserver(observer)
                    loopObserver = nil
                }
            }
    }
}
