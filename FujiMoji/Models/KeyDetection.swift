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
    
    private var startDelimiter = "/"
    private var endDelimiter = "/"
    private var captureStarted = false 
    
    private var preDelimiterDigits = ""
    private var multiplier: Int = 1
    private var digitsCountBeforeStart: Int = 0
    private var lastDigitTypedAt: Date?
    private let digitValidityWindow: TimeInterval = 2.0

    // Remove space toggle logic - replacement now triggered by end delimiter, tab, or enter only
    
    private init() {
        // Load saved delimiters or use defaults
        startDelimiter = UserDefaults.standard.string(forKey: "startCaptureKey") ?? "/"
        endDelimiter = UserDefaults.standard.string(forKey: "endCaptureKey") ?? "/"
    }
    
    func updateDelimiters(start: String, end: String) {
        startDelimiter = start
        endDelimiter = end
    }
    
    var currentEndDelimiter: String {
        return endDelimiter
    }
    
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
                    if KeyDetection.shared.captureStarted {
                        // Space cancels capture AND prints space (unlike escape)
                        KeyDetection.shared.cancelCapture()
                        // Let the space character through by not consuming the event
                        return Unmanaged.passUnretained(event)
                    } else {
                        KeyDetection.shared.handleCharacter(" ")
                    }
                } else if keyCode == 48 { // Tab key
                    if KeyDetection.shared.captureStarted {
                        // Notify the popup to select the highlighted item
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .selectHighlightedSuggestion, object: nil)
                        }
                        // Fallback: ensure capture ends even if no observer reacts
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if KeyDetection.shared.captureStarted {
                                print("⏱️ Fallback: Tab triggered finishCapture due to no observer reaction")
                                KeyDetection.shared.finishCapture(triggerKeyConsumed: true)
                            }
                        }
                        return nil
                    } else {
                        return Unmanaged.passUnretained(event)
                    }
                } else if keyCode == 36 { // Enter/Return key
                    if KeyDetection.shared.captureStarted {
                        // Notify the popup to select the highlighted item
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .selectHighlightedSuggestion, object: nil)
                        }
                        // Fallback: ensure capture ends even if no observer reacts
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if KeyDetection.shared.captureStarted {
                                print("⏱️ Fallback: Enter triggered finishCapture due to no observer reaction")
                                KeyDetection.shared.finishCapture(triggerKeyConsumed: true)
                            }
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
                    // Handle other end delimiters that might be typed (excluding space)
                    if KeyDetection.shared.captureStarted && characters == KeyDetection.shared.currentEndDelimiter && characters != " " {
                        // Custom end delimiter - consume and trigger suggestion logic
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .selectHighlightedSuggestion, object: nil)
                        }
                        // Fallback: ensure capture ends even if no observer reacts
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if KeyDetection.shared.captureStarted {
                                print("⏱️ Fallback: End delimiter triggered finishCapture due to no observer reaction")
                                KeyDetection.shared.finishCapture(triggerKeyConsumed: true)
                            }
                        }
                        return nil
                    } else {
                        KeyDetection.shared.handleCharacter(characters)
                    }
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
        
        print("KeyDetection started - monitoring pattern: [digits]?/tag[delimiter/tab/enter] (triggers replacement)")
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
        // Check for end delimiter first when capturing (handles same start/end delimiter case)
        if character == endDelimiter && captureStarted {
            // End delimiter triggers suggestion logic (except for space which cancels)
            if endDelimiter != " " { // Space always cancels in callback
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .selectHighlightedSuggestion, object: nil)
                }
            }
        } else if character == startDelimiter {
            if captureStarted {
                // If we're already capturing and this is the start delimiter (but not end delimiter),
                // add it to the captured string
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
        } else if captureStarted {
            DispatchQueue.main.async {
                self.currentString += character
            }
            // Remove immediate mode replacement - only triggered by end delimiter, tab, or enter
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
            let endTrigger: String
            if self.endDelimiter == " " {
                endTrigger = "none (space cancels)"
            } else if self.endDelimiter == self.startDelimiter {
                endTrigger = "'\(self.endDelimiter)' (same as start)"
            } else {
                endTrigger = "'\(self.endDelimiter)'"
            }
            print("🚀 Started capturing after '\(self.startDelimiter)' key (triggers: \(endTrigger), tab, or enter; space cancels + prints)")
            print("🔍 DEBUG: captureStarted = \(self.captureStarted)")
        }
    }
    
    func finishCapture(triggerKeyConsumed: Bool) {
        let capturedString = currentString
        
        if !capturedString.isEmpty {
            DispatchQueue.main.async {
                self.detectedStrings.append(capturedString)
                print("Detected string: '\(capturedString)'")
                
                let replacementSuccess = TextReplacement.shared.replaceWithEmoji(
                    capturedString,
                    startDelimiter: self.startDelimiter,
                    multiplier: self.multiplier,
                    digitsCountBeforeStart: self.digitsCountBeforeStart,
                    triggerKeyConsumed: triggerKeyConsumed
                )
                
                if !replacementSuccess {
                    print("🔍 No replacement occurred for '\(capturedString)', but capture will still end")
                }
            }
        } else {
            print("🔍 Captured string was empty, but capture will still end")
        }
        
        // Always stop capture regardless of whether replacement occurred
        stopCapture()
    }
    
    // Finish capture by directly specifying the replacement unit (emoji or custom string)
    func finishCaptureWithDirectReplacement(_ replacementUnit: String, endWithSpace: Bool) {
        let capturedString = currentString
        
        if !capturedString.isEmpty {
            DispatchQueue.main.async {
                self.detectedStrings.append(capturedString)
                let replacementSuccess = TextReplacement.shared.replaceWithUnit(
                    replacementUnit,
                    forCapturedText: capturedString,
                    startDelimiter: self.startDelimiter,
                    multiplier: self.multiplier,
                    digitsCountBeforeStart: self.digitsCountBeforeStart,
                    triggerKeyConsumed: true // Popup selections ARE triggered by consumed keys (tab/enter/end delimiter)
                )
                
                if !replacementSuccess {
                    print("🔍 No replacement occurred for '\(capturedString)', but capture will still end")
                }
            }
        }
        
        // Always stop capture regardless of whether replacement occurred
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
            print("🛑 Capture stopped immediately - ready for next capture")
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

