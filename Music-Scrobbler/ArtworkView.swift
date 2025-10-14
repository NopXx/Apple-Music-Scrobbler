
import SwiftUI

struct ArtworkView: View {
    let artworkUrl: URL?
    var size: CGFloat = 200

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        ZStack {
            shape
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .overlay(
                    shape
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 12)

            if let url = artworkUrl, url.isLikelyImageResource {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderSymbol
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderSymbol
                    }
                }
                .frame(width: size, height: size)
                .clipShape(shape)
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
            } else {
                placeholderSymbol
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholderSymbol: some View {
        Image(systemName: "music.note")
            .font(.system(size: 48))
            .foregroundStyle(Color.white.opacity(0.7))
    }
}


