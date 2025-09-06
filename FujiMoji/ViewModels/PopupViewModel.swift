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
    
    private var favoriteEmojis: Set<String> = []
    private var favoriteCustomTags: Set<String> = []
    
    weak var fujiMojiState: FujiMojiState?
    
    init(fujiMojiState: FujiMojiState? = nil) {
        self.fujiMojiState = fujiMojiState
        loadFavorites()
        setupObservers()
    }

    private func canonicalEmoji(_ emoji: String) -> String {
        let filtered = emoji.unicodeScalars.filter { scalar in
            scalar.value != 0xFE0F && scalar.value != 0xFE0E
        }
        return String(String.UnicodeScalarView(filtered))
    }
    
    private func setupObservers() {
        KeyDetection.shared.$currentString
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.updateMatches(for: newValue)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .navigateLeft)
            .sink { [weak self] _ in
                self?.navigateLeft()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .navigateRight)
            .sink { [weak self] _ in
                self?.navigateRight()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .navigateUp)
            .sink { [weak self] _ in
                self?.navigateUp()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .navigateDown)
            .sink { [weak self] _ in
                self?.navigateDown()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.loadFavorites()
            }
            .store(in: &cancellables)
    }
    
    private func loadFavorites() {
        if let saved = UserDefaults.standard.array(forKey: "favoriteEmojis") as? [String] {
            favoriteEmojis = Set(saved.map { canonicalEmoji($0) })
        } else {
            favoriteEmojis = []
        }

        let customTagsLower: Set<String>
        if let savedTags = UserDefaults.standard.array(forKey: "favoriteCustomTags") as? [String] {
            customTagsLower = Set(savedTags.map { $0.lowercased() })
        } else {
            customTagsLower = []
        }

        let imageTagsLower: Set<String>
        if let savedImageTags = UserDefaults.standard.array(forKey: "favoriteImageTags") as? [String] {
            imageTagsLower = Set(savedImageTags.map { $0.lowercased() })
        } else {
            imageTagsLower = []
        }

        favoriteCustomTags = customTagsLower.union(imageTagsLower)
    }
    
    func updateMatches(for current: String) {
        let prefix = current.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard fujiMojiState?.showSuggestionPopup != false else {
            let hasExactCustom = CustomStorage.shared.getText(forTag: prefix) != nil
            let hasExactEmoji = EmojiStorage.shared.findEmoji(forTag: prefix) != nil
            
            if hasExactCustom || hasExactEmoji {
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
        
        guard prefix.count >= minCharsForSuggestions else {
            customMatches = []
            emojiMatches = []
            highlightedIndex = 0
            return
        }
        let fetchPrefix = prefix
        struct Cache {
            static var lastPrefix: String = ""
            static var lastPairs: [(tag: String, emoji: String)] = []
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let customTags = CustomStorage.shared.collectTags(withPrefix: fetchPrefix, limit: 25)

            let baseLimit = 200
            var emojiPairs: [(tag: String, emoji: String)]

            emojiPairs = EmojiStorage.shared.collectPairs(withPrefix: fetchPrefix, limit: baseLimit)
            
            let sortedCustom = customTags.sorted { tag1, tag2 in
                let exact1 = tag1.lowercased() == fetchPrefix
                let exact2 = tag2.lowercased() == fetchPrefix
                if exact1 && !exact2 { return true }
                if !exact1 && exact2 { return false }
                let fav1 = self.favoriteCustomTags.contains(tag1.lowercased())
                let fav2 = self.favoriteCustomTags.contains(tag2.lowercased())
                if fav1 != fav2 { return fav1 }
                return tag1 < tag2 
            }
            
            var exact: [EmojiMatch] = []
            var favs: [EmojiMatch] = []
            var nonFavs: [EmojiMatch] = []
            for pair in emojiPairs {
                let match = EmojiMatch(tag: pair.tag, emoji: pair.emoji)
                if match.tag.lowercased() == fetchPrefix.lowercased() {
                    exact.append(match)
                } else if self.isFavorite(emoji: match.emoji) {
                    favs.append(match)
                } else {
                    nonFavs.append(match)
                }
            }
            let ranked = exact + favs + nonFavs
            var seenEmojis = Set<String>()
            let dedupedEmoji = ranked.filter { match in
                let key = self.canonicalEmoji(match.emoji)
                if seenEmojis.contains(key) { return false }
                seenEmojis.insert(key)
                return true
            }
            let limitedEmoji = Array(dedupedEmoji.prefix(25))
            
            DispatchQueue.main.async {
                if KeyDetection.shared.currentString.lowercased() == fetchPrefix {
                    self.customMatches = sortedCustom
                    self.emojiMatches = limitedEmoji
                    
                    self.highlightedIndex = self.findFirstExactMatchIndex(for: fetchPrefix)
                    Cache.lastPrefix = fetchPrefix
                    Cache.lastPairs = emojiPairs
                }
            }
        }
    }

    func performEmojiSelection(tag: String, emoji: String) {
        let currentPrefix = KeyDetection.shared.currentString.lowercased()
        if !currentPrefix.isEmpty {
            EmojiStorage.shared.recordKeywordUsage(prefix: currentPrefix, emoji: emoji)
        }
        let output = FujiMojiState.shared.applySkinTone(emoji)
        KeyDetection.shared.finishCaptureWithDirectReplacement(output, endWithSpace: false)
    }

    func performCustomSelection(tag: String) {
        let lower = tag.lowercased()
        if let text = CustomStorage.shared.getText(forTag: lower), !text.isEmpty {
            KeyDetection.shared.finishCaptureWithDirectReplacement(text, endWithSpace: false)
            return
        }
        if let _ = CustomStorage.shared.getImageURL(forTag: lower) {
            KeyDetection.shared.finishCaptureWithImageTag(lower)
            return
        }
    }
    
    func findFirstExactMatchIndex(for input: String) -> Int {
        let lowercaseInput = input.lowercased()

        if let exactCustomIndex = customMatches.firstIndex(where: { $0.lowercased() == lowercaseInput }) {
            return exactCustomIndex
        }

        if let exactEmojiIndex = emojiMatches.firstIndex(where: { $0.tag.lowercased() == lowercaseInput }) {
            let adjustedIndex = customMatches.count + exactEmojiIndex
            return adjustedIndex
        }

        return 0
    }
    
    func selectHighlightedItem() {
        if !customMatches.isEmpty && highlightedIndex < customMatches.count {
            let tag = customMatches[highlightedIndex]
            performCustomSelection(tag: tag)
        } else if !emojiMatches.isEmpty {
            let adjustedIndex = highlightedIndex - customMatches.count
            if adjustedIndex >= 0 && adjustedIndex < emojiMatches.count {
                let pair = emojiMatches[adjustedIndex]
                performEmojiSelection(tag: pair.tag, emoji: pair.emoji)
            }
        } else {
            performExactMatchReplacement()
        }
    }
    
    private func performExactMatchReplacement() {
        let currentText = KeyDetection.shared.currentString.lowercased()
        guard !currentText.isEmpty else { 
            KeyDetection.shared.finishCapture(triggerKeyConsumed: true)
            return 
        }
        
        if let _ = CustomStorage.shared.getText(forTag: currentText) {
            performCustomSelection(tag: currentText)
            return
        }
        
        if let emoji = EmojiStorage.shared.findEmoji(forTag: currentText) {
            performEmojiSelection(tag: currentText, emoji: emoji)
            return
        }
        
        KeyDetection.shared.finishCapture(triggerKeyConsumed: true)
    }
    
    func isFavorite(emoji: String) -> Bool {
        return favoriteEmojis.contains(canonicalEmoji(emoji))
    }
    func isFavoriteCustom(tag: String) -> Bool {
        return favoriteCustomTags.contains(tag.lowercased())
    }
    
    private func getEmojiMatchPriority(for match: EmojiMatch, inputPrefix: String) -> EmojiMatchPriority {
        let isExactMatch = match.tag.lowercased() == inputPrefix.lowercased()
        let isFav = favoriteEmojis.contains(canonicalEmoji(match.emoji))
        let isDefaultTag = EmojiStorage.shared.getDefaultTag(forEmoji: match.emoji)?.lowercased() == match.tag.lowercased()
        
        if isExactMatch {
            return isFav ? .exactFavorite : .exactMatch
        } else if isFav {
            return .favorite
        } else if isDefaultTag {
            return .defaultTag
        } else {
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
        
        if highlightedIndex > 0 {
            highlightedIndex -= 1
        }
    }
    
    func navigateRight() {
        let totalItems = customMatches.count + emojiMatches.count
        guard totalItems > 0 else { return }
        
        if highlightedIndex < totalItems - 1 {
            highlightedIndex += 1
        }
    }
    
    func navigateUp() {
        let totalItems = customMatches.count + emojiMatches.count
        guard totalItems > 0 else { return }
        

        if highlightedIndex >= customMatches.count && !customMatches.isEmpty {
            highlightedIndex = 0 
        }
    }
    
    func navigateDown() {
        let totalItems = customMatches.count + emojiMatches.count
        guard totalItems > 0 else { return }
        
        
        if highlightedIndex < customMatches.count && !emojiMatches.isEmpty {
            highlightedIndex = customMatches.count 
        }
    }
}
