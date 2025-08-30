//
//  CustomMap.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-26.
//

import Foundation

final class CustomMap {
    private var storage: [String: String] = [:] // { tag: text }
    private var order: [String] = [] // insertion order of normalized tags

    init() {}

    func set(_ text: String, forTag tag: String) {
        let normalizedTag = tag.lowercased()
        let isNew = storage[normalizedTag] == nil
        storage[normalizedTag] = text
        if isNew {
            order.append(normalizedTag)
        }
    }

    func get(forTag tag: String) -> String? {
        let normalizedTag = tag.lowercased()
        return storage[normalizedTag]
    }

    func remove(tag: String) {
        let normalizedTag = tag.lowercased()
        storage.removeValue(forKey: normalizedTag)
        if let idx = order.firstIndex(of: normalizedTag) {
            order.remove(at: idx)
        }
    }

    func getAll() -> [String: String] {
        return storage
    }

    func getAllMappings() -> [(tag: String, text: String)] {
        return storage.map { ($0.key, $0.value) }
    }

    func getAllByInsertionOrder() -> [(tag: String, text: String)] {
        return order.compactMap { key in
            if let text = storage[key] { return (tag: key, text: text) }
            return nil
        }
    }

    func replaceAll(_ entries: [String: String]) {
        storage = entries.reduce(into: [:]) { acc, pair in
            acc[pair.key.lowercased()] = pair.value
        }
        order = entries.keys.map { $0.lowercased() }
    }

    func getOrder() -> [String] { order }
    func setOrder(_ newOrder: [String]) {
        // Keep only keys that still exist
        let normalized = newOrder.map { $0.lowercased() }
        let filtered = normalized.filter { storage[$0] != nil }
        // Add any missing keys at the end to avoid losing data
        let missing = storage.keys.filter { !filtered.contains($0) }
        order = filtered + missing
    }
}

