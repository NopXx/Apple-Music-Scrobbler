import Foundation

extension URL {
    var isLikelyImageResource: Bool {
        let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp"]
        let ext = pathExtension.lowercased()
        return !ext.isEmpty && supportedExtensions.contains(ext)
    }

    var isLikelyVideoResource: Bool {
        let supportedExtensions: Set<String> = ["mp4", "m4v", "mov", "m3u8"]
        let ext = pathExtension.lowercased()
        return !ext.isEmpty && supportedExtensions.contains(ext)
    }
}
