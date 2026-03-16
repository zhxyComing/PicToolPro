import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImageInfoView: View {
    @Binding var images: [LoadedImage]
    @State private var detailedInfo: [String: ImageDetailedInfo] = [:]
    @State private var isLoading: Bool = false
    
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
                            ImageInfoCard(image: image, detailedInfo: detailedInfo[image.id.uuidString])
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .onChange(of: images) { newImages in
            loadDetailedInfo(for: newImages)
        }
        .onAppear {
            loadDetailedInfo(for: images)
        }
    }
    
    private func loadDetailedInfo(for images: [LoadedImage]) {
        guard !images.isEmpty else { return }
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [String: ImageDetailedInfo] = [:]
            for image in images {
                let info = getDetailedInfo(from: image.url)
                results[image.id.uuidString] = info
            }
            DispatchQueue.main.async {
                self.detailedInfo = results
                self.isLoading = false
            }
        }
    }
    
    private func getDetailedInfo(from url: URL) -> ImageDetailedInfo {
        var info = ImageDetailedInfo()
        
        // 使用 identify -verbose 获取详细信息
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/identify")
        task.arguments = ["-verbose", url.path]
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                info = parseIdentifyOutput(output)
            }
        } catch {
            print("Error running identify: \(error)")
        }
        
        return info
    }
    
    private func parseIdentifyOutput(_ output: String) -> ImageDetailedInfo {
        var info = ImageDetailedInfo()
        
        let lines = output.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 基本信息解析
            if trimmed.hasPrefix("Filename:") {
                info.filename = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Format:") {
                info.format = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Mime type:") {
                info.mimeType = String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Class:") {
                info.imageClass = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Geometry:") {
                let geometry = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                // 解析如 "360x360+0+0"
                let parts = geometry.components(separatedBy: "+")
                if let sizePart = parts.first {
                    let dims = sizePart.components(separatedBy: "x")
                    if dims.count == 2 {
                        info.width = Int(dims[0]) ?? 0
                        info.height = Int(dims[1]) ?? 0
                    }
                }
            } else if trimmed.hasPrefix("Colorspace:") {
                info.colorspace = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Type:") {
                info.imageType = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Depth:") {
                info.depth = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Gamma:") {
                info.gamma = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Rendering intent:") {
                info.renderingIntent = String(trimmed.dropFirst(16)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Compression:") {
                info.compression = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Orientation:") {
                info.orientation = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Interlace:") {
                info.interlace = String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Background color:") {
                info.backgroundColor = String(trimmed.dropFirst(18)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Matte color:") {
                info.matteColor = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            }
            
            // 通道统计
            if trimmed.hasPrefix("Red:") || trimmed.hasPrefix("Green:") || trimmed.hasPrefix("Blue:") {
                parseChannelStatistics(trimmed, info: &info)
            }
            
            // 色度坐标
            if trimmed.hasPrefix("red primary:") {
                info.redPrimary = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("green primary:") {
                info.greenPrimary = String(trimmed.dropFirst(14)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("blue primary:") {
                info.bluePrimary = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("white point:") {
                info.whitePoint = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
            }
            
            // Profiles
            if trimmed.hasPrefix("Profile-") {
                if info.profiles.isEmpty {
                    info.profiles = []
                }
                let profileName = String(trimmed.dropFirst(8)).components(separatedBy: ":").first ?? trimmed
                info.profiles.append(profileName)
            }
        }
        
        return info
    }
    
    private func parseChannelStatistics(_ line: String, info: inout ImageDetailedInfo) {
        // 解析如 "Red: min: 21 (0.0823529), max: 255 (1), mean: 172.319 (0.675762)..."
        let components = line.components(separatedBy: ",")
        var values: [String: String] = [:]
        
        for comp in components {
            let parts = comp.components(separatedBy: ":")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                values[key] = value
            }
        }
        
        if line.hasPrefix("Red:") {
            info.redChannel = values
        } else if line.hasPrefix("Green:") {
            info.greenChannel = values
        } else if line.hasPrefix("Blue:") {
            info.blueChannel = values
        }
    }
}

struct ImageDetailedInfo {
    var filename: String = ""
    var format: String = ""
    var mimeType: String = ""
    var imageClass: String = ""
    var width: Int = 0
    var height: Int = 0
    var colorspace: String = ""
    var imageType: String = ""
    var depth: String = ""
    var gamma: String = ""
    var renderingIntent: String = ""
    var compression: String = ""
    var orientation: String = ""
    var interlace: String = ""
    var backgroundColor: String = ""
    var matteColor: String = ""
    var redPrimary: String = ""
    var greenPrimary: String = ""
    var bluePrimary: String = ""
    var whitePoint: String = ""
    var profiles: [String] = []
    var redChannel: [String: String] = [:]
    var greenChannel: [String: String] = [:]
    var blueChannel: [String: String] = [:]
}

struct ImageInfoCard: View {
    let image: LoadedImage
    let detailedInfo: ImageDetailedInfo?
    
    var info: ImageMetadata {
        ImageMetadata(from: image)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 文件名
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.accentColor)
                Text(image.url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
            }
            
            Divider()
            
            // 基本信息
            Group {
                InfoRow(label: "尺寸", value: "\(info.width) × \(info.height) px")
                InfoRow(label: "文件大小", value: info.fileSize)
                InfoRow(label: "格式", value: info.format.uppercased())
            }
            
            if let detailed = detailedInfo {
                Divider()
                
                // 详细信息
                if !detailed.mimeType.isEmpty {
                    InfoRow(label: "MIME类型", value: detailed.mimeType)
                }
                
                if !detailed.imageClass.isEmpty {
                    InfoRow(label: "图像类", value: detailed.imageClass)
                }
                
                if !detailed.colorspace.isEmpty {
                    InfoRow(label: "色彩空间", value: detailed.colorspace)
                }
                
                if !detailed.imageType.isEmpty {
                    InfoRow(label: "图像类型", value: detailed.imageType)
                }
                
                if !detailed.depth.isEmpty {
                    InfoRow(label: "位深度", value: detailed.depth)
                }
                
                if !detailed.gamma.isEmpty {
                    InfoRow(label: "Gamma", value: detailed.gamma)
                }
                
                if !detailed.compression.isEmpty {
                    InfoRow(label: "压缩方式", value: detailed.compression)
                }
                
                if !detailed.orientation.isEmpty && detailed.orientation != "Undefined" {
                    InfoRow(label: "方向", value: detailed.orientation)
                }
                
                if !detailed.interlace.isEmpty && detailed.interlace != "Undefined" {
                    InfoRow(label: "交错", value: detailed.interlace)
                }
                
                if !detailed.renderingIntent.isEmpty {
                    InfoRow(label: "渲染意图", value: detailed.renderingIntent)
                }
                
                // 色度坐标
                if !detailed.redPrimary.isEmpty || !detailed.whitePoint.isEmpty {
                    Divider()
                    Text("色度坐标")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !detailed.redPrimary.isEmpty {
                        InfoRow(label: "红基色", value: detailed.redPrimary)
                    }
                    if !detailed.greenPrimary.isEmpty {
                        InfoRow(label: "绿基色", value: detailed.greenPrimary)
                    }
                    if !detailed.bluePrimary.isEmpty {
                        InfoRow(label: "蓝基色", value: detailed.bluePrimary)
                    }
                    if !detailed.whitePoint.isEmpty {
                        InfoRow(label: "白点", value: detailed.whitePoint)
                    }
                }
                
                // 通道统计
                if !detailed.redChannel.isEmpty {
                    Divider()
                    Text("通道统计")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let min = detailed.redChannel["min"], let max = detailed.redChannel["max"], let mean = detailed.redChannel["mean"] {
                        ChannelStatsRow(channel: "红", min: min, max: max, mean: mean)
                    }
                    if let min = detailed.greenChannel["min"], let max = detailed.greenChannel["max"], let mean = detailed.greenChannel["mean"] {
                        ChannelStatsRow(channel: "绿", min: min, max: max, mean: mean)
                    }
                    if let min = detailed.blueChannel["min"], let max = detailed.blueChannel["max"], let mean = detailed.blueChannel["mean"] {
                        ChannelStatsRow(channel: "蓝", min: min, max: max, mean: mean)
                    }
                }
                
                // 配置文件
                if !detailed.profiles.isEmpty {
                    Divider()
                    InfoRow(label: "嵌入配置", value: detailed.profiles.joined(separator: ", "))
                }
            } else {
                // 备用基本信息（当没有详细信息的）
                if !info.colorSpace.isEmpty {
                    InfoRow(label: "颜色空间", value: info.colorSpace)
                }
                
                if info.bitDepth > 0 {
                    InfoRow(label: "位深度", value: "\(info.bitDepth) 位")
                }
                
                if info.dpi > 0 {
                    InfoRow(label: "DPI", value: "\(info.dpi)")
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
        }
        .font(.subheadline)
    }
}

struct ChannelStatsRow: View {
    let channel: String
    let min: String
    let max: String
    let mean: String
    
    var body: some View {
        HStack {
            Text(channel)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            Text("Min: \(min)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Max: \(max)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Mean: \(mean)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
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
        if let cgColorSpace = cgImage.colorSpace {
            let model = cgColorSpace.model
            switch model {
            case .rgb:
                colorSpace = "RGB"
            case .monochrome:
                colorSpace = "灰度"
            case .cmyk:
                colorSpace = "CMYK"
            default:
                colorSpace = "其他"
            }
        }
        
        // Bit depth
        bitDepth = cgImage.bitsPerComponent
        
        // DPI - from image source
        if let imageSource = CGImageSourceCreateWithURL(loadedImage.url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            if let dpiWidth = properties[kCGImagePropertyDPIWidth as String] as? Int {
                dpi = dpiWidth
            }
        }
    }
}
