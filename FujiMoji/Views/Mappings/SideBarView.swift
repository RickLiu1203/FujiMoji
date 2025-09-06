//
//  SideBarView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-20.
//

import SwiftUI

enum EmojiCategory: String, CaseIterable, Identifiable, Hashable {
    case smileysPeople
    case peopleBody
    case animalsNature
    case foodDrink
    case travelPlaces
    case activityObjects
    case symbols
    case flags

    var id: Self { self }

    var title: String {
        switch self {
        case .smileysPeople: return "Smileys & Emotions"
        case .peopleBody: return "People & Body"
        case .animalsNature: return "Animals & Nature"
        case .foodDrink: return "Food & Drink"
        case .travelPlaces: return "Travel & Places"
        case .activityObjects: return "Activities & Objects"
        case .symbols: return "Symbols & Signs"
        case .flags: return "Flags"
        }
    }

    var iconName: String {
        switch self {
        case .smileysPeople: return "face.smiling"
        case .peopleBody: return "hand.raised"
        case .animalsNature: return "pawprint"
        case .foodDrink: return "fork.knife"
        case .travelPlaces: return "tram.fill"
        case .activityObjects: return "gamecontroller"
        case .symbols: return "textformat"
        case .flags: return "flag"
        }
    }
}

enum MappingSidebarItem: Identifiable, Hashable {
    case emojiCategory(EmojiCategory)
    case customMappings
    case customFavorites
    case favorites
    case imageTags
    case imageFavorites

    var id: String {
        switch self {
        case .emojiCategory(let category): return "emoji-\(category.rawValue)"
        case .customMappings: return "custom"
        case .customFavorites: return "custom-favorites"
        case .favorites: return "favorites"
        case .imageTags: return "image-tags"
        case .imageFavorites: return "image-favorites"
        }
    }
}

struct SideBarView: View {
    @Binding var selection: MappingSidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section("Emojis") {
                ForEach(EmojiCategory.allCases) { category in
                    Label(category.title, systemImage: category.iconName)
                        .tag(MappingSidebarItem.emojiCategory(category))
                        .font(.system(size: 14, weight: .medium))
                        .padding(.vertical, 2)
                }
            }
            Section("Custom") {
                Label("Custom Text", systemImage: "slider.horizontal.3")
                    .tag(MappingSidebarItem.customMappings)
                    .font(.system(size: 14, weight: .medium))
                Label("Custom Media", systemImage: "photo")
                    .tag(MappingSidebarItem.imageTags)
                    .font(.system(size: 14, weight: .medium))
            }
            Section("Favorites") {
                Label("Emojis", systemImage: "star.circle")
                    .tag(MappingSidebarItem.favorites)
                    .font(.system(size: 14, weight: .medium))
                Label("Texts", systemImage: "text.badge.star")
                    .tag(MappingSidebarItem.customFavorites)
                    .font(.system(size: 14, weight: .medium))
                Label("Media", systemImage: "star.square.on.square")
                    .tag(MappingSidebarItem.imageFavorites)
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial.opacity(0.7))
    }
}