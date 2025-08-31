//
//  MenuSixthSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-31.
//

import SwiftUI

struct MenuSixthSectionView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                guard let url = URL(string: "https://github.com/RickLiu1203/FujiMoji#readme") else { return }
                openURL(url)
            }){
                HStack {
                    Text("How to Use  ↗")
                        .padding(.vertical, 4)

                    Spacer()

                    Text("⌘H")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("h")
            .buttonStyle(MenuHoverButtonStyle())
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .font(.system(size: 13, weight: .medium))
    }
}
