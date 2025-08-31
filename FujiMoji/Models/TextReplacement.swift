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
} 