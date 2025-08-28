//
//  PopupView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-28.
//

import SwiftUI
import AppKit
import Combine

extension Notification.Name {
    static let selectHighlightedSuggestion = Notification.Name("selectHighlightedSuggestion")
}

// MARK: - SwiftUI content shown inside the popup
struct PopupView: View {
    @ObservedObject private var keyDetection = KeyDetection.shared
    @StateObject private var viewModel = PopupViewModel()
    
    var body: some View {
            VStack(spacing: 8) {
                if viewModel.shouldShowSuggestions {
                    VStack(alignment: .leading, spacing: 8) {
                        if !viewModel.customMatches.isEmpty {
                            Text("Custom")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                            HorizontalMouseScrollView {
                                HStack(spacing: 8) {
                                    ForEach(Array(viewModel.customMatches.enumerated()), id: \.element) { index, tag in
                                        Button(action: {
                                            viewModel.performCustomSelection(tag: tag)
                                        }) {
                                            TagPill(text: tag, isHighlighted: index == viewModel.highlightedIndex && !viewModel.customMatches.isEmpty)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                        if !viewModel.emojiMatches.isEmpty {
                            Text("Emojis")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                            HorizontalMouseScrollView {
                                HStack(spacing: 8) {
                                    ForEach(Array(viewModel.emojiMatches.enumerated()), id: \.element.tag) { index, pair in
                                        Button(action: {
                                            viewModel.performEmojiSelection(tag: pair.tag, emoji: pair.emoji)
                                        }) {
                                            let adjustedIndex = viewModel.customMatches.count + index
                                            TagPill(text: "\(pair.emoji)  \(pair.tag)", isHighlighted: (viewModel.customMatches.isEmpty && index == viewModel.highlightedIndex) || (!viewModel.customMatches.isEmpty && adjustedIndex == viewModel.highlightedIndex))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                    }
                }
                Text(keyDetection.currentString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        .frame(width: 400, height: 150)
        .background(.ultraThinMaterial)
        .onReceive(NotificationCenter.default.publisher(for: .selectHighlightedSuggestion)) { _ in
            viewModel.selectHighlightedItem()
        }
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
        guard let window = self.window, let screen = NSScreen.main else { return }
        let targetFrame = frameForBottomCenter(on: screen)
        var startFrame = targetFrame
        startFrame.origin.y = screen.visibleFrame.minY - targetFrame.height - 10
        window.setFrame(startFrame, display: false)
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(targetFrame, display: true)
            window.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let window = self.window, let screen = NSScreen.main else { return }
        let targetFrame = frameForBottomCenter(on: screen)
        var endFrame = targetFrame
        endFrame.origin.y = screen.visibleFrame.minY - targetFrame.height - 10
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(endFrame, display: true)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            window.setFrame(targetFrame, display: false)
            window.alphaValue = 1
            self?.positionAtBottomCenter()
        })
    }

    private func positionAtBottomCenter() {
        guard let screen = NSScreen.main, let window = self.window else { return }
        window.setFrame(frameForBottomCenter(on: screen), display: true)
    }

    private func frameForBottomCenter(on screen: NSScreen) -> NSRect {
        let targetSize = NSSize(width: 400, height: 150)
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - targetSize.width / 2
        let y = screenFrame.minY + 24
        return NSRect(x: x, y: y, width: targetSize.width, height: targetSize.height)
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

// MARK: - UI Components
private struct TagPill: View {
    let text: String
    let isHighlighted: Bool
    
    init(text: String, isHighlighted: Bool = false) {
        self.text = text
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHighlighted ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isHighlighted ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Horizontal scroll with mouse wheel support
private struct HorizontalMouseScrollView: NSViewRepresentable {
    let content: AnyView
    
    init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        self.content = AnyView(content())
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = MouseWheelScrollView()
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.verticalScrollElasticity = .none
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.borderType = .noBorder
        
        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(hosting)
        scrollView.documentView = documentView
        
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            hosting.topAnchor.constraint(equalTo: documentView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            hosting.trailingAnchor.constraint(greaterThanOrEqualTo: documentView.trailingAnchor),
            hosting.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let hosting = nsView.documentView?.subviews.first as? NSHostingView<AnyView> {
            hosting.rootView = content
        }
    }
}

private class MouseWheelScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        if event.scrollingDeltaX == 0 && event.scrollingDeltaY != 0 && !event.hasPreciseScrollingDeltas {
            guard let documentView = self.documentView else { return }
            let clipView = self.contentView
            let isNatural = event.isDirectionInvertedFromDevice
            let factor: CGFloat = 10.0
            let delta = -event.scrollingDeltaY * (isNatural ? 1.0 : -1.0) * factor

            var newOrigin = clipView.bounds.origin
            newOrigin.x += delta

            let maxX = max(0, documentView.bounds.width - clipView.bounds.width)
            newOrigin.x = min(max(newOrigin.x, 0), maxX)

            clipView.scroll(to: NSPoint(x: newOrigin.x, y: newOrigin.y))
            self.reflectScrolledClipView(clipView)
            return
        }
        super.scrollWheel(with: event)
    }
}



