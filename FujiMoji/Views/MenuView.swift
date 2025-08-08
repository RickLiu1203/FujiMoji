//
//  MenuView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-06.
//

import SwiftUI

class AppState: ObservableObject {
    @Published var isEnabled: Bool = true
}

struct MenuView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FujiMoji 🍎")
                .bold()
            Text(appState.isEnabled ? "On" : "Off")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
        }
    }
}

