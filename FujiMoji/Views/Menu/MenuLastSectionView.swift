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
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                fujiMojiState.isEnabled.toggle()
            }){
                HStack {
                    Text(fujiMojiState.isEnabled ? "Disable" : "Enable")

                    Spacer()

                    Text("⌘D")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("d")
            .buttonStyle(.plain)
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
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .keyboardShortcut("q")
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .background(.clear)
        .font(.system(size: 13, weight: .medium))
    }
}