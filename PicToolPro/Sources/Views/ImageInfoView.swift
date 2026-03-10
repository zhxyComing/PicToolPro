import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImageInfoView: View {
    @Binding var images: [LoadedImage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("图片信息")
                .font(.headline)
            
            Divider()
            
            if images.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无图片")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(images) { image in
                            ImageInfoCard(image: image)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ImageInfoCard: View {
    let image: LoadedImage
    
    var info: ImageMetadata {
        ImageMetadata(from: image)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 文件名
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.accentColor)
                Text(image.url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
            }
            
            Divider()
            
            // 尺寸
            HStack {
                Text("尺寸")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(info.width) × \(info.height) px")
            }
            .font(.subheadline)
            
            // 文件大小
            HStack {
                Text("大小")
                    .foregroundColor(.secondary)
                Spacer()
                Text(info.fileSize)
            }
            .font(.subheadline)
            
            // 格式
            HStack {
                Text("格式")
                    .foregroundColor(.secondary)
                Spacer()
                Text(info.format.uppercased())
            }
            .font(.subheadline)
            
            // 颜色空间
            if !info.colorSpace.isEmpty {
                HStack {
                    Text("颜色空间")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(info.colorSpace)
                }
                .font(.subheadline)
            }
            
            // 位深度
            if info.bitDepth > 0 {
                HStack {
                    Text("位深度")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(info.bitDepth) 位")
                }
                .font(.subheadline)
            }
            
            // DPI
            if info.dpi > 0 {
                HStack {
                    Text("DPI")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(info.dpi)")
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ImageMetadata {
    var width: Int = 0
    var height: Int = 0
    var fileSize: String = ""
    var format: String = ""
    var colorSpace: String = ""
    var bitDepth: Int = 0
    var dpi: Int = 0
    
    init(from loadedImage: LoadedImage) {
        guard let cgImage = loadedImage.nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        
        width = cgImage.width
        height = cgImage.height
        format = loadedImage.url.pathExtension.uppercased()
        
        // File size
        if let data = loadedImage.originalData {
            let bytes = data.count
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            fileSize = formatter.string(fromByteCount: Int64(bytes))
        }
        
        // Color space
        if let colorSpace = cgImage.colorSpace {
            let name = colorSpace.model
            switch name {
            case .rgb:
                colorSpace = "RGB"
            case .gray:
                colorSpace = "灰度"
            case .cmyk:
                colorSpace = "CMYK"
            case .deviceN:
                colorSpace = "DeviceN"
            case .indexed:
                colorSpace = "索引"
            case .monochrome:
                colorSpace = "单色"
            @unknown default:
                colorSpace = "未知"
            }
        }
        
        // Bit depth
        bitDepth = cgImage.bitsPerComponent * cgImage.componentsPerPixel
        
        // DPI - from image source
        if let imageSource = CGImageSourceCreateWithURL(loadedImage.url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            if let dpiWidth = properties[kCGImagePropertyDPIWidth as String] as? Int {
                dpi = dpiWidth
            }
        }
    }
}
