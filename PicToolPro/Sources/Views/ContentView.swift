import SwiftUI

struct ContentView: View {
    @State private var selectedTool: ToolType = .cornerCrop
    @State private var images: [LoadedImage] = []
    @State private var processedImages: [ProcessedImage] = []
    @State private var isProcessing: Bool = false
    @State private var showOriginal: Bool = true
    
    enum ToolType: String, CaseIterable {
        case cornerCrop = "圆角裁剪"
        case compression = "图片压缩"
        case formatConvert = "格式转换"
        
        var icon: String {
            switch self {
            case .cornerCrop: return "rectangle.on.rectangle"
            case .compression: return "arrow.down.circle"
            case .formatConvert: return "arrow.triangle.2.circlecircle"
            }
        }
    }
    
    var body: some View {
        HSplitView {
            // Left: Tool Selection
            VStack(spacing: 0) {
                ForEach(ToolType.allCases, id: \.self) { tool in
                    Button(action: { selectedTool = tool }) {
                        VStack(spacing: 4) {
                            Image(systemName: tool.icon)
                                .font(.system(size: 20))
                            Text(tool.rawValue)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedTool == tool ? Color.accentColor : Color.clear)
                        .foregroundColor(selectedTool == tool ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .frame(width: 80)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Middle: Preview
            VStack {
                if images.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("拖拽图片到此处或点击选择")
                            .foregroundColor(.secondary)
                        Button("选择图片") {
                            selectImages()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack {
                        if !processedImages.isEmpty && !showOriginal {
                            if let processed = processedImages.first {
                                Image(processed.nsImage, scale: 1.0)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        } else if let first = images.first {
                            Image(first.nsImage, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
                    
                    // Toggle Original/Processed
                    if !processedImages.isEmpty {
                        Toggle("显示原图", isOn: $showOriginal)
                            .padding(8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Right: Parameters
            VStack {
                ScrollView {
                    switch selectedTool {
                    case .cornerCrop:
                        CornerCropView(images: $images, processedImages: $processedImages, isProcessing: $isProcessing)
                    case .compression:
                        CompressionView(images: $images, processedImages: $processedImages, isProcessing: $isProcessing)
                    case .formatConvert:
                        FormatConvertView(images: $images, processedImages: $processedImages, isProcessing: $isProcessing)
                    }
                }
                
                Divider()
                
                HStack {
                    Button("添加图片") {
                        selectImages()
                    }
                    .disabled(images.isEmpty)
                    
                    Button("导出") {
                        exportImages()
                    }
                    .disabled(processedImages.isEmpty || isProcessing)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .frame(width: 280)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 900, minHeight: 600)
    }
    
    private func selectImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .heic, .webP, .bmp, .gif, .avif]
        
        if panel.runModal() == .OK {
            images = panel.urls.compactMap { url in
                guard let nsImage = NSImage(contentsOf: url) else { return nil }
                return LoadedImage(url: url, nsImage: nsImage)
            }
            processedImages = []
        }
    }
    
    private func exportImages() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "选择导出目录"
        
        if panel.runModal() == .OK, let url = panel.url {
            for (index, processed) in processedImages.enumerated() {
                let fileName = "PicTool_Export_\(index + 1).\(processed.format.rawValue)"
                let fileURL = url.appendingPathComponent(fileName)
                try? processed.data.write(to: fileURL)
            }
        }
    }
}

#Preview {
    ContentView()
}
