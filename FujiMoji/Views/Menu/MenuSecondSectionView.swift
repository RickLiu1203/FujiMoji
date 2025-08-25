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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: MappingContentView())
        window.level = .floating
        window.isMovable = true
        window.center()
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear

        let controller = NSWindowController(window: window)
        controller.showWindow(self)
    }
}