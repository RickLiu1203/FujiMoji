//
//  MenuFirstSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-08.
//

import SwiftUI

struct MenuFirstSectionView: View {
    @ObservedObject var fujiMojiState: FujiMojiState

    var body: some View {   
        VStack(alignment: .leading, spacing: 8) {
            Text("FujiMoji 🍎")
                .bold()
            Text(fujiMojiState.isEnabled ? "On" : "Off")
                .foregroundColor(.secondary)
        }
    }
}