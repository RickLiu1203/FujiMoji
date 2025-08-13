import Foundation

class TrieNode {
    var children: [Character: TrieNode] = [:]
    var emoji: String?
    var isEndOfCode = false
    var isDeleted = false
    var referenceCount = 0
}

class EmojiTrie {
    private var root = TrieNode()
    private var deletionCount = 0
    private let cleanupThreshold = 1000
    
    func insert(tag: String, emoji: String) {
        var current = root
        let normalizedTag = tag.lowercased()
        
        for char in normalizedTag {
            if current.children[char] == nil {
                current.children[char] = TrieNode()
            }
            current = current.children[char]!
        }
        
        current.isEndOfCode = true
        current.emoji = emoji
        current.isDeleted = false
        current.referenceCount += 1
    }
    
    func remove(tag: String, emoji: String) {
        var current = root
        var path = [TrieNode]()
        let normalizedTag = tag.lowercased()
        
        for char in normalizedTag {
            guard let next = current.children[char] else { return }
            path.append(current)
            current = next
        }
        
        if current.isEndOfCode && current.emoji == emoji {
            current.referenceCount -= 1
            if current.referenceCount <= 0 {
                current.isDeleted = true
                deletionCount += 1
            }
        }
        
        if deletionCount >= cleanupThreshold {
            cleanup()
        }
    }
    
    func find(tag: String) -> String? {
        var current = root
        let normalizedTag = tag.lowercased()
        
        for char in normalizedTag {
            guard let next = current.children[char] else {
                return nil
            }
            current = next
        }
        
        if current.isEndOfCode && !current.isDeleted {
            return current.emoji
        }
        return nil
    }
    
    func cleanup() {
        root = TrieNode()
        deletionCount = 0
    }
    
    func rebuild(from mappings: [(tag: String, emoji: String)]) {
        cleanup()
        for mapping in mappings {
            insert(tag: mapping.tag, emoji: mapping.emoji)
        }
    }
} 