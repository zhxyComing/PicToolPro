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
        .onChange(of: images.count) { _ in
            loadDetailedInfo(for: images)
        }
        .onAppear {
            loadDetailedInfo(for: images)
        }
    }
    
    private func loadDetailedInfo(for images: [LoadedImage]) {
        guard !images.isEmpty else { return }
        
        // 获取已加载的 keys
        let existingKeys = Set(detailedInfo.keys)
        
        // 只加载新图片
        let newImages = images.filter { !existingKeys.contains($0.id.uuidString) }
        
        guard !newImages.isEmpty else { return }
        
        isLoading = true
        
        // 复制当前的 detailedInfo 以便在后台线程使用
        var currentInfo = detailedInfo
        
        DispatchQueue.global(qos: .userInitiated).async {
            for image in newImages {
                let info = self.getDetailedInfo(from: image.url)
                currentInfo[image.id.uuidString] = info
            }
            
            DispatchQueue.main.async {
                self.detailedInfo = currentInfo
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
        
        // 后备方案：如果 identify 没有获取到文件信息，用原生方式补充
        if info.fileSize.isEmpty {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? Int64 {
                    let formatter = ByteCountFormatter()
                    formatter.countStyle = .file
                    info.fileSize = formatter.string(fromByteCount: fileSize)
                }
            } catch {
                print("Error getting file size: \(error)")
            }
        }
        
        return info
    }
    
    private func parseIdentifyOutput(_ output: String) -> ImageDetailedInfo {
        var info = ImageDetailedInfo()
        
        let lines = output.components(separatedBy: "\n")
        var inHistogram = false
        var histogramLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 开始解析直方图
            if trimmed.hasPrefix("Histogram:") {
                inHistogram = true
                continue
            }
            
            // 直方图行 (以数字开头)
            if inHistogram {
                if trimmed.isEmpty || (!trimmed.hasPrefix(" ") && !trimmed.first!.isNumber) {
                    inHistogram = false
                    if !histogramLines.isEmpty {
                        info.histogram = Array(histogramLines.prefix(10))
                    }
                } else if trimmed.first?.isNumber == true {
                    histogramLines.append(trimmed)
                    continue
                }
            }
            
            // ==================== 基本信息 ====================
            if trimmed.hasPrefix("Filename:") {
                info.filename = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Permissions:") {
                // 权限信息可后续添加
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
            } else if trimmed.hasPrefix("Resolution:") {
                info.resolution = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Units:") {
                info.units = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Colorspace:") {
                info.colorspace = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Type:") {
                info.imageType = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Base type:") {
                info.baseType = String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Endianness:") {
                // 字节序可后续添加
            } else if trimmed.hasPrefix("Depth:") {
                info.depth = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Channels:") {
                let channelStr = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                info.channels = Double(channelStr.components(separatedBy: ".").first ?? "0") ?? 0
            } else if trimmed.hasPrefix("Colors:") {
                info.colors = Int(String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)) ?? 0
            } else if trimmed.hasPrefix("Page geometry:") {
                info.pageGeometry = String(trimmed.dropFirst(14)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Dispose:") {
                info.dispose = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Iterations:") {
                info.iterations = Int(String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespaces)) ?? 0
            } else if trimmed.hasPrefix("Compose:") {
                info.compose = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Intensity:") {
                info.intensity = String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespaces)
                
                // ==================== Gamma 与渲染 ====================
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
                
                // ==================== 颜色信息 ====================
            } else if trimmed.hasPrefix("Background color:") {
                info.backgroundColor = String(trimmed.dropFirst(18)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Matte color:") {
                info.matteColor = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Border color:") {
                info.borderColor = String(trimmed.dropFirst(13)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Transparent color:") {
                info.transparentColor = String(trimmed.dropFirst(18)).trimmingCharacters(in: .whitespaces)
                
                // ==================== 色度坐标 ====================
            } else if trimmed.hasPrefix("red primary:") {
                info.redPrimary = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("green primary:") {
                info.greenPrimary = String(trimmed.dropFirst(14)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("blue primary:") {
                info.bluePrimary = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("white point:") {
                info.whitePoint = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
                
                // ==================== 通道统计 ====================
            } else if trimmed.hasPrefix("Red:") {
                parseChannelStatistics(trimmed, info: &info, channel: "red")
            } else if trimmed.hasPrefix("Green:") {
                parseChannelStatistics(trimmed, info: &info, channel: "green")
            } else if trimmed.hasPrefix("Blue:") {
                parseChannelStatistics(trimmed, info: &info, channel: "blue")
            } else if trimmed.hasPrefix("Alpha:") {
                parseChannelStatistics(trimmed, info: &info, channel: "alpha")
            } else if trimmed.hasPrefix("Overall:") {
                parseOverallStatistics(trimmed, info: &info)
                
                // ==================== 配置文件 ====================
            } else if trimmed.hasPrefix("Profile-") {
                if info.profiles.isEmpty {
                    info.profiles = []
                }
                let profileName = String(trimmed.dropFirst(8)).components(separatedBy: ":").first ?? trimmed
                info.profiles.append(profileName)
                
                // ==================== PNG 特有属性 ====================
            } else if trimmed.hasPrefix("date:create:") {
                info.dateCreate = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("date:modify:") {
                info.dateModify = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("date:timestamp:") {
                info.dateTimestamp = String(trimmed.dropFirst(15)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("png:IHDR.bit-depth-orig:") {
                info.bitDepthOriginal = String(trimmed.dropFirst(22)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("png:IHDR.bit_depth:") {
                // 位深度已在 Depth 中
            } else if trimmed.hasPrefix("png:IHDR.color-type-orig:") {
                let val = String(trimmed.dropFirst(24)).trimmingCharacters(in: .whitespaces)
                info.pngColorTypeOriginal = parsePNGColorType(val)
            } else if trimmed.hasPrefix("png:IHDR.color_type:") {
                let val = String(trimmed.dropFirst(20)).trimmingCharacters(in: .whitespaces)
                info.pngColorType = parsePNGColorType(val)
            } else if trimmed.hasPrefix("png:IHDR.interlace_method:") {
                let val = String(trimmed.dropFirst(25)).trimmingCharacters(in: .whitespaces)
                info.pngInterlaceMethod = parsePNGInterlaceMethod(val)
            } else if trimmed.hasPrefix("png:tIME:") {
                // PNG修改时间
            } else if trimmed.hasPrefix("signature:") {
                info.signature = String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespaces)
                
                // ==================== 文件信息 ====================
            } else if trimmed.hasPrefix("Filesize:") {
                info.fileSize = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Number pixels:") {
                info.pixels = Int(String(trimmed.dropFirst(14)).trimmingCharacters(in: .whitespaces)) ?? 0
            } else if trimmed.hasPrefix("Pixels per second:") {
                info.pixelsPerSecond = String(trimmed.dropFirst(18)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("User time:") {
                info.userTime = String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Elapsed time:") {
                info.elapsedTime = String(trimmed.dropFirst(14)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Tainted:") {
                info.tainted = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces) == "True"
            } else if trimmed.hasPrefix("Pixel cache type:") {
                info.memorySize = String(trimmed.dropFirst(16)).trimmingCharacters(in: .whitespaces)
            }
            
            // 统计 tEXt/zTXt/iTXt 块数量
            if trimmed.contains("tEXt/zTXt/iTXt chunks") {
                if let num = trimmed.components(separatedBy: " ").first(where: { Int($0) != nil }) {
                    info.pngTextChunks = Int(num) ?? 0
                }
            }
        }
        
        // 处理最后的直方图
        if inHistogram && !histogramLines.isEmpty {
            info.histogram = Array(histogramLines.prefix(10))
        }
        
        return info
    }
    
    // 解析PNG颜色类型
    private func parsePNGColorType(_ value: String) -> String {
        if value.contains("0") { return "灰度 (Grayscale)" }
        if value.contains("1") { return "灰度+Alpha (Grayscale+Alpha)" }
        if value.contains("2") { return "真彩色 (RGB)" }
        if value.contains("3") { return "索引颜色 (Indexed)" }
        if value.contains("4") { return "真彩色+Alpha (RGB+Alpha)" }
        if value.contains("6") { return "真彩色+Alpha (RGB+Alpha)" }
        return value
    }
    
    // 解析PNG交错方法
    private func parsePNGInterlaceMethod(_ value: String) -> String {
        if value.contains("0") { return "无交错 (None)" }
        if value.contains("1") { return "Adam7交错 (Adam7)" }
        return value
    }
    
    private func parseChannelStatistics(_ line: String, info: inout ImageDetailedInfo, channel: String? = nil) {
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
        
        // 确定通道类型
        let channelType: String
        if let ch = channel {
            channelType = ch
        } else if line.hasPrefix("Red:") {
            channelType = "red"
        } else if line.hasPrefix("Green:") {
            channelType = "green"
        } else if line.hasPrefix("Blue:") {
            channelType = "blue"
        } else if line.hasPrefix("Alpha:") {
            channelType = "alpha"
        } else {
            return
        }
        
        switch channelType {
        case "red":
            info.redChannel = values
        case "green":
            info.greenChannel = values
        case "blue":
            info.blueChannel = values
        case "alpha":
            info.alphaChannel = values
        default:
            break
        }
    }
    
    // 解析整体统计信息
    private func parseOverallStatistics(_ line: String, info: inout ImageDetailedInfo) {
        // 解析如 "Overall: min: 13143 (0.200549), max: 60128 (0.917494), mean: 34695 (0.529412)..."
        let components = line.components(separatedBy: ",")
        
        for comp in components {
            let parts = comp.components(separatedBy: ":")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                if key == "min" || key == "max" || key == "mean" || key == "median" || 
                   key == "standard deviation" || key == "kurtosis" || key == "skewness" || key == "entropy" {
                    info.overallStatistics[key] = value
                }
            }
        }
    }
}

struct ImageDetailedInfo {
    // === 基本信息 ===
    var filename: String = ""
    var format: String = ""
    var mimeType: String = ""
    var imageClass: String = ""
    var width: Int = 0
    var height: Int = 0
    var resolution: String = ""      // 分辨率 (如 144x144)
    
    // === 颜色与图像类型 ===
    var colorspace: String = ""
    var imageType: String = ""
    var baseType: String = ""
    var colors: Int = 0              // 颜色数量
    var channels: Double = 0         // 通道数
    
    // === 位深度与压缩 ===
    var depth: String = ""
    var bitDepthOriginal: String = ""    // 原始位深度 (PNG特有)
    var compression: String = ""
    var interlace: String = ""
    var gamma: String = ""
    
    // === 方向与布局 ===
    var orientation: String = ""
    var pageGeometry: String = ""    // 页面几何尺寸
    var dispose: String = ""         // 处置方法
    var iterations: Int = 0          // 迭代次数
    
    // === 渲染参数 ===
    var renderingIntent: String = ""
    var compose: String = ""         // 合成方式
    var intensity: String = ""        // 强度模式
    
    // === 颜色信息 ===
    var backgroundColor: String = ""
    var matteColor: String = ""
    var borderColor: String = ""      // 边框颜色
    var transparentColor: String = "" // 透明颜色
    var units: String = ""             // 单位
    
    // === 色度坐标 ===
    var redPrimary: String = ""
    var greenPrimary: String = ""
    var bluePrimary: String = ""
    var whitePoint: String = ""
    
    // === 通道统计 (RGB) ===
    var redChannel: [String: String] = [:]
    var greenChannel: [String: String] = [:]
    var blueChannel: [String: String] = [:]
    var alphaChannel: [String: String] = [:]    // Alpha通道统计
    
    // === 整体统计 ===
    var overallStatistics: [String: String] = [:]  // mean, median, std dev, kurtosis, skewness, entropy
    
    // === 配置文件 ===
    var profiles: [String] = []
    
    // === 元数据属性 ===
    var dateCreate: String = ""       // 创建日期
    var dateModify: String = ""       // 修改日期
    var dateTimestamp: String = ""    // 时间戳
    var signature: String = ""        // 图像签名 (SHA256)
    
    // === PNG 特有 ===
    var pngColorType: String = ""           // PNG颜色类型
    var pngColorTypeOriginal: String = ""   // PNG原始颜色类型
    var pngInterlaceMethod: String = ""     // PNG交错方法
    var pngTextChunks: Int = 0              // 文本块数量
    
    // === 文件信息 ===
    var fileSize: String = ""         // 文件大小 (Bytes)
    var pixels: Int = 0                // 总像素数
    var pixelsPerSecond: String = ""   // 每秒像素处理速度
    var userTime: String = ""          // 用户时间
    var elapsedTime: String = ""       // 耗时
    var tainted: Bool = false           // 是否被修改过
    var memorySize: String = ""        // 像素缓存大小
    
    // === 直方图 (前10个主要颜色) ===
    var histogram: [String] = []
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
                
                if let detailed = detailedInfo, !detailed.resolution.isEmpty {
                    InfoRow(label: "分辨率", value: detailed.resolution)
                }
                
                InfoRow(label: "文件大小", value: info.fileSize)
                InfoRow(label: "格式", value: info.format.uppercased())
            }
            
            if let detailed = detailedInfo {
                Divider()
                
                // ==================== 详细信息 ====================
                Group {
                    if !detailed.mimeType.isEmpty {
                        InfoRow(label: "MIME类型", value: detailed.mimeType)
                    }
                    
                    if !detailed.imageClass.isEmpty {
                        InfoRow(label: "图像类", value: detailed.imageClass)
                    }
                    
                    if !detailed.baseType.isEmpty {
                        InfoRow(label: "基础类型", value: detailed.baseType)
                    }
                    
                    if !detailed.colorspace.isEmpty {
                        InfoRow(label: "色彩空间", value: detailed.colorspace)
                    }
                    
                    if detailed.colors > 0 {
                        InfoRow(label: "颜色数量", value: "\(detailed.colors)")
                    }
                    
                    if detailed.channels > 0 {
                        InfoRow(label: "通道数", value: String(format: "%.1f", detailed.channels))
                    }
                    
                    if !detailed.imageType.isEmpty {
                        InfoRow(label: "图像类型", value: detailed.imageType)
                    }
                    
                    if !detailed.depth.isEmpty {
                        InfoRow(label: "位深度", value: detailed.depth)
                    }
                    
                    if !detailed.bitDepthOriginal.isEmpty && detailed.bitDepthOriginal != detailed.depth {
                        InfoRow(label: "原始位深度", value: detailed.bitDepthOriginal)
                    }
                    
                    if !detailed.gamma.isEmpty {
                        InfoRow(label: "Gamma", value: detailed.gamma)
                    }
                    
                    if !detailed.compression.isEmpty {
                        InfoRow(label: "压缩方式", value: detailed.compression)
                    }
                    
                    if !detailed.units.isEmpty && detailed.units != "Undefined" {
                        InfoRow(label: "单位", value: detailed.units)
                    }
                }
                
                // ==================== 布局信息 ====================
                if !detailed.orientation.isEmpty && detailed.orientation != "Undefined" ||
                   !detailed.pageGeometry.isEmpty ||
                   !detailed.compose.isEmpty {
                    Divider()
                    Text("布局信息")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !detailed.orientation.isEmpty && detailed.orientation != "Undefined" {
                        InfoRow(label: "方向", value: detailed.orientation)
                    }
                    
                    if !detailed.pageGeometry.isEmpty {
                        InfoRow(label: "页面尺寸", value: detailed.pageGeometry)
                    }
                    
                    if !detailed.compose.isEmpty {
                        InfoRow(label: "合成方式", value: detailed.compose)
                    }
                    
                    if !detailed.dispose.isEmpty && detailed.dispose != "Undefined" {
                        InfoRow(label: "处置方法", value: detailed.dispose)
                    }
                    
                    if detailed.iterations > 0 {
                        InfoRow(label: "迭代次数", value: "\(detailed.iterations)")
                    }
                }
                
                // ==================== 渲染参数 ====================
                if !detailed.renderingIntent.isEmpty || !detailed.interlace.isEmpty && detailed.interlace != "Undefined" {
                    Divider()
                    Text("渲染参数")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !detailed.renderingIntent.isEmpty {
                        InfoRow(label: "渲染意图", value: detailed.renderingIntent)
                    }
                    
                    if !detailed.interlace.isEmpty && detailed.interlace != "Undefined" {
                        InfoRow(label: "交错", value: detailed.interlace)
                    }
                    
                    if !detailed.intensity.isEmpty && detailed.intensity != "Undefined" {
                        InfoRow(label: "强度模式", value: detailed.intensity)
                    }
                }
                
                // ==================== 颜色信息 ====================
                if !detailed.backgroundColor.isEmpty || !detailed.matteColor.isEmpty || 
                   !detailed.borderColor.isEmpty || !detailed.transparentColor.isEmpty {
                    Divider()
                    Text("颜色信息")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !detailed.backgroundColor.isEmpty {
                        InfoRow(label: "背景色", value: detailed.backgroundColor)
                    }
                    
                    if !detailed.matteColor.isEmpty {
                        InfoRow(label: "Matte色", value: detailed.matteColor)
                    }
                    
                    if !detailed.borderColor.isEmpty {
                        InfoRow(label: "边框色", value: detailed.borderColor)
                    }
                    
                    if !detailed.transparentColor.isEmpty {
                        InfoRow(label: "透明色", value: detailed.transparentColor)
                    }
                }
                
                // ==================== PNG 特有信息 ====================
                if !detailed.pngColorType.isEmpty || !detailed.pngColorTypeOriginal.isEmpty || 
                   !detailed.pngInterlaceMethod.isEmpty || detailed.pngTextChunks > 0 {
                    Divider()
                    Text("PNG 特有")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !detailed.pngColorType.isEmpty {
                        InfoRow(label: "颜色类型", value: detailed.pngColorType)
                    }
                    
                    if !detailed.pngColorTypeOriginal.isEmpty && detailed.pngColorTypeOriginal != detailed.pngColorType {
                        InfoRow(label: "原始颜色类型", value: detailed.pngColorTypeOriginal)
                    }
                    
                    if !detailed.pngInterlaceMethod.isEmpty {
                        InfoRow(label: "交错方法", value: detailed.pngInterlaceMethod)
                    }
                    
                    if detailed.pngTextChunks > 0 {
                        InfoRow(label: "文本块", value: "\(detailed.pngTextChunks) 个")
                    }
                }
                
                // ==================== 色度坐标 ====================
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
                
                // ==================== 通道统计 ====================
                if !detailed.redChannel.isEmpty || !detailed.greenChannel.isEmpty || 
                   !detailed.blueChannel.isEmpty || !detailed.alphaChannel.isEmpty {
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
                    if let min = detailed.alphaChannel["min"], let max = detailed.alphaChannel["max"], let mean = detailed.alphaChannel["mean"] {
                        ChannelStatsRow(channel: "Alpha", min: min, max: max, mean: mean)
                    }
                    
                    // 显示标准差和熵
                    if !detailed.overallStatistics.isEmpty {
                        if let stdDev = detailed.overallStatistics["standard deviation"] {
                            InfoRow(label: "整体标准差", value: stdDev)
                        }
                        if let entropy = detailed.overallStatistics["entropy"] {
                            InfoRow(label: "熵", value: entropy)
                        }
                    }
                }
                
                // ==================== 元数据 ====================
                if !detailed.dateCreate.isEmpty || !detailed.dateModify.isEmpty || 
                   !detailed.signature.isEmpty {
                    Divider()
                    Text("元数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !detailed.dateCreate.isEmpty {
                        let createDate = formatDate(detailed.dateCreate)
                        InfoRow(label: "创建时间", value: createDate)
                    }
                    
                    if !detailed.dateModify.isEmpty {
                        let modifyDate = formatDate(detailed.dateModify)
                        InfoRow(label: "修改时间", value: modifyDate)
                    }
                    
                    if !detailed.signature.isEmpty {
                        InfoRow(label: "签名", value: String(detailed.signature.prefix(16)) + "...")
                    }
                }
                
                // ==================== 配置文件 ====================
                if !detailed.profiles.isEmpty {
                    Divider()
                    InfoRow(label: "嵌入配置", value: detailed.profiles.joined(separator: ", "))
                }
                
                // ==================== 文件信息 ====================
                Divider()
                Text("文件信息")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if detailed.pixels > 0 {
                    InfoRow(label: "总像素", value: formatPixelCount(detailed.pixels))
                }
                
                if !detailed.fileSize.isEmpty {
                    InfoRow(label: "文件大小", value: detailed.fileSize)
                }
                
                if detailed.tainted {
                    InfoRow(label: "已修改", value: "是")
                }
                
                if !detailed.memorySize.isEmpty {
                    InfoRow(label: "内存占用", value: detailed.memorySize)
                }
                
                // ==================== 直方图 (前5个) ====================
                if !detailed.histogram.isEmpty {
                    Divider()
                    Text("主要颜色 (前5)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(detailed.histogram.prefix(5).enumerated()), id: \.offset) { _, line in
                        HistogramRow(line: line)
                    }
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

// MARK: - 辅助方法

// 格式化日期
private func formatDate(_ dateString: String) -> String {
    // ISO8601 格式: 2026-03-11T08:07:05+00:00
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    if let date = formatter.date(from: dateString) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .medium
        return displayFormatter.string(from: date)
    }
    
    // 尝试不带毫秒的格式
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: dateString) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .medium
        return displayFormatter.string(from: date)
    }
    
    return dateString
}

// 格式化像素数量
private func formatPixelCount(_ count: Int) -> String {
    if count >= 1_000_000 {
        return String(format: "%.1fM", Double(count) / 1_000_000)
    } else if count >= 1_000 {
        return String(format: "%.1fK", Double(count) / 1_000)
    }
    return "\(count)"
}

// 直方图行
struct HistogramRow: View {
    let line: String
    
    var body: some View {
        // 解析: "    64: (20432,17954,58863) #4FD04622E5EF srgb(31.1772%,27.396%,89.8192%)"
        let components = line.components(separatedBy: ")")
        let countPart = line.trimmingCharacters(in: .whitespaces).components(separatedBy: ":").first ?? ""
        let colorPart = components.count > 1 ? components[1].trimmingCharacters(in: .whitespaces) : ""
        
        HStack {
            Text(countPart)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            Text(colorPart)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
        }
    }
}
