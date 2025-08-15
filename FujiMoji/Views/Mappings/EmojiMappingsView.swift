//
//  EmojiMappingsView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-13.
//

import SwiftUI

struct EmojiMappingsView: View {
    @State private var mappings: [EmojiTags] = []
    @State private var editingEmoji: String? = nil
    @State private var editingText: String = ""
    private let emojiStorage = EmojiStorage.shared
    
    var body: some View {
        VStack {
            HStack {
                Text("Emoji")
                    .bold()
                    .frame(width: 80, alignment: .center)
                
                Text("Default Tag")
                    .bold()
                    .frame(width: 150, alignment: .leading)
                
                Text("Aliases")
                    .bold()
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(mappings, id: \.emoji) { mapping in
                        HStack {
                            Text(mapping.emoji)
                                .font(.title2)
                                .frame(width: 80, alignment: .center)
                            
                            Text(mapping.defaultTag)
                                .frame(width: 150, alignment: .leading)
                            
                            if editingEmoji == mapping.emoji {
                                TextField("Enter aliases (comma-separated)", text: $editingText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                    .onSubmit {
                                        updateAliases(for: mapping.emoji)
                                    }
                                    .onExitCommand {
                                        editingEmoji = nil
                                    }
                            } else {
                                Button(action: {
                                    editingEmoji = mapping.emoji
                                    editingText = mapping.aliases.joined(separator: ", ")
                                }) {
                                    Text(mapping.aliases.joined(separator: ", "))
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 500, height: 500, alignment: .top)
        .onAppear {
            refreshMappings()
        }
    }
    
    private func refreshMappings() {
        mappings = emojiStorage.getAllEmojisWithTags()
    }
    
    private func updateAliases(for emoji: String) {
        let newAliases = editingText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        emojiStorage.setAliases(Array(newAliases), forEmoji: emoji)
        
        editingEmoji = nil
        editingText = ""
        refreshMappings()
    }
}