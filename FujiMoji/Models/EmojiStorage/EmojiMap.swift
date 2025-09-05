// EmojiMap.swift
// FujiMoji
//
// Created by Rick Liu on 2025-08-20.
//

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
    private var templateStorage: [String: EmojiTags] = [:]
    private let templateURL: URL?
    private let userDataURL: URL
    
    init(templateURL: URL?, userDataURL: URL) {
        self.templateURL = templateURL
        self.userDataURL = userDataURL
        
        if let templateURL = templateURL {
            loadTemplate(from: templateURL)
        }
        
        loadUserData()
        
        if storage.isEmpty {
            setupDefaultMappings()
        }
    }
        
    private func loadTemplate(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            struct DefaultEmojiRecord: Codable {
                let id: Int?
                let defaultTag: String
                let unicode: String?
                let aliases: [String]
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case defaultTag = "default_tag"
                    case unicode
                    case aliases
                }
            }
            
            let defaultEmojiMap = try decoder.decode([String: DefaultEmojiRecord].self, from: data)
            
            templateStorage = defaultEmojiMap.reduce(into: [:]) { result, pair in
                let (emoji, record) = pair
                result[emoji] = EmojiTags(
                    emoji: emoji,
                    defaultTag: record.defaultTag,
                    aliases: record.aliases
                )
            }
            
            if storage.isEmpty {
                storage = templateStorage
            }
            
        } catch {
            print("Error loading template: \(error)")
        }
    }
    
    private func loadUserData() {
        if !FileManager.default.fileExists(atPath: userDataURL.path) {
            if storage.isEmpty {
                storage = templateStorage
            }
            return
        }
        
        do {
            let data = try Data(contentsOf: userDataURL)
            let mappings = try JSONDecoder().decode([EmojiTags].self, from: data)
            
            var merged = templateStorage
            for mapping in mappings {
                merged[mapping.emoji] = mapping
            }
            storage = merged
            
        } catch {
            print("Error loading user data: \(error)")
            if storage.isEmpty {
                storage = templateStorage
            }
        }
    }
    
    func getDefaultTag(forEmoji emoji: String) -> String? {
        return storage[emoji]?.defaultTag
    }
    
    func getAliases(forEmoji emoji: String) -> [String] {
        return storage[emoji]?.aliases ?? []
    }
    
    func setAliases(_ aliases: [String], forEmoji emoji: String) {
        let normalized = aliases.map { $0.lowercased() }
        var seen: Set<String> = []
        var deduped: [String] = []
        for alias in normalized {
            if !alias.isEmpty, seen.insert(alias).inserted {
                deduped.append(alias)
            }
        }

        if !deduped.isEmpty {
            for (key, var tags) in storage {
                if key == emoji { continue }
                let originalCount = tags.aliases.count
                tags.aliases.removeAll { deduped.contains($0) }
                if tags.aliases.count != originalCount {
                    storage[key] = tags
                }
            }
        }

        if var emojiTags = storage[emoji] {
            emojiTags.aliases = deduped
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
    
    func resetToTemplate() {
        storage = templateStorage
    }
    
    private func setupDefaultMappings() {        
        let defaults: [(emoji: String, defaultTag: String, aliases: [String])] = [

        ]
        
        for mapping in defaults {
            storage[mapping.emoji] = EmojiTags(
                emoji: mapping.emoji,
                defaultTag: mapping.defaultTag,
                aliases: mapping.aliases
            )
        }
        
        templateStorage = storage
        
    }
} 
