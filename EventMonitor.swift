import Cocoa
import SwiftUI

class EventMonitor {
    private var eventTap: CFMachPort?
    var emojiMap: [String: String] = [:]
    private var textView: NSTextView?
    static let shared = EventMonitor()
    var typedString = ""
    
    
    @AppStorage("spaceToggle") private var spaceToggle: Bool = true // Add this line to use AppStorage

    private init() {
        loadEmojiMappings()
    }

    private let callback: CGEventTapCallBack = { _, type, event, _ in
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        if let nsEvent = NSEvent(cgEvent: event) {
            if let characters = nsEvent.charactersIgnoringModifiers {
                if nsEvent.keyCode == 51 { // Key code for backspace
                    if !EventMonitor.shared.typedString.isEmpty {
                        EventMonitor.shared.typedString.removeLast()
                    }
                } else {
                    EventMonitor.shared.typedString.append(characters.lowercased())

                    // Check for emoji replacement immediately if spaceToggle is off
                    if !EventMonitor.shared.spaceToggle {
                        if let (prefixIndex, emoji, repeatCount) = EventMonitor.shared.checkForEmoji(replaceOnSpace: false) {
                            EventMonitor.shared.deleteCharacters(count: EventMonitor.shared.typedString.count - prefixIndex)
                            EventMonitor.shared.replaceWithEmoji(emoji: emoji, repeatCount: repeatCount, event: event)
                            EventMonitor.shared.typedString = ""
                            return nil
                        }
                    }

                    // Check for emoji replacement if spaceToggle is on and a space is typed
                    if EventMonitor.shared.spaceToggle && characters == " " {
                        if let (prefixIndex, emoji, repeatCount) = EventMonitor.shared.checkForEmoji(replaceOnSpace: true) {
                            EventMonitor.shared.deleteCharacters(count: EventMonitor.shared.typedString.count - prefixIndex)
                            EventMonitor.shared.replaceWithEmoji(emoji: emoji, repeatCount: repeatCount, event: event)
                            EventMonitor.shared.typedString = ""
                            return nil
                        }
                    }
                }
            }
        }
        return Unmanaged.passUnretained(event)
    }

    func start() {
        let mask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: CGEventMask(mask), callback: callback, userInfo: nil)

        guard let eventTap = eventTap else {
            print("Failed to create event tap")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0), .commonModes)
            self.eventTap = nil
        }
    }

    func checkForEmoji(replaceOnSpace: Bool) -> (Int, String, Int)? {
        for (key, value) in emojiMap {
            let patterns = [":\(key):", "/\(key)"]
            for pattern in patterns {
                if replaceOnSpace {
                    if typedString.hasSuffix(pattern + " ") {
                        let patternStartIndex = typedString.index(typedString.endIndex, offsetBy: -(pattern.count + 1))
                        let prefixRange = typedString[..<patternStartIndex]
                        if let match = prefixRange.range(of: #"(\d*)$"#, options: .regularExpression) {
                            let prefix = String(prefixRange[match])
                            let repeatCount = Int(prefix) ?? 1
                            return (typedString.count - pattern.count - 1 - prefix.count, value, repeatCount)
                        } else {
                            return (typedString.count - pattern.count - 1, value, 1)
                        }
                    }
                } else {
                    if typedString.hasSuffix(pattern) {
                        let patternStartIndex = typedString.index(typedString.endIndex, offsetBy: -pattern.count)
                        let prefixRange = typedString[..<patternStartIndex]
                        if let match = prefixRange.range(of: #"(\d*)$"#, options: .regularExpression) {
                            let prefix = String(prefixRange[match])
                            let repeatCount = Int(prefix) ?? 1
                            return (typedString.count - pattern.count - prefix.count, value, repeatCount)
                        } else {
                            return (typedString.count - pattern.count, value, 1)
                        }
                    } else if pattern.hasPrefix("/") && typedString.hasSuffix(key) {
                        let patternStartIndex = typedString.index(typedString.endIndex, offsetBy: -key.count)
                        let suffixRange = typedString[..<patternStartIndex]
                        if suffixRange.hasSuffix("/") {
                            let numberStartIndex = suffixRange.index(suffixRange.endIndex, offsetBy: -1)
                            if let repeatCount = Int(suffixRange[numberStartIndex...]) {
                                return (typedString.count - key.count - 2, value, repeatCount)
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    func deleteCharacters(count: Int) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<count {
            let deleteEvent = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true)
            deleteEvent?.post(tap: .cghidEventTap)
            let deleteEventUp = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false)
            deleteEventUp?.post(tap: .cghidEventTap)
        }
    }

    func replaceWithEmoji(emoji: String, repeatCount: Int, event: CGEvent) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let replacementString = String(repeating: emoji, count: repeatCount)
        let replacementEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        
        let replacementUniChars = Array(replacementString.utf16)
        replacementEvent?.keyboardSetUnicodeString(stringLength: replacementUniChars.count, unicodeString: replacementUniChars)
        
        replacementEvent?.post(tap: .cghidEventTap)
    }

    func setTextView(_ textView: NSTextView) {
        self.textView = textView
    }

    func loadEmojiMappings() {
        guard let url = Bundle.main.url(forResource: "emojiMappings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mappings = try? JSONDecoder().decode([String: String].self, from: data) else {
            print("Failed to load emoji mappings")
            return
        }
        self.emojiMap = mappings
    }
}

