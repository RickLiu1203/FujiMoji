//
//  MappingContentView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-20.
//

import SwiftUI
import AppKit
import QuartzCore

struct MappingContentView: View {
    @State private var selection: MappingSidebarItem? = .emojiCategory(.smileysPeople)
    @State private var allEmojis: [String] = []
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
                EmojiGridView(emojis: allEmojis)
                    .background(EnclosingScrollViewFinder { sv in
                        nsScrollView = sv
                    })
            }
            .padding(.top, topPadding)
            .padding(.bottom, 16)
            .onChange(of: selection) { oldValue, newValue in
                guard case let .emojiCategory(category) = newValue else { return }
                guard let row = categoryRowAnchors[category] else { return }
                scrollToRow(row)
            }
        }
        .frame(width: 600, height: 500)
        .background(.ultraThinMaterial)
        .onAppear {
            loadFromEmojiArray()
        }

    }

    private func loadFromEmojiArray() {
        if let url = Bundle.main.url(forResource: "emoji_array", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            allEmojis = arr
        } else {
            let all = EmojiStorage.shared.getAllEmojisWithTags()
            allEmojis = all.map { $0.emoji }
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
