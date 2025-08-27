import Foundation
import SwiftUI

final class MappingsViewModel: ObservableObject {
    @Published var allEmojis: [String] = []
    @Published var selectedEmoji: String?
    @Published var selectedDetail: EmojiDetail?
    @Published var favoriteEmojis: Set<String> = []
    @Published var selection: MappingSidebarItem? = .emojiCategory(.smileysPeople)

    private var defaultMap: [String: DefaultEmojiRecord] = [:]

    init() {
        loadFromEmojiArray()
        loadDefaultMap()
        loadFavorites()
        updateSelectedDetail()
    }

    // MARK: - Derived
    var currentEmojis: [String] {
        if case .favorites? = selection {
            return allEmojis.filter { favoriteEmojis.contains($0) }
        }
        return allEmojis
    }

    // MARK: - Public actions
    func setAliases(_ aliases: [String], for emoji: String) {
        EmojiStorage.shared.setAliases(aliases, forEmoji: emoji)
        if emoji == selectedEmoji { updateSelectedDetail() }
    }

    func toggleFavorite(_ emoji: String, isOn: Bool) {
        if isOn { favoriteEmojis.insert(emoji) } else { favoriteEmojis.remove(emoji) }
        saveFavorites()
        objectWillChange.send()
    }

    func didSelectEmoji(_ emoji: String) {
        selectedEmoji = emoji
        updateSelectedDetail()
    }

    // MARK: - Loading
    private func loadFromEmojiArray() {
        if let url = Bundle.main.url(forResource: "emoji_array", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            allEmojis = arr
            if selectedEmoji == nil { selectedEmoji = allEmojis.first }
        } else {
            let all = EmojiStorage.shared.getAllEmojisWithTags()
            allEmojis = all.map { $0.emoji }
            if selectedEmoji == nil { selectedEmoji = allEmojis.first }
        }
    }

    private struct DefaultEmojiRecord: Decodable {
        let id: Int?
        let defaultTag: String
        let unicode: String?
        let aliases: [String]
        enum CodingKeys: String, CodingKey { case id; case defaultTag = "default_tag"; case unicode; case aliases }
    }

    private func loadDefaultMap() {
        if let url = Bundle.main.url(forResource: "default", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let map = try? JSONDecoder().decode([String: DefaultEmojiRecord].self, from: data) {
            defaultMap = map
        }
    }

    private func updateSelectedDetail() {
        guard let symbol = selectedEmoji else { selectedDetail = nil; return }
        let record = defaultMap[symbol]
        let tag = EmojiStorage.shared.getDefaultTag(forEmoji: symbol) ?? record?.defaultTag ?? ""
        let aliases = EmojiStorage.shared.getAliases(forEmoji: symbol)
        let unicode = record?.unicode
        let idVal = record?.id
        selectedDetail = EmojiDetail(id: idVal, emoji: symbol, defaultTag: tag, unicode: unicode, aliases: aliases)
    }

    private func loadFavorites() {
        if let saved = UserDefaults.standard.array(forKey: "favoriteEmojis") as? [String] {
            favoriteEmojis = Set(saved)
        }
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteEmojis), forKey: "favoriteEmojis")
    }
}

final class CustomMappingsViewModel: ObservableObject {
    @Published var items: [(tag: String, text: String)] = []
    @Published var selectedTag: String? = nil

    init() {
        reload()
    }

    func reload() {
        items = CustomStorage.shared.getAllSorted()
        if selectedTag == nil { selectedTag = items.first?.tag }
    }

    func addNew() {
        let base = "new_tag"
        var candidate = base
        var index = 1
        while CustomStorage.shared.getText(forTag: candidate) != nil {
            index += 1
            candidate = "\(base)_\(index)"
        }
        CustomStorage.shared.set(text: "custom string", forTag: candidate)
        // Prepend new item to the top without re-sorting
        let newItem = (tag: candidate, text: "custom string")
        // Remove any existing instance of the same tag just in case
        items.removeAll { $0.tag.lowercased() == candidate.lowercased() }
        items.insert(newItem, at: 0)
        selectedTag = candidate
    }

    func update(tag: String, text: String) {
        CustomStorage.shared.set(text: text, forTag: tag)
        reload()
        selectedTag = tag
    }

    func rename(oldTag: String, newTag: String, text: String) {
        if oldTag.lowercased() != newTag.lowercased() {
            CustomStorage.shared.remove(tag: oldTag)
        }
        CustomStorage.shared.set(text: text, forTag: newTag)
        reload()
        selectedTag = newTag
    }

    func delete(tag: String) {
        CustomStorage.shared.remove(tag: tag)
        items.removeAll { $0.tag.lowercased() == tag.lowercased() }
        if selectedTag?.lowercased() == tag.lowercased() {
            selectedTag = items.first?.tag
        }
        objectWillChange.send()
    }
}

