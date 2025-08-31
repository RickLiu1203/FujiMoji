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
    static let resultsRenderModeChanged = Notification.Name("resultsRenderModeChanged")
}
private let popupWidth: CGFloat = 300
private let screenBottomMargin: CGFloat = 0
private let screenTopMargin: CGFloat = 0
private let detectedTextWindowHeight: CGFloat = 72
private let predictionResultsDefaultHeight: CGFloat = 100
private let resultsYOffset: CGFloat = -12
private let debounceDelayMs: Int = 250



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
enum ResultsRenderMode: String { case single, double }
struct PredictionResultsPopupView: View {
    @StateObject private var viewModel = PopupViewModel(fujiMojiState: FujiMojiState.shared)
    @ObservedObject private var fujiMojiState = FujiMojiState.shared
    private let padding: CGFloat = 16
    @State private var renderedMode: ResultsRenderMode? = nil
    
    
    private var desiredMode: ResultsRenderMode? {
        let hasEmoji = !viewModel.emojiMatches.isEmpty
        let hasCustom = !viewModel.customMatches.isEmpty
        if hasEmoji && hasCustom { return .double }
        if hasEmoji || hasCustom { return .single }
        return nil
    }
    
    private func postMode(_ mode: ResultsRenderMode?) {
        guard let mode = mode else { return }
        NotificationCenter.default.post(name: .resultsRenderModeChanged, object: nil, userInfo: ["mode": mode.rawValue])
    }

    private func applyImmediateModeChange() {
        let target = desiredMode
        if target == renderedMode {
            return
        }
        renderedMode = target
        postMode(target)
    }
    
    var body: some View {
        ZStack {
            DoubleResultsPopupView(viewModel: viewModel)
                .opacity(renderedMode == .double ? 1 : 0)
                .allowsHitTesting(renderedMode == .double)
                .frame(width: popupWidth)
                .frame(height: renderedMode == .double ? nil : 0)
            SingleResultsPopupView(viewModel: viewModel)
                .opacity(renderedMode == .single ? 1 : 0)
                .allowsHitTesting(renderedMode == .single)
                .frame(width: popupWidth)
                .frame(height: renderedMode == .single ? nil : 0)
        }
        .frame(width: popupWidth)
        .onReceive(NotificationCenter.default.publisher(for: .selectHighlightedSuggestion)) { _ in
            viewModel.selectHighlightedItem()
        }
        .onAppear { renderedMode = desiredMode; postMode(renderedMode) }
        .onChange(of: viewModel.customMatches) { _, _ in applyImmediateModeChange() }
        .onChange(of: viewModel.emojiMatches) { _, _ in applyImmediateModeChange() }
    }
}

// MARK: - Split Results Containers
private struct SingleResultsPopupView: View {
    @ObservedObject var viewModel: PopupViewModel
    private let padding: CGFloat = 16
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Spacer(minLength: 0)
            if !viewModel.customMatches.isEmpty {
                PredictionResultsView(
                    title: "Custom",
                    items: viewModel.customMatches,
                    displayText: { $0 },
                    isHighlighted: { index, _ in index == viewModel.highlightedIndex },
                    isFavorite: { viewModel.isFavoriteCustom(tag: $0) },
                    onTap: { tag in viewModel.performCustomSelection(tag: tag) },
                    highlightedIndex: viewModel.highlightedIndex
                )
            } else if !viewModel.emojiMatches.isEmpty {
                PredictionResultsView(
                    title: "Emojis",
                    items: viewModel.emojiMatches,
                    displayText: { "\(FujiMojiState.shared.applySkinTone($0.emoji))  \($0.tag)" },
                    isHighlighted: { index, _ in index == viewModel.highlightedIndex },
                    isFavorite: { viewModel.isFavorite(emoji: $0.emoji) },
                    onTap: { match in viewModel.performEmojiSelection(tag: match.tag, emoji: match.emoji) },
                    highlightedIndex: viewModel.highlightedIndex
                )
            }
        }
        .padding(.horizontal, padding)
        .padding(.bottom, 12)
        .padding(.top, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1.5)
        )
    }
}

private struct DoubleResultsPopupView: View {
    @ObservedObject var viewModel: PopupViewModel
    private let padding: CGFloat = 16
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Spacer(minLength: 0)
            PredictionResultsView(
                title: "Emojis",
                items: viewModel.emojiMatches,
                displayText: { "\(FujiMojiState.shared.applySkinTone($0.emoji))  \($0.tag)" },
                isHighlighted: { index, _ in
                    let adjustedIndex = viewModel.customMatches.count + index
                    return adjustedIndex == viewModel.highlightedIndex
                },
                isFavorite: { viewModel.isFavorite(emoji: $0.emoji) },
                onTap: { match in viewModel.performEmojiSelection(tag: match.tag, emoji: match.emoji) },
                highlightedIndex: max(0, viewModel.highlightedIndex - viewModel.customMatches.count)
            )
            PredictionResultsView(
                title: "Custom",
                items: viewModel.customMatches,
                displayText: { $0 },
                isHighlighted: { index, _ in index == viewModel.highlightedIndex },
                isFavorite: { viewModel.isFavoriteCustom(tag: $0) },
                onTap: { tag in viewModel.performCustomSelection(tag: tag) },
                highlightedIndex: viewModel.highlightedIndex
            )
        }
        .padding(.horizontal, padding)
        .padding(.bottom, 12)
        .padding(.top, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1.5)
        )
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
        positionAccordingToAnchor()
    }

    func show() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if self.window == nil {
                    self.setupWindow()
                }
                guard let window = self.window, let screen = NSScreen.main else { return }
                
                let targetFrame = FujiMojiState.shared.popupAnchor == .bottom ? self.frameForBottomCenter(on: screen) : self.frameForTopCenter(on: screen)
                window.setFrame(targetFrame, display: true)
                window.alphaValue = 1
                window.orderFrontRegardless()
            }
        }
    }

    func hide() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let window = self.window else { return }
                window.orderOut(nil)
            }
        }
    }

    private func positionAccordingToAnchor() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let screen = NSScreen.main, let window = self.window else { return }
                let frame = FujiMojiState.shared.popupAnchor == .bottom ? self.frameForBottomCenter(on: screen) : self.frameForTopCenter(on: screen)
                window.setFrame(frame, display: true)
            }
        }
    }

    private func frameForBottomCenter(on screen: NSScreen) -> NSRect {
        guard let window = self.window else {
            return NSRect(x: 0, y: 0, width: popupWidth, height: detectedTextWindowHeight)
        }
        
        let contentSize = window.contentView?.fittingSize ?? NSSize(width: popupWidth, height: detectedTextWindowHeight)
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - popupWidth / 2
        let y = screenFrame.minY + screenBottomMargin // Fixed bottom position
        
        return NSRect(x: x, y: y, width: popupWidth, height: contentSize.height)
    }

    private func frameForTopCenter(on screen: NSScreen) -> NSRect {
        guard let window = self.window else {
            return NSRect(x: 0, y: 0, width: popupWidth, height: detectedTextWindowHeight)
        }
        
        let contentSize = window.contentView?.fittingSize ?? NSSize(width: popupWidth, height: detectedTextWindowHeight)
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - popupWidth / 2
        let y = screenFrame.maxY - contentSize.height - screenTopMargin
        
        return NSRect(x: x, y: y, width: popupWidth, height: contentSize.height)
    }

    private func setupObservers() {
        KeyDetection.shared.$isCapturing
            .receive(on: RunLoop.main)
            .sink { [weak self] isCapturing in
                if isCapturing && FujiMojiState.shared.showSuggestionPopup {
                    self?.show()
                } else {
                    self?.hide()
                }
            }
            .store(in: &cancellables)
        
        FujiMojiState.shared.$showSuggestionPopup
            .receive(on: RunLoop.main)
            .sink { [weak self] showPopup in
                if !showPopup {
                    self?.hide()
                }
            }
            .store(in: &cancellables)
        
        FujiMojiState.shared.$popupAnchor
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, let window = self.window, window.isVisible, let screen = NSScreen.main else { return }
                let frame = FujiMojiState.shared.popupAnchor == .bottom ? self.frameForBottomCenter(on: screen) : self.frameForTopCenter(on: screen)
                window.setFrame(frame, display: true)
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
    private var currentRenderMode: ResultsRenderMode = .single

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
        panel.hasShadow = false
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
                
                let frame = FujiMojiState.shared.popupAnchor == .bottom ? self.frameAboveDetectedText(on: screen) : self.frameBelowTopAnchor(on: screen)
                window.setFrame(frame, display: true)
                window.alphaValue = 1
                window.orderFrontRegardless()
            }
        }
    }

    func hide() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let window = self.window else { return }
                window.orderOut(nil)
            }
        }
    }

    private func frameAboveDetectedText(on screen: NSScreen) -> NSRect {
        guard let window = self.window else {
            return NSRect(x: 0, y: 0, width: popupWidth, height: predictionResultsDefaultHeight)
        }
        
        let contentSize = window.contentView?.fittingSize ?? NSSize(width: popupWidth, height: predictionResultsDefaultHeight)
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - popupWidth / 2
        let yOffset = resultsYOffset
        let y = screenFrame.minY + screenBottomMargin + detectedTextWindowHeight + yOffset
        return NSRect(x: x, y: y, width: popupWidth, height: contentSize.height)
    }

    private func frameBelowTopAnchor(on screen: NSScreen) -> NSRect {
        guard let window = self.window else {
            return NSRect(x: 0, y: 0, width: popupWidth, height: predictionResultsDefaultHeight)
        }
        
        let contentSize = window.contentView?.fittingSize ?? NSSize(width: popupWidth, height: predictionResultsDefaultHeight)
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - popupWidth / 2
        // place just below the detected text when detected text is anchored at top
        let yOffset: CGFloat = 28
        let y = screenFrame.maxY - detectedTextWindowHeight - contentSize.height - screenTopMargin + yOffset
        return NSRect(x: x, y: y, width: popupWidth, height: contentSize.height)
    }

    private func setupObservers() {
        KeyDetection.shared.$currentString
            .removeDuplicates()
            .debounce(for: .milliseconds(debounceDelayMs), scheduler: RunLoop.main)
            .sink { [weak self] currentString in
                self?.handleStringChange(currentString)
            }
            .store(in: &cancellables)
        
        FujiMojiState.shared.$showSuggestionPopup
            .receive(on: RunLoop.main)
            .sink { [weak self] showPopup in
                if !showPopup {
                    self?.hide()
                }
            }
            .store(in: &cancellables)
        
        KeyDetection.shared.$currentString
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] currentString in
                self?.handleImmediateShow(currentString)
            }
            .store(in: &cancellables)
        
        KeyDetection.shared.$currentString
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindowFrameIfVisible()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .resultsRenderModeChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let raw = notification.userInfo?["mode"] as? String, let mode = ResultsRenderMode(rawValue: raw) {
                    self?.currentRenderMode = mode
                    self?.updateWindowFrameIfVisible()
                }
            }
            .store(in: &cancellables)

        FujiMojiState.shared.$popupAnchor
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindowFrameIfVisible()
            }
            .store(in: &cancellables)
    }
    
    private func handleStringChange(_ currentString: String) {
        updateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            if KeyDetection.shared.isCapturing && currentString.count >= 2 {
                guard FujiMojiState.shared.showSuggestionPopup else {
                    self.hide()
                    return
                }
                
                let hasMatches = !CustomStorage.shared.collectTags(withPrefix: currentString.lowercased(), limit: 1).isEmpty ||
                                !EmojiStorage.shared.collectPairs(withPrefix: currentString.lowercased(), limit: 1).isEmpty
                
                if hasMatches {
                    if self.window?.isVisible != true {
                        self.show()
                    }
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
    
    private func handleImmediateShow(_ currentString: String) {
        guard KeyDetection.shared.isCapturing,
              currentString.count >= 2,
              FujiMojiState.shared.showSuggestionPopup else { return }
        
        let prefix = currentString.lowercased()
        let hasMatches = !CustomStorage.shared.collectTags(withPrefix: prefix, limit: 1).isEmpty ||
                         !EmojiStorage.shared.collectPairs(withPrefix: prefix, limit: 1).isEmpty
        
        if hasMatches, self.window?.isVisible != true {
            self.show()
        }
    }
    
    private func updateWindowFrameIfVisible() {
        guard let window = self.window, window.isVisible else { return }
        self.updateWindowFrame()
    }
    
    private func updateWindowFrame() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let window = self.window, let screen = NSScreen.main else { return }
                let newFrame = FujiMojiState.shared.popupAnchor == .bottom ? self.frameAboveDetectedText(on: screen) : self.frameBelowTopAnchor(on: screen)
                window.setFrame(newFrame, display: true)
            }
        }
    }
}





