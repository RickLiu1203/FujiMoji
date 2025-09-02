//
//  ImageEditorView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-09-01.
//

import SwiftUI
import AppKit

struct ImageTagEditorView: View {
    @ObservedObject var vm: ImageTagMappingsViewModel
    @State private var isHoveringChoose = false
    @State private var isHoveringPaste = false
    @State private var tagInput: String = ""
    @FocusState private var tagFocused: Bool
    var isEmptyState: Bool = false

    var body: some View {
        Group {
            if isEmptyState {
                VStack { Spacer() }
            } else {
                VStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Unique Tag")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                ZStack {
                    TextEditor(text: $tagInput)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden)
                        .frame(height: 40)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(tagFocused ? Color.black.opacity(0.15) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .focused($tagFocused)
                }
                .onKeyPress(phases: .down) { keyPress in
                    if keyPress.key == .return {
                        DispatchQueue.main.async {
                            vm.submitIfPossible()
                        }
                        tagFocused = false
                        return .handled
                    }
                    return .ignored
                }
            }
            .frame(width: 220)
            .onAppear {
                tagInput = vm.selectedTag ?? vm.currentTagInput
            }
            .onChange(of: tagInput) { _, newVal in
                DispatchQueue.main.async {
                    vm.currentTagInput = newVal
                }
            }
            .onChange(of: vm.selectedTag) { _, newVal in
                if let sel = newVal { tagInput = sel }
            }
            .onTapGesture { 
                tagFocused = false
                DispatchQueue.main.async {
                    vm.submitIfPossible()
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)).frame(width: 220, height: 200)
                if let data = vm.selectedImageData, vm.selectedImageFileExtension?.lowercased() == "gif" {
                    AnimatedGIFView(data: data)
                        .frame(width: 220, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let tag = vm.selectedTag, let url = CustomStorage.shared.getImageURL(forTag: tag), url.pathExtension.lowercased() == "gif" {
                    AnimatedGIFView(url: url)
                        .frame(width: 220, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let img = vm.selectedImage {
                    Image(nsImage: img).resizable().scaledToFit().frame(maxWidth: 220, maxHeight: 200)
                } else if let tag = vm.selectedTag, let url = CustomStorage.shared.getImageURL(forTag: tag), let nsimg = NSImage(contentsOf: url) {
                    Image(nsImage: nsimg).resizable().scaledToFit().frame(maxWidth: 220, maxHeight: 200)
                } else {
                    Text("No Media Selected")
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    // Defer to next runloop to avoid publishing during view update
                    DispatchQueue.main.async {
                        vm.chooseImageFromDisk()
                    }
                } label: {
                    HStack(alignment: .center, spacing: 6) {
                        Text("Upload Media")
                            .foregroundColor(.primary)
                        Image(systemName: "folder")
                    }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHoveringChoose ? Color.white.opacity(0.2) : Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }
                .onHover { isHovering in isHoveringChoose = isHovering }
                .buttonStyle(.plain)

                Button {
                    // Defer to next runloop to avoid publishing during view update
                    DispatchQueue.main.async {
                        vm.pasteImageFromPasteboard()
                    }
                } label: {
                    HStack(alignment: .center, spacing: 6) {
                        Text("Paste Media")
                            .foregroundColor(.primary)
                        Text("⌘V")
                            .foregroundColor(.secondary)
                    }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHoveringPaste ? Color.white.opacity(0.2) : Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }
                .onHover { isHovering in isHoveringPaste = isHovering }
                .buttonStyle(.plain)
            }
            .frame(width: 220, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("Accepted Formats: PNG, JPEG, GIF, HEIC, HEIF, TIFF, BMP, WebP")
                if let err = vm.errorMessage {
                  Text(err).foregroundStyle(.red.opacity(0.9))
                } else {
                  Text("Maximum size: 10 MB")
                }
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 12, weight: .medium))
            .frame(width: 220, alignment: .leading)

                Spacer()
                }
            }
        }
        .frame(alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { tagFocused = false }
        .onChange(of: tagFocused) { _, isFocused in
            if !isFocused { 
                DispatchQueue.main.async {
                    vm.submitIfPossible()
                }
            }
        }
    }
}


private struct AnimatedGIFView: NSViewRepresentable {
    var url: URL? = nil
    var data: Data? = nil

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        imageView.animates = true
        imageView.canDrawSubviewsIntoLayer = true
        imageView.wantsLayer = true
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: container.heightAnchor),
            imageView.widthAnchor.constraint(greaterThanOrEqualTo: container.widthAnchor, multiplier: 0.1),
            imageView.heightAnchor.constraint(greaterThanOrEqualTo: container.heightAnchor, multiplier: 0.1)
        ])
        context.coordinator.imageView = imageView
        setImage(on: imageView)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let imageView = context.coordinator.imageView {
            setImage(on: imageView)
        }
    }

    func setImage(on imageView: NSImageView) {
        if let data = data {
            imageView.image = NSImage(data: data)
        } else if let url = url {
            imageView.image = NSImage(contentsOf: url)
        } else {
            imageView.image = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { weak var imageView: NSImageView? }
}
