//
//  MenuSecondSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-13.
//

import SwiftUI
import AppKit

struct MenuSecondSectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                dismiss()
                openMappingsWindow(initialSelection: .emojiCategory(.smileysPeople))
            }) {
                HStack {
                    Text("Set Emojis")
                    
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
            
            Button(action: {
                dismiss()
                openMappingsWindow(initialSelection: .customMappings)
            }) {
                HStack {
                    Text("Set Custom Text")
                    
                    Spacer()
                    
                    Text("⌘T")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("t")
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .font(.system(size: 13, weight: .medium))
    }
    
    private func openMappingsWindow(initialSelection: MappingSidebarItem) {
        MappingsWindowCoordinator.shared.show(initialSelection: initialSelection)
    }
}
