import SwiftUI

struct EmojiMappingView: View {
    let emojis: [Emoji] = loadEmojiMappings()
    
    var body: some View {
        NavigationView {
            List(emojis) { emoji in
                HStack {
                    Text(emoji.symbol)
                        .font(.largeTitle)
                    Text(emoji.name)
                        .font(.headline)
                }
                .padding()
            }
            .navigationTitle("Emoji Mapping")
        }
    }
}

struct EmojiMappingView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiMappingView()
    }
}
