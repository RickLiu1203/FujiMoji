import SwiftUI

struct EmojiCell: View {
    let emoji: String
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .center) {
            Text(emoji)
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
    let columns = Array(repeating: GridItem(.fixed(40), spacing: 10), count: 7)
    
    var body: some View {
        VStack(alignment: .center) {
            if emojis.isEmpty {
                Spacer()
                Text("No Emojis Yet!")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(emojis, id: \.self) { emoji in
                        EmojiCell(
                            emoji: emoji,
                            isSelected: selectedEmoji == emoji,
                            onSelect: { selectedEmoji = emoji }
                        )
                    }
                }
            }
        }
        .frame(width: 380, height: emojis.isEmpty ? 450 : nil, alignment: .center)
        .padding(.leading, 16)
    }
}
