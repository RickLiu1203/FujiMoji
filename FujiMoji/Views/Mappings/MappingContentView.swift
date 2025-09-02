//
//  MappingContentView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-20.
//

import SwiftUI
import AppKit
import QuartzCore
import UniformTypeIdentifiers

struct EmojiDetail: Identifiable {
    let id: Int?
    let emoji: String
    let defaultTag: String
    let unicode: String?
    let aliases: [String]
}

struct MappingContentView: View {
    @StateObject private var mappingViewModel: MappingsViewModel
    @State private var sidebarSelection: MappingSidebarItem? = .emojiCategory(.smileysPeople)
    
    init(mappingViewModel: MappingsViewModel? = nil) {
        self._mappingViewModel = StateObject(wrappedValue: mappingViewModel ?? MappingsViewModel())
    }
    private let categoryRowAnchors: [EmojiCategory: Int] = [
        .smileysPeople: 0,
        .peopleBody: 24,
        .animalsNature: 79,
        .foodDrink: 102,
        .travelPlaces: 121,
        .activityObjects: 152,
        .symbols: 202,
        .flags: 234
    ]
    @State private var nsScrollView: NSScrollView?
    @State private var pendingScrollRow: Int?
    private let cellSize: CGFloat = 48
    private let rowSpacing: CGFloat = 8
    private let topPadding: CGFloat = 2

    @StateObject private var customVM = CustomMappingsViewModel()
    @StateObject private var imageTagVM = ImageTagMappingsViewModel()

    private let sidebarWidth: CGFloat = 200
    private let editorWidth: CGFloat = 280
    private let midSectionWidth: CGFloat = 420

    var body: some View {
        HStack(spacing: 0) {
            SideBarView(selection: $sidebarSelection)
                .frame(width: sidebarWidth)
            if case .customMappings? = mappingViewModel.selection {
                CustomListView(vm: customVM, onSelect: { tag in
                    customVM.selectedTag = tag
                })
                    .padding(.top, topPadding)
                    .padding(.bottom, 20)
                    .frame(width: midSectionWidth)
                Divider()
                    .padding(.bottom, 20)
                CustomEditorView(vm: customVM)
                    .frame(width: editorWidth)
            } else if case .customFavorites? = mappingViewModel.selection {
                CustomListView(vm: customVM, showOnlyFavorites: true, onSelect: { tag in
                    customVM.selectedTag = tag
                })
                    .padding(.top, topPadding)
                    .padding(.bottom, 20)
                    .frame(width: midSectionWidth)
                Divider()
                    .padding(.bottom, 20)
                CustomEditorView(
                    vm: customVM,
                    isEmptyState: (customVM.favoriteTags.isEmpty || customVM.selectedTag == nil)
                )
                .frame(width: editorWidth)
            } else if case .imageTags? = mappingViewModel.selection {
                HStack(spacing: 0) {
                    ImageTagListView(vm: imageTagVM) { tag in
                        imageTagVM.selectedTag = tag
                    }
                    .padding(.top, topPadding)
                    .padding(.bottom, 20)
                    .frame(width: midSectionWidth)
                    Divider()
                        .padding(.bottom, 20)
                    ImageTagEditorView(vm: imageTagVM)
                        .frame(width: editorWidth)
                }
            } else if case .imageFavorites? = mappingViewModel.selection {
                HStack(spacing: 0) {
                    ImageTagListView(
                        vm: imageTagVM,
                        onSelect: { tag in imageTagVM.selectedTag = tag },
                        showOnlyFavorites: true
                    )
                    .padding(.top, topPadding)
                    .padding(.bottom, 20)
                    .frame(width: midSectionWidth)
                    Divider()
                        .padding(.bottom, 20)
                    ImageTagEditorView(
                        vm: imageTagVM,
                        isEmptyState: (imageTagVM.favoriteImageTags.isEmpty || imageTagVM.selectedTag == nil)
                    )
                    .frame(width: editorWidth)
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    EmojiGridView(emojis: mappingViewModel.currentEmojis, selectedEmoji: $mappingViewModel.selectedEmoji)
                        .background(EnclosingScrollViewFinder { sv in
                            nsScrollView = sv
                            if let row = pendingScrollRow {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    scrollToRow(row)
                                    pendingScrollRow = nil
                                }
                            }
                        })
                }
                .frame(width: midSectionWidth)
                .padding(.top, topPadding)
                .padding(.bottom, 24)
                Divider()
                    .padding(.bottom, 20)
                EmojiEditorView(
                    selected: mappingViewModel.selectedDetail,
                    isFavorite: mappingViewModel.selectedEmoji.map { mappingViewModel.favoriteEmojis.contains($0) } ?? false,
                    onSaveAliases: { emoji, aliases in mappingViewModel.setAliases(aliases, for: emoji) },
                    onToggleFavorite: { emoji, newValue in mappingViewModel.toggleFavorite(emoji, isOn: newValue) },
                    isEmptyState: ({ () -> Bool in
                        if case .favorites? = mappingViewModel.selection {
                            return mappingViewModel.favoriteEmojis.isEmpty || mappingViewModel.selectedEmoji == nil
                        }
                        return false
                    })()
                )
                .frame(width: editorWidth)
            }
        }
        .frame(width: 900, height: 500)
        .background(.thinMaterial)
        .preferredColorScheme(.dark)
        .onAppear {
            sidebarSelection = mappingViewModel.selection
        }
        .onChange(of: mappingViewModel.selection) { _, newValue in
            if sidebarSelection != newValue { sidebarSelection = newValue }
            if case let .emojiCategory(category) = newValue, let row = categoryRowAnchors[category] {
                if nsScrollView != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrollToRow(row)
                    }
                } else {
                    pendingScrollRow = row
                }
            }
        }
        .onChange(of: sidebarSelection) { _, newValue in
            guard mappingViewModel.selection != newValue else { return }
            DispatchQueue.main.async {
                mappingViewModel.selection = newValue
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { keyPress in
            let isV = keyPress.key == KeyEquivalent("v")
            let hasCommand = keyPress.modifiers.contains(.command)
            let hasControl = keyPress.modifiers.contains(.control)
            
            if isV && (hasCommand || hasControl) {
                switch mappingViewModel.selection {
                case .imageTags, .imageFavorites:
                    DispatchQueue.main.async { imageTagVM.pasteImageFromPasteboard() }
                    return .handled
                default:
                    break
                }
            }
            return .ignored
        }
        

    }
}

private struct EnclosingScrollViewFinder: NSViewRepresentable {
    let onFound: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                onFound(scrollView)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = nsView.enclosingScrollView {
                onFound(scrollView)
            }
        }
    }
}

private extension MappingContentView {
    func scrollToRow(_ row: Int) {
        guard let scrollView = nsScrollView else { return }
        let perRow = cellSize + rowSpacing
        let y = max(0, CGFloat(row) * perRow - topPadding)
        let target = NSPoint(x: 0, y: y)
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.65
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                scrollView.contentView.animator().setBoundsOrigin(target)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }
}

private func categoryTitle(for selection: MappingSidebarItem?) -> String {
    if case let .emojiCategory(category) = selection {
        return category.title
    }
    return EmojiCategory.smileysPeople.title
}
