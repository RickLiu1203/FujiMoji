//
//  MenuThirdSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-29.
//

import SwiftUI

struct FrostedToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(configuration.isOn ? .white.opacity(0.3) : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.3), lineWidth: 0.5)
                )
                .frame(width: 32, height: 18)
                .overlay(
                    Circle()
                        .fill(.white.opacity(configuration.isOn ? 0.9 : 0.6))
                        .frame(width: 12, height: 12)
                        .offset(x: configuration.isOn ? 6 : -6)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)
                        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

struct MenuThirdSectionView: View {
    @ObservedObject var fujiMojiState: FujiMojiState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $fujiMojiState.showSuggestionPopup) {
                HStack {
                    Text("Show Suggestions")
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .toggleStyle(FrostedToggleStyle())
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .font(.system(size: 13, weight: .medium))
    }
}