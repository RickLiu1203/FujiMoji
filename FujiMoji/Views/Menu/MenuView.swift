//
//  MenuView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-06.
//

import SwiftUI

struct MenuView: View {
    @ObservedObject var fujiMojiState: FujiMojiState

    var body: some View {
        VStack(alignment: .leading) {
            MenuFirstSectionView(fujiMojiState: fujiMojiState)

            Divider()
                .padding(.vertical, 8)

            MenuSecondSectionView()

            Divider()
                .padding(.vertical, 8)

            MenuThirdSectionView(fujiMojiState: fujiMojiState)

            Divider()
                .padding(.vertical, 8)

            MenuFourthSectionView(fujiMojiState: fujiMojiState)

            Divider()
                .padding(.vertical, 8)

            MenuLastSectionView(fujiMojiState: fujiMojiState)

        }
        .padding(16)
        .frame(width: 200)
        .background(.ultraThinMaterial)
        .onChange(of: fujiMojiState.isEnabled) {
            fujiMojiState.updateKeyDetection()
        }
    }
}

