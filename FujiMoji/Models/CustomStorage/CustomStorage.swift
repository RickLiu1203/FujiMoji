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

    private init() {
        loadFromDisk()
    }

    private func loadFromDisk() {
        if !fileManager.fileExists(atPath: userCustomURL.path) {
            trie.rebuild(from: map.getAllMappings())
            print("No custom mappings found; starting fresh")
            return
        }
        do {
            let data = try Data(contentsOf: userCustomURL)
            let decoded = try JSONDecoder().decode([String: String].self, from: data)
            map.replaceAll(decoded)
            trie.rebuild(from: map.getAllMappings())
            print("Loaded custom mappings: \(decoded.count)")
        } catch {
            print("Error loading custom mappings: \(error)")
            trie.rebuild(from: map.getAllMappings())
        }
    }

    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(map.getAll())
            try fileManager.createDirectory(at: userCustomURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: userCustomURL)
            print("Saved custom mappings: \(map.getAll().count)")
        } catch {
            print("Error saving custom mappings: \(error)")
        }
    }

    func set(text: String, forTag tag: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTag.isEmpty, !trimmedText.isEmpty else { return }
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
}

