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
    
    private let keyDetection = KeyDetection.shared

    init() {
        updateKeyDetection()
    }
    
    func updateKeyDetection() {
        if isEnabled {
            keyDetection.start()
        } else {
            keyDetection.stop()
        }
    }
}

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

            MenuLastSectionView(fujiMojiState: fujiMojiState)

        }
        .padding(16)
        .frame(width: 150)
        .onChange(of: fujiMojiState.isEnabled) {_ in    
            fujiMojiState.updateKeyDetection()
        }
    }
}

