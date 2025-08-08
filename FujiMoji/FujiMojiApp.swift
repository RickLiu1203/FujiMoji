//
//  FujiMojiApp.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-06.
//

import SwiftUI

@main
struct FujiMojiApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra("🍎") {
            VStack(alignment: .leading, spacing: 4) {
                MenuView(appState: appState)

                Divider()
                .padding(.vertical, 4)

                Button(action: {
                   appState.isEnabled.toggle()
                }){
                    HStack {
                        Text(appState.isEnabled ? "Disable" : "Enable")

                        Spacer()

                        Text("⌘D")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .keyboardShortcut("d")
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }){
                    HStack {
                        Text("Quit")

                        Spacer()

                        Text("⌘Q")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .keyboardShortcut("q")
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

              

            }
            .padding(16)
            .frame(width: 200)

        }
        .menuBarExtraStyle(.window)
    }
}
