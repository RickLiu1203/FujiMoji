//
//  PopupView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-28.
//

import SwiftUI
import AppKit
import Combine

private let popupWidth: CGFloat = 300
private let screenBottomMargin: CGFloat = 24
private let detectedTextWindowHeight: CGFloat = 72
private let predictionResultsDefaultHeight: CGFloat = 100
private let debounceDelayMs: Int = 150
private let windowAnimationDuration: Double = 0.25
private let layoutDelay: Double = 0.05 // Small delay for SwiftUI layout before window resize

extension Notification.Name {
    static let selectHighlightedSuggestion = Notification.Name("selectHighlightedSuggestion")
}

// MARK: - Detected Text View (Fixed at bottom)
struct DetectedTextPopupView: View {
    @ObservedObject private var keyDetection = KeyDetection.shared
    private let padding: CGFloat = 16
    
    var body: some View {
        DetectedTextView(text: keyDetection.currentString)
            .padding(.bottom, padding)
            .frame(width: popupWidth)
            .background(.clear)
    }
}

// MARK: - Prediction Results View (Appears above detected text)
struct PredictionResultsPopupView: View {
    @StateObject private var viewModel = PopupViewModel()
    private let padding: CGFloat = 16
    
    var body: some View {
        // Instantly clear the entire view when there are no results
        if viewModel.customMatches.isEmpty && viewModel.emojiMatches.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .center, spacing: 8) {
                Spacer(minLength: 0)
                if !viewModel.emojiMatches.isEmpty {
                    PredictionResultsView(
                        title: "Emojis",
                        items: viewModel.emojiMatches,
                        displayText: { match in
                            "\(match.emoji)  \(match.tag)"
                        },
                        isHighlighted: { index, _ in
                            let adjustedIndex = viewModel.customMatches.count + index
                            return (viewModel.customMatches.isEmpty && index == viewModel.highlightedIndex) || 
                                   (!viewModel.customMatches.isEmpty && adjustedIndex == viewModel.highlightedIndex)
                        },
                        onTap: { match in
                            viewModel.performEmojiSelection(tag: match.tag, emoji: match.emoji)
                        }
                    )
                }
                
                // Custom matches (appears above emoji)
                if !viewModel.customMatches.isEmpty {
                    PredictionResultsView(
                        title: "Custom",
                        items: viewModel.customMatches,
                        displayText: { $0 },
                        isHighlighted: { index, _ in
                            index == viewModel.highlightedIndex
                        },
                        onTap: { tag in
                            viewModel.performCustomSelection(tag: tag)
                        }
                    )
                }
            }
            .padding(.horizontal, padding)
            .padding(.bottom, 16)
            .padding(.top, 8)
            .frame(width: popupWidth)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.3), lineWidth: 1.5)
            )
            .onReceive(NotificationCenter.default.publisher(for: .selectHighlightedSuggestion)) { _ in
                viewModel.selectHighlightedItem()
            }
        }
    }
}

// MARK: - Detected Text Window Controller (Fixed at bottom)
final class DetectedTextWindowController: NSWindowController {
    static let shared = DetectedTextWindowController()

    private var hostingController: NSHostingController<DetectedTextPopupView>?
    private var cancellables = Set<AnyCancellable>()
    private let updateQueue = DispatchQueue(label: "DetectedTextWindowUpdate", qos: .userInteractive)

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
        let content = DetectedTextPopupView()
        let hosting = NSHostingController(rootView: content)
        self.hostingController = hosting

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: popupWidth, height: detectedTextWindowHeight), // Base height: 40 + 32 padding
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = false
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
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if self.window == nil {
                    self.setupWindow()
                }
                guard let window = self.window, let screen = NSScreen.main else { return }
                
                let targetFrame = self.frameForBottomCenter(on: screen)
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
        }
    }

    func hide() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let window = self.window, let screen = NSScreen.main else { return }
                
                let targetFrame = self.frameForBottomCenter(on: screen)
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
        }
    }

    private func positionAtBottomCenter() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let screen = NSScreen.main, let window = self.window else { return }
                window.setFrame(self.frameForBottomCenter(on: screen), display: true)
            }
        }
    }

    private func frameForBottomCenter(on screen: NSScreen) -> NSRect {
        guard let window = self.window else {
            return NSRect(x: 0, y: 0, width: popupWidth, height: detectedTextWindowHeight)
        }
        
        // Get the actual content size from the hosting controller
        let contentSize = window.contentView?.fittingSize ?? NSSize(width: popupWidth, height: detectedTextWindowHeight)
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - contentSize.width / 2
        let y = screenFrame.minY + screenBottomMargin // Fixed bottom position
        
        return NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height)
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

