//
//  MenuSixthSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-31.
//

import SwiftUI
import ServiceManagement

struct MenuSixthSectionView: View {
    @State private var launchAtLogin: Bool = false
    @State private var isUpdatingFromSystem: Bool = false
    
    private let popoverShowPublisher = NotificationCenter.default.publisher(
        for: .popoverDidShow
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $launchAtLogin) {
                HStack {
                    Text("Launch at Login")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .toggleStyle(FrostedToggleStyle())
            .frame(maxWidth: .infinity)
            .onChange(of: launchAtLogin) { _, newValue in
                guard !isUpdatingFromSystem else { return }
                setLaunchAtLogin(enabled: newValue)
            }
        }
        .padding(.horizontal, 16)
        .font(.system(size: 13, weight: .medium))
        .onAppear {
            refreshStatus()
        }
        .onReceive(popoverShowPublisher) { _ in
            refreshStatus()
        }
    }
    
    private func refreshStatus() {
        let currentStatus = getLaunchAtLoginStatus()
        if launchAtLogin != currentStatus {
            isUpdatingFromSystem = true
            launchAtLogin = currentStatus
            DispatchQueue.main.async {
                isUpdatingFromSystem = false
            }
        }
    }
    
    private func getLaunchAtLoginStatus() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert toggle if operation failed
            refreshStatus()
        }
    }
}
