//
//  EmojiEditorView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-25.
//

import SwiftUI

struct EmojiEditorView: View {
    var selected: EmojiDetail?
    var isFavorite: Bool
    var onSaveAliases: (String, [String]) -> Void
    var onToggleFavorite: (String, Bool) -> Void
    @State private var aliasesInput: String = ""
    @FocusState private var isAliasesFocused: Bool
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Text(selected?.emoji ?? "")
                    .font(.system(size: 110))
                    .padding(8)
                    .frame(width: 220, height: 220, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    if let selected = selected {
                        Button(action: {
                            onToggleFavorite(selected.emoji, !isFavorite)
                        }) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .foregroundColor(isFavorite ? .yellow : .white)
                                .imageScale(.large)
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                }
                if let selected = selected {
                    Text(selected.defaultTag)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .truncationMode(.tail)
                        .frame(maxWidth: 220, alignment: .center)
                        .padding(.top, 8)
                    Spacer()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comma Separated Keywords")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.leading, 2)
                        ZStack {
                            TextEditor(text: $aliasesInput)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .scrollContentBackground(.hidden)
                                .frame(height: 110)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isAliasesFocused ? Color.black.opacity(0.15) : Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .focused($isAliasesFocused)
                        }
                        .onKeyPress(.return) {
                            let symbol = selected.emoji
                            let aliases = aliasesInput
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            onSaveAliases(symbol, aliases)
                            isAliasesFocused = false
                            return .handled
                        }
                    }
                    .padding(.bottom, 40)
                    .frame(width: 220)
                }
        }
        .frame(width: 240, height: 500, alignment: .top)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            isAliasesFocused = false
        }
        .onAppear {
            aliasesInput = selected?.aliases.joined(separator: ", ") ?? ""
        }
        .onChange(of: selected?.emoji) { _, _ in
            aliasesInput = selected?.aliases.joined(separator: ", ") ?? ""
        }
    }
}

private struct SubmittingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.drawsBackground = false
        textView.delegate = context.coordinator
        let font = NSFont.systemFont(ofSize: 14)
        textView.font = font
        textView.textColor = NSColor.controlTextColor
        textView.insertionPointColor = NSColor.controlTextColor
        textView.typingAttributes = [
            .foregroundColor: NSColor.controlTextColor,
            .font: font
        ]
        
        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            container.lineFragmentPadding = 0
        }
        
        context.coordinator.textView = textView

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.documentView = textView
        scroll.autohidesScrollers = true
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        
        DispatchQueue.main.async {
            let availableWidth = nsView.contentSize.width - 8 
            if let container = textView.textContainer, 
               container.containerSize.width != availableWidth {
                container.containerSize = NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        let onSubmit: () -> Void
        weak var textView: NSTextView?

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text = tv.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit()
                return true
            }
            return false
        }
    }
}