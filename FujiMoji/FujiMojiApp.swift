//
//  FujiMojiApp.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-06.
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = DetectedTextWindowController.shared
        _ = PredictionResultsWindowController.shared
        let hasShown = UserDefaults.standard.bool(forKey: "hasShownLanding")
        if !hasShown {
            LandingWindowController.shared.showFloating()
            UserDefaults.standard.set(true, forKey: "hasShownLanding")
        }
    }
}

@main
struct FujiMojiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var fujiMojiState = FujiMojiState.shared
    
    var body: some Scene {
        MenuBarExtra {
            MenuView(fujiMojiState: fujiMojiState)
            .background(.ultraThinMaterial)
            .onAppear {
                fujiMojiState.checkInputMonitoringAuthorization()
            }
        } label: {
            let size = NSStatusBar.system.thickness - 4
            menuBarIcon(size: size)
        }
        .menuBarExtraStyle(.window)
    }
    
    private func menuBarIcon(size: CGFloat) -> Image {
        guard let base = NSImage(named: "MenuIcon") else {
            return Image(systemName: "circle.fill")
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
        return Image(nsImage: resized)
    }
}