import Foundation
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

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
    
    func convert(image: NSImage, to format: ImageFormat, quality: Double = 0.8) -> (NSImage, Data, ImageFormat)? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        
        var data: Data?
        var actualFormat = format
        
        switch format {
        case .png:
            data = bitmap.representation(using: .png, properties: [:])
        case .jpg:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .webp:
            // Try native WebP encoding via ImageIO
            if let webpData = encodeToWebP(image: image, quality: quality) {
                data = webpData
            } else {
                // Fallback to JPEG
                data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
                actualFormat = .jpg
            }
        case .heic:
            data = bitmap.representation(using: .jpeg2000, properties: [.compressionFactor: quality])
        case .bmp:
            data = bitmap.representation(using: .bmp, properties: [:])
        case .gif:
            data = bitmap.representation(using: .gif, properties: [:])
        case .avif:
            // Try native AVIF encoding via ImageIO
            if let avifData = encodeToAVIF(image: image, quality: quality) {
                data = avifData
            } else {
                // Fallback to JPEG
                data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
                actualFormat = .jpg
            }
        }
        
        guard let convertedData = data,
              let convertedImage = NSImage(data: convertedData) else { return nil }
        
        return (convertedImage, convertedData, actualFormat)
    }
    
    // MARK: - WebP Encoding via ImageIO
    
    private func encodeToWebP(image: NSImage, quality: Double) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "org.webmproject.webp" as CFString, 1, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
    
    // MARK: - AVIF Encoding via ImageIO
    
    private func encodeToAVIF(image: NSImage, quality: Double) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.avif" as CFString, 1, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
    
    // MARK: - Batch Processing
    
    func batchProcess(images: [LoadedImage], processor: (LoadedImage) -> ProcessedImage?) -> [ProcessedImage] {
        return images.compactMap { processor($0) }
    }
    
    // MARK: - Image Stitching
    
    func stitchImages(
        images: [LoadedImage],
        direction: String, // "horizontal" or "vertical"
        alignmentHorizontal: String, // "top", "center", "bottom"
        alignmentVertical: String, // "left", "center", "right"
        spacing: Int,
        spacingColor: NSColor,
        backgroundColor: NSColor,
        useTransparentBackground: Bool,
        outputWidth: Int?,
        outputHeight: Int?
    ) -> (NSImage, Data)? {
        guard images.count >= 2 else { return nil }
        
        // Get all CGImages
        let cgImages = images.compactMap { $0.nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) }
        guard cgImages.count == images.count else { return nil }
        
        // Calculate dimensions based on direction
        let spacingCGFloat = CGFloat(spacing)
        
        if direction == "horizontal" {
            return stitchHorizontal(
                cgImages: cgImages,
                alignment: alignmentHorizontal,
                spacing: spacingCGFloat,
                spacingColor: spacingColor,
                backgroundColor: backgroundColor,
                useTransparentBackground: useTransparentBackground,
                outputWidth: outputWidth,
                outputHeight: outputHeight
            )
        } else {
            return stitchVertical(
                cgImages: cgImages,
                alignment: alignmentVertical,
                spacing: spacingCGFloat,
                spacingColor: spacingColor,
                backgroundColor: backgroundColor,
                useTransparentBackground: useTransparentBackground,
                outputWidth: outputWidth,
                outputHeight: outputHeight
            )
        }
    }
    
    private func stitchHorizontal(
        cgImages: [CGImage],
        alignment: String,
        spacing: CGFloat,
        spacingColor: NSColor,
        backgroundColor: NSColor,
        useTransparentBackground: Bool,
        outputWidth: Int?,
        outputHeight: Int?
    ) -> (NSImage, Data)? {
        // Find max height and total width
        let heights = cgImages.map { CGFloat($0.height) }
        let maxHeight = heights.max() ?? 0
        let totalWidth = cgImages.map { CGFloat($0.width) }.reduce(0, +) + spacing * CGFloat(cgImages.count - 1)
        
        // Calculate output size
        var finalWidth = Int(totalWidth)
        var finalHeight = Int(maxHeight)
        
        if let targetWidth = outputWidth, let targetHeight = outputHeight {
            finalWidth = targetWidth
            finalHeight = targetHeight
        } else if let targetWidth = outputWidth {
            finalWidth = targetWidth
            finalHeight = Int(maxHeight)
        } else if let targetHeight = outputHeight {
            finalHeight = targetHeight
        }
        
        // Create context
        guard let ctx = CGContext(
            data: nil,
            width: finalWidth,
            height: finalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Fill background
        if useTransparentBackground {
            ctx.clear(CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight))
        } else {
            ctx.setFillColor(backgroundColor.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight))
        }
        
        // Draw images
        var currentX: CGFloat = 0
        
        for (index, cgImage) in cgImages.enumerated() {
            let imgWidth = CGFloat(cgImage.width)
            let imgHeight = CGFloat(cgImage.height)
            
            // Calculate Y offset based on alignment
            let yOffset: CGFloat
            switch alignment {
            case "top":
                yOffset = CGFloat(finalHeight) - imgHeight
            case "center":
                yOffset = (CGFloat(finalHeight) - imgHeight) / 2
            default:
                yOffset = 0
            }
            
            // Scale if needed
            let drawRect: CGRect
            if let targetWidth = outputWidth, targetWidth != finalWidth {
                let scale = CGFloat(targetWidth) / CGFloat(Int(totalWidth))
                let scaledWidth = CGFloat(cgImage.width) * scale
                let scaledHeight = CGFloat(cgImage.height) * scale
                drawRect = CGRect(x: currentX, y: yOffset, width: scaledWidth, height: scaledHeight)
            } else {
                drawRect = CGRect(x: currentX, y: yOffset, width: imgWidth, height: imgHeight)
            }
            
            ctx.draw(cgImage, in: drawRect)
            
            // Add spacing
            currentX += CGFloat(cgImage.width) + spacing
            
            // Draw spacing if not last image
            if index < cgImages.count - 1 && spacing > 0 {
                ctx.setFillColor(spacingColor.cgColor)
                ctx.fill(CGRect(x: currentX - spacing, y: 0, width: spacing, height: CGFloat(finalHeight)))
            }
        }
        
        guard let stitchedCGImage = ctx.makeImage() else { return nil }
        let stitchedNSImage = NSImage(cgImage: stitchedCGImage, size: NSSize(width: CGFloat(finalWidth), height: CGFloat(finalHeight)))
        
        guard let tiffData = stitchedNSImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
        
        return (stitchedNSImage, pngData)
    }
    
    private func stitchVertical(
        cgImages: [CGImage],
        alignment: String,
        spacing: CGFloat,
        spacingColor: NSColor,
        backgroundColor: NSColor,
        useTransparentBackground: Bool,
        outputWidth: Int?,
        outputHeight: Int?
    ) -> (NSImage, Data)? {
        // Find max width and total height
        let widths = cgImages.map { CGFloat($0.width) }
        let maxWidth = widths.max() ?? 0
        let totalHeight = cgImages.map { CGFloat($0.height) }.reduce(0, +) + spacing * CGFloat(cgImages.count - 1)
        
        // Calculate output size
        var finalWidth = Int(maxWidth)
        var finalHeight = Int(totalHeight)
        
        if let targetWidth = outputWidth, let targetHeight = outputHeight {
            finalWidth = targetWidth
            finalHeight = targetHeight
        } else if let targetHeight = outputHeight {
            finalHeight = targetHeight
        } else if let targetWidth = outputWidth {
            finalWidth = targetWidth
        }
        
        // Create context
        guard let ctx = CGContext(
            data: nil,
            width: finalWidth,
            height: finalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Fill background
        if useTransparentBackground {
            ctx.clear(CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight))
        } else {
            ctx.setFillColor(backgroundColor.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: finalWidth, height: finalHeight))
        }
        
        // Draw images
        var currentY: CGFloat = CGFloat(finalHeight) - CGFloat(cgImages[0].height)
        
        for (index, cgImage) in cgImages.enumerated() {
            let imgWidth = CGFloat(cgImage.width)
            let imgHeight = CGFloat(cgImage.height)
            
            // Calculate X offset based on alignment
            let xOffset: CGFloat
            switch alignment {
            case "left":
                xOffset = 0
            case "center":
                xOffset = (CGFloat(finalWidth) - imgWidth) / 2
            default:
                xOffset = CGFloat(finalWidth) - imgWidth
            }
            
            // Scale if needed
            let drawRect: CGRect
            if let targetHeight = outputHeight, targetHeight != finalHeight {
                let scale = CGFloat(targetHeight) / CGFloat(Int(totalHeight))
                let scaledWidth = CGFloat(cgImage.width) * scale
                let scaledHeight = CGFloat(cgImage.height) * scale
                drawRect = CGRect(x: xOffset, y: currentY, width: scaledWidth, height: scaledHeight)
            } else {
                drawRect = CGRect(x: xOffset, y: currentY, width: imgWidth, height: imgHeight)
            }
            
            ctx.draw(cgImage, in: drawRect)
            
            // Move Y position for next image
            currentY -= CGFloat(cgImage.height) + spacing
            
            // Draw spacing if not last image
            if index < cgImages.count - 1 && spacing > 0 {
                ctx.setFillColor(spacingColor.cgColor)
                ctx.fill(CGRect(x: 0, y: currentY + spacing, width: CGFloat(finalWidth), height: spacing))
            }
        }
        
        guard let stitchedCGImage = ctx.makeImage() else { return nil }
        let stitchedNSImage = NSImage(cgImage: stitchedCGImage, size: NSSize(width: CGFloat(finalWidth), height: CGFloat(finalHeight)))
        
        guard let tiffData = stitchedNSImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
        
        return (stitchedNSImage, pngData)
    }
}
