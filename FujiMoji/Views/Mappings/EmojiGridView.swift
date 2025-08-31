//
//  EmojiGridView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-25.
//

import SwiftUI

struct EmojiCell: View {
    let emoji: String
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    @ObservedObject private var fujiMojiState = FujiMojiState.shared
    
    var body: some View {
        VStack(alignment: .center) {
            Text(fujiMojiState.applySkinTone(emoji))
                .font(.system(size: 36))
        }
        .frame(width: 48, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isSelected ? 0.22 : (isHovered ? 0.12 : 0)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct EmojiGridView: View {
    let emojis: [String]
    @Binding var selectedEmoji: String?
    let columns = Array(repeating: GridItem(.fixed(40), spacing: 12), count: 7)
    @ObservedObject private var fujiMojiState = FujiMojiState.shared
    
    var body: some View {
        VStack(alignment: .center) {
            if emojis.isEmpty {
                Text("No Favourite Emojis Yet!")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.top, 200)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(emojis, id: \.self) { emoji in
                        EmojiCell(
                            emoji: fujiMojiState.applySkinTone(emoji),
                            isSelected: selectedEmoji == emoji,
                            onSelect: { selectedEmoji = emoji }
                        )
                    }
                }
            }
        }
        .frame(alignment: .center)
        .padding(.leading, 16)
    }
}
