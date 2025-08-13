import Cocoa
import Carbon

class TextReplacement {
    static let shared = TextReplacement()
    private let emojiStorage = EmojiStorage.shared
    
    private init() {}
    
    /// Replaces the captured text (including delimiters) with an emoji
    /// - Parameters:
    ///   - capturedText: The text that was captured between delimiters
    ///   - delimiter: The delimiter character used
    func replaceWithEmoji(_ capturedText: String, delimiter: String) {
        // Look up the emoji using our storage
        let emoji = emojiStorage.findEmoji(forTag: capturedText) ?? "❓"
        
        // Calculate how many characters to delete:
        let totalCharactersToDelete = delimiter.count + capturedText.count + delimiter.count
        
        // Delete the typed text
        deleteCharacters(count: totalCharactersToDelete)
        
        // Insert the emoji
        insertText(emoji)
        
        print("Replaced '\(delimiter)\(capturedText)\(delimiter)' with \(emoji)")
    }
    
    /// Deletes a specified number of characters by simulating backspace key presses
    private func deleteCharacters(count: Int) {
        for _ in 0..<count {
            simulateBackspace()
        }
    }
    
    /// Inserts text by simulating typing
    private func insertText(_ text: String) {
        for character in text {
            simulateTyping(String(character))
        }
    }
    
    /// Simulates a backspace key press
    private func simulateBackspace() {
        let keyCode: CGKeyCode = 51 // Backspace key code
        
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    /// Simulates typing a character
    private func simulateTyping(_ character: String) {
        // Convert the character to UTF-16 code units
        let utf16CodeUnits = Array(character.utf16)
        
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        
        // Set the Unicode string for the event
        keyDownEvent?.keyboardSetUnicodeString(stringLength: utf16CodeUnits.count, unicodeString: utf16CodeUnits)
        keyUpEvent?.keyboardSetUnicodeString(stringLength: utf16CodeUnits.count, unicodeString: utf16CodeUnits)
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
} 