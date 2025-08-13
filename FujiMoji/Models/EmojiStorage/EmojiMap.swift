import Foundation

struct EmojiTags: Codable {
    var emoji: String
    var tags: Set<String>
    
    init(emoji: String, tags: Set<String>) {
        self.emoji = emoji
        self.tags = tags
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
            let defaultTagMap = try JSONDecoder().decode([String: [String]].self, from: data)
            
            // Convert the simple tag arrays into EmojiTags objects
            templateStorage = defaultTagMap.reduce(into: [:]) { result, pair in
                let (emoji, tags) = pair
                result[emoji] = EmojiTags(emoji: emoji, tags: Set(tags.map { $0.lowercased() }))
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
    
    func addTag(_ tag: String, forEmoji emoji: String) -> Bool {
        let normalizedTag = tag.lowercased()
        if var emojiTags = storage[emoji] {
            let wasAdded = emojiTags.tags.insert(normalizedTag).inserted
            if wasAdded {
                storage[emoji] = emojiTags
            }
            return wasAdded
        } else {
            storage[emoji] = EmojiTags(emoji: emoji, tags: [normalizedTag])
            return true
        }
    }
    
    func removeTag(_ tag: String, fromEmoji emoji: String) -> Bool {
        let normalizedTag = tag.lowercased()
        if var emojiTags = storage[emoji] {
            let wasRemoved = emojiTags.tags.remove(normalizedTag) != nil
            if wasRemoved {
                if emojiTags.tags.isEmpty {
                    storage.removeValue(forKey: emoji)
                } else {
                    storage[emoji] = emojiTags
                }
            }
            return wasRemoved
        }
        return false
    }
    
    func getTagsForEmoji(_ emoji: String) -> Set<String>? {
        return storage[emoji]?.tags
    }
    
    func getAllEmojisWithTags() -> [EmojiTags] {
        return Array(storage.values)
    }
    
    func getAllMappings() -> [(tag: String, emoji: String)] {
        var mappings: [(tag: String, emoji: String)] = []
        for (emoji, emojiTags) in storage {
            for tag in emojiTags.tags {
                mappings.append((tag: tag, emoji: emoji))
            }
        }
        return mappings
    }
    
    // MARK: - Template Management
    
    func resetToTemplate() {
        storage = templateStorage
    }
    
    func clear() {
        storage.removeAll()
    }
    
    // MARK: - Default Mappings (Fallback)
    
    private func setupDefaultMappings() {
        print("Setting up hardcoded default mappings...")
        
        let defaults: [(emoji: String, tags: Set<String>)] = [
            ("😊", ["smile", "happy", "smiley"]),
            ("😂", ["laugh", "joy", "crying laughing", "lol"]),
            ("❤️", ["heart", "love", "red heart"]),
            ("👍", ["thumbs up", "ok", "good", "like"]),
            ("🎉", ["party", "celebration", "tada"]),
            ("🤔", ["thinking", "hmm", "think"]),
            ("😭", ["cry", "sad", "crying", "tears"]),
            ("🔥", ["fire", "hot", "lit"]),
            ("✨", ["sparkles", "shine", "stars"]),
            ("🙏", ["please", "thank you", "pray", "thanks"])
        ]
        
        for mapping in defaults {
            storage[mapping.emoji] = EmojiTags(emoji: mapping.emoji, tags: mapping.tags)
        }
        
        // Also save as template
        templateStorage = storage
        
        print("Added \(defaults.count) default emoji mappings")
    }
} 