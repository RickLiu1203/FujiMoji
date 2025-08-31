//
//  CustomStorage.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-26.
//

import Foundation

final class CustomStorage {
    static let shared = CustomStorage()

    private let map = CustomMap()
    private let trie = CustomTrie()

    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var userCustomURL: URL {
        documentsDirectory.appendingPathComponent("user_custom_mappings.json")
    }
    private var userCustomOrderURL: URL {
        documentsDirectory.appendingPathComponent("user_custom_order.json")
    }

    private init() {
        loadFromDisk()
    }

    private func loadFromDisk() {
        var decoded: [String: String] = [:]
        var savedOrder: [String]? = nil
        if fileManager.fileExists(atPath: userCustomURL.path) {
            if let data = try? Data(contentsOf: userCustomURL),
               let dict = try? JSONDecoder().decode([String: String].self, from: data) {
                decoded = dict
            }
        }
        if fileManager.fileExists(atPath: userCustomOrderURL.path) {
            if let data = try? Data(contentsOf: userCustomOrderURL),
               let arr = try? JSONDecoder().decode([String].self, from: data) {
                savedOrder = arr
            }
        }
        if let order = savedOrder {
            map.replaceAll(decoded, withOrder: order)
        } else {
            map.replaceAll(decoded)
        }
        trie.rebuild(from: map.getAllMappings())
    }

    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let dictData = try encoder.encode(map.getAll())
            let orderData = try encoder.encode(map.getOrder())
            try fileManager.createDirectory(at: userCustomURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try dictData.write(to: userCustomURL)
            try orderData.write(to: userCustomOrderURL)
        } catch {
            print("Error saving custom mappings: \(error)")
        }
    }

    func set(text: String, forTag tag: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTag.isEmpty, !trimmedText.isEmpty else { return }
        if let previous = map.get(forTag: normalizedTag) {
            trie.remove(tag: normalizedTag, text: previous)
        }
        map.set(trimmedText, forTag: normalizedTag)
        trie.insert(tag: normalizedTag, text: trimmedText)
        saveToDisk()
    }

    func remove(tag: String) {
        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTag.isEmpty else { return }
        if let text = map.get(forTag: normalizedTag) {
            trie.remove(tag: normalizedTag, text: text)
        }
        map.remove(tag: normalizedTag)
        saveToDisk()
    }

    func getText(forTag tag: String) -> String? {
        return trie.find(tag: tag)
    }

    func getAllMappings() -> [String: String] {
        return map.getAll()
    }

    func getAllSorted() -> [(tag: String, text: String)] {
        return map.getAllMappings().sorted { $0.tag < $1.tag }
    }

    func getAllNewestFirst() -> [(tag: String, text: String)] {
        let entries = map.getAllByInsertionOrder()
        return Array(entries.reversed())
    }

    func collectTags(withPrefix prefix: String, limit: Int = 25) -> [String] {
        return trie.collectTags(withPrefix: prefix, limit: limit)
    }
}

