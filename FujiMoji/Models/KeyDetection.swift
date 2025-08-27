//
//  KeyDetection.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-08.
//

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
    
    private var preDelimiterDigits = ""
    private var multiplier: Int = 1
    private var digitsCountBeforeStart: Int = 0
    private var lastDigitTypedAt: Date?
    private let digitValidityWindow: TimeInterval = 2.0

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
                
                if keyCode == 51 {
                    KeyDetection.shared.handleBackspace()
                }
                else if keyCode == 49 { // Space key
                    if KeyDetection.shared.captureStarted && KeyDetection.shared.replaceOnSpaceEnabled {
                        KeyDetection.shared.handleCharacter(" ")
                        return nil
                    } else {
                        KeyDetection.shared.handleCharacter(characters)
                    }
                } else if keyCode == 48 { // Tab key
                    if KeyDetection.shared.captureStarted {
                        KeyDetection.shared.finishCapture(endWithSpace: false)
                        return nil
                    } else {
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
                DispatchQueue.main.async {
                    self.currentString += character
                }
            } else {
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
                startCapture()
            }
        } else if character == endDelimiter && captureStarted && replaceOnSpaceEnabled {
            finishCapture(endWithSpace: true)
        } else if captureStarted {
            DispatchQueue.main.async {
                self.currentString += character
            }
            if !replaceOnSpaceEnabled {
                // Immediate mode: replace as soon as we have a match. Prefer custom mappings.
                let tag = self.currentString.lowercased()
                let hasCustom = CustomStorage.shared.getText(forTag: tag) != nil
                let hasEmoji = EmojiStorage.shared.findEmoji(forTag: tag) != nil
                if hasCustom || hasEmoji {
                    finishCapture(endWithSpace: false)
                }
            }
        } else {
            if character.range(of: "^\\d$", options: .regularExpression) != nil {
                preDelimiterDigits.append(contentsOf: character)
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

