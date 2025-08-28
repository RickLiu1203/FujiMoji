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
        _ = PopupWindowController.shared // initialize controller and observers
    }
}

@main
struct FujiMojiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var fujiMojiState = FujiMojiState()
    
    var body: some Scene {
        MenuBarExtra("🍎") {
            MenuView(fujiMojiState: fujiMojiState)
            .background(.ultraThinMaterial)
        }
        .menuBarExtraStyle(.window)
    }
}