//
//  LandingView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-09-05.
//
//
import SwiftUI
import AppKit

struct LandingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to FujiMoji 🍎")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Type tags anywhere to instantly insert **emojis 🤗** **custom text 📝** or **images 🎆**")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().opacity(0.6)

            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 12) {
                    Text("⌨️").padding(.top, 1).font(.system(size: 16))
                    Text("**Type \"/\"** in any app to begin seeing suggestions. Use **arrow keys** to navigate between suggestions and **Enter**, **Tab**, or **\"/\"** to insert")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("⚙️").padding(.top, 1).font(.system(size: 16))
                    Text("Add custom text, media, and emoji aliases in the menu bar app")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("👏🏼").padding(.top, 1).font(.system(size: 16))
                    Text("Skin tone, trigger keys, suggestions visibility, and more can be customized right in the menu bar")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("🔒").padding(.top, 1).font(.system(size: 16))
                    Text("FujiMoji runs entirely on your Mac. Your **keystrokes** and **media** never leave your device. Check out the code on **[GitHub](https://github.com/RickLiu1203/FujiMoji)**")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            HStack {
                Spacer()
                Button(action: { NSApp.keyWindow?.close() }) {
                    Text("Amazing! 🤩")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial)
        )
        .frame(width: 550)
        .preferredColorScheme(.dark)
    }
}

final class LandingWindowController: NSWindowController {
    static let shared = LandingWindowController()

    private var hostingController: NSHostingController<LandingView>?

    private override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func ensureWindow() {
        if window != nil { return }

        let hosting = NSHostingController(rootView: LandingView())
        hosting.view.wantsLayer = true
        hosting.view.layer?.masksToBounds = false
        hosting.view.appearance = NSAppearance(named: .darkAqua)
        self.hostingController = hosting

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 350),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )

        win.isOpaque = false
        win.backgroundColor = NSColor.clear
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovable = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        win.contentViewController = hosting
        win.appearance = NSAppearance(named: .darkAqua)
        win.standardWindowButton(.closeButton)?.isHidden = true
        win.standardWindowButton(.miniaturizeButton)?.isHidden = true
        win.standardWindowButton(.zoomButton)?.isHidden = true

        self.window = win
    }

    private func centerOnActiveScreen(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let targetScreen = screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? window.screen ?? NSScreen.main
        if let screen = targetScreen {
            let size = window.frame.size
            let visible = screen.visibleFrame
            let newX = visible.origin.x + (visible.size.width - size.width) / 2
            let newY = visible.origin.y + (visible.size.height - size.height) / 2
            window.setFrameOrigin(NSPoint(x: newX, y: newY))
        } else {
            window.center()
        }
    }

    func showFloating() {
        ensureWindow()
        if let win = self.window {
            centerOnActiveScreen(win)
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func toggle() {
        ensureWindow()
        if let win = self.window, win.isVisible {
            win.orderOut(nil)
        } else {
            showFloating()
        }
    }
}

