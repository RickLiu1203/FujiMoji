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
            if fujiMojiState.needsInputMonitoring {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enable Input Monitoring")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Go to System Settings → Privacy & Security → Input Monitoring, enable FujiMoji, then relaunch")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 6) {
                        Button("Open Settings") {
                            fujiMojiState.openInputMonitoringSettings()
                        }
                        .buttonStyle(MenuHoverButtonStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Relaunch App") {
                            fujiMojiState.relaunchApp()
                        }
                        .buttonStyle(MenuHoverButtonStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.yellow.opacity(0.15))
                )
            }
        }
        .padding(.horizontal, 16)
        .background(.clear)
    }
}