//
//  MappingsViewModel.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-20.
//


import Foundation
import SwiftUI
import AppKit

final class MappingsViewModel: ObservableObject {
    @Published var allEmojis: [String] = []
    @Published var selectedEmoji: String? {
        didSet {
            if oldValue != selectedEmoji {
                updateSelectedDetail()
            }
        }
    }
    @Published var selectedDetail: EmojiDetail?
    @Published var favoriteEmojis: Set<String> = []
    @Published var selection: MappingSidebarItem? = .emojiCategory(.smileysPeople)

    private var defaultMap: [String: DefaultEmojiRecord] = [:]
    private func canonical(_ s: String) -> String {
        let filtered = s.unicodeScalars.filter { scalar in
            scalar.value != 0xFE0F && scalar.value != 0xFE0E
        }
        return String(String.UnicodeScalarView(filtered))
    }

    init(initialSelection: MappingSidebarItem? = .emojiCategory(.smileysPeople)) {
        self.selection = initialSelection
        loadFromEmojiArray()
        loadDefaultMap()
        loadFavorites()
        updateSelectedDetail()
    }

    var currentEmojis: [String] {
        if case .favorites? = selection {
            return allEmojis.filter { isFavoriteEmoji($0) }
        }
        return allEmojis
    }

    // MARK: - Public actions
    func setAliases(_ aliases: [String], for emoji: String) {
        EmojiStorage.shared.setAliases(aliases, forEmoji: emoji)
        if emoji == selectedEmoji {
            DispatchQueue.main.async { [weak self] in
                self?.updateSelectedDetail()
            }
        }
    }

    func toggleFavorite(_ emoji: String, isOn: Bool) {
        let key = canonical(emoji)
        if isOn { favoriteEmojis.insert(key) } else { favoriteEmojis.remove(key) }
        saveFavorites()
    }

    func didSelectEmoji(_ emoji: String) {
        if selectedEmoji != emoji {
            selectedEmoji = emoji
        }
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
            favoriteEmojis = Set(saved.map { canonical($0) })
        }
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteEmojis), forKey: "favoriteEmojis")
    }

    func isFavoriteEmoji(_ emoji: String) -> Bool {
        return favoriteEmojis.contains(canonical(emoji))
    }
}

final class CustomMappingsViewModel: ObservableObject {
    @Published var items: [(tag: String, text: String)] = []
    @Published var selectedTag: String? = nil
    @Published var favoriteTags: Set<String> = []
    private var lastAddedTag: String? = nil

    init() {
        reload()
        loadFavorites()
    }

    func reload() {
        items = CustomStorage.shared.getAllNewestFirst()
        if selectedTag == nil { selectedTag = items.first?.tag }
    }

    // MARK: - Favorites
    func loadFavorites() {
        if let saved = UserDefaults.standard.array(forKey: "favoriteCustomTags") as? [String] {
            favoriteTags = Set(saved.map { $0.lowercased() })
        }
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteTags), forKey: "favoriteCustomTags")
    }

    func toggleFavorite(tag: String) {
        let key = tag.lowercased()
        if favoriteTags.contains(key) {
            favoriteTags.remove(key)
        } else {
            favoriteTags.insert(key)
        }
        saveFavorites()
    }


    func addNew() {
        let base = "new_tag"
        var candidate = base
        var index = 1
        while CustomStorage.shared.getText(forTag: candidate) != nil {
            index += 1
            candidate = "\(base)_\(index)"
        }
        CustomStorage.shared.set(text: "custom text", forTag: candidate)
        let newItem = (tag: candidate, text: "custom text")
        items.removeAll { $0.tag.lowercased() == candidate.lowercased() }
        items.insert(newItem, at: 0)
        selectedTag = candidate
    }

    func update(tag: String, text: String) {
        CustomStorage.shared.set(text: text, forTag: tag)
        items.removeAll { $0.tag.lowercased() == tag.lowercased() }
        items.insert((tag: tag, text: text), at: 0)
        selectedTag = tag
    }

    func rename(oldTag: String, newTag: String, text: String) {
        if oldTag.lowercased() != newTag.lowercased() {
            CustomStorage.shared.remove(tag: oldTag)
        }
        CustomStorage.shared.set(text: text, forTag: newTag)
        items.removeAll { $0.tag.lowercased() == oldTag.lowercased() }
        items.removeAll { $0.tag.lowercased() == newTag.lowercased() }
        items.insert((tag: newTag, text: text), at: 0)
        selectedTag = newTag
        let oldKey = oldTag.lowercased()
        let newKey = newTag.lowercased()
        if favoriteTags.contains(oldKey) {
            favoriteTags.remove(oldKey)
            favoriteTags.insert(newKey)
            UserDefaults.standard.set(Array(favoriteTags), forKey: "favoriteCustomTags")
        }
    }

    func delete(tag: String) {
        CustomStorage.shared.remove(tag: tag)
        items.removeAll { $0.tag.lowercased() == tag.lowercased() }
        if selectedTag?.lowercased() == tag.lowercased() {
            selectedTag = items.first?.tag
        }
        objectWillChange.send()
        let key = tag.lowercased()
        if favoriteTags.contains(key) {
            favoriteTags.remove(key)
            UserDefaults.standard.set(Array(favoriteTags), forKey: "favoriteCustomTags")
        }
    }
}

// MARK: - Shared Mappings Window Coordinator (singleton)
final class MappingsWindowCoordinator: NSWindowController {
    static let shared = MappingsWindowCoordinator()

    private var hostingController: NSHostingController<MappingContentView>?
    private var mappingsViewModel: MappingsViewModel?

    private override init(window: NSWindow?) {
        super.init(window: window)
    }

    convenience init() {
        self.init(window: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(initialSelection: MappingSidebarItem) {
        if window == nil {
            setupWindow(initialSelection: initialSelection)
        } else {
            if mappingsViewModel == nil {
                mappingsViewModel = MappingsViewModel(initialSelection: initialSelection)
            }
            DispatchQueue.main.async { [weak self] in
                self?.mappingsViewModel?.selection = initialSelection
            }
        }

        guard let window = self.window else { return }
        centerOnActiveScreen(window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func setupWindow(initialSelection: MappingSidebarItem) {
        let viewModel = MappingsViewModel(initialSelection: initialSelection)
        self.mappingsViewModel = viewModel

        let contentView = MappingContentView(mappingViewModel: viewModel)
        let hosting = NSHostingController(rootView: contentView)
        self.hostingController = hosting

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 500),
            styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isMovable = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]

        self.window = window
    }

    private func centerOnActiveScreen(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let targetScreen = screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? window.screen ?? NSScreen.main
        if let screen = targetScreen {
            let size = window.frame.size
            let visible = screen.visibleFrame
            let newX = visible.origin.x + (visible.size.width - size.width) / 2
            let newY = visible.origin.y + (visible.size.height - size.height) / 2
            window.setFrameOrigin(NSPoint(x: newX, y: newY))
        } else {
            window.center()
        }
    }
}


