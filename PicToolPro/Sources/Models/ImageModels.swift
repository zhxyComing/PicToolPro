import Foundation
import AppKit

struct LoadedImage: Identifiable {
    let id = UUID()
    let url: URL
    let nsImage: NSImage
    var originalData: Data?
    
    init?(url: URL, nsImage: NSImage) {
        self.url = url
        self.nsImage = nsImage
        self.originalData = try? Data(contentsOf: url)
    }
}

struct ProcessedImage: Identifiable {
    let id = UUID()
    let nsImage: NSImage
    let data: Data
    let format: ImageFormat
    let originalSize: Int
    let processedSize: Int
    
    var compressionRatio: Double {
        guard originalSize > 0 else { return 0 }
        return Double(originalSize - processedSize) / Double(originalSize) * 100
    }
}

enum ImageFormat: String, CaseIterable {
    case png = "png"
    case jpg = "jpg"
    case webp = "webp"
    case heic = "heic"
    case bmp = "bmp"
    case gif = "gif"
    case avif = "avif"
    
    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpg: return "JPEG"
        case .webp: return "WebP"
        case .heic: return "HEIC"
        case .bmp: return "BMP"
        case .gif: return "GIF"
        case .avif: return "AVIF"
        }
    }
    
    var utType: String {
        switch self {
        case .png: return "public.png"
        case .jpg: return "public.jpeg"
        case .webp: return "public.webp"
        case .heic: return "public.heic"
        case .bmp: return "com.microsoft.bmp"
        case .gif: return "com.compuserve.gif"
        case .avif: return "public.avif"
        }
    }
}

enum CompressionMode {
    case lossless
    case lossy(quality: Double)
    case scale(width: Int?, height: Int?, percentage: Double?)
}

enum CornerRadiusPreset: String, CaseIterable {
    case custom = "自定义"
    case px10 = "10px"
    case px20 = "20px"
    case px50 = "50px"
    case px100 = "100px"
    
    var value: CGFloat? {
        switch self {
        case .custom: return nil
        case .px10: return 10
        case .px20: return 20
        case .px50: return 50
        case .px100: return 100
        }
    }
}
