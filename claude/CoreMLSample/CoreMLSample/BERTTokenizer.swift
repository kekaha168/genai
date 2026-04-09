//
//  BERTTokenizer.swift
//  CoreMLSample
//
//  Created by Dennis Sheu on 4/8/26.
//

import Foundation

/// Minimal WordPiece tokenizer for BERT-Base (uncased).
/// For production use, replace with a full vocab-file-based tokenizer.
struct BERTTokenizer {
    private let vocab: [String: Int]
    
    init() {
        // Load bert-base-uncased vocab.txt bundled in the app
        if let url = Bundle.main.url(forResource: "vocab", withExtension: "txt"),
           let content = try? String(contentsOf: url) {
            var dict: [String: Int] = [:]
            content.components(separatedBy: "\n").enumerated().forEach { idx, token in
                dict[token] = idx
            }
            vocab = dict
        } else {
            vocab = [:]
            print("WARNING: vocab.txt not found — tokenization will be empty.")
        }
    }
    
    /// Returns (inputIds, attentionMask, tokenTypeIds, tokens)
    func tokenize(question: String,
                  context: String,
                  maxLength: Int) -> ([Int], [Int], [Int], [String]) {
        
        let qTokens = wordPiece(text: question.lowercased())
        let cTokens = wordPiece(text: context.lowercased())
        
        // [CLS] q [SEP] c [SEP]
        var tokens  = ["[CLS]"] + qTokens + ["[SEP]"] + cTokens + ["[SEP]"]
        var typeIds = [Int](repeating: 0, count: qTokens.count + 2) +
        [Int](repeating: 1, count: cTokens.count + 1)
        
        // Truncate
        if tokens.count > maxLength {
            tokens  = Array(tokens.prefix(maxLength - 1)) + ["[SEP]"]
            typeIds = Array(typeIds.prefix(maxLength))
        }
        
        let ids  = tokens.map  { vocab[$0] ?? vocab["[UNK]"] ?? 100 }
        let mask = [Int](repeating: 1, count: tokens.count)
        
        return (ids, mask, typeIds, tokens)
    }
    
    /// Convert token list back to a readable string
    func decode(tokens: [String]) -> String {
        tokens
            .filter { !["[CLS]", "[SEP]", "[PAD]"].contains($0) }
            .joined()
            .replacingOccurrences(of: "##", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Minimal WordPiece
    
    private func wordPiece(text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var result: [String] = []
        for word in words where !word.isEmpty {
            result.append(contentsOf: tokenizeWord(word))
        }
        return result
    }
    
    private func tokenizeWord(_ word: String) -> [String] {
        guard !word.isEmpty else { return [] }
        if vocab[word] != nil { return [word] }
        
        var tokens: [String] = []
        var start = word.startIndex
        var isFirst = true
        
        while start < word.endIndex {
            var end = word.endIndex
            var found = false
            while start < end {
                let sub = isFirst ? String(word[start..<end])
                : "##" + String(word[start..<end])
                if vocab[sub] != nil {
                    tokens.append(sub)
                    start = end
                    isFirst = false
                    found = true
                    break
                }
                end = word.index(before: end)
            }
            if !found {
                return ["[UNK]"]
            }
        }
        return tokens
    }
}
