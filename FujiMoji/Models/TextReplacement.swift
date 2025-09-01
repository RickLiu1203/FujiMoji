//
//  TextReplacement.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-20.
//

import Cocoa
import Carbon

class TextReplacement {
    static let shared = TextReplacement()
    private let emojiStorage = EmojiStorage.shared
    private let pasteboard = NSPasteboard.general
    
    private init() {}
    
    func replaceWithEmoji(_ capturedText: String, startDelimiter: String, multiplier: Int, digitsCountBeforeStart: Int, triggerKeyConsumed: Bool) -> Bool {
        let normalizedTag = capturedText.lowercased()
        // First, try image replacement if an image tag exists
        if let imageURL = CustomStorage.shared.getImageURL(forTag: normalizedTag) {
            let triggerKeyCount = triggerKeyConsumed ? 0 : 1
            let totalCharactersToDelete = max(0, digitsCountBeforeStart) + startDelimiter.count + capturedText.count + triggerKeyCount
            deleteCharacters(count: totalCharactersToDelete)

            let repeatCount = max(1, multiplier)
            pasteInsertImage(from: imageURL, times: repeatCount)
            return true
        }

        let customText = CustomStorage.shared.getText(forTag: normalizedTag)
        let emoji = customText ?? emojiStorage.findEmoji(forTag: normalizedTag)
        
        guard let replacementUnit = emoji else {
            return false
        }

        let triggerKeyCount = triggerKeyConsumed ? 0 : 1
        let totalCharactersToDelete = max(0, digitsCountBeforeStart) + startDelimiter.count + capturedText.count + triggerKeyCount

        deleteCharacters(count: totalCharactersToDelete)

        let repeatCount = max(1, multiplier)
        let replacement = String(repeating: replacementUnit, count: repeatCount)
        pasteInsert(replacement)

        return true
    }


    func replaceWithUnit(_ replacementUnit: String, forCapturedText capturedText: String, startDelimiter: String, multiplier: Int, digitsCountBeforeStart: Int, triggerKeyConsumed: Bool) -> Bool {
        guard !replacementUnit.isEmpty else {
            return false
        }
        
        let triggerKeyCount = triggerKeyConsumed ? 0 : 1
        let totalCharactersToDelete = max(0, digitsCountBeforeStart) + startDelimiter.count + capturedText.count + triggerKeyCount
        deleteCharacters(count: totalCharactersToDelete)

        let repeatCount = max(1, multiplier)
        let replacement = String(repeating: replacementUnit, count: repeatCount)
        pasteInsert(replacement)
        return true
    }
    
    func replaceWithImageTag(_ tag: String, forCapturedText capturedText: String, startDelimiter: String, multiplier: Int, digitsCountBeforeStart: Int, triggerKeyConsumed: Bool) -> Bool {
        let normalizedTag = tag.lowercased()
        guard let imageURL = CustomStorage.shared.getImageURL(forTag: normalizedTag) else { return false }
        let triggerKeyCount = triggerKeyConsumed ? 0 : 1
        let totalCharactersToDelete = max(0, digitsCountBeforeStart) + startDelimiter.count + capturedText.count + triggerKeyCount
        deleteCharacters(count: totalCharactersToDelete)
        let repeatCount = max(1, multiplier)
        pasteInsertImage(from: imageURL, times: repeatCount)
        return true
    }
    
    private func deleteCharacters(count: Int) {
        for _ in 0..<count {
            simulateBackspace()
        }
    }
    
    private func insertText(_ text: String) {
        let utf16CodeUnits = Array(text.utf16)
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        keyDownEvent?.keyboardSetUnicodeString(stringLength: utf16CodeUnits.count, unicodeString: utf16CodeUnits)
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    private func simulateBackspace() {
        let keyCode: CGKeyCode = 51
        
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    private func simulateTyping(_ character: String) {
        let utf16CodeUnits = Array(character.utf16)
        
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        
        keyDownEvent?.keyboardSetUnicodeString(stringLength: utf16CodeUnits.count, unicodeString: utf16CodeUnits)
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    private func pasteInsert(_ text: String) {
        let savedString = pasteboard.string(forType: .string)
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        let vKey: CGKeyCode = 9
        let cmdKey: CGKeyCode = 55
        
        let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: cmdKey, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: cmdKey, keyDown: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            cmdDown?.flags = .maskCommand
            cmdDown?.post(tap: .cghidEventTap)
            vDown?.flags = .maskCommand
            vDown?.post(tap: .cghidEventTap)
            vUp?.flags = .maskCommand
            vUp?.post(tap: .cghidEventTap)
            cmdUp?.flags = .maskCommand
            cmdUp?.post(tap: .cghidEventTap)
        }
        
        if let previous = savedString {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.pasteboard.clearContents()
                self.pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private func pasteInsertImage(from url: URL, times: Int) {
        let savedString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        if let data = try? Data(contentsOf: url) {
            let ext = url.pathExtension.lowercased()
            if ext == "gif" {
                let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")
                let item = NSPasteboardItem()
                item.setData(data, forType: gifType)
                item.setString(url.absoluteString, forType: .fileURL)
                pasteboard.clearContents()
                pasteboard.writeObjects([item])
            } else {
                var typeToSet: NSPasteboard.PasteboardType? = nil
                switch ext {
                case "png": typeToSet = .png
                case "jpg", "jpeg": typeToSet = NSPasteboard.PasteboardType("public.jpeg")
                case "tif", "tiff": typeToSet = .tiff
                case "heic": typeToSet = NSPasteboard.PasteboardType("public.heic")
                case "heif": typeToSet = NSPasteboard.PasteboardType("public.heif")
                case "bmp": typeToSet = NSPasteboard.PasteboardType("com.microsoft.bmp")
                case "webp": typeToSet = NSPasteboard.PasteboardType("org.webmproject.webp")
                default: typeToSet = nil
                }
                if let type = typeToSet {
                    _ = pasteboard.setData(data, forType: type)
                } else if let img = NSImage(data: data) {
                    _ = pasteboard.writeObjects([img])
                } else {
                    _ = pasteboard.writeObjects([url as NSURL])
                }
            }
        } else if let img = NSImage(contentsOf: url) {
            _ = pasteboard.writeObjects([img])
        } else {
            _ = pasteboard.writeObjects([url as NSURL])
        }

        let vKey: CGKeyCode = 9
        let cmdKey: CGKeyCode = 55

        for i in 0..<max(1, times) {
            let baseDelay = 0.01 + (0.1 * Double(i))
            let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: cmdKey, keyDown: true)
            let vDown = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: true)
            let vUp = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: false)
            let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: cmdKey, keyDown: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay) {
                cmdDown?.flags = .maskCommand
                cmdDown?.post(tap: .cghidEventTap)
                vDown?.flags = .maskCommand
                vDown?.post(tap: .cghidEventTap)
                vUp?.flags = .maskCommand
                vUp?.post(tap: .cghidEventTap)
                cmdUp?.flags = .maskCommand
                cmdUp?.post(tap: .cghidEventTap)
            }
        }

        if let previous = savedString {
            let restoreDelay = 0.25 + (0.1 * Double(max(0, times - 1)))
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                self.pasteboard.clearContents()
                self.pasteboard.setString(previous, forType: .string)
            }
        }
    }
} 