// KeywordTrie.swift
// FujiMoji
//
// Created by Rick Liu on 2025-09-05.
//

import Foundation

final class KeywordTrieNode {
    var children: [Character: KeywordTrieNode] = [:]
    var isEndOfKeyword: Bool = false
    var keywordEmojis: [String] = []
    var recentEmojis: [String] = []
}

final class KeywordTrie {
    private let root = KeywordTrieNode()
    private let recentCapacity: Int = 12

    func insert(keyword: String, emoji: String) {
        let normalized = keyword.lowercased()
        guard !normalized.isEmpty else { return }

        var current = root
        for ch in normalized {
            if current.children[ch] == nil {
                current.children[ch] = KeywordTrieNode()
            }
            current = current.children[ch]!
        }

        current.isEndOfKeyword = true
        if !current.keywordEmojis.contains(emoji) {
            current.keywordEmojis.append(emoji)
        }
    }

    func collectPairs(withPrefix prefix: String, limit: Int = 25) -> [(tag: String, emoji: String)] {
        let normalized = prefix.lowercased()
        var current = root
        for ch in normalized {
            guard let next = current.children[ch] else { return [] }
            current = next
        }

        var results: [(String, String)] = []
        var seen = Set<String>()
        var buffer = Array(normalized)
        if !current.recentEmojis.isEmpty {
            for emoji in current.recentEmojis {
                if results.count >= limit { break }
                if !seen.contains(emoji) {
                    seen.insert(emoji)
                    results.append((String(buffer), emoji))
                }
            }
        }
        collect(from: current, buffer: &buffer, results: &results, seen: &seen, limit: limit)
        return results
    }

    private func collect(from node: KeywordTrieNode,
                         buffer: inout [Character],
                         results: inout [(String, String)],
                         seen: inout Set<String>,
                         limit: Int) {
        if results.count >= limit { return }

        if node.isEndOfKeyword {
            let keyword = String(buffer)
            if !node.keywordEmojis.isEmpty {
                for emoji in node.keywordEmojis {
                    if results.count >= limit { return }
                    if !seen.contains(emoji) {
                        seen.insert(emoji)
                        results.append((keyword, emoji))
                    }
                }
            }
        }

        if results.count >= limit { return }
        for (ch, child) in node.children.sorted(by: { $0.key < $1.key }) {
            buffer.append(ch)
            collect(from: child, buffer: &buffer, results: &results, seen: &seen, limit: limit)
            buffer.removeLast()
            if results.count >= limit { return }
        }
    }

    func recordUsage(prefix: String, emoji: String) {
        let normalized = prefix.lowercased()
        guard !normalized.isEmpty else { return }

        var current = root
        for ch in normalized {
            guard let next = current.children[ch] else { return }
            current = next
        }

        if let index = current.recentEmojis.firstIndex(of: emoji) {
            current.recentEmojis.remove(at: index)
        }
        current.recentEmojis.insert(emoji, at: 0)
        if current.recentEmojis.count > recentCapacity {
            current.recentEmojis.removeLast(current.recentEmojis.count - recentCapacity)
        }
    }

    func recentEmojis(forPrefix prefix: String) -> [String] {
        let normalized = prefix.lowercased()
        guard !normalized.isEmpty else { return [] }

        var current = root
        for ch in normalized {
            guard let next = current.children[ch] else { return [] }
            current = next
        }
        return current.recentEmojis
    }
    
    // MARK: - Recency Persistence
    
    func exportRecencyData() -> [String: [String]] {
        var result: [String: [String]] = [:]
        var buffer: [Character] = []
        collectRecency(from: root, buffer: &buffer, result: &result)
        return result
    }
    
    private func collectRecency(from node: KeywordTrieNode,
                                buffer: inout [Character],
                                result: inout [String: [String]]) {
        if !node.recentEmojis.isEmpty {
            let prefix = String(buffer)
            result[prefix] = node.recentEmojis
        }
        for (ch, child) in node.children {
            buffer.append(ch)
            collectRecency(from: child, buffer: &buffer, result: &result)
            buffer.removeLast()
        }
    }
    
    func importRecencyData(_ data: [String: [String]]) {
        for (prefix, emojis) in data {
            let normalized = prefix.lowercased()
            guard !normalized.isEmpty else { continue }
            
            // Navigate to the node, creating path if needed
            var current = root
            for ch in normalized {
                if current.children[ch] == nil {
                    current.children[ch] = KeywordTrieNode()
                }
                current = current.children[ch]!
            }
            
            // Restore recency data (capped to capacity)
            current.recentEmojis = Array(emojis.prefix(recentCapacity))
        }
    }
}


