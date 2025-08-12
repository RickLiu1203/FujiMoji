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
    
    private var delimiter = "/"
    private var captureStarted = false 
    
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
                else {
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
            options: .listenOnly,
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
        
        print("KeyDetection started - monitoring for strings after '\(KeyDetection.shared.delimiter)' key")
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
        if character == delimiter {
            if captureStarted {
                // Closing delimiter - complete the capture
                finishCapture()
            } else {
                // Opening delimiter - start capturing
                startCapture()
            }
        } else if captureStarted {
            // Add character to current string
            DispatchQueue.main.async {
                self.currentString += character
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
        }
    }
    
    private func startCapture() {
        DispatchQueue.main.async {
            self.captureStarted = true
            self.isCapturing = true
            self.currentString = ""
            print("Started capturing after '\(self.delimiter)' key")
        }
    }
    
    private func finishCapture() {
        let capturedString = currentString
        
        if !capturedString.isEmpty {
            DispatchQueue.main.async {
                self.detectedStrings.append(capturedString)
                print("Detected string: '\(capturedString)'")
                
                // Replace the delimiter + text + delimiter with an emoji
                TextReplacement.shared.replaceWithEmoji(capturedString, delimiter: self.delimiter)
            }
        }
        
        stopCapture()
    }
    
    private func stopCapture() {
        DispatchQueue.main.async {
            self.captureStarted = false
            self.isCapturing = false
            self.currentString = ""
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

