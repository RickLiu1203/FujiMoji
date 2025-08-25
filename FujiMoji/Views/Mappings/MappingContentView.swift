//
//  MappingContentView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-20.
//

import SwiftUI

struct MappingContentView: View {
    @State private var selection: MappingSidebarItem? = .emojiCategory(.smileysPeople)
    @State private var allEmojis: [String] = []
    var body: some View {
        HStack {
            SideBarView(selection: $selection)
            ScrollView {
                EmojiGridView(emojis: allEmojis)
            }
            .padding(.top, 2)
            .padding(.bottom, 16)
        }
        .frame(width: 500, height: 500)
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

private func categoryTitle(for selection: MappingSidebarItem?) -> String {
    if case let .emojiCategory(category) = selection {
        return category.title
    }
    return EmojiCategory.smileysPeople.title
}
