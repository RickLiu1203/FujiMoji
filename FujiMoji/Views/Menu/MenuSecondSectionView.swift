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
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                dismiss()
                openMappingsWindow(initialSelection: .emojiCategory(.smileysPeople))
            }) {
                HStack {
                    Text("Set Emojis")
                    
                    Spacer()
                    
                    Text("⌘E")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("E")
            .buttonStyle(MenuHoverButtonStyle())
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
                .padding(.vertical, 4)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("t")
            .buttonStyle(MenuHoverButtonStyle())
            .frame(maxWidth: .infinity)
            
            Button(action: {
                dismiss()
                openMappingsWindow(initialSelection: .imageTags)
            }) {
                HStack {
                    Text("Set Custom Media")
                    
                    Spacer()
                    
                    Text("⌘M")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("m")
            .buttonStyle(MenuHoverButtonStyle())
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .font(.system(size: 13, weight: .medium))
    }
    
    private func openMappingsWindow(initialSelection: MappingSidebarItem) {
        MappingsWindowCoordinator.shared.show(initialSelection: initialSelection)
    }
}
