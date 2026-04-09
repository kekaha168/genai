//
//  BERTView.swift
//  CoreMLSample
//
//  Created by Dennis Sheu on 4/8/26.
//

import SwiftUI
import CoreML
import NaturalLanguage

struct BERTView: View {
    @State private var context: String = ""
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    // debug info
    @State private var modelInfo: String = ""

    
    // BERT tokenizer helper (see BERTTokenizer.swift below)
    private let tokenizer = BERTTokenizer()
    
    // Load the CoreML model once
    // BERTSQUADFP16
    // private let bertModel: BERT_SQuAD? = {
    private let bertModel: BERTSQuADFP16? = {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            return try BERTSQuADFP16(configuration: config)
        } catch {
            print("BERT model load error: \(error)")
            return nil
        }
    }()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Context input
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Context paragraph", systemImage: "doc.text")
                            .font(.headline)
                        TextEditor(text: $context)
                            .font(.body)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                        if context.isEmpty {
                            Text("Paste a paragraph for the model to read…")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 4)
                        }
                    }
                    
                    // Question input
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Question", systemImage: "questionmark.circle")
                            .font(.headline)
                        TextField("Ask something about the context…", text: $question)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                    }
                    
                    // Run button
                    Button {
                        runBERT()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView().tint(.white)
                            }
                            Text(isProcessing ? "Running…" : "Run BERT-SQuAD")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(context.trimmingCharacters(in: .whitespaces).isEmpty ||
                              question.trimmingCharacters(in: .whitespaces).isEmpty ||
                              isProcessing)
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    
                    // Answer card
                    if !answer.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Answer", systemImage: "checkmark.seal.fill")
                                .font(.headline)
                                .foregroundStyle(.green)
                            Text(answer)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    // Debug card — remove before shipping
                    if !modelInfo.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Model Inspector")
                                .font(.headline)
                            Text(modelInfo)
                                .font(.system(.caption, design: .monospaced))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("BERT-SQuAD — Q&A")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard let model = bertModel else {
                    modelInfo = "Model unavailable"
                    return
                }
                
                var info = "── Inputs ──\n"
                for (name, desc) in model.model.modelDescription.inputDescriptionsByName {
                    info += "• \(name) : \(desc.type)"
                    if let ma = desc.multiArrayConstraint {
                        info += " \(ma.shape) \(ma.dataType)"
                    }
                    info += "\n"
                }
                
                info += "\n── Outputs ──\n"
                for (name, desc) in model.model.modelDescription.outputDescriptionsByName {
                    info += "• \(name) : \(desc.type)"
                    if let ma = desc.multiArrayConstraint {
                        info += " \(ma.shape) \(ma.dataType)"
                    }
                    info += "\n"
                }
                
                modelInfo = info
                //guard let model = bertModel else { return }
                
                print("=== BERT Model Inputs ===")
                for (name, desc) in model.model.modelDescription.inputDescriptionsByName {
                    print("Name: \(name)")
                    print("Type: \(desc.type)")
                    if let multiArray = desc.multiArrayConstraint {
                        print("Shape: \(multiArray.shape)")
                        print("DataType: \(multiArray.dataType)")
                    }
                    print("---")
                }
                
                print("=== BERT Model Outputs ===")
                for (name, desc) in model.model.modelDescription.outputDescriptionsByName {
                    print("Name: \(name)")
                    print("Type: \(desc.type)")
                    if let multiArray = desc.multiArrayConstraint {
                        print("Shape: \(multiArray.shape)")
                        print("DataType: \(multiArray.dataType)")
                    }
                    print("---")
                }
                
                if let bert = bertModel {
                    printModelInfo(bert.model, name: "BERT_SQuAD_FP16")
                }
            }
        }
    }

    private func runBERT() {
        guard let model = bertModel else {
            errorMessage = "BERT model unavailable."
            return
        }
        
        let capturedQuestion = question
        let capturedContext  = context
        
        isProcessing = true
        errorMessage = nil
        answer = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let (inputIds, _, tokenTypeIds, tokens) =    // ✅ ignore attentionMask with _
                self.tokenizer.tokenize(
                    question: capturedQuestion,
                    context: capturedContext,
                    maxLength: 384
                )
                
                let seqLen = 384   // ✅ fixed size to match model shape 1 x 384
                
                // ✅ Double type, shape [1, 384] to match model inspector
                let wordIDsArray    = try MLMultiArray(shape: [1, 384], dataType: .double)
                let wordTypesArray  = try MLMultiArray(shape: [1, 384], dataType: .double)
                
                // ✅ Fill arrays, pad with 0 if input is shorter than 384
                for i in 0..<seqLen {
                    wordIDsArray[i]   = i < inputIds.count    ? NSNumber(value: inputIds[i])    : 0
                    wordTypesArray[i] = i < tokenTypeIds.count ? NSNumber(value: tokenTypeIds[i]) : 0
                }
                
                // ✅ Use correct argument labels from Model inspector
                let input = BERTSQuADFP16Input(
                    wordIDs:   wordIDsArray,
                    wordTypes: wordTypesArray
                )
                
                let output = try model.prediction(input: input)
                
                // Check Model inspector Outputs section for exact names
                let startArray = output.startLogits   // update if name differs
                let endArray   = output.endLogits     // update if name differs
                
                let startLogits = (0..<tokens.count).map { startArray[$0].doubleValue }
                let endLogits   = (0..<tokens.count).map { endArray[$0].doubleValue }
                
                let startIdx = startLogits.indices.max(by: { startLogits[$0] < startLogits[$1] }) ?? 0
                let endIdx   = max(startIdx, endLogits.indices.max(by: { endLogits[$0] < endLogits[$1] }) ?? 0)
                
                let answerTokens    = Array(tokens[startIdx...min(endIdx, tokens.count - 1)])
                let extractedAnswer = self.tokenizer.decode(tokens: answerTokens)
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.answer = extractedAnswer.isEmpty ? "No answer found." : extractedAnswer
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = "Inference failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
