//
//  PopupViewModel.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-28.
//

import SwiftUI
import Combine

struct EmojiMatch: Hashable {
    let tag: String
    let emoji: String
}

enum EmojiMatchPriority: Int, Comparable {
    case exactMatch = 0          // Exact match, not favorite
    case exactFavorite = 1       // Exact match, favorite
    case favorite = 2            // Favorite (alias or default)
    case alias = 3               // Non-favorite alias
    case defaultTag = 4          // Non-favorite default
    
    static func < (lhs: EmojiMatchPriority, rhs: EmojiMatchPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

class PopupViewModel: ObservableObject {
    @Published var customMatches: [String] = []
    @Published var emojiMatches: [EmojiMatch] = []
    @Published var highlightedIndex: Int = 0
    
    private let minCharsForSuggestions = 2
    private var cancellables = Set<AnyCancellable>()
    
    // Favorites data cached for O(1) lookup
    private var favoriteEmojis: Set<String> = []
    
    // Reference to FujiMojiState for controlling popup behavior
    weak var fujiMojiState: FujiMojiState?
    
    init(fujiMojiState: FujiMojiState? = nil) {
        self.fujiMojiState = fujiMojiState
        loadFavorites()
        setupObservers()
    }
    
    private func setupObservers() {
        KeyDetection.shared.$currentString
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.updateMatches(for: newValue)
            }
            .store(in: &cancellables)
        
        // Listen for left/right arrow navigation
        NotificationCenter.default.publisher(for: .navigateLeft)
            .sink { [weak self] _ in
                print("🔍 DEBUG: PopupViewModel received navigateLeft notification")
                self?.navigateLeft()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .navigateRight)
            .sink { [weak self] _ in
                print("🔍 DEBUG: PopupViewModel received navigateRight notification")
                self?.navigateRight()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .navigateUp)
            .sink { [weak self] _ in
                print("🔍 DEBUG: PopupViewModel received navigateUp notification")
                self?.navigateUp()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .navigateDown)
            .sink { [weak self] _ in
                print("🔍 DEBUG: PopupViewModel received navigateDown notification")
                self?.navigateDown()
            }
            .store(in: &cancellables)
        
        // Listen for favorites changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.loadFavorites()
            }
            .store(in: &cancellables)
    }
    
    private func loadFavorites() {
        if let saved = UserDefaults.standard.array(forKey: "favoriteEmojis") as? [String] {
            favoriteEmojis = Set(saved)
        } else {
            favoriteEmojis = []
        }
    }
    
