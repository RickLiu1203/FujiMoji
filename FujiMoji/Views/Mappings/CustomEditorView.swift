//
//  CustomEditorView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-26.
//

import SwiftUI

struct CustomEditorView: View {
    @State private var tagInput: String = ""
    @State private var textInput: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case tag, text }

    @ObservedObject var vm: CustomMappingsViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            tagInputView
            textInputView
            Spacer()
        }
        .frame(width: .infinity, height: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .onChange(of: focusedField) { _ in
            if focusedField == nil { submitIfPossible() }
        }
        .onAppear {
            syncInputsFromSelection()
        }
        .onChange(of: vm.selectedTag) { _ in
            syncInputsFromSelection()
        }
    }

    private var tagInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unique Custom Tag")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            tagEditorView
        }
        .frame(width: 220)
    }

    private var textInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Text")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            textEditorView
        }
        .frame(width: 220)
    }

    private var tagEditorView: some View {
        ZStack {
            TextEditor(text: $tagInput)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .scrollContentBackground(.hidden)
                .frame(height: 60)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(focusedField == .tag ? Color.black.opacity(0.15) : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .focused($focusedField, equals: .tag)
        }
        .onKeyPress(phases: .down) { keyPress in
            if keyPress.key == .return {
                submitIfPossible()
                focusedField = nil
                return .handled
            }
            return .ignored
        }
    }

    private var textEditorView: some View {
        ZStack {
            TextEditor(text: $textInput)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .scrollContentBackground(.hidden)
                .frame(height: 150)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(focusedField == .text ? Color.black.opacity(0.15) : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .focused($focusedField, equals: .text)
        }
        .onKeyPress(phases: .down) { keyPress in
            if keyPress.key == .return {
                if keyPress.modifiers.contains(.shift) {
                    // Allow Shift+Enter to insert a newline in custom text input
                    return .ignored
                } else {
                    submitIfPossible()
                    focusedField = nil
                    return .handled
                }
            }
            return .ignored
        }
    }

    private func syncInputsFromSelection() {
        guard let tag = vm.selectedTag else { return }
        tagInput = tag
        textInput = CustomStorage.shared.getText(forTag: tag) ?? ""
    }

    private func submitIfPossible() {
        let newTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let newText = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTag.isEmpty, !newText.isEmpty else { return }
        if let current = vm.selectedTag {
            vm.rename(oldTag: current, newTag: newTag, text: newText)
        } else {
            vm.update(tag: newTag, text: newText)
        }
    }
}