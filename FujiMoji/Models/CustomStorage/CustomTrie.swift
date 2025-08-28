//
//  CustomTrie.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-26.
//

import Foundation

class CustomTrieNode {
    var children: [Character: CustomTrieNode] = [:]
    var text: String?
    var isEndOfCode = false
    var isDeleted = false
    var referenceCount = 0
    
    var depth: Int = 0
    weak var parent: CustomTrieNode?
}

final class CustomTrie {
    private var root = CustomTrieNode()
    private var deletionCount = 0
    private let cleanupThreshold = 1000
    
    private var pathCache: [String: [Character]] = [:]
    
    func insert(tag: String, text: String) {
        var current = root
        let normalizedTag = tag.lowercased()
        var depth = 0
        
        for char in normalizedTag {
            if current.children[char] == nil {
                let newNode = CustomTrieNode()
                newNode.depth = depth + 1
                newNode.parent = current
                current.children[char] = newNode
            }
            current = current.children[char]!
            depth += 1
        }
        
        current.isEndOfCode = true
        current.text = text
        current.isDeleted = false
        current.referenceCount += 1
        
        pathCache["\(normalizedTag):\(text)"] = Array(normalizedTag)
    }
    
    func remove(tag: String, text: String) {
        var current = root
        let normalizedTag = tag.lowercased()
        let pathKey = "\(normalizedTag):\(text)"
        
        guard let path = pathCache[pathKey] else { return }
        
        for char in path {
            guard let next = current.children[char] else { return }
            current = next
        }
        
        if current.isEndOfCode && current.text == text {
            current.referenceCount -= 1
            if current.referenceCount <= 0 {
                current.isDeleted = true
                deletionCount += 1
                cleanupPath(current)
                pathCache.removeValue(forKey: pathKey)
            }
        }
    }
    
    private func cleanupPath(_ node: CustomTrieNode) {
        var current: CustomTrieNode? = node
        
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
            return current.text
        }
        return nil
    }
    
    func updateMappings(added: [(tag: String, text: String)], removed: [(tag: String, text: String)]) {
        for entry in removed {
            remove(tag: entry.tag, text: entry.text)
        }
        for entry in added {
            insert(tag: entry.tag, text: entry.text)
        }
        if deletionCount >= cleanupThreshold {
            performFullCleanup()
        }
    }
    
    private func performFullCleanup() {
        let newRoot = CustomTrieNode()
        
        for (key, path) in pathCache {
            let components = key.split(separator: ":")
            guard components.count == 2 else { continue }
            let tag = String(components[0])
            let text = String(components[1])
            
            var current = newRoot
            var depth = 0
            
            for char in path {
                if current.children[char] == nil {
                    let newNode = CustomTrieNode()
                    newNode.depth = depth + 1
                    newNode.parent = current
                    current.children[char] = newNode
                }
                current = current.children[char]!
                depth += 1
            }
            
            current.isEndOfCode = true
            current.text = text
            current.isDeleted = false
            current.referenceCount = 1
        }
        
        root = newRoot
        deletionCount = 0
    }
    
    func rebuild(from mappings: [(tag: String, text: String)]) {
        root = CustomTrieNode()
        pathCache.removeAll()
        deletionCount = 0
        for entry in mappings {
            insert(tag: entry.tag, text: entry.text)
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

    private func collect(from node: CustomTrieNode, buffer: inout [Character], results: inout [String], limit: Int) {
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
}

