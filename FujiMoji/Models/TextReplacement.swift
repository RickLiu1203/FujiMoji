import Cocoa
import Carbon

class TextReplacement {
    static let shared = TextReplacement()
    private let emojiStorage = EmojiStorage.shared
    private let pasteboard = NSPasteboard.general
    
    private init() {}
    
    /// Replaces the captured text (including delimiters) with an emoji (optionally repeated)
    /// - Parameters:
    ///   - capturedText: The text that was captured after the opening delimiter
    ///   - startDelimiter: The opening delimiter character(s) used (e.g., "/")
    ///   - endDelimiter: The closing delimiter character(s) used (e.g., " ")
    ///   - multiplier: How many times to repeat the resulting emoji (minimum 1)
    ///   - digitsCountBeforeStart: Number of numeric characters immediately before the opening delimiter to also delete
    ///   - endDelimiterPresentInDocument: If true, delete the end delimiter from the document; if false, do not (e.g., when the space was swallowed)
    func replaceWithEmoji(_ capturedText: String, startDelimiter: String, endDelimiter: String, multiplier: Int, digitsCountBeforeStart: Int, endDelimiterPresentInDocument: Bool) {
        // Look up the emoji using our storage
        let emoji = emojiStorage.findEmoji(forTag: capturedText.lowercased()) ?? "❓"
        
        // Calculate how many characters to delete (digits + start + content + optional end)
        let endCount = endDelimiterPresentInDocument ? endDelimiter.count : 0
        let totalCharactersToDelete = max(0, digitsCountBeforeStart) + startDelimiter.count + capturedText.count + endCount
        
        // Delete the typed text. When capture ended on space, we swallowed that space key event, so deleting endDelimiter here still works.
        deleteCharacters(count: totalCharactersToDelete)
        
        // Insert the emoji, repeated by the multiplier, plus the trailing end delimiter (single event)
        let repeatCount = max(1, multiplier)
        let replacement = String(repeating: emoji, count: repeatCount) + endDelimiter
        // Always use paste-based insertion for maximum compatibility across apps
        pasteInsert(replacement)
        
        print("Replaced '\(String(repeating: "#", count: digitsCountBeforeStart))\(startDelimiter)\(capturedText)\(endDelimiter)' with \(repeatCount)x \(emoji)")
    }
    
    /// Deletes a specified number of characters by simulating backspace key presses
    private func deleteCharacters(count: Int) {
        for _ in 0..<count {
            simulateBackspace()
        }
    }
    
    /// Inserts text by simulating typing
    private func insertText(_ text: String) {
        let utf16CodeUnits = Array(text.utf16)
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        keyDownEvent?.keyboardSetUnicodeString(stringLength: utf16CodeUnits.count, unicodeString: utf16CodeUnits)
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
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
        
        // Only set Unicode on keyDown to avoid duplicate character issues in terminals
        keyDownEvent?.keyboardSetUnicodeString(stringLength: utf16CodeUnits.count, unicodeString: utf16CodeUnits)
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Pasteboard fallback for stubborn apps
    private func shouldUsePasteFallback() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        // Common terminals/editors that may mishandle synthetic key events
        let fallbackApps: Set<String> = [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.googlecode.iterm2",
            "com.apple.Terminal",
            "com.jetbrains.toolbox", // JetBrains Toolbox launchers
            "com.jetbrains.intellij",
            "com.jetbrains.goland",
            "com.jetbrains.pycharm",
            "org.alacritty"
        ]
        return fallbackApps.contains(app)
    }
    
    private func pasteInsert(_ text: String) {
        // Save current clipboard (string only to avoid NSPasteboardItem ownership issues)
        let savedString = pasteboard.string(forType: .string)
        
        // Write our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate Cmd down, 'v', Cmd up with slight delays for reliability across apps
        let vKey: CGKeyCode = 9   // 'v'
        let cmdKey: CGKeyCode = 55 // left command
        
        let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: cmdKey, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: cmdKey, keyDown: false)
        
        // Post with small scheduling to ensure pasteboard is ready
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
        
        // Best-effort restore previous clipboard string after a slightly longer delay to avoid race
        if let previous = savedString {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.pasteboard.clearContents()
                self.pasteboard.setString(previous, forType: .string)
            }
        }
    }
} 