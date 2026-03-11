import SwiftUI

struct FormatConvertView: View {
    @Binding var images: [LoadedImage]
    @Binding var processedImages: [ProcessedImage]
    @Binding var isProcessing: Bool
    
    @State private var selectedFormat: ImageFormat = .png
    @State private var quality: Double = 85
    @State private var showQualitySlider: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("格式转换")
                .font(.headline)
            
            Divider()
            
            // Format Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("目标格式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(ImageFormat.allCases, id: \.self) { format in
                        Button(action: { selectedFormat = format }) {
                            VStack(spacing: 4) {
                                Image(systemName: format == selectedFormat ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(format == selectedFormat ? .accentColor : .secondary)
                                Text(format.displayName)
                                    .font(.caption)
                                    .foregroundColor(format == selectedFormat ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(format == selectedFormat ? Color.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Format-specific options
            VStack(alignment: .leading, spacing: 8) {
                switch selectedFormat {
                case .jpg:
                    Toggle("渐进式加载", isOn: .constant(false))
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("质量: \(Int(quality))%")
                            .font(.subheadline)
                        Slider(value: $quality, in: 10...100, step: 5)
                    }
                    
                case .webp:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("质量: \(Int(quality))%")
                            .font(.subheadline)
                        Slider(value: $quality, in: 0...100, step: 5)
                        Text("WebP: 0 = 无损, 100 = 高质量有损")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                case .heic:
                    Text("HEIC: Apple 生态格式，高画质小体积")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                case .png:
                    Text("PNG: 无损格式，支持透明背景")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                default:
                    EmptyView()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Conversion stats
            if !processedImages.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("转换结果")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(processedImages) { processed in
                        HStack {
                            Text(processed.format.displayName)
                            Text("(\(formatBytes(processed.processedSize)))")
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
            Button("转换格式") {
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
        
        DispatchQueue.global(qos: .userInitiated).async {
            let results = ImageProcessingService.shared.batchProcess(images: images) { loadedImage in
                guard let (processed, data, actualFormat) = ImageProcessingService.shared.convert(
                    image: loadedImage.nsImage,
                    to: selectedFormat,
                    quality: quality / 100.0
                ) else { return nil }
                
                return ProcessedImage(
                    nsImage: processed,
                    data: data,
                    format: actualFormat,
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
