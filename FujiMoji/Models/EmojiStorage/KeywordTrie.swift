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
}

final class KeywordTrie {
    private let root = KeywordTrieNode()

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
        // Avoid duplicates while preserving insertion order
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
}


