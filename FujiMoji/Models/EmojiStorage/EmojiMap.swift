import Foundation

struct EmojiTags: Codable {
    var emoji: String
    var defaultTag: String
    var aliases: [String]
    
    init(emoji: String, defaultTag: String, aliases: [String] = []) {
        self.emoji = emoji
        self.defaultTag = defaultTag.lowercased()
        self.aliases = aliases.map { $0.lowercased() }
    }
}

class EmojiMap {
    private var storage: [String: EmojiTags] = [:]
    private var templateStorage: [String: EmojiTags] = [:] // Keep template separate
    private let templateURL: URL?
    private let userDataURL: URL
    
    init(templateURL: URL?, userDataURL: URL) {
        self.templateURL = templateURL
        self.userDataURL = userDataURL
        
        // Load template first
        if let templateURL = templateURL {
            loadTemplate(from: templateURL)
        }
        
        // Then overlay user modifications
        loadUserData()
        
        // If both are empty, use hardcoded defaults
        if storage.isEmpty {
            setupDefaultMappings()
        }
    }
    
    // MARK: - Storage Operations
    
    private func loadTemplate(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            // Define a local struct to match the JSON structure
            struct EmojiTagData: Codable {
                let defaultTag: String
                let aliases: [String]
            }
            
            let defaultTagMap = try decoder.decode([String: EmojiTagData].self, from: data)
            
            // Convert the JSON structure into EmojiTags objects
            templateStorage = defaultTagMap.reduce(into: [:]) { result, pair in
                let (emoji, tagData) = pair
                result[emoji] = EmojiTags(
                    emoji: emoji,
                    defaultTag: tagData.defaultTag,
                    aliases: tagData.aliases
                )
            }
            
            // Copy template to storage if no user data exists
            if storage.isEmpty {
                storage = templateStorage
            }
            
            print("Loaded \(templateStorage.count) emoji mappings from template")
        } catch {
            print("Error loading template: \(error)")
        }
    }
    
    private func loadUserData() {
        if !FileManager.default.fileExists(atPath: userDataURL.path) {
            print("No user modifications found (first run) - using template data")
            if storage.isEmpty {
                storage = templateStorage
            }
            return
        }
        
        do {
            let data = try Data(contentsOf: userDataURL)
            let mappings = try JSONDecoder().decode([EmojiTags].self, from: data)
            
            // Convert array to dictionary
            storage = mappings.reduce(into: [:]) { result, mapping in
                result[mapping.emoji] = mapping
            }
            
            print("Loaded \(storage.count) emoji mappings from user data")
        } catch {
            print("Error loading user data: \(error)")
            // If error loading user data, use template data
            if storage.isEmpty {
                storage = templateStorage
            }
        }
    }
    
    // MARK: - Public Interface
    
    func getDefaultTag(forEmoji emoji: String) -> String? {
        return storage[emoji]?.defaultTag
    }
    
    func getAliases(forEmoji emoji: String) -> [String] {
        return storage[emoji]?.aliases ?? []
    }
    
    func setAliases(_ aliases: [String], forEmoji emoji: String) {
        if var emojiTags = storage[emoji] {
            emojiTags.aliases = aliases.map { $0.lowercased() }
            storage[emoji] = emojiTags
        }
    }
    
    func getAllEmojisWithTags() -> [EmojiTags] {
        return Array(storage.values)
    }
    
    func getAllMappings() -> [(tag: String, emoji: String)] {
        var mappings: [(tag: String, emoji: String)] = []
        for (emoji, emojiTags) in storage {
            mappings.append((tag: emojiTags.defaultTag, emoji: emoji))
            for alias in emojiTags.aliases {
                mappings.append((tag: alias, emoji: emoji))
            }
        }
        return mappings
    }
    
    // MARK: - Template Management
    
    func resetToTemplate() {
        storage = templateStorage
    }
    
    // MARK: - Default Mappings (Fallback)
    
    private func setupDefaultMappings() {
        print("Setting up hardcoded default mappings...")
        
        let defaults: [(emoji: String, defaultTag: String, aliases: [String])] = [

        ]
        
        for mapping in defaults {
            storage[mapping.emoji] = EmojiTags(
                emoji: mapping.emoji,
                defaultTag: mapping.defaultTag,
                aliases: mapping.aliases
            )
        }
        
        // Also save as template
        templateStorage = storage
        
        print("Added \(defaults.count) default emoji mappings")
    }
} 
