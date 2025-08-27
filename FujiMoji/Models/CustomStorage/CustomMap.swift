//
//  CustomMap.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-26.
//

import Foundation

final class CustomMap {
    private var storage: [String: String] = [:] // { tag: text }

    init() {}

    func set(_ text: String, forTag tag: String) {
        let normalizedTag = tag.lowercased()
        storage[normalizedTag] = text
    }

    func get(forTag tag: String) -> String? {
        let normalizedTag = tag.lowercased()
        return storage[normalizedTag]
    }

    func remove(tag: String) {
        let normalizedTag = tag.lowercased()
        storage.removeValue(forKey: normalizedTag)
    }

    func getAll() -> [String: String] {
        return storage
    }

    func getAllMappings() -> [(tag: String, text: String)] {
        return storage.map { ($0.key, $0.value) }
    }

    func replaceAll(_ entries: [String: String]) {
        storage = entries.reduce(into: [:]) { acc, pair in
            acc[pair.key.lowercased()] = pair.value
        }
    }
}

