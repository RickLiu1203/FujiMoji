import SwiftUI

struct EmojiCell: View {
    let emoji: String
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .center) {
            Text(emoji)
                .font(.system(size: 32))
        }
        .frame(width: 36, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isHovered ? 0.12 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

struct EmojiGridView: View {
    let emojis: [String]
    let columns = Array(repeating: GridItem(.fixed(36), spacing: 8), count: 6)
    
    var body: some View {
        HStack {
            LazyVGrid(columns: columns, spacing: 8) {
            ForEach(emojis, id: \.self) { emoji in
                EmojiCell(emoji: emoji)
                }
            }
            Spacer()
        }
        .frame(width: 300)
    }
}
