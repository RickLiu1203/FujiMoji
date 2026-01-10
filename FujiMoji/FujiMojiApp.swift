//
//  FujiMojiApp.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-06.
//

import SwiftUI
import AppKit

extension Notification.Name {
    static let popoverDidShow = Notification.Name("popoverDidShow")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = DetectedTextWindowController.shared
        _ = PredictionResultsWindowController.shared
        
        setupStatusItem()
        
        let hasShown = UserDefaults.standard.bool(forKey: "hasShownLanding")
        if !hasShown {
            LandingWindowController.shared.showFloating()
            UserDefaults.standard.set(true, forKey: "hasShownLanding")
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = createMenuBarIcon()
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 230, height: 450)
        popover.behavior = .transient
        popover.animates = true
        
        let fujiMojiState = FujiMojiState.shared
        let menuView = MenuView(fujiMojiState: fujiMojiState)
            .background(.ultraThinMaterial)
            .onAppear {
                fujiMojiState.checkInputMonitoringAuthorization()
            }
        
        popover.contentViewController = NSHostingController(rootView: menuView)
        self.popover = popover
        
        // Monitor for clicks outside popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }
    
    private func createMenuBarIcon() -> NSImage {
        let size = NSStatusBar.system.thickness - 4
        guard let base = NSImage(named: "MenuIcon") else {
            let fallback = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "FujiMoji")
            fallback?.isTemplate = true
            return fallback ?? NSImage()
        }
        let targetSize = NSSize(width: size, height: size)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        NSColor.clear.set()
        NSBezierPath(rect: NSRect(origin: .zero, size: targetSize)).fill()
        base.isTemplate = true
        base.draw(in: NSRect(origin: .zero, size: targetSize),
                  from: NSRect(origin: .zero, size: base.size),
                  operation: .sourceOver,
                  fraction: 1.0,
                  respectFlipped: true,
                  hints: [.interpolation: NSImageInterpolation.high])
        resized.unlockFocus()
        resized.isTemplate = true
        return resized
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ensure the popover window becomes key for interaction
            popover.contentViewController?.view.window?.makeKey()
            // Notify views that popover is now visible
            NotificationCenter.default.post(name: .popoverDidShow, object: nil)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        // Save recency cache before quitting
        EmojiStorage.shared.saveRecencyCacheNow()
    }
}

@main
struct FujiMojiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        // Empty Settings scene required for menu bar only apps
        Settings {
            EmptyView()
        }
    }
}