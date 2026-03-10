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
        let cornerRadius = min(radius, min(size.width, size.height) / 2)
        
        if transparentBackground {
            return createRoundedImageWithTransparency(cgImage: cgImage, size: size, cornerRadius: cornerRadius)
        } else {
            return createRoundedImageWithWhiteBackground(cgImage: cgImage, size: size, cornerRadius: cornerRadius)
        }
    }
    
    private func createRoundedImageWithTransparency(cgImage: CGImage, size: NSSize, cornerRadius: CGFloat) -> NSImage? {
        let rect = CGRect(origin: .zero, size: size)
        
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        ctx.beginPath()
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(path)
        ctx.clip()
        ctx.draw(cgImage, in: rect)
        
        guard let clippedImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: clippedImage, size: size)
    }
    
    private func createRoundedImageWithWhiteBackground(cgImage: CGImage, size: NSSize, cornerRadius: CGFloat) -> NSImage? {
        let rect = CGRect(origin: .zero, size: size)
        
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // White background
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(rect)
        
        // Clip to rounded rect
        ctx.beginPath()
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(path)
        ctx.clip()
        
        ctx.draw(cgImage, in: rect)
        
        guard let clippedImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: clippedImage, size: size)
    }
    
    // MARK: - Compression
    
    func compress(image: NSImage, mode: CompressionMode) -> (NSImage, Data)? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        var processedCGImage: CGImage = cgImage
        let ciImage = CIImage(cgImage: cgImage)
        
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
                let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                processedCGImage = context.createCGImage(scaledImage, from: scaledImage.extent) ?? cgImage
            }
        }
        
        // Create NSImage from CGImage
        let processedNSImage = NSImage(cgImage: processedCGImage, size: NSSize(width: processedCGImage.width, height: processedCGImage.height))
        
        guard let tiffData = processedNSImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        
        var data: Data?
        var quality: Double = 0.8
        
        if case .lossy(let q) = mode {
            quality = q
        }
        
        if case .lossy = mode {
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        } else {
            data = bitmap.representation(using: .png, properties: [:])
        }
        
        guard let compressedData = data,
              let compressedImage = NSImage(data: compressedData) else { return nil }
        
        return (compressedImage, compressedData)
    }
    
    // MARK: - Format Conversion
    
    func convert(image: NSImage, to format: ImageFormat, quality: Double = 0.8) -> (NSImage, Data)? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        
        var data: Data?
        
        switch format {
        case .png:
            data = bitmap.representation(using: .png, properties: [:])
        case .jpg:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .webp:
            // WebP - use JPEG as fallback (WebP requires additional library)
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .heic:
            data = bitmap.representation(using: .jpeg2000, properties: [.compressionFactor: quality])
        case .bmp:
            data = bitmap.representation(using: .bmp, properties: [:])
        case .gif:
            data = bitmap.representation(using: .gif, properties: [:])
        case .avif:
            // AVIF - use JPEG as fallback
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
