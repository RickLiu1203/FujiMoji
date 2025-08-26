//
//  FujiMojiApp.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-06.
//

import SwiftUI

@main
struct FujiMojiApp: App {
    @StateObject private var fujiMojiState = FujiMojiState()
    
    var body: some Scene {
        MenuBarExtra("🍎") {
            MenuView(fujiMojiState: fujiMojiState)
            .background(.ultraThinMaterial)
        }
        .menuBarExtraStyle(.window)
    }
}