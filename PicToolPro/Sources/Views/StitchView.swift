import SwiftUI

// MARK: - Stitch Models

enum StitchDirection: String, CaseIterable {
    case horizontal = "横向拼接"
    case vertical = "纵向拼接"
    
    var icon: String {
        switch self {
        case .horizontal: return "arrow.left.and.right"
        case .vertical: return "arrow.up.and.down"
        }
    }
}

enum AlignmentHorizontal: String, CaseIterable {
    case top = "顶部对齐"
    case center = "居中"
    case bottom = "底部对齐"
    
    var icon: String {
        switch self {
        case .top: return "arrow.up.to.line"
        case .center: return "arrow.up.arrow.down"
        case .bottom: return "arrow.down.to.line"
        }
    }
}

enum AlignmentVertical: String, CaseIterable {
    case left = "左侧对齐"
    case center = "居中"
    case right = "右侧对齐"
    
    var icon: String {
        switch self {
        case .left: return "arrow.left.to.line"
        case .center: return "arrow.left.arrow.right"
        case .right: return "arrow.right.to.line"
        }
    }
}

struct StitchSettings {
    var direction: StitchDirection = .horizontal
    var alignmentHorizontal: AlignmentHorizontal = .center
    var alignmentVertical: AlignmentVertical = .center
    var spacing: Int = 0
    var spacingColor: Color = .clear
    var backgroundColor: Color = .white
    var useTransparentBackground: Bool = false
    var outputWidth: Int? = nil
    var outputHeight: Int? = nil
    var scaleMode: OutputScaleMode = .original
    
    enum OutputScaleMode: String, CaseIterable {
        case original = "保持原始"
        case fitWidth = "适应宽度"
        case fitHeight = "适应高度"
        case custom = "自定义"
    }
}

// MARK: - Stitch View

struct StitchView: View {
    @Binding var images: [LoadedImage]
    @Binding var processedImages: [ProcessedImage]
    @Binding var isProcessing: Bool
    
    @State private var settings = StitchSettings()
    @State private var draggedIndex: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("图片拼接")
                .font(.headline)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Direction Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("拼接方向")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("拼接方向", selection: $settings.direction) {
                            ForEach(StitchDirection.allCases, id: \.self) { direction in
                                Label(direction.rawValue, systemImage: direction.icon).tag(direction)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Alignment Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("对齐方式")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if settings.direction == .horizontal {
                            Picker("对齐", selection: $settings.alignmentHorizontal) {
                                ForEach(AlignmentHorizontal.allCases, id: \.self) { alignment in
                                    Label(alignment.rawValue, systemImage: alignment.icon).tag(alignment)
                                }
                            }
                            .pickerStyle(.segmented)
                        } else {
                            Picker("对齐", selection: $settings.alignmentVertical) {
                                ForEach(AlignmentVertical.allCases, id: \.self) { alignment in
                                    Label(alignment.rawValue, systemImage: alignment.icon).tag(alignment)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    // Spacing Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("间距: \(settings.spacing)px")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { Double(settings.spacing) },
                            set: { settings.spacing = Int($0) }
                        ), in: 0...50, step: 1)
                        
                        Toggle("纯色间距", isOn: Binding(
                            get: { settings.spacingColor != .clear },
                            set: { settings.spacingColor = $0 ? Color.gray : .clear }
                        ))
                        
                        if settings.spacingColor != .clear {
                            ColorPicker("间距颜色", selection: $settings.spacingColor)
                                .labelsHidden()
                        }
                    }
                    
                    // Background Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("背景设置")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Toggle("透明背景", isOn: $settings.useTransparentBackground)
                        
                        if !settings.useTransparentBackground {
                            ColorPicker("背景颜色", selection: $settings.backgroundColor)
                                .labelsHidden()
                        }
                    }
                    
                    // Output Size Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("输出尺寸")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("缩放模式", selection: $settings.scaleMode) {
                            ForEach(StitchSettings.OutputScaleMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if settings.scaleMode == .custom {
                            HStack {
                                TextField("宽", value: $settings.outputWidth, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                Text("×")
                                TextField("高", value: $settings.outputHeight, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                Text("px").foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Image Order (Drag & Drop)
                    if images.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("图片顺序 (拖拽调整)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                                HStack {
                                    Image(systemName: "\(index + 1).circle.fill")
                                        .foregroundColor(.accentColor)
                                    
                                    Image(nsImage: image.nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 40)
                                        .cornerRadius(4)
                                    
                                    Text(image.url.lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                                .onDrag { draggedIndex = index; return NSItemProvider(object: "\(index)" as NSString) }
                                .onDrop(of: [.text], delegate: ImageDropDelegate(
                                    itemIndex: index,
                                    items: $images,
                                    draggedIndex: $draggedIndex
                                ))
                            }
                        }
                    }
                    
                    // Batch Resize Button
                    if images.count > 1 {
                        Button(action: batchResize) {
                            Label("一键统一尺寸", systemImage: "rectangle.expand.vertical")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Spacer()
            
            // Process Button
            Button("拼接图片") {
                stitchImages()
            }
            .disabled(images.count < 2 || isProcessing)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
    
    private func batchResize() {
        // Find the most common size or largest size
        let sizes = images.map { $0.nsImage.size }
        guard let maxWidth = sizes.map({ Int($0.width) }).max(),
              let maxHeight = sizes.map({ Int($0.height) }).max() else { return }
        
        settings.outputWidth = maxWidth
        settings.outputHeight = maxHeight
        settings.scaleMode = .custom
    }
    
    private func stitchImages() {
        isProcessing = true
        processedImages = []
        
        // Convert enums to strings for ImageProcessingService
        let directionStr = settings.direction == .horizontal ? "horizontal" : "vertical"
        let alignmentHStr = settings.alignmentHorizontal == .top ? "top" : (settings.alignmentHorizontal == .center ? "center" : "bottom")
        let alignmentVStr = settings.alignmentVertical == .left ? "left" : (settings.alignmentVertical == .center ? "center" : "right")
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let (stitchedImage, data) = ImageProcessingService.shared.stitchImages(
                images: images,
                direction: directionStr,
                alignmentHorizontal: alignmentHStr,
                alignmentVertical: alignmentVStr,
                spacing: settings.spacing,
                spacingColor: NSColor(settings.spacingColor),
                backgroundColor: NSColor(settings.backgroundColor),
                useTransparentBackground: settings.useTransparentBackground,
                outputWidth: settings.scaleMode == .custom ? settings.outputWidth : nil,
                outputHeight: settings.scaleMode == .custom ? settings.outputHeight : nil
            ) else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
                return
            }
            
            let processed = ProcessedImage(
                nsImage: stitchedImage,
                data: data,
                format: .png,
                originalSize: images.compactMap { $0.originalData?.count }.reduce(0, +),
                processedSize: data.count
            )
            
            DispatchQueue.main.async {
                processedImages = [processed]
                isProcessing = false
            }
        }
    }
}

// MARK: - Drag & Drop Delegate

struct ImageDropDelegate: DropDelegate {
    let itemIndex: Int
    @Binding var items: [LoadedImage]
    @Binding var draggedIndex: Int?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedIndex = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedIndex = draggedIndex,
              draggedIndex != itemIndex else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            let draggedItem = items[draggedIndex]
            items.remove(at: draggedIndex)
            items.insert(draggedItem, at: itemIndex)
            self.draggedIndex = itemIndex
        }
    }
}
