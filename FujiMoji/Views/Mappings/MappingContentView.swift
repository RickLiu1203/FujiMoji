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
    @StateObject private var mappingViewModel = MappingsViewModel()
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
            SideBarView(selection: $mappingViewModel.selection)
            ScrollView(.vertical, showsIndicators: true) {
                EmojiGridView(emojis: mappingViewModel.currentEmojis, selectedEmoji: $mappingViewModel.selectedEmoji)
                    .background(EnclosingScrollViewFinder { sv in
                        nsScrollView = sv
                    })
            }
            .padding(.top, topPadding)
            .padding(.bottom, 20)
            .padding(.trailing, mappingViewModel.currentEmojis.count < 56 ? 15 : 0)
            Divider()
            .padding(.bottom, 20)
            EmojiEditorView(
                selected: mappingViewModel.selectedDetail,
                isFavorite: mappingViewModel.selectedEmoji.map { mappingViewModel.favoriteEmojis.contains($0) } ?? false,
                onSaveAliases: { emoji, aliases in mappingViewModel.setAliases(aliases, for: emoji) },
                onToggleFavorite: { emoji, newValue in mappingViewModel.toggleFavorite(emoji, isOn: newValue) }
            )
        }
        .frame(width: 920, height: 500)
        .background(.ultraThinMaterial)
        .onChange(of: mappingViewModel.selection) { newValue in
            if case let .emojiCategory(category) = newValue, let row = categoryRowAnchors[category] {
                scrollToRow(row)
            }
        }
        .onChange(of: mappingViewModel.selectedEmoji) { newEmoji in
            if let symbol = newEmoji {
                mappingViewModel.didSelectEmoji(symbol)
            }
        }

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
