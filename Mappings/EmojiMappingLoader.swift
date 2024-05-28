import Foundation

func EmojiMappingLoading() -> [Emoji] {
    guard let url = Bundle.main.url(forResource: "emojiMappings", withExtension: "json") else {
        fatalError("Failed to locate emojiMappings.json in bundle.")
    }
    
    guard let data = try? Data(contentsOf: url) else {
        fatalError("Failed to load emojiMappings.json from bundle.")
    }
    
    let decoder = JSONDecoder()
    guard let emojiMappings = try? decoder.decode([String: String].self, from: data) else {
        fatalError("Failed to decode emojiMappings.json from bundle.")
    }
    
    return emojiMappings.map { Emoji(name: $0.key, symbol: $0.value) }
}
