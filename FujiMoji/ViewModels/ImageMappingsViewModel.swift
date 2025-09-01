//
//  ImageMappingsViewModel.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-09-01.
//

import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class ImageTagMappingsViewModel: ObservableObject {
    @Published var items: [(tag: String, url: URL)] = []
    @Published var selectedTag: String? = nil
    @Published var selectedImage: NSImage? = nil
    @Published var selectedImageData: Data? = nil
    @Published var selectedImageFileExtension: String? = nil
    @Published var currentTagInput: String = ""
    @Published var errorMessage: String? = nil
    @Published var favoriteImageTags: Set<String> = []

    let allowedExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "heif", "tif", "tiff", "bmp", "webp"]
    let maxFileSizeBytes: Int = 10 * 1024 * 1024

    init() {
        reload()
        loadFavorites()
    }

    func reload() {
        items = CustomStorage.shared.getAllImageTagsNewestFirst()
        if selectedTag == nil { selectedTag = items.first?.tag }
    }

    func chooseImageFromDisk() {
        let panel = NSOpenPanel()
        var contentTypes: [UTType] = [.png, .jpeg, .gif, .heic, .heif, .tiff]
        if let bmp = UTType(filenameExtension: "bmp") { contentTypes.append(bmp) }
        if let webp = UTType(filenameExtension: "webp") { contentTypes.append(webp) }
        if let jpg = UTType(filenameExtension: "jpg") { contentTypes.append(jpg) }
        if let tif = UTType(filenameExtension: "tif") { contentTypes.append(tif) }
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            let ext = url.pathExtension.lowercased()
            validateAndSet(data: data, ext: ext)
            if selectedTag != nil { save() }
        }
    }

    func pasteImageFromPasteboard() {
        let pb = NSPasteboard.general
        if let urlStr = pb.string(forType: .fileURL), let url = URL(string: urlStr), let data = try? Data(contentsOf: url) {
            let ext = url.pathExtension.lowercased()
            validateAndSet(data: data, ext: ext)
            if selectedTag != nil { save() }
            return
        }
        if let data = pb.data(forType: .png) { 
            validateAndSet(data: data, ext: "png")
            if selectedTag != nil { save() }
            return 
        }
        if let data = pb.data(forType: .tiff) { 
            validateAndSet(data: data, ext: "tiff")
            if selectedTag != nil { save() }
            return 
        }
        if let data = pb.data(forType: NSPasteboard.PasteboardType("com.compuserve.gif")) { 
            validateAndSet(data: data, ext: "gif")
            if selectedTag != nil { save() }
            return 
        }
        if let data = pb.data(forType: NSPasteboard.PasteboardType("public.jpeg")) { 
            validateAndSet(data: data, ext: "jpeg")
            if selectedTag != nil { save() }
            return 
        }
        if let data = pb.data(forType: NSPasteboard.PasteboardType("public.heic")) { 
            validateAndSet(data: data, ext: "heic")
            if selectedTag != nil { save() }
            return 
        }
        if let data = pb.data(forType: NSPasteboard.PasteboardType("public.heif")) { 
            validateAndSet(data: data, ext: "heif")
            if selectedTag != nil { save() }
            return 
        }
        if let data = pb.data(forType: NSPasteboard.PasteboardType("com.microsoft.bmp")) { 
            validateAndSet(data: data, ext: "bmp")
            if selectedTag != nil { save() }
            return 
        }
        if let data = pb.data(forType: NSPasteboard.PasteboardType("org.webmproject.webp")) { 
            validateAndSet(data: data, ext: "webp")
            if selectedTag != nil { save() }
            return 
        }
    }

    private func validateAndSet(data: Data, ext: String) {
        errorMessage = nil
        let normalizedExt = ext.lowercased()
        guard allowedExtensions.contains(normalizedExt) else {
            errorMessage = "Unsupported type .\(normalizedExt). Allowed: PNG, JPEG, GIF, HEIC, TIFF, BMP, WebP."
            return
        }
        guard data.count <= maxFileSizeBytes else {
            errorMessage = "File too large (\(formatBytes(data.count))) Max 10 MB"
            return
        }
        selectedImageData = data
        selectedImageFileExtension = normalizedExt
        selectedImage = NSImage(data: data)
    }

    private func formatBytes(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(count))
    }

    func save() {
        let image = selectedImage
        let tag = (selectedTag ?? currentTagInput).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }

        if let data = selectedImageData, let ext = selectedImageFileExtension {
            CustomStorage.shared.setImage(data: data, fileExtension: ext, forTag: tag)
            reload()
            selectedTag = tag
            currentTagInput = ""
            errorMessage = nil
            selectedImage = nil
            selectedImageData = nil
            selectedImageFileExtension = nil
            return
        }

        guard let image = image else { return }
        if let tiff = image.tiffRepresentation, let bmp = NSBitmapImageRep(data: tiff), let data = bmp.representation(using: .png, properties: [:]) {
            CustomStorage.shared.setImage(data: data, fileExtension: "png", forTag: tag)
            reload()
            selectedTag = tag
            currentTagInput = ""
            errorMessage = nil
            selectedImage = nil
            selectedImageData = nil
            selectedImageFileExtension = nil
        } else if let tiff = image.tiffRepresentation {
            CustomStorage.shared.setImage(data: tiff, fileExtension: "tiff", forTag: tag)
            reload()
            selectedTag = tag
            currentTagInput = ""
            errorMessage = nil
            selectedImage = nil
            selectedImageData = nil
            selectedImageFileExtension = nil
        }
    }

    func delete(tag: String) {
        CustomStorage.shared.removeImage(tag: tag)
        reload()
        if selectedTag?.lowercased() == tag.lowercased() {
            selectedTag = items.first?.tag
        }
        let key = tag.lowercased()
        if favoriteImageTags.contains(key) {
            favoriteImageTags.remove(key)
            saveFavorites()
        }
    }

    func addNew() {
        let base = "new_media_tag"
        var candidate = base
        var index = 1
        let existing = Set(items.map { $0.tag.lowercased() })
        while existing.contains(candidate.lowercased()) || CustomStorage.shared.getImageURL(forTag: candidate) != nil {
            index += 1
            candidate = "\(base)_\(index)"
        }
        selectedImage = nil
        currentTagInput = candidate
        selectedTag = candidate
    }

    func submitIfPossible() {
        let newTag = currentTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTag.isEmpty else { return }
        if let old = selectedTag {
            if old.lowercased() != newTag.lowercased() {
                let wasFavorite = favoriteImageTags.contains(old.lowercased())
                CustomStorage.shared.renameImageTag(oldTag: old, newTag: newTag)
                if wasFavorite {
                    favoriteImageTags.remove(old.lowercased())
                    favoriteImageTags.insert(newTag.lowercased())
                    saveFavorites()
                }
            }
            selectedTag = newTag
            reload()
        } else {
            selectedTag = newTag
        }
    }

    // MARK: - Favorites
    private func loadFavorites() {
        if let saved = UserDefaults.standard.array(forKey: "favoriteImageTags") as? [String] {
            favoriteImageTags = Set(saved.map { $0.lowercased() })
        }
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteImageTags), forKey: "favoriteImageTags")
    }

    func toggleFavorite(tag: String) {
        let key = tag.lowercased()
        if favoriteImageTags.contains(key) {
            favoriteImageTags.remove(key)
        } else {
            favoriteImageTags.insert(key)
        }
        saveFavorites()
    }
}

