//
//  MenuButtonStyles.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-31.
//

import SwiftUI

struct MenuHoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(HoverOpacityModifier(isPressed: configuration.isPressed))
    }

    private struct HoverOpacityModifier: ViewModifier {
        @State private var isHovering = false
        let isPressed: Bool
        private let targetOpacity: Double = 0.6

        func body(content: Content) -> some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill( isHovering ? isPressed ? Color.white.opacity(0.05) : Color.white.opacity(0.15) : Color.clear)
                )
                .onHover { hovering in
                    isHovering = hovering
                }
        }
    }
}


