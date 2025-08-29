import Foundation

class EmojiStorage {
    static let shared = EmojiStorage()
    
    private let fileManager = FileManager.default
    private let emojiMap: EmojiMap
    private let searchTrie = EmojiTrie()
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var userMappingsURL: URL {
        documentsDirectory.appendingPathComponent("user_emoji_mappings.json")
    }
    
    private init() {
        let templateURL = Bundle.main.url(forResource: "default", withExtension: "json")
        // Compute the path locally to avoid accessing self before initialization
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let userURL = docs.appendingPathComponent("user_emoji_mappings.json")
        do {
            try FileManager.default.createDirectory(at: userURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
        } catch {
            print("Error ensuring documents directory exists: \(error)")
        }
        emojiMap = EmojiMap(templateURL: templateURL,
                           userDataURL: userURL)
        rebuildTrie()
    }
    
    private func rebuildTrie() {
        searchTrie.rebuild(from: emojiMap.getAllMappings())
    }
    
    private func saveUserMappings() {
        do {
            let mappings = emojiMap.getAllEmojisWithTags()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(mappings)
            
            try fileManager.createDirectory(at: userMappingsURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
            
            try data.write(to: userMappingsURL)
            print("Successfully saved \(mappings.count) emoji mappings to user data")
        } catch {
            print("Error saving user mappings: \(error)")
        }
    }
    
    func resetToDefaults() {
        do {
            if fileManager.fileExists(atPath: userMappingsURL.path) {
                try fileManager.removeItem(at: userMappingsURL)
                print("Removed user modifications file")
            }
            emojiMap.resetToTemplate()
            rebuildTrie()
            print("Reset to template mappings")
        } catch {
            print("Error resetting to defaults: \(error)")
        }
    }
    
    func findEmoji(forTag tag: String) -> String? {
        return searchTrie.find(tag: tag)
    }
    
    func getDefaultTag(forEmoji emoji: String) -> String? {
        return emojiMap.getDefaultTag(forEmoji: emoji)
    }
    
    func getAliases(forEmoji emoji: String) -> [String] {
        return emojiMap.getAliases(forEmoji: emoji)
    }
    
    func setAliases(_ aliases: [String], forEmoji emoji: String) {
        emojiMap.setAliases(aliases, forEmoji: emoji)
        rebuildTrie()
        saveUserMappings()
    }
    
    func getAllEmojisWithTags() -> [EmojiTags] {
        return emojiMap.getAllEmojisWithTags()
    }
    
    func exportUserMappings() -> URL? {
        return userMappingsURL
    }
    
    func importUserMappings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let mappings = try decoder.decode([EmojiTags].self, from: data)
        
        emojiMap.resetToTemplate()
        
        for mapping in mappings {
            emojiMap.setAliases(mapping.aliases, forEmoji: mapping.emoji)
        }
        
        rebuildTrie()
        saveUserMappings()
    }
    
    // MARK: - Prefix search facade
    func collectTags(withPrefix prefix: String, limit: Int = 25) -> [String] {
        return searchTrie.collectTags(withPrefix: prefix, limit: limit)
    }

    func collectPairs(withPrefix prefix: String, limit: Int = 25) -> [(tag: String, emoji: String)] {
        return searchTrie.collectPairs(withPrefix: prefix, limit: limit)
    }
} 