import Foundation
import AppKit
import CoreImage

class ImageProcessingService {
    static let shared = ImageProcessingService()
    private let context = CIContext()
    
    private init() {}
    
    // MARK: - Corner Crop
    
    func applyCornerRadius(to image: NSImage, radius: CGFloat, transparentBackground: Bool = true) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let rect = CGRect(origin: .zero, size: size)
        
        let cornerRadius = min(radius, min(size.width, size.height) / 2)
        
        if transparentBackground {
            return createRoundedImageWithTransparency(cgImage: cgImage, size: size, cornerRadius: cornerRadius)
        } else {
            return createRoundedImageWithWhiteBackground(cgImage: cgImage, size: size, cornerRadius: cornerRadius)
        }
    }
    
    private func createRoundedImageWithTransparency(cgImage: CGImage, size: NSSize, cornerRadius: CGFloat) -> NSImage? {
        let rect = CGRect(origin: .zero, size: size)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.beginPath()
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        context.clip()
        context.draw(cgImage, in: rect)
        
        guard let clippedImage = context.makeImage() else { return nil }
        return NSImage(cgImage: clippedImage, size: size)
    }
    
    private func createRoundedImageWithWhiteBackground(cgImage: CGImage, size: NSSize, cornerRadius: CGFloat) -> NSImage? {
        let rect = CGRect(origin: .zero, size: size)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // White background
        context.setFillColor(NSColor.white.cgColor)
        context.fill(rect)
        
        // Clip to rounded rect
        context.beginPath()
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        context.clip()
        
        context.draw(cgImage, in: rect)
        
        guard let clippedImage = context.makeImage() else { return nil }
        return NSImage(cgImage: clippedImage, size: size)
    }
    
    // MARK: - Compression
    
    func compress(image: NSImage, mode: CompressionMode) -> (NSImage, Data)? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        var processedCIImage = ciImage
        
        // Apply scale if needed
        if case .scale(let width, let height, let percentage) = mode {
            var scaleX: CGFloat = 1.0
            var scaleY: CGFloat = 1.0
            
            if let width = width {
                scaleX = CGFloat(width) / CGFloat(cgImage.width)
            }
            if let height = height {
                scaleY = CGFloat(height) / CGFloat(cgImage.height)
            }
            if let percentage = percentage {
                let scale = percentage / 100.0
                scaleX = scale
                scaleY = scale
            }
            
            if scaleX != 1.0 || scaleY != 1.0 {
                processedCIImage = processedCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            }
        }
        
        // For lossy compression, we use JPEG
        var data: Data?
        var quality: Double = 0.8
        
        if case .lossy(let q) = mode {
            quality = q
        }
        
        if let tiffData = processedCIImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {
            if case .lossy = mode {
                data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
            } else {
                // Lossless - use PNG
                data = bitmap.representation(using: .png, properties: [:])
            }
        }
        
        guard let compressedData = data,
              let compressedImage = NSImage(data: compressedData) else { return nil }
        
        return (compressedImage, compressedData)
    }
    
    // MARK: - Format Conversion
    
    func convert(image: NSImage, to format: ImageFormat, quality: Double = 0.8) -> (NSImage, Data)? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let tiffData = ciImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        
        var data: Data?
        
        switch format {
        case .png:
            data = bitmap.representation(using: .png, properties: [:])
        case .jpg:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .webp:
            // WebP requires additional handling - use HEIC as fallback for now
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .heic:
            if #available(macOS 10.13, *) {
                data = bitmap.representation(using: .jpeg2000, properties: [.compressionFactor: quality])
            } else {
                data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
            }
        case .bmp:
            data = bitmap.representation(using: .bmp, properties: [:])
        case .gif:
            data = bitmap.representation(using: .gif, properties: [:])
        case .avif:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        }
        
        guard let convertedData = data,
              let convertedImage = NSImage(data: convertedData) else { return nil }
        
        return (convertedImage, convertedData)
    }
    
    // MARK: - Batch Processing
    
    func batchProcess(images: [LoadedImage], processor: (LoadedImage) -> ProcessedImage?) -> [ProcessedImage] {
        return images.compactMap { processor($0) }
    }
}
