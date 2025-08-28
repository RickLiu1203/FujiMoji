//
//  PopupViewModel.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-28.
//

import SwiftUI
import Combine

class PopupViewModel: ObservableObject {
    @Published var customMatches: [String] = []
    @Published var emojiMatches: [(tag: String, emoji: String)] = []
    @Published var highlightedIndex: Int = 0
    
    private let minCharsForSuggestions = 2
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        KeyDetection.shared.$currentString
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.updateMatches(for: newValue)
            }
            .store(in: &cancellables)
    }
    
    func updateMatches(for current: String) {
        let prefix = current.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard prefix.count >= minCharsForSuggestions else {
            customMatches = []
            emojiMatches = []
            highlightedIndex = 0
            return
        }
        let fetchPrefix = prefix
        DispatchQueue.global(qos: .userInitiated).async {
            let customTags = CustomStorage.shared.collectTags(withPrefix: fetchPrefix, limit: 50)
            let emojiPairs = EmojiStorage.shared.collectPairs(withPrefix: fetchPrefix, limit: 50)
            
            let sortedCustom = customTags.sorted { tag1, tag2 in
                let exact1 = tag1.lowercased() == fetchPrefix
                let exact2 = tag2.lowercased() == fetchPrefix
                if exact1 && !exact2 { return true }
                if !exact1 && exact2 { return false }
                return tag1 < tag2 
            }
            
            let sortedEmoji = emojiPairs.sorted { pair1, pair2 in
                let exact1 = pair1.tag.lowercased() == fetchPrefix
                let exact2 = pair2.tag.lowercased() == fetchPrefix
                if exact1 && !exact2 { return true }
                if !exact1 && exact2 { return false }
                return pair1.tag < pair2.tag 
            }
            
            DispatchQueue.main.async {
                if KeyDetection.shared.currentString.lowercased() == fetchPrefix {
                    self.customMatches = sortedCustom
                    self.emojiMatches = sortedEmoji
                    
                    self.highlightedIndex = self.findFirstExactMatchIndex(for: fetchPrefix)
                }
            }
        }
    }

    func performEmojiSelection(tag: String, emoji: String) {
        KeyDetection.shared.finishCaptureWithDirectReplacement(emoji, endWithSpace: false)
    }

    func performCustomSelection(tag: String) {
        let replacement = CustomStorage.shared.getText(forTag: tag) ?? ""
        guard !replacement.isEmpty else { return }
        KeyDetection.shared.finishCaptureWithDirectReplacement(replacement, endWithSpace: false)
    }
    
    func findFirstExactMatchIndex(for input: String) -> Int {
        let lowercaseInput = input.lowercased()
        
        if let exactCustomIndex = customMatches.firstIndex(where: { $0.lowercased() == lowercaseInput }) {
            return exactCustomIndex
        }
        
        if let exactEmojiIndex = emojiMatches.firstIndex(where: { $0.tag.lowercased() == lowercaseInput }) {
            return customMatches.count + exactEmojiIndex
        }
        
        return 0
    }
    
    func selectHighlightedItem() {
        let currentInput = KeyDetection.shared.currentString.lowercased()
        
        if let exactCustom = customMatches.first(where: { $0.lowercased() == currentInput }) {
            performCustomSelection(tag: exactCustom)
            return
        }
        
        if let exactEmoji = emojiMatches.first(where: { $0.tag.lowercased() == currentInput }) {
            performEmojiSelection(tag: exactEmoji.tag, emoji: exactEmoji.emoji)
            return
        }
        
        if !customMatches.isEmpty && highlightedIndex < customMatches.count {
            let tag = customMatches[highlightedIndex]
            performCustomSelection(tag: tag)
        } else if !emojiMatches.isEmpty {
            let adjustedIndex = highlightedIndex - customMatches.count
            if adjustedIndex >= 0 && adjustedIndex < emojiMatches.count {
                let pair = emojiMatches[adjustedIndex]
                performEmojiSelection(tag: pair.tag, emoji: pair.emoji)
            }
        }
    }
    
    var shouldShowSuggestions: Bool {
        return KeyDetection.shared.currentString.count >= minCharsForSuggestions
    }
}
