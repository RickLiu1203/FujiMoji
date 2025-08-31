//
//  MenuLastSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-08.
//

import SwiftUI

struct MenuLastSectionView: View {
    @ObservedObject var fujiMojiState: FujiMojiState
    

    var body: some View{
        VStack(alignment: .leading, spacing: 2) {
            Button(action: {
                fujiMojiState.isEnabled.toggle()
            }){
                HStack {
                    Text(fujiMojiState.isEnabled ? "Disable" : "Enable")

                    Spacer()

                    Text("⌘D")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("d")
            .buttonStyle(MenuHoverButtonStyle())
            .frame(maxWidth: .infinity)
            
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }){
                HStack {
                    Text("Quit")

                    Spacer()

                    Text("⌘Q")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("q")
            .buttonStyle(MenuHoverButtonStyle())
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .font(.system(size: 13, weight: .medium))
    }
}