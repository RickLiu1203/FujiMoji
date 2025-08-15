//
//  MenuSecondSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-13.
//

import SwiftUI

struct MenuSecondSectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                dismiss()
                openEmojiMappingsWindow()
            }) {
                HStack {
                    Text("Set Emojis")
                        .bold()
                    
                    Spacer()
                    
                    Text("⌘M")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("m")
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }
    
    private func openEmojiMappingsWindow() {
        let controller = NSWindowController(
            window: NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 500), // Set initial size
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
        )
        
        controller.window?.title = "Emoji Mappings"
        controller.window?.contentView = NSHostingView(
            rootView: EmojiMappingsView()
        )
        controller.window?.level = NSWindow.Level.floating
        
        // Force window to size itself to fit content
        controller.window?.setContentSize(NSSize(width: 500, height: 500))
        
        // Position window at exact center of main screen
        if let window = controller.window, let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let newOrigin = NSPoint(
                x: screenFrame.midX - window.frame.width/2,
                y: screenFrame.midY - window.frame.height/2
            )
            window.setFrameOrigin(newOrigin)
        }
        
        controller.showWindow(self)
    }
}