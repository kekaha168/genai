//
//  FastVitView.swift
//  CoreMLSample
//
//  Created by Dennis Sheu on 4/8/26.
//

import SwiftUI
import Vision
import CoreML

struct ClassificationResult: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
}

struct FastViTView: View {
    @State private var selectedImage: UIImage?
    @State private var results: [ClassificationResult] = []
    @State private var isProcessing = false
    @State private var showPicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var errorMessage: String?

    // ✅ Store both so we can inspect the raw MLModel
    private let visionModel: VNCoreMLModel?
    private var rawModel: MLModel?
    
    init() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let coreMLModel = try FastViTT8F16(configuration: config)
            self.rawModel   = coreMLModel.model          // ✅ keep raw MLModel
            self.visionModel = try VNCoreMLModel(for: coreMLModel.model)
        } catch {
            print("FastViT model load error: \(error)")
            self.rawModel    = nil
            self.visionModel = nil
        }
    }
    
    // Load the CoreML model once
    private let model: VNCoreMLModel? = {
        do {
            // Replace "FastViT_MA36" with your actual .mlpackage class name
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let coreMLModel = try FastViTT8F16(configuration: config)
            return try VNCoreMLModel(for: coreMLModel.model)
        } catch {
            print("FastViT model load error: \(error)")
            return nil
        }
    }()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 280)
                        if let img = selectedImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.secondary)
                                Text("Choose an image to classify")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Source buttons
                    HStack(spacing: 12) {
                        Button {
                            sourceType = .photoLibrary
                            showPicker = true
                        } label: {
                            Label("Photos", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                sourceType = .camera
                                showPicker = true
                            }
                        } label: {
                            Label("Camera", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    
                    // Run button
                    Button {
                        classifyImage()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView().tint(.white)
                            }
                            Text(isProcessing ? "Running…" : "Run FastViT")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedImage == nil || isProcessing)
                    .padding(.horizontal)
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    
                    // Results
                    if !results.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top predictions")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(results) { result in
                                ResultRow(label: result.label, confidence: result.confidence)
                            }
                        }
                        .padding(.bottom)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("FastViT — Image Classification")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let raw = rawModel {
                    printModelInfo(raw, name: "FastViTT8F16")
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: $selectedImage, sourceType: sourceType)
        }
    }
    
    private func classifyImage() {
        guard let image = selectedImage,
              let cgImage = image.cgImage,
              let model = model else {
            errorMessage = "Model unavailable or no image selected."
            return
        }
        
        isProcessing = true
        errorMessage = nil
        results = []
        
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNCoreMLRequest(model: model) { req, err in
                DispatchQueue.main.async {
                    isProcessing = false
                    if let err = err {
                        errorMessage = err.localizedDescription
                        return
                    }
                    guard let observations = req.results as? [VNClassificationObservation] else { return }
                    results = observations.prefix(5).map {
                        ClassificationResult(label: $0.identifier, confidence: $0.confidence)
                    }
                }
            }
            request.imageCropAndScaleOption = .centerCrop
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    errorMessage = "Inference failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Result row with confidence bar

struct ResultRow: View {
    let label: String
    let confidence: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%.1f%%", confidence * 100))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * CGFloat(confidence), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal)
    }
}
