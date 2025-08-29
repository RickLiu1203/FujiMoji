//
//  KeyDetection.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-08.
//

import Cocoa
import SwiftUI

// MARK: - Notification Names for Arrow Key Navigation
extension Notification.Name {
    static let selectHighlightedSuggestion = Notification.Name("selectHighlightedSuggestion")
    static let navigateLeft = Notification.Name("navigateLeft")
    static let navigateRight = Notification.Name("navigateRight")
    static let navigateUp = Notification.Name("navigateUp")
    static let navigateDown = Notification.Name("navigateDown")
}

class KeyDetection: ObservableObject {
    private var eventTap: CFMachPort?
    private var localEventMonitor: Any?
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
            let keyCode = nsEvent.keyCode
            
            // PRIORITY: Block arrow keys during capture BEFORE any other processing
            if KeyDetection.shared.captureStarted {
                if keyCode == 123 { // Left arrow
                    print("🔍 DEBUG: Global event tap - BLOCKING Left arrow during capture")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .navigateLeft, object: nil)
                    }
                    return nil // BLOCK THE EVENT
                } else if keyCode == 124 { // Right arrow
                    print("🔍 DEBUG: Global event tap - BLOCKING Right arrow during capture")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .navigateRight, object: nil)
                    }
                    return nil // BLOCK THE EVENT
                } else if keyCode == 126 { // Up arrow
                    print("🔍 DEBUG: Global event tap - BLOCKING Up arrow during capture")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .navigateDown, object: nil)
                    }
                    return nil // BLOCK THE EVENT
                } else if keyCode == 125 { // Down arrow
                    print("🔍 DEBUG: Global event tap - BLOCKING Down arrow during capture")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .navigateUp, object: nil)
                    }
                    return nil // BLOCK THE EVENT
                }
            }
            
            // Ignore shortcuts and non-text keystrokes: don't process when Command/Control/Fn are held
            let flags = nsEvent.modifierFlags
            if flags.contains(.command) || flags.contains(.control) || flags.contains(.function) {
                return Unmanaged.passUnretained(event)
            }
            if let characters = nsEvent.charactersIgnoringModifiers {
                
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
                        // Notify the popup to select the highlighted item
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .selectHighlightedSuggestion, object: nil)
                        }
                        return nil
                    } else {
                        return Unmanaged.passUnretained(event)
                    }
                } else if keyCode == 53 { // Escape key
                    if KeyDetection.shared.captureStarted {
                        KeyDetection.shared.cancelCapture()
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
            print("❌ Failed to create event tap for KeyDetection")
            // Check if we have accessibility permissions
            let trusted = AXIsProcessTrusted()
            print("🔍 DEBUG: Process trusted (accessibility permissions): \(trusted)")
            return
        }
        
        print("✅ Event tap created successfully")
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        // Add local event monitor as backup for arrow keys
        setupLocalEventMonitor()
        
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
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        print("KeyDetection stopped")
    }
    
    private func setupLocalEventMonitor() {
        // Aggressive local event monitor that blocks arrow keys during capture
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            
            let keyCode = event.keyCode
            
            // AGGRESSIVE BLOCKING: Arrow keys during capture are ALWAYS consumed
            if self.captureStarted && (keyCode == 123 || keyCode == 124 || keyCode == 125 || keyCode == 126) {
                print("🔍 DEBUG: Local monitor - AGGRESSIVELY BLOCKING arrow key \(keyCode) during capture")
                DispatchQueue.main.async {
                    if keyCode == 123 {
                        NotificationCenter.default.post(name: .navigateLeft, object: nil)
                    } else if keyCode == 124 {
                        NotificationCenter.default.post(name: .navigateRight, object: nil)
                    } else if keyCode == 125 {
                        NotificationCenter.default.post(name: .navigateDown, object: nil)
                    } else if keyCode == 126 {
                        NotificationCenter.default.post(name: .navigateUp, object: nil)
                    }
                }
                return nil // DEFINITELY CONSUME THE EVENT
            }
            
            return event // Let other events pass through
        }
        print("✅ Local event monitor set up")
        
        // Also add a global event monitor as backup
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            
            let keyCode = event.keyCode
            
            if self.captureStarted && (keyCode == 123 || keyCode == 124 || keyCode == 125 || keyCode == 126) {
                print("🔍 DEBUG: Global monitor - Arrow key during capture - keyCode: \(keyCode)")
                DispatchQueue.main.async {
                    if keyCode == 123 {
                        NotificationCenter.default.post(name: .navigateLeft, object: nil)
                    } else if keyCode == 124 {
                        NotificationCenter.default.post(name: .navigateRight, object: nil)
                    } else if keyCode == 125 {
                        NotificationCenter.default.post(name: .navigateDown, object: nil)
                    } else if keyCode == 126 {
                        NotificationCenter.default.post(name: .navigateUp, object: nil)
                    }
                }
            }
        }
        print("✅ Global event monitor set up")
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
            print("🚀 Started capturing after '\(self.startDelimiter)' key (end on space)")
            print("🔍 DEBUG: captureStarted = \(self.captureStarted)")
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
    
    // Finish capture by directly specifying the replacement unit (emoji or custom string)
    func finishCaptureWithDirectReplacement(_ replacementUnit: String, endWithSpace: Bool) {
        let capturedString = currentString
        if !capturedString.isEmpty {
            DispatchQueue.main.async {
                self.detectedStrings.append(capturedString)
                TextReplacement.shared.replaceWithUnit(
                    replacementUnit,
                    forCapturedText: capturedString,
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

    // Public cancel without replacement
    func cancelCapture() {
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

