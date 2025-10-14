import SwiftUI
import CoreImage

fileprivate final class AverageColorExtractor {
    private static let context = CIContext()

    static func averageColor(from image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        let extentVector = CIVector(x: ciImage.extent.origin.x,
                                    y: ciImage.extent.origin.y,
                                    z: ciImage.extent.size.width,
                                    w: ciImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else {
            return nil
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return NSColor(red: CGFloat(bitmap[0]) / 255.0,
                       green: CGFloat(bitmap[1]) / 255.0,
                       blue: CGFloat(bitmap[2]) / 255.0,
                       alpha: CGFloat(bitmap[3]) / 255.0)
    }
}

extension NSImage {
    func extractGradientColors() -> [Color]? {
        guard let averageNsColor = AverageColorExtractor.averageColor(from: self) else {
            return nil
        }
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        averageNsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let secondNsColor = NSColor(hue: hue,
                                  saturation: min(saturation * 1.2, 1.0),
                                  brightness: max(brightness * 0.6, 0.0),
                                  alpha: alpha)
        
        let firstColor = Color(nsColor: averageNsColor)
        let secondColor = Color(nsColor: secondNsColor)
        
        return [firstColor, secondColor]
    }
}
