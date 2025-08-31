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
                .padding(.horizontal, 16)

            MenuSecondSectionView()

            Divider()
                .padding(.vertical, 8)
                .padding(.horizontal, 16)

            MenuThirdSectionView(fujiMojiState: fujiMojiState)

            Divider()
                .padding(.vertical, 8)
                .padding(.horizontal, 16)

            MenuFourthSectionView(fujiMojiState: fujiMojiState)

            Divider()
                .padding(.vertical, 8)
                .padding(.horizontal, 16)

            MenuFifthSectionView(fujiMojiState: fujiMojiState)

            Divider()
                .padding(.top, 8)
                .padding(.bottom, 4)
                .padding(.horizontal, 16)

            MenuSixthSectionView()

            Divider()
                .padding(.top, 4)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)

            MenuLastSectionView(fujiMojiState: fujiMojiState)

        }
        .padding(.vertical, 16)
        .frame(width: 200)
        .background(.ultraThinMaterial)
        .onChange(of: fujiMojiState.isEnabled) {
            fujiMojiState.updateKeyDetection()
        }
    }
}

