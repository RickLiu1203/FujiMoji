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
    private var globalMouseMonitor: Any?
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

    
    private init() {
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
            
            if KeyDetection.shared.captureStarted {
                if keyCode == 123 { // Left arrow
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .navigateLeft, object: nil)
                    }
                    return nil 
                } else if keyCode == 124 { // Right arrow
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .navigateRight, object: nil)
                    }
                    return nil 
                } else if keyCode == 126 { // Up arrow
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .navigateDown, object: nil)
                    }
                    return nil 
                } else if keyCode == 125 { // Down arrow
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .navigateUp, object: nil)
                    }
                    return nil 
                }
            }
            
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
                        KeyDetection.shared.cancelCapture()
                        return Unmanaged.passUnretained(event)
                    } else {
                        KeyDetection.shared.handleCharacter(" ")
                    }
                } else if keyCode == 48 { // Tab key
                    if KeyDetection.shared.captureStarted {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .selectHighlightedSuggestion, object: nil)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if KeyDetection.shared.captureStarted {
                                KeyDetection.shared.finishCapture(triggerKeyConsumed: true)
                            }
                        }
                        return nil
                    } else {
                        return Unmanaged.passUnretained(event)
                    }
                } else if keyCode == 36 { // Enter key
                    if KeyDetection.shared.captureStarted {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .selectHighlightedSuggestion, object: nil)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if KeyDetection.shared.captureStarted {
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
                    if KeyDetection.shared.captureStarted && characters == KeyDetection.shared.currentEndDelimiter && characters != " " {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .selectHighlightedSuggestion, object: nil)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if KeyDetection.shared.captureStarted {
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
            DispatchQueue.main.async {
                FujiMojiState.shared.needsInputMonitoring = true
            }
            return
        }
                
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        DispatchQueue.main.async {
            FujiMojiState.shared.needsInputMonitoring = false
        }
        
        setupLocalEventMonitor()
        
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
        
        if let mouseMonitor = globalMouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            globalMouseMonitor = nil
        }
        
    }
    
    private func setupLocalEventMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            
            let keyCode = event.keyCode
            
            if self.captureStarted && (keyCode == 123 || keyCode == 124 || keyCode == 125 || keyCode == 126) {
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
                return nil 
            }
            
            return event 
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            
            let keyCode = event.keyCode
            
            if self.captureStarted && (keyCode == 123 || keyCode == 124 || keyCode == 125 || keyCode == 126) {
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
        
        if globalMouseMonitor == nil {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { _ in
                if KeyDetection.shared.isCapturing {
                    DispatchQueue.main.async {
                        KeyDetection.shared.cancelCapture()
                    }
                    return
                }

                let isPopupVisible = (DetectedTextWindowController.shared.window?.isVisible == true) || (PredictionResultsWindowController.shared.window?.isVisible == true)
                if isPopupVisible { return }

                let mousePoint = NSEvent.mouseLocation
                let targetScreen = NSScreen.screens.first { screen in
                    NSMouseInRect(mousePoint, screen.frame, false)
                } ?? NSScreen.main
                guard let screen = targetScreen else { return }
                let visible = screen.visibleFrame
                let quarterY = visible.minY + (visible.height * 0.3)
                if mousePoint.y <= quarterY {
                    FujiMojiState.shared.popupAnchor = .top
                } else {
                    FujiMojiState.shared.popupAnchor = .bottom
                }
            }
        }
    }
    
    private func handleCharacter(_ character: String) {
        if character == endDelimiter && captureStarted {
            if endDelimiter != " " { 
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .selectHighlightedSuggestion, object: nil)
                }
            }
        } else if character == startDelimiter {
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
        } else if captureStarted {
            DispatchQueue.main.async {
                self.currentString += character
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
        }
    }
    
    func finishCapture(triggerKeyConsumed: Bool) {
        let capturedString = currentString
        
        if !capturedString.isEmpty {
            DispatchQueue.main.async {
                self.detectedStrings.append(capturedString)
                
                let replacementSuccess = TextReplacement.shared.replaceWithEmoji(
                    capturedString,
                    startDelimiter: self.startDelimiter,
                    multiplier: self.multiplier,
                    digitsCountBeforeStart: self.digitsCountBeforeStart,
                    triggerKeyConsumed: triggerKeyConsumed
                )
                
                if !replacementSuccess {
                }
            }
        } else {
        }
        
        stopCapture()
    }
    
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
                    triggerKeyConsumed: true 
                )
                
                if !replacementSuccess {
                }
            }
        }
        
        stopCapture()
    }

    // Image tag replacement that preserves correct deletion semantics
    func finishCaptureWithImageTag(_ tag: String) {
        let capturedString = currentString

        if !capturedString.isEmpty {
            DispatchQueue.main.async {
                self.detectedStrings.append(capturedString)
                _ = TextReplacement.shared.replaceWithImageTag(
                    tag,
                    forCapturedText: capturedString,
                    startDelimiter: self.startDelimiter,
                    multiplier: self.multiplier,
                    digitsCountBeforeStart: self.digitsCountBeforeStart,
                    triggerKeyConsumed: true
                )
            }
        }

        stopCapture()
    }

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

