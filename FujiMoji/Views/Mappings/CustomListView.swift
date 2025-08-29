//
//  CustomListView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-26.
//

import SwiftUI

struct CustomListView: View {
    private struct CustomItem: Identifiable, Hashable {
        let id = UUID()
        var tag: String
        var value: String
    }

    private let tagWidth: CGFloat = 120

    private struct CustomRowView: View {
        let item: CustomItem
        let isSelected: Bool
        let tagWidth: CGFloat
        let onDelete: (String) -> Void
        @State private var isHovered = false

        var body: some View {
            HStack(spacing: 12) {
                Text(item.tag)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: tagWidth, alignment: .leading)
                    .padding(.leading, 4)
                Divider()
                    .opacity(0)
                Text(item.value)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)

                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "star")
                            .font(.system(size: 13, weight: .regular))
                    }
                    .buttonStyle(.plain)

                    Button(action: { onDelete(item.tag) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .regular))
                    }
                    .buttonStyle(.plain)
                }
                .opacity((isSelected || isHovered) ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isSelected || isHovered)
                .allowsHitTesting(isSelected || isHovered)
                .foregroundStyle(.secondary)
                .padding(.trailing, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.system(size: 14, weight: .regular))
            .padding(.leading, 4)
            .padding(.trailing, 8)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(isHovered ? 0.12 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke((isSelected || isHovered) ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.leading, 4)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
    }

    @ObservedObject var vm: CustomMappingsViewModel
    @State private var isHoveringAdd = false

    var onSelect: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Button {
                withAnimation {
                    vm.addNew()
                    if let tag = vm.selectedTag { onSelect(tag) }
                }
            } label: {
                Label("Add Custom Text", systemImage: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHoveringAdd ? Color.white.opacity(0.2) : Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            }
            .onHover { isHovering in
                isHoveringAdd = isHovering
            }
            .padding(.bottom, 24)
            .buttonStyle(.plain)

            HStack {
                Text("Tags")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .padding(.bottom, 12)
                    .frame(width: tagWidth + 12, alignment: .leading)
                Divider()
                    .padding(.bottom, 6)
                Text("Custom Texts")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: 24, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1.5)
                    .padding(.trailing, 15)
            }

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(vm.items, id: \.tag) { pair in
                        CustomRowView(
                            item: CustomItem(tag: pair.tag, value: pair.text),
                            isSelected: vm.selectedTag?.lowercased() == pair.tag.lowercased(),
                            tagWidth: tagWidth,
                            onDelete: { tag in
                                withAnimation {
                                    vm.delete(tag: tag)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.selectedTag = pair.tag
                            onSelect(pair.tag)
                        }
                    }
                }
            }
            .onAppear { vm.reload() }
        }
        .padding(.leading, 16)
        .padding(.trailing, vm.items.count < 10 ? 8 : 4)
        .frame(width: .infinity, height: .infinity)
    }
}
