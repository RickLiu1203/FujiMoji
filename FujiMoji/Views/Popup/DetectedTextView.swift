//
//  DetectedTextView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-28.
//

import SwiftUI

struct DetectedTextView: View {
    let text: String
    let height: CGFloat = 40

    var body: some View {
        HStack(alignment: .center) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            Image("MenuIcon")
                .resizable()
                .renderingMode(.original)
                .frame(width: 16, height: 16)
                .opacity(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.4))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.3), lineWidth: 1.5)
        }
    }
}