// MARK: - Prediction Results Window Controller (Appears above detected text)
final class PredictionResultsWindowController: NSWindowController {
    static let shared = PredictionResultsWindowController()

    private var hostingController: NSHostingController<PredictionResultsPopupView>?
    private var cancellables = Set<AnyCancellable>()
    private let updateQueue = DispatchQueue(label: "PredictionResultsWindowUpdate", qos: .userInteractive)
    private var updateWorkItem: DispatchWorkItem?

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
        let content = PredictionResultsPopupView()
        let hosting = NSHostingController(rootView: content)
        self.hostingController = hosting

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: popupWidth, height: predictionResultsDefaultHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false // No shadow to blend with detected text
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentViewController = hosting

        self.window = panel
    }

    func show() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if self.window == nil {
                    self.setupWindow()
                }
                guard let window = self.window, let screen = NSScreen.main else { return }
                
                let targetFrame = self.frameAboveDetectedText(on: screen)
                window.setFrame(targetFrame, display: false)
                window.alphaValue = 0
                window.orderFrontRegardless()
                
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().alphaValue = 1
                }
            }
        }
    }

    func hide() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let window = self.window else { return }
                
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    window.animator().alphaValue = 0
                }, completionHandler: {
                    window.orderOut(nil)
                })
            }
        }
    }

    private func frameAboveDetectedText(on screen: NSScreen) -> NSRect {
        guard let window = self.window else {
            return NSRect(x: 0, y: 0, width: popupWidth, height: predictionResultsDefaultHeight)
        }
        
        let contentSize = window.contentView?.fittingSize ?? NSSize(width: popupWidth, height: predictionResultsDefaultHeight)
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - contentSize.width / 2
        // Anchor bottom edge at top of detected text - only top edge moves as height changes
        // This creates the expanding/contracting effect from bottom up
        let y = screenFrame.minY + screenBottomMargin + detectedTextWindowHeight
        return NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height)
    }

    private func setupObservers() {
        // Show/hide based on whether there are any matches with aggressive debouncing
        KeyDetection.shared.$currentString
            .removeDuplicates()
            .debounce(for: .milliseconds(debounceDelayMs), scheduler: RunLoop.main)
            .sink { [weak self] currentString in
                self?.handleStringChange(currentString)
            }
            .store(in: &cancellables)
        
        // Immediate window frame updates for smooth animations (no debounce)
        KeyDetection.shared.$currentString
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindowFrameIfVisible()
            }
            .store(in: &cancellables)
    }
    
    private func handleStringChange(_ currentString: String) {
        // Cancel any pending update
        updateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            if KeyDetection.shared.isCapturing && currentString.count >= 2 {
                // Check if we have any matches
                let hasMatches = !CustomStorage.shared.collectTags(withPrefix: currentString.lowercased(), limit: 1).isEmpty ||
                                !EmojiStorage.shared.collectPairs(withPrefix: currentString.lowercased(), limit: 1).isEmpty
                
                if hasMatches {
                    if self.window?.isVisible != true {
                        self.show()
                    }
                    // Frame updates are now handled by the immediate observer
                } else {
                    self.hide()
                }
            } else {
                self.hide()
            }
        }
        
        updateWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }
    
    private func updateWindowFrameIfVisible() {
        // Only update frame if window is visible, avoiding unnecessary work
        guard let window = self.window, window.isVisible else { return }
        
        // Small delay to let SwiftUI content layout first for smoother transitions
        DispatchQueue.main.asyncAfter(deadline: .now() + layoutDelay) {
            self.updateWindowFrame()
        }
    }
    
    private func updateWindowFrame() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let window = self.window, let screen = NSScreen.main else { return }
                let newFrame = self.frameAboveDetectedText(on: screen)
                
                // Animate window frame changes for smooth container size transitions
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = windowAnimationDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(newFrame, display: true)
                }
            }
        }
    }
}

// MARK: - UI Components moved to separate files
// TagPill, HorizontalMouseScrollView, and related components are now in PredictionResultsView.swift



