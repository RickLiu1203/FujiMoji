// EmojiStorage.swift
// FujiMoji
//
// Created by Rick Liu on 2025-08-20.
//

import Foundation

class EmojiStorage {
    static let shared = EmojiStorage()
    
    private let fileManager = FileManager.default
    private let emojiMap: EmojiMap
    private let searchTrie = EmojiTrie()
    private let keywordTrie = KeywordTrie()
    private var canonicalDefaultMap: [String: String] = [:]
    private var prefixRecents: [String: [String]] = [:]
    private let prefixRecentCapacity: Int = 12
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var userMappingsURL: URL {
        documentsDirectory.appendingPathComponent("user_emoji_mappings.json")
    }
    
    private init() {
        let templateURL = Bundle.main.url(forResource: "default", withExtension: "json")
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
        buildKeywordTrie()
        rebuildCanonicalMap()
    }
    
    private func rebuildTrie() {
        searchTrie.rebuild(from: emojiMap.getAllMappings())
        rebuildCanonicalMap()
    }

    private func buildKeywordTrie() {
        guard let url = Bundle.main.url(forResource: "emoji_keywords", withExtension: "json") else {
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let dict = try decoder.decode([String: [String]].self, from: data)
            for (emoji, keywords) in dict {
                for keyword in keywords {
                    keywordTrie.insert(keyword: keyword, emoji: emoji)
                }
            }
        } catch {
            print("Error building keyword trie: \(error)")
        }
    }

    private func canonicalEmoji(_ emoji: String) -> String {
        let filtered = emoji.unicodeScalars.filter { scalar in
            scalar.value != 0xFE0F && 
            scalar.value != 0xFE0E 
        }
        return String(String.UnicodeScalarView(filtered))
    }

    private func rebuildCanonicalMap() {
        var map: [String: String] = [:]
        for record in emojiMap.getAllEmojisWithTags() {
            let key = canonicalEmoji(record.emoji)
            map[key] = record.defaultTag
        }
        canonicalDefaultMap = map
    }

    func getDefaultTagCanonical(forEmoji emoji: String) -> String? {
        return canonicalDefaultMap[canonicalEmoji(emoji)]
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
        } catch {
            print("Error saving user mappings: \(error)")
        }
    }
    
    func resetToDefaults() {
        do {
            if fileManager.fileExists(atPath: userMappingsURL.path) {
                try fileManager.removeItem(at: userMappingsURL)
            }
            emojiMap.resetToTemplate()
            rebuildTrie()
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
    
    func collectTags(withPrefix prefix: String, limit: Int = 25) -> [String] {
        return searchTrie.collectTags(withPrefix: prefix, limit: limit)
    }

    func collectPairs(withPrefix prefix: String, limit: Int = 25) -> [(tag: String, emoji: String)] {
        let normalizedPrefix = prefix.lowercased()
        let aliasAndDefault = searchTrie.collectPairs(withPrefix: normalizedPrefix, limit: limit)
        let keywordPairs = keywordTrie.collectPairs(withPrefix: normalizedPrefix, limit: limit)

        var aliasByCanon: [String: (tag: String, emoji: String)] = [:]
        for pair in aliasAndDefault { aliasByCanon[canonicalEmoji(pair.emoji)] = pair }
        var keywordByCanon: [String: (tag: String, emoji: String)] = [:]
        for pair in keywordPairs { keywordByCanon[canonicalEmoji(pair.emoji)] = pair }

        var results: [(tag: String, emoji: String)] = []
        var usedCanon = Set<String>()

        let recentA = prefixRecents[normalizedPrefix] ?? []
        let recentB = keywordTrie.recentEmojis(forPrefix: normalizedPrefix)
        var recentCombined: [String] = []
        for e in recentA + recentB {
            if !recentCombined.contains(e) { recentCombined.append(e) }
        }

        for emoji in recentCombined {
            let canon = canonicalEmoji(emoji)
            if usedCanon.contains(canon) { continue }
            if let pair = aliasByCanon[canon] {
                results.append(pair)
                usedCanon.insert(canon)
                continue
            }
            if let pair = keywordByCanon[canon] {
                results.append((tag: getDefaultTagCanonical(forEmoji: pair.emoji) ?? pair.tag, emoji: pair.emoji))
                usedCanon.insert(canon)
                continue
            }
            results.append((tag: getDefaultTagCanonical(forEmoji: emoji) ?? normalizedPrefix, emoji: emoji))
            usedCanon.insert(canon)
        }

        if results.count >= limit { return Array(results.prefix(limit)) }

        let aliasItems = aliasAndDefault.filter { pair in
            let def = getDefaultTag(forEmoji: pair.emoji)?.lowercased()
            return def == nil || def != pair.tag.lowercased()
        }
        let defaultItems = aliasAndDefault.filter { pair in
            let def = getDefaultTag(forEmoji: pair.emoji)?.lowercased()
            return def == pair.tag.lowercased()
        }
        for pair in aliasItems + defaultItems {
            if results.count >= limit { break }
            let canon = canonicalEmoji(pair.emoji)
            if usedCanon.contains(canon) { continue }
            results.append(pair)
            usedCanon.insert(canon)
        }

        if results.count >= limit { return Array(results.prefix(limit)) }

        for pair in keywordPairs {
            if results.count >= limit { break }
            let canon = canonicalEmoji(pair.emoji)
            if usedCanon.contains(canon) { continue }
            let displayTag = getDefaultTagCanonical(forEmoji: pair.emoji) ?? pair.tag
            results.append((tag: displayTag, emoji: pair.emoji))
            usedCanon.insert(canon)
        }

        return Array(results.prefix(limit))
    }

    func recordKeywordUsage(prefix: String, emoji: String) {
        let normalized = prefix.lowercased()
        keywordTrie.recordUsage(prefix: normalized, emoji: emoji)
        var list = prefixRecents[normalized] ?? []
        if let idx = list.firstIndex(of: emoji) {
            list.remove(at: idx)
        }
        list.insert(emoji, at: 0)
        if list.count > prefixRecentCapacity {
            list.removeLast(list.count - prefixRecentCapacity)
        }
        prefixRecents[normalized] = list
    }
} 