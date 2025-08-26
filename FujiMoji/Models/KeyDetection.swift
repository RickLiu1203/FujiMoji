//
//  KeyDetection.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-08.
//
//  This model monitors keyboard input and detects strings typed after the "/" key.
//  
//  Usage:
//  1. Type "/" anywhere in any app
//  2. Type some text (e.g., "hello")
//  3. Type "/" again to complete detection
//  4. The string "hello" will be logged to detectedStrings array
//
//  Key behaviors:
//  - First "/" starts capturing mode
//  - Backspace removes characters while capturing
//  - Second "/" ends capturing and logs the string
//  - Empty strings are not logged

import Cocoa
import SwiftUI

class KeyDetection: ObservableObject {
    private var eventTap: CFMachPort?
    static let shared = KeyDetection()
    
    @Published var detectedStrings: [String] = []
    @Published var currentString = ""
    @Published var isCapturing = false
    
    private let startDelimiter = "/"
    private let endDelimiter = " "
    private var captureStarted = false 
    
    // Tracks digits immediately preceding the start delimiter when not capturing
    private var preDelimiterDigits = ""
    private var multiplier: Int = 1
    private var digitsCountBeforeStart: Int = 0
    private var lastDigitTypedAt: Date?
    private let digitValidityWindow: TimeInterval = 2.0

    // Toggle: when true, end capture on space; when false, replace immediately on exact tag match
    private var replaceOnSpaceEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "spaceToggle") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "spaceToggle") }
    }
    
    private init() {}
    
    private let callback: CGEventTapCallBack = { _, type, event, _ in
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        
        if let nsEvent = NSEvent(cgEvent: event) {
            if let characters = nsEvent.charactersIgnoringModifiers {
                let keyCode = nsEvent.keyCode
                
                // Handle backspace (key code 51)
                if keyCode == 51 {
                    KeyDetection.shared.handleBackspace()
                }
                else if keyCode == 49 { // Space key
                    if KeyDetection.shared.captureStarted && KeyDetection.shared.replaceOnSpaceEnabled {
                        KeyDetection.shared.handleCharacter(" ")
                        // Swallow the space so we can control re-insertion
                        return nil
                    } else {
                        KeyDetection.shared.handleCharacter(characters)
                    }
                } else if keyCode == 48 { // Tab key
                    if KeyDetection.shared.captureStarted {
                        // Finish capture on Tab WITHOUT inserting trailing space,
                        // and swallow the Tab so focus does not change
                        KeyDetection.shared.finishCapture(endWithSpace: false)
                        return nil
                    } else {
                        // Not capturing → let Tab behave normally
                        return Unmanaged.passUnretained(event)
                    }
                } else {
                    KeyDetection.shared.handleCharacter(characters)
                }
            }
        }
        return Unmanaged.passUnretained(event)
    }
    
    func start() {
        let mask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: nil
        )
        
        guard let eventTap = eventTap else {
            print("Failed to create event tap for KeyDetection")
            return
        }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        let modeDescription = replaceOnSpaceEnabled ? "[digits]?/tag␠ (space ends capture)" : "[digits]?/tag (immediate replacement)"
        print("KeyDetection started - monitoring pattern: \(modeDescription)")
    }
    
    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0),
                .commonModes
            )
            self.eventTap = nil
        }
        print("KeyDetection stopped")
    }
    
    private func handleCharacter(_ character: String) {
        if character == startDelimiter {
            if captureStarted {
                // If another start delimiter is typed while capturing, treat it as content
                DispatchQueue.main.async {
                    self.currentString += character
                }
            } else {
                // Determine multiplier from preceding digits
                let withinWindow: Bool
                if let last = lastDigitTypedAt {
                    withinWindow = Date().timeIntervalSince(last) <= digitValidityWindow
                } else {
                    withinWindow = false
                }
                if withinWindow, let parsed = Int(preDelimiterDigits), parsed > 0 {
                    multiplier = parsed
                    digitsCountBeforeStart = preDelimiterDigits.count
                } else {
                    multiplier = 1
                    digitsCountBeforeStart = 0
                }
                preDelimiterDigits = ""
                lastDigitTypedAt = nil
                // Opening delimiter - start capturing
                startCapture()
            }
        } else if character == endDelimiter && captureStarted && replaceOnSpaceEnabled {
            // Closing delimiter (space) - complete the capture
            finishCapture(endWithSpace: true)
        } else if captureStarted {
            // Add character to current string
            DispatchQueue.main.async {
                self.currentString += character
            }
            // If configured for immediate replacement, check for exact tag match after each keystroke
            if !replaceOnSpaceEnabled {
                if EmojiStorage.shared.findEmoji(forTag: self.currentString.lowercased()) != nil {
                    finishCapture(endWithSpace: false)
                }
            }
        } else {
            // Not capturing: track digits preceding a potential start delimiter
            if character.range(of: "^\\d$", options: .regularExpression) != nil {
                preDelimiterDigits.append(contentsOf: character)
                // Limit to last 9 digits to avoid unbounded growth
                if preDelimiterDigits.count > 9 {
                    preDelimiterDigits = String(preDelimiterDigits.suffix(9))
                }
                lastDigitTypedAt = Date()
            } else {
                preDelimiterDigits = ""
                lastDigitTypedAt = nil
            }
        }
    }
    
    private func handleBackspace() {
        if captureStarted {
            if currentString.isEmpty {
                // Backspacing when no content means we're deleting the opening delimiter
                stopCapture()
            } else {
                // Remove last character from current string
                DispatchQueue.main.async {
                    if !self.currentString.isEmpty {
                        self.currentString.removeLast()
                    }
                }
            }
        } else {
            // Keep preDelimiterDigits in sync when user backspaces while not capturing
            if !preDelimiterDigits.isEmpty {
                preDelimiterDigits.removeLast()
            }
        }
    }
    
    private func startCapture() {
        DispatchQueue.main.async {
            self.captureStarted = true
            self.isCapturing = true
            self.currentString = ""
            print("Started capturing after '\(self.startDelimiter)' key (end on space)")
        }
    }
    
    func finishCapture(endWithSpace: Bool) {
        let capturedString = currentString
        
        if !capturedString.isEmpty {
            DispatchQueue.main.async {
                self.detectedStrings.append(capturedString)
                print("Detected string: '\(capturedString)'")
                
                // Replace the (optional digits) + start + text + end with emoji(s)
                TextReplacement.shared.replaceWithEmoji(
                    capturedString,
                    startDelimiter: self.startDelimiter,
                    endDelimiter: endWithSpace ? self.endDelimiter : "",
                    multiplier: self.multiplier,
                    digitsCountBeforeStart: self.digitsCountBeforeStart,
                    endDelimiterPresentInDocument: endWithSpace
                )
            }
        }
        
        stopCapture()
    }
    
    private func stopCapture() {
        DispatchQueue.main.async {
            self.captureStarted = false
            self.isCapturing = false
            self.currentString = ""
            self.multiplier = 1
            self.digitsCountBeforeStart = 0
        }
    }
    
    // Public methods for external use
    func clearDetectedStrings() {
        DispatchQueue.main.async {
            self.detectedStrings.removeAll()
        }
    }
    
    func getLastDetectedString() -> String? {
        return detectedStrings.last
    }
    
    func getAllDetectedStrings() -> [String] {
        return detectedStrings
    }
}

