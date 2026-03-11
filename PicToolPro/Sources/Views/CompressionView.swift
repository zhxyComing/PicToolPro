import SwiftUI

struct CompressionView: View {
    @Binding var images: [LoadedImage]
    @Binding var processedImages: [ProcessedImage]
    @Binding var isProcessing: Bool
    
    @State private var compressionMode: CompressionModeType = .lossless
    @State private var quality: Double = 80
    @State private var scaleMode: ScaleMode = .percentage
    @State private var width: String = ""
    @State private var height: String = ""
    @State private var percentage: Double = 50
    
    enum CompressionModeType: String, CaseIterable {
        case lossless = "无损压缩"
        case lossy = "有损压缩"
        case scale = "尺寸压缩"
    }
    
    enum ScaleMode: String, CaseIterable {
        case fixed = "固定尺寸"
        case percentage = "百分比"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("图片压缩")
                .font(.headline)
            
            Divider()
            
            // Mode Selection
            Picker("压缩模式", selection: $compressionMode) {
                ForEach(CompressionModeType.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            // Mode-specific options
            switch compressionMode {
            case .lossless:
                VStack(alignment: .leading, spacing: 8) {
                    Text("保留原图细节，仅优化冗余数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
            case .lossy:
                VStack(alignment: .leading, spacing: 8) {
                    Text("压缩质量: \(Int(quality))%")
                        .font(.subheadline)
                    Slider(value: $quality, in: 10...100, step: 5)
                }
                
            case .scale:
                VStack(alignment: .leading, spacing: 8) {
                    Picker("缩放模式", selection: $scaleMode) {
                        ForEach(ScaleMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if scaleMode == .fixed {
                        HStack {
                            TextField("宽", text: $width)
                                .textFieldStyle(.roundedBorder)
                            Text("×")
                            TextField("高", text: $height)
                                .textFieldStyle(.roundedBorder)
                            Text("px")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("缩放比例: \(Int(percentage))%")
                            Slider(value: $percentage, in: 10...100, step: 5)
                        }
                    }
                }
            }
            
            // Compression stats
            if !processedImages.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("压缩统计")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(processedImages) { processed in
                        HStack {
                            Text("原始: \(formatBytes(processed.originalSize))")
                            Image(systemName: "arrow.right")
                            Text("压缩后: \(formatBytes(processed.processedSize))")
                            Text("(\(String(format: "%.1f", processed.compressionRatio))%↓)")
                                .foregroundColor(.green)
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Process Button
            Button("压缩图片") {
                processImages()
            }
            .disabled(images.isEmpty || isProcessing)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
    
    private func processImages() {
        isProcessing = true
        processedImages = []
        
        let mode: CompressionMode
        switch compressionMode {
        case .lossless:
            mode = .lossless
        case .lossy:
            mode = .lossy(quality: quality / 100.0)
        case .scale:
            if scaleMode == .fixed {
                let w = Int(width)
                let h = Int(height)
                mode = .scale(width: w, height: h, percentage: nil)
            } else {
                mode = .scale(width: nil, height: nil, percentage: percentage)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Determine output format based on compression mode
            let outputFormat: ImageFormat
            switch compressionMode {
            case .lossless:
                outputFormat = .png
            case .lossy:
                outputFormat = .jpg
            case .scale:
                outputFormat = .png
            }
            
            let results = ImageProcessingService.shared.batchProcess(images: images) { loadedImage in
                guard let (processed, data) = ImageProcessingService.shared.compress(
                    image: loadedImage.nsImage,
                    mode: mode
                ) else { return nil }
                
                return ProcessedImage(
                    nsImage: processed,
                    data: data,
                    format: outputFormat,
                    originalSize: loadedImage.originalData?.count ?? 0,
                    processedSize: data.count
                )
            }
            
            DispatchQueue.main.async {
                processedImages = results
                isProcessing = false
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