    func updateMatches(for current: String) {
        let prefix = current.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // If popup is disabled, only show exact matches
        guard fujiMojiState?.showSuggestionPopup != false else {
            // Only show if there's an exact match
            let hasExactCustom = CustomStorage.shared.getText(forTag: prefix) != nil
            let hasExactEmoji = EmojiStorage.shared.findEmoji(forTag: prefix) != nil
            
            if hasExactCustom || hasExactEmoji {
                // Show exact matches only
                let customTags = hasExactCustom ? [prefix] : []
                let emojiPairs = hasExactEmoji ? EmojiStorage.shared.collectPairs(withPrefix: prefix, limit: 1).filter { $0.tag.lowercased() == prefix } : []
                
                DispatchQueue.main.async {
                    self.customMatches = customTags
                    self.emojiMatches = emojiPairs.map { EmojiMatch(tag: $0.tag, emoji: $0.emoji) }
                    self.highlightedIndex = 0
                }
            } else {
                customMatches = []
                emojiMatches = []
                highlightedIndex = 0
            }
            return
        }
        
        // Normal popup behavior - show suggestions with prefix matching
        guard prefix.count >= minCharsForSuggestions else {
            customMatches = []
            emojiMatches = []
            highlightedIndex = 0
            return
        }
        let fetchPrefix = prefix
        DispatchQueue.global(qos: .userInitiated).async {
            let customTags = CustomStorage.shared.collectTags(withPrefix: fetchPrefix, limit: 25)
            let emojiPairs = EmojiStorage.shared.collectPairs(withPrefix: fetchPrefix, limit: 25)
            
            let sortedCustom = customTags.sorted { tag1, tag2 in
                let exact1 = tag1.lowercased() == fetchPrefix
                let exact2 = tag2.lowercased() == fetchPrefix
                if exact1 && !exact2 { return true }
                if !exact1 && exact2 { return false }
                return tag1 < tag2 
            }
            
            let sortedEmoji = emojiPairs.map { EmojiMatch(tag: $0.tag, emoji: $0.emoji) }
                .sorted { match1, match2 in
                    let priority1 = self.getEmojiMatchPriority(for: match1, inputPrefix: fetchPrefix)
                    let priority2 = self.getEmojiMatchPriority(for: match2, inputPrefix: fetchPrefix)
                    
                    // Primary sort by priority (exact match > exact favorite > favorites > aliases > defaults)
                    if priority1 != priority2 {
                        return priority1 < priority2
                    }
                    
                    // Secondary sort alphabetically within same priority
                    return match1.tag < match2.tag
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

        // Check for exact matches in custom first
        if let exactCustomIndex = customMatches.firstIndex(where: { $0.lowercased() == lowercaseInput }) {
            print("🔍 DEBUG: Found exact custom match '\(customMatches[exactCustomIndex])' at index \(exactCustomIndex)")
            return exactCustomIndex
        }

        // Then check for exact matches in emoji
        if let exactEmojiIndex = emojiMatches.firstIndex(where: { $0.tag.lowercased() == lowercaseInput }) {
            let adjustedIndex = customMatches.count + exactEmojiIndex
            print("🔍 DEBUG: Found exact emoji match '\(emojiMatches[exactEmojiIndex].tag)' at adjusted index \(adjustedIndex)")
            return adjustedIndex
        }

        // No exact match, highlight first item
        print("🔍 DEBUG: No exact match found, highlighting first item (index 0)")
        return 0
    }
    
    func selectHighlightedItem() {
        // First try to select from popup suggestions
        if !customMatches.isEmpty && highlightedIndex < customMatches.count {
            let tag = customMatches[highlightedIndex]
            performCustomSelection(tag: tag)
            print("🔍 DEBUG: Selected highlighted custom item: \(tag) at index \(highlightedIndex)")
        } else if !emojiMatches.isEmpty {
            let adjustedIndex = highlightedIndex - customMatches.count
            if adjustedIndex >= 0 && adjustedIndex < emojiMatches.count {
                let pair = emojiMatches[adjustedIndex]
                performEmojiSelection(tag: pair.tag, emoji: pair.emoji)
                print("🔍 DEBUG: Selected highlighted emoji item: \(pair.tag) at adjusted index \(adjustedIndex)")
            }
        } else {
            // No popup matches - try exact match replacement
            performExactMatchReplacement()
        }
    }
    
    private func performExactMatchReplacement() {
        let currentText = KeyDetection.shared.currentString.lowercased()
        guard !currentText.isEmpty else { 
            KeyDetection.shared.finishCapture(triggerKeyConsumed: true)
            return 
        }
        
        // Try custom mapping first
        if let customText = CustomStorage.shared.getText(forTag: currentText) {
            performCustomSelection(tag: currentText)
            print("🔍 DEBUG: Exact match custom replacement: \(currentText) -> \(customText)")
            return
        }
        
        // Try emoji mapping
        if let emoji = EmojiStorage.shared.findEmoji(forTag: currentText) {
            performEmojiSelection(tag: currentText, emoji: emoji)
            print("🔍 DEBUG: Exact match emoji replacement: \(currentText) -> \(emoji)")
            return
        }
        
        // No match found - still use finishCapture to get proper logging and state cleanup
        print("🔍 DEBUG: No exact match found for: \(currentText), calling finishCapture")
        KeyDetection.shared.finishCapture(triggerKeyConsumed: true)
    }
    
    func isFavorite(emoji: String) -> Bool {
        return favoriteEmojis.contains(emoji)
    }
    
    private func getEmojiMatchPriority(for match: EmojiMatch, inputPrefix: String) -> EmojiMatchPriority {
        let isExactMatch = match.tag.lowercased() == inputPrefix.lowercased()
        let isFav = favoriteEmojis.contains(match.emoji)
        let isDefaultTag = EmojiStorage.shared.getDefaultTag(forEmoji: match.emoji)?.lowercased() == match.tag.lowercased()
        
        if isExactMatch {
            return isFav ? .exactFavorite : .exactMatch
        } else if isFav {
            // For prefix matches, favorites come before non-favorites regardless of alias vs default
            return .favorite
        } else if isDefaultTag {
            return .defaultTag
        } else {
            // It's an alias
            return .alias
        }
    }
    
    var shouldShowSuggestions: Bool {
        guard fujiMojiState?.showSuggestionPopup != false else { return false }
        return KeyDetection.shared.currentString.count >= minCharsForSuggestions
    }
    
    // MARK: - Navigation Methods
    func navigateLeft() {
        let totalItems = customMatches.count + emojiMatches.count
        guard totalItems > 0 else { return }
        
        let oldIndex = highlightedIndex
        // Non-circular: stop at beginning
        if highlightedIndex > 0 {
            highlightedIndex -= 1
            print("🔍 DEBUG: Navigation left: \(oldIndex) -> \(highlightedIndex)")
        } else {
            print("🔍 DEBUG: Already at beginning, cannot navigate left")
        }
    }
    
    func navigateRight() {
        let totalItems = customMatches.count + emojiMatches.count
        guard totalItems > 0 else { return }
        
        let oldIndex = highlightedIndex
        // Non-circular: stop at end
        if highlightedIndex < totalItems - 1 {
            highlightedIndex += 1
            print("🔍 DEBUG: Navigation right: \(oldIndex) -> \(highlightedIndex)")
        } else {
            print("🔍 DEBUG: Already at end, cannot navigate right")
        }
    }
    
    func navigateUp() {
        let totalItems = customMatches.count + emojiMatches.count
        guard totalItems > 0 else { return }
        
        let oldIndex = highlightedIndex
        
        // If currently in Emoji list (index >= customMatches.count), move to first Custom item
        if highlightedIndex >= customMatches.count && !customMatches.isEmpty {
            highlightedIndex = 0 // First custom item
            print("🔍 DEBUG: Navigation up: \(oldIndex) -> \(highlightedIndex) (Emoji -> Custom)")
        } else {
            print("🔍 DEBUG: Cannot navigate up - already in Custom list or Custom list is empty")
        }
    }
    
    func navigateDown() {
        let totalItems = customMatches.count + emojiMatches.count
        guard totalItems > 0 else { return }
        
        let oldIndex = highlightedIndex
        
        // If currently in Custom list (index < customMatches.count), move to first Emoji item
        if highlightedIndex < customMatches.count && !emojiMatches.isEmpty {
            highlightedIndex = customMatches.count // First emoji item
            print("🔍 DEBUG: Navigation down: \(oldIndex) -> \(highlightedIndex) (Custom -> Emoji)")
        } else {
            print("🔍 DEBUG: Cannot navigate down - already in Emoji list or Emoji list is empty")
        }
    }
}
