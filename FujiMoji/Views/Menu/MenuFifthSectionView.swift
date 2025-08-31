//
//  MenuFifthSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-30.
//

import SwiftUI

private struct SkinToneSwatch: View {
    let tone: SkinTone
    let isSelected: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(tone.displayColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: isSelected ? 2 : 1)
            )
            .frame(width: 16, height: 16)
            .accessibilityLabel(Text(tone.accessibilityLabel))
    }
}

struct MenuFifthSectionView: View {
    @ObservedObject var fujiMojiState: FujiMojiState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Skin Tone")
                .font(.system(size: 13, weight: .medium))
            
            HStack(spacing: 8) {
                ForEach(SkinTone.allCases, id: \.self) { tone in
                    SkinToneSwatch(tone: tone, isSelected: fujiMojiState.selectedSkinTone == tone)
                        .onTapGesture {
                            fujiMojiState.selectedSkinTone = tone
                            fujiMojiState.saveSkinTone()
                        }
                }
            }
        }
    }
}

