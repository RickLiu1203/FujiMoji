//
//  MappingContentView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-20.
//

import SwiftUI
import AppKit
import QuartzCore

struct EmojiDetail: Identifiable {
    let id: Int?
    let emoji: String
    let defaultTag: String
    let unicode: String?
    let aliases: [String]
}

struct MappingContentView: View {
    @State private var selection: MappingSidebarItem? = .emojiCategory(.smileysPeople)
    @State private var allEmojis: [String] = []
    @State private var selectedEmoji: String?
    @State private var selectedDetail: EmojiDetail?
    @State private var defaultMap: [String: DefaultEmojiRecord] = [:]
    @State private var favoriteEmojis: Set<String> = []
    private let columnsCount = 6
    private let categoryRowAnchors: [EmojiCategory: Int] = [
        .smileysPeople: 0,
        .animalsNature: 1,
        .foodDrink: 126,
        .activity: 182,
        .travelPlaces: 142,
        .objects: 198,
        .symbols: 258,
        .flags: 300
    ]
    @State private var nsScrollView: NSScrollView?
    private let cellSize: CGFloat = 48
    private let rowSpacing: CGFloat = 8
    private let topPadding: CGFloat = 2
    var body: some View {
        HStack {
            SideBarView(selection: $selection)
            ScrollView(.vertical, showsIndicators: true) {
                EmojiGridView(emojis: currentEmojis, selectedEmoji: $selectedEmoji)
                    .background(EnclosingScrollViewFinder { sv in
                        nsScrollView = sv
                    })
            }
            .padding(.top, topPadding)
            .padding(.bottom, 20)
            .onChange(of: selection) { oldValue, newValue in
                guard case let .emojiCategory(category) = newValue else { return }
                guard let row = categoryRowAnchors[category] else { return }
                scrollToRow(row)
            }
            Divider()
            .padding(.bottom, 20)
            EmojiEditorView(
                selected: selectedDetail,
                isFavorite: selectedEmoji.map { favoriteEmojis.contains($0) } ?? false,
                onSaveAliases: { emoji, aliases in
                    EmojiStorage.shared.setAliases(aliases, forEmoji: emoji)
                    updateSelectedDetail()
                },
                onToggleFavorite: { emoji, newValue in
                    if newValue { favoriteEmojis.insert(emoji) } else { favoriteEmojis.remove(emoji) }
                    saveFavorites()
                }
            )
        }
        .frame(width: 920, height: 500)
        .background(.ultraThinMaterial)
        .onAppear {
            loadFromEmojiArray()
            loadDefaultMap()
            updateSelectedDetail()
            loadFavorites()
        }
        .onChange(of: selectedEmoji) { _, _ in
            updateSelectedDetail()
        }

    }

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
        enum CodingKeys: String, CodingKey {
            case id
            case defaultTag = "default_tag"
            case unicode
            case aliases
        }
    }

    private func loadDefaultMap() {
        if let url = Bundle.main.url(forResource: "default", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let map = try? JSONDecoder().decode([String: DefaultEmojiRecord].self, from: data) {
            defaultMap = map
        }
    }

    private func updateSelectedDetail() {
        guard let symbol = selectedEmoji else {
            selectedDetail = nil
            return
        }
        let record = defaultMap[symbol]
        let tag = EmojiStorage.shared.getDefaultTag(forEmoji: symbol) ?? record?.defaultTag ?? ""
        let aliases = EmojiStorage.shared.getAliases(forEmoji: symbol)
        let unicode = record?.unicode
        let idVal = record?.id
        selectedDetail = EmojiDetail(id: idVal, emoji: symbol, defaultTag: tag, unicode: unicode, aliases: aliases)
    }

    private var currentEmojis: [String] {
        if case .favorites? = selection {
            return allEmojis.filter { favoriteEmojis.contains($0) }
        }
        return allEmojis
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


private struct EnclosingScrollViewFinder: NSViewRepresentable {
    let onFound: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                onFound(scrollView)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = nsView.enclosingScrollView {
                onFound(scrollView)
            }
        }
    }
}

private extension MappingContentView {
    func scrollToRow(_ row: Int) {
        guard let scrollView = nsScrollView else { return }
        let perRow = cellSize + rowSpacing
        let y = max(0, CGFloat(row) * perRow - topPadding)
        let target = NSPoint(x: 0, y: y)
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.65
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                scrollView.contentView.animator().setBoundsOrigin(target)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }
}

private func categoryTitle(for selection: MappingSidebarItem?) -> String {
    if case let .emojiCategory(category) = selection {
        return category.title
    }
    return EmojiCategory.smileysPeople.title
}
