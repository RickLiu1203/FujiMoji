//
//  PopupView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-28.
//

import SwiftUI
import AppKit
import Combine

// MARK: - SwiftUI content shown inside the popup
struct PopupView: View {
    @ObservedObject private var keyDetection = KeyDetection.shared
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                Text("FujiMoji")
                    .font(.headline)
                Text(keyDetection.currentString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(width: 400, height: 150)
    }
}

// MARK: - NSPanel host that stays above all other windows
final class PopupWindowController: NSWindowController {
    static let shared = PopupWindowController()

    private var hostingController: NSHostingController<PopupView>?
    private var cancellables = Set<AnyCancellable>()

    private override init(window: NSWindow?) {
        super.init(window: window)
    }

    convenience init() {
        self.init(window: nil)
        setupWindow()
        setupObservers()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupWindow() {
        let content = PopupView()
        let hosting = NSHostingController(rootView: content)
        self.hostingController = hosting

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentViewController = hosting

        self.window = panel
        positionAtBottomCenter()
    }

    func show() {
        if window == nil {
            setupWindow()
        }
        positionAtBottomCenter()
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func positionAtBottomCenter() {
        guard let screen = NSScreen.main, let window = self.window else { return }

        let targetSize = NSSize(width: 400, height: 150)
        let screenFrame = screen.visibleFrame

        let x = screenFrame.midX - targetSize.width / 2
        let y = screenFrame.minY + 24 // a little margin above bottom dock/menu

        window.setFrame(NSRect(x: x, y: y, width: targetSize.width, height: targetSize.height), display: true)
    }

    private func setupObservers() {
        KeyDetection.shared.$isCapturing
            .receive(on: RunLoop.main)
            .sink { [weak self] isCapturing in
                if isCapturing {
                    self?.show()
                } else {
                    self?.hide()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - AppKit blur helper (macOS 12+)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

