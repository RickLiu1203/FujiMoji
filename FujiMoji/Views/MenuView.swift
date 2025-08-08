//
//  MenuView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-06.
//

import SwiftUI

class FujiMojiState: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var isCool: Bool = true
}

struct MenuView: View {
    @ObservedObject var fujiMojiState: FujiMojiState
    
    var body: some View {
        VStack(alignment: .leading) {
            MenuFirstSectionView(fujiMojiState: fujiMojiState)

            Divider()
                .padding(.vertical, 4)

            MenuLastSectionView(fujiMojiState: fujiMojiState)

        }
        .padding(16)
        .frame(width: 200)
    }
}

