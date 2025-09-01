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
    private let imageMarker = "__IMAGE__"

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var appSupportDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleId = Bundle.main.bundleIdentifier ?? "FujiMoji"
        return base.appendingPathComponent(bundleId, isDirectory: true)
    }

    private var userCustomURL: URL {
        documentsDirectory.appendingPathComponent("user_custom_mappings.json")
    }
    private var userCustomOrderURL: URL {
        documentsDirectory.appendingPathComponent("user_custom_order.json")
    }

    private var imageTagsDBURL: URL { appSupportDirectory.appendingPathComponent("user_image_tags.json") }
    private var imageTagsOrderURL: URL { appSupportDirectory.appendingPathComponent("user_image_tags_order.json") }
    private var imageMediaDir: URL { appSupportDirectory.appendingPathComponent("user_image_tags_media", isDirectory: true) }
    private var imageTagMap: [String: String] = [:] 
    private var imageTagOrder: [String] = []

    private init() {
        loadFromDisk()
        loadImageTagsFromDisk()
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

    private func loadImageTagsFromDisk() {
        try? fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: imageTagsDBURL),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            imageTagMap = dict
        }
        if let orderData = try? Data(contentsOf: imageTagsOrderURL),
           let savedOrder = try? JSONDecoder().decode([String].self, from: orderData) {
            let setKeys = Set(imageTagMap.keys)
            imageTagOrder = savedOrder.filter { setKeys.contains($0) }
            for key in imageTagMap.keys where !imageTagOrder.contains(key) {
                imageTagOrder.append(key)
            }
        } else {
            imageTagOrder = Array(imageTagMap.keys)
        }
        for key in imageTagMap.keys {
            trie.insert(tag: key, text: imageMarker)
        }
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

    private func saveImageTagsToDisk() {
        do {
            try fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(imageTagMap)
            try data.write(to: imageTagsDBURL)
            let orderData = try JSONEncoder().encode(imageTagOrder)
            try orderData.write(to: imageTagsOrderURL)
        } catch {
            print("Error saving image tag db: \(error)")
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
        if imageTagMap[normalizedTag.lowercased()] != nil {
            trie.remove(tag: normalizedTag, text: imageMarker)
        }
        map.remove(tag: normalizedTag)
        saveToDisk()
    }

    func getText(forTag tag: String) -> String? {
        let found = trie.find(tag: tag)
        if found == imageMarker { return nil }
        return found
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

    func setImage(data: Data, fileExtension: String, forTag tag: String) {
        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTag.isEmpty else { return }
        do {
            try fileManager.createDirectory(at: imageMediaDir, withIntermediateDirectories: true)
            if let prev = imageTagMap[normalizedTag] {
                let prevURL = imageMediaDir.appendingPathComponent(prev)
                try? fileManager.removeItem(at: prevURL)
            }
            let filename = "\(UUID().uuidString).\(fileExtension)"
            let url = imageMediaDir.appendingPathComponent(filename)
            try data.write(to: url)
            imageTagMap[normalizedTag] = filename
            if !imageTagOrder.contains(normalizedTag) { imageTagOrder.append(normalizedTag) }
            trie.remove(tag: normalizedTag, text: imageMarker)
            trie.insert(tag: normalizedTag, text: imageMarker)
            saveImageTagsToDisk()
        } catch {
            print("Error saving image for tag: \(error)")
        }
    }

    func removeImage(tag: String) {
        let key = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let filename = imageTagMap[key] {
            let url = imageMediaDir.appendingPathComponent(filename)
            try? fileManager.removeItem(at: url)
        }
        imageTagMap.removeValue(forKey: key)
        if let idx = imageTagOrder.firstIndex(of: key) { imageTagOrder.remove(at: idx) }
        trie.remove(tag: key, text: imageMarker)
        saveImageTagsToDisk()
    }

    func getImageURL(forTag tag: String) -> URL? {
        let key = tag.lowercased()
        guard let filename = imageTagMap[key] else { return nil }
        return imageMediaDir.appendingPathComponent(filename)
    }

    func getAllImageTagsNewestFirst() -> [(tag: String, url: URL)] {
        let ordered = imageTagOrder.reversed()
        var result: [(tag: String, url: URL)] = []
        result.reserveCapacity(ordered.count)
        for key in ordered {
            if let filename = imageTagMap[key] {
                result.append((tag: key, url: imageMediaDir.appendingPathComponent(filename)))
            }
        }
        return result
    }

    func renameImageTag(oldTag: String, newTag: String) {
        let oldKey = oldTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let newKey = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !oldKey.isEmpty, !newKey.isEmpty, oldKey != newKey else { return }
        guard let filename = imageTagMap[oldKey] else { return }

        if let existing = imageTagMap[newKey] {
            let existingURL = imageMediaDir.appendingPathComponent(existing)
            try? fileManager.removeItem(at: existingURL)
            imageTagMap.removeValue(forKey: newKey)
            trie.remove(tag: newKey, text: imageMarker)
            if let idx = imageTagOrder.firstIndex(of: newKey) {
                imageTagOrder.remove(at: idx)
            }
        }

        imageTagMap[newKey] = filename
        imageTagMap.removeValue(forKey: oldKey)
        if let idx = imageTagOrder.firstIndex(of: oldKey) {
            imageTagOrder[idx] = newKey
        }
        trie.remove(tag: oldKey, text: imageMarker)
        trie.insert(tag: newKey, text: imageMarker)
        saveImageTagsToDisk()
    }
}

