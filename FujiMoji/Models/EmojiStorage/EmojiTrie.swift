class TrieNode {
    var children: [Character: TrieNode] = [:]
    var emoji: String?
    var isEndOfCode = false
    var isDeleted = false
    var referenceCount = 0
    
    var depth: Int = 0
    weak var parent: TrieNode?
}

class EmojiTrie {
    private var root = TrieNode()
    private var deletionCount = 0
    private let cleanupThreshold = 1000
    
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
        
        pathCache["\(normalizedTag):\(emoji)"] = Array(normalizedTag)
    }
    
    func remove(tag: String, emoji: String) {
        var current = root
        let normalizedTag = tag.lowercased()
        let pathKey = "\(normalizedTag):\(emoji)"
        
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
                
                cleanupPath(current)
                
                pathCache.removeValue(forKey: pathKey)
            }
        }
    }
    
    private func cleanupPath(_ node: TrieNode) {
        var current: TrieNode? = node
        
        while let node = current, 
              node.children.isEmpty && 
              node.isDeleted && 
              node.parent != nil {
            let parent = node.parent!
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
    
    func updateAliases(forEmoji emoji: String, added: Set<String>, removed: Set<String>) {
        for alias in removed {
            remove(tag: alias, emoji: emoji)
        }
        
        for alias in added {
            insert(tag: alias, emoji: emoji)
        }
        
        if deletionCount >= cleanupThreshold {
            performFullCleanup()
        }
    }
    
    private func performFullCleanup() {
        let newRoot = TrieNode()
        
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
        
        root = newRoot
        deletionCount = 0
    }
    
    func rebuild(from mappings: [(tag: String, emoji: String)]) {
        root = TrieNode()
        pathCache.removeAll()
        deletionCount = 0
        
        for mapping in mappings {
            insert(tag: mapping.tag, emoji: mapping.emoji)
        }
    }

    // MARK: - Prefix search
    func collectTags(withPrefix prefix: String, limit: Int = 50) -> [String] {
        let normalized = prefix.lowercased()
        var current = root
        for char in normalized {
            guard let next = current.children[char] else { return [] }
            current = next
        }
        var results: [String] = []
        var buffer = Array(normalized)
        collect(from: current, buffer: &buffer, results: &results, limit: limit)
        return results
    }

    private func collect(from node: TrieNode, buffer: inout [Character], results: inout [String], limit: Int) {
        if results.count >= limit { return }
        if node.isEndOfCode && !node.isDeleted {
            results.append(String(buffer))
        }
        if results.count >= limit { return }
        for (ch, child) in node.children.sorted(by: { $0.key < $1.key }) {
            buffer.append(ch)
            collect(from: child, buffer: &buffer, results: &results, limit: limit)
            buffer.removeLast()
            if results.count >= limit { return }
        }
    }

    // Collect tag and emoji pairs for suggestions
    func collectPairs(withPrefix prefix: String, limit: Int = 50) -> [(tag: String, emoji: String)] {
        let normalized = prefix.lowercased()
        var current = root
        for char in normalized {
            guard let next = current.children[char] else { return [] }
            current = next
        }
        var results: [(String, String)] = []
        var buffer = Array(normalized)
        collectPairs(from: current, buffer: &buffer, results: &results, limit: limit)
        return results
    }

    private func collectPairs(from node: TrieNode, buffer: inout [Character], results: inout [(String, String)], limit: Int) {
        if results.count >= limit { return }
        if node.isEndOfCode && !node.isDeleted, let e = node.emoji {
            results.append((String(buffer), e))
        }
        if results.count >= limit { return }
        for (ch, child) in node.children.sorted(by: { $0.key < $1.key }) {
            buffer.append(ch)
            collectPairs(from: child, buffer: &buffer, results: &results, limit: limit)
            buffer.removeLast()
            if results.count >= limit { return }
        }
    }
}