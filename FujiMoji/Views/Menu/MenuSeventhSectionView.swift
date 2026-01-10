//
//  MenuSeventhSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-01-10.
//

import SwiftUI

struct MenuSeventhSectionView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                LandingWindowController.shared.toggle()
            }){
                HStack {
                    Text("Show Landing Page")
                        .padding(.vertical, 4)

                    Spacer()

                    Text("⌘L")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("l")
            .buttonStyle(MenuHoverButtonStyle())
            .frame(maxWidth: .infinity)

            Button(action: {
                guard let url = URL(string: "https://github.com/RickLiu1203/FujiMoji") else { return }
                openURL(url)
            }){
                HStack {
                    Text("GitHub  ↗")
                        .padding(.vertical, 4)

                    Spacer()

                    Text("⌘G")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("G")
            .buttonStyle(MenuHoverButtonStyle())
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .font(.system(size: 13, weight: .medium))
    }
}
