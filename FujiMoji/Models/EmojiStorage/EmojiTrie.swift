class TrieNode {
    var children: [Character: TrieNode] = [:]
    var emoji: String?
    var isEndOfCode = false
    var isDeleted = false
    var referenceCount = 0
    
    // New: Track depth for cleanup optimization
    var depth: Int = 0
    weak var parent: TrieNode?
}

class EmojiTrie {
    private var root = TrieNode()
    private var deletionCount = 0
    private let cleanupThreshold = 1000
    
    // New: Track all paths for efficient cleanup
    private var pathCache: [String: [Character]] = [:]
    
    func insert(tag: String, emoji: String) {
        var current = root
        let normalizedTag = tag.lowercased()
        var depth = 0
        
        for char in normalizedTag {
            if current.children[char] == nil {
                let newNode = TrieNode()
                newNode.depth = depth + 1
                newNode.parent = current
                current.children[char] = newNode
            }
            current = current.children[char]!
            depth += 1
        }
        
        current.isEndOfCode = true
        current.emoji = emoji
        current.isDeleted = false
        current.referenceCount += 1
        
        // Cache the path for this tag
        pathCache["\(normalizedTag):\(emoji)"] = Array(normalizedTag)
    }
    
    func remove(tag: String, emoji: String) {
        var current = root
        let normalizedTag = tag.lowercased()
        let pathKey = "\(normalizedTag):\(emoji)"
        
        // Use cached path if available
        guard let path = pathCache[pathKey] else { return }
        
        for char in path {
            guard let next = current.children[char] else { return }
            current = next
        }
        
        if current.isEndOfCode && current.emoji == emoji {
            current.referenceCount -= 1
            if current.referenceCount <= 0 {
                current.isDeleted = true
                deletionCount += 1
                
                // Cleanup this specific path if possible
                cleanupPath(current)
                
                // Remove from path cache
                pathCache.removeValue(forKey: pathKey)
            }
        }
    }
    
    // New: Cleanup specific path
    private func cleanupPath(_ node: TrieNode) {
        var current: TrieNode? = node
        
        while let node = current, 
              node.children.isEmpty && 
              node.isDeleted && 
              node.parent != nil {
            let parent = node.parent!
            // Find and remove this node from parent's children
            for (char, child) in parent.children {
                if child === node {
                    parent.children.removeValue(forKey: char)
                    break
                }
            }
            current = parent
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
    
    // New: Update aliases efficiently
    func updateAliases(forEmoji emoji: String, added: Set<String>, removed: Set<String>) {
        // Remove old aliases
        for alias in removed {
            remove(tag: alias, emoji: emoji)
        }
        
        // Add new aliases
        for alias in added {
            insert(tag: alias, emoji: emoji)
        }
        
        // Only perform full cleanup if we've hit the threshold
        if deletionCount >= cleanupThreshold {
            performFullCleanup()
        }
    }
    
    // New: Full cleanup when needed
    private func performFullCleanup() {
        // Create new root
        let newRoot = TrieNode()
        
        // Rebuild only active paths
        for (key, path) in pathCache {
            let components = key.split(separator: ":")
            guard components.count == 2 else { continue }
            let tag = String(components[0])
            let emoji = String(components[1])
            
            var current = newRoot
            var depth = 0
            
            for char in path {
                if current.children[char] == nil {
                    let newNode = TrieNode()
                    newNode.depth = depth + 1
                    newNode.parent = current
                    current.children[char] = newNode
                }
                current = current.children[char]!
                depth += 1
            }
            
            current.isEndOfCode = true
            current.emoji = emoji
            current.isDeleted = false
            current.referenceCount = 1
        }
        
        // Replace root and reset deletion count
        root = newRoot
        deletionCount = 0
    }
    
    // Modified rebuild to use new efficient approach
    func rebuild(from mappings: [(tag: String, emoji: String)]) {
        root = TrieNode()
        pathCache.removeAll()
        deletionCount = 0
        
        for mapping in mappings {
            insert(tag: mapping.tag, emoji: mapping.emoji)
        }
    }
}