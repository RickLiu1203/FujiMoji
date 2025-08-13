import Foundation

class EmojiStorage {
    static let shared = EmojiStorage()
    
    private let fileManager = FileManager.default
    private let emojiMap: EmojiMap
    private let searchTrie = EmojiTrie()
    
    // File paths
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var userMappingsURL: URL {
        documentsDirectory.appendingPathComponent("user_mappings.json")
    }
    
    private init() {
        // Compute URLs first
        let userMappingsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("user_mappings.json")
        let templateURL = Bundle.main.url(forResource: "default", withExtension: "json")
        
        // Ensure documents directory exists
        do {
            try fileManager.createDirectory(at: userMappingsPath.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
        } catch {
            print("Error ensuring documents directory exists: \(error)")
        }
        
        // Initialize with merged data from template and user modifications
        emojiMap = EmojiMap(templateURL: templateURL,
                           userDataURL: userMappingsPath)
        rebuildTrie()
    }
    
    private func rebuildTrie() {
        searchTrie.rebuild(from: emojiMap.getAllMappings())
    }
    
    // MARK: - Data Management
    
    /// Save current state to user mappings file
    private func saveUserMappings() {
        do {
            let mappings = emojiMap.getAllEmojisWithTags()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(mappings)
            
            // Ensure parent directory exists
            try fileManager.createDirectory(at: userMappingsURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
            
            // Write the file
            try data.write(to: userMappingsURL)
            print("Successfully saved \(mappings.count) emoji mappings to user data")
        } catch {
            print("Error saving user mappings: \(error)")
        }
    }
    
    /// Reset to default template
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
    
    // MARK: - Public Interface
    
    func addTag(_ tag: String, forEmoji emoji: String) {
        if emojiMap.addTag(tag, forEmoji: emoji) {
            searchTrie.insert(tag: tag, emoji: emoji)
            saveUserMappings()
        }
    }
    
    func removeTag(_ tag: String, fromEmoji emoji: String) {
        if emojiMap.removeTag(tag, fromEmoji: emoji) {
            searchTrie.remove(tag: tag, emoji: emoji)
            saveUserMappings()
        }
    }
    
    func findEmoji(forTag tag: String) -> String? {
        return searchTrie.find(tag: tag)
    }
    
    func getTagsForEmoji(_ emoji: String) -> Set<String>? {
        return emojiMap.getTagsForEmoji(emoji)
    }
    
    func getAllEmojisWithTags() -> [EmojiTags] {
        return emojiMap.getAllEmojisWithTags()
    }
    
    // MARK: - Batch Operations
    
    func batchAddTags(_ updates: [(tag: String, emoji: String)]) {
        var didUpdate = false
        for (tag, emoji) in updates {
            if emojiMap.addTag(tag, forEmoji: emoji) {
                searchTrie.insert(tag: tag, emoji: emoji)
                didUpdate = true
            }
        }
        if didUpdate {
            saveUserMappings()
        }
    }
    
    // MARK: - Import/Export
    
    func exportUserMappings() -> URL? {
        return userMappingsURL
    }
    
    func importUserMappings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let mappings = try decoder.decode([EmojiTags].self, from: data)
        
        // Clear existing mappings
        emojiMap.clear()
        
        // Add imported mappings
        for mapping in mappings {
            for tag in mapping.tags {
                emojiMap.addTag(tag, forEmoji: mapping.emoji)
            }
        }
        
        // Rebuild trie and save
        rebuildTrie()
        saveUserMappings()
    }
} 