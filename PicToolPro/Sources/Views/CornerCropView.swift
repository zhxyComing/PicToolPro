import SwiftUI

struct CornerCropView: View {
    @Binding var images: [LoadedImage]
    @Binding var processedImages: [ProcessedImage]
    @Binding var isProcessing: Bool
    
    @State private var selectedPreset: CornerRadiusPreset = .px20
    @State private var customRadius: String = "20"
    @State private var transparentBackground: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("圆角裁剪")
                .font(.headline)
            
            Divider()
            
            // Preset Selection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("圆角半径")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Picker("", selection: $selectedPreset) {
                    ForEach(CornerRadiusPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                if selectedPreset == .custom {
                    HStack {
                        TextField("半径", text: $customRadius)
                            .textFieldStyle(.roundedBorder)
                        Text("px")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Background Option
            VStack(alignment: .leading, spacing: 8) {
                Toggle("透明背景 (PNG)", isOn: $transparentBackground)
                
                if !transparentBackground {
                    Text("将使用白色背景")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Process Button
            Button("应用圆角") {
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
        
        let radius: CGFloat
        if let presetValue = selectedPreset.value {
            radius = presetValue
        } else {
            radius = CGFloat(Double(customRadius) ?? 20)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let results = ImageProcessingService.shared.batchProcess(images: images) { loadedImage in
                guard let processed = ImageProcessingService.shared.applyCornerRadius(
                    to: loadedImage.nsImage,
                    radius: radius,
                    transparentBackground: transparentBackground
                ) else { return nil }
                
                let data = processed.tiffRepresentation ?? Data()
                return ProcessedImage(
                    nsImage: processed,
                    data: data,
                    format: .png,
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
}
