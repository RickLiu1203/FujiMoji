//
//  SideBarView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-20.
//

import SwiftUI

enum EmojiCategory: String, CaseIterable, Identifiable, Hashable {
    case smileysPeople
    case animalsNature
    case foodDrink
    case activity
    case travelPlaces
    case objects
    case symbols
    case flags

    var id: Self { self }

    var title: String {
        switch self {
        case .smileysPeople: return "Smileys & People"
        case .animalsNature: return "Animals & Nature"
        case .foodDrink: return "Food & Drink"
        case .activity: return "Activity"
        case .travelPlaces: return "Travel & Places"
        case .objects: return "Objects"
        case .symbols: return "Symbols"
        case .flags: return "Flags"
        }
    }

    var iconName: String {
        switch self {
        case .smileysPeople: return "face.smiling"
        case .animalsNature: return "tortoise"
        case .foodDrink: return "fork.knife"
        case .activity: return "sportscourt"
        case .travelPlaces: return "tram.fill"
        case .objects: return "lightbulb"
        case .symbols: return "textformat"
        case .flags: return "flag"
        }
    }
}

enum MappingSidebarItem: Identifiable, Hashable {
    case emojiCategory(EmojiCategory)
    case customMappings
    case favorites

    var id: String {
        switch self {
        case .emojiCategory(let category): return "emoji-\(category.rawValue)"
        case .customMappings: return "custom"
        case .favorites: return "favorites"
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
                }
            }
            Section("Custom") {
                Label("Custom Text", systemImage: "slider.horizontal.3")
                    .tag(MappingSidebarItem.customMappings)
            }
            Section("Favourites") {
                Label("My Favorites", systemImage: "star")
                    .tag(MappingSidebarItem.favorites)
            }
        }
        .listStyle(.sidebar)
        .frame(width: 200)
        .padding(.leading, 24)
    }
}