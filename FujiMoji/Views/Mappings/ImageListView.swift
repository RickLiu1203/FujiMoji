//
//  ImageListView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-09-01.
//

import SwiftUI

struct ImageTagListView: View {
    private struct ImageItem: Identifiable, Hashable {
        let id = UUID()
        var tag: String
    }

    @ObservedObject var vm: ImageTagMappingsViewModel
    @State private var isHoveringAdd = false
    var onSelect: (String) -> Void = { _ in }
    var showOnlyFavorites: Bool = false

    private struct RowView: View {
        let tag: String
        let isSelected: Bool
        let isFavorite: Bool
        let onDelete: (String) -> Void
        let onToggleFavorite: (String) -> Void
        @State private var isHovered = false

        var body: some View {
            HStack(spacing: 12) {
                Text(tag)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)

                HStack(spacing: 8) {
                    Button(action: { onToggleFavorite(tag) }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 13, weight: .regular))
                    }
                    .buttonStyle(.plain)

                    Button(action: { onDelete(tag) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .regular))
                    }
                    .buttonStyle(.plain)
                }
                .opacity(1)
                .allowsHitTesting(true)
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
                withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation {
                    vm.addNew()
                    if let tag = vm.selectedTag {
                        if showOnlyFavorites { vm.toggleFavorite(tag: tag) }
                        onSelect(tag)
                    }
                }
            } label: {
                Label("Add Media", systemImage: "plus")
                    .font(.system(size: 14))
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
            .onHover { isHovering in isHoveringAdd = isHovering }
            .padding(.bottom, 24)
            .buttonStyle(.plain)

            Divider()

            ScrollView {
                if (showOnlyFavorites && vm.items.filter { vm.favoriteImageTags.contains($0.tag.lowercased()) }.isEmpty) {
                    VStack(spacing: 8) {
                        Text("No Favourite Media Yet!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 64)
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if vm.items.isEmpty {
                    VStack(spacing: 8) {
                        Text("No Custom Media Yet!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 64)
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach((showOnlyFavorites ? vm.items.filter { vm.favoriteImageTags.contains($0.tag.lowercased()) } : vm.items), id: \.tag) { pair in
                            RowView(
                                tag: pair.tag,
                                isSelected: vm.selectedTag?.lowercased() == pair.tag.lowercased(),
                                isFavorite: vm.favoriteImageTags.contains(pair.tag.lowercased()),
                                onDelete: { tag in
                                    withAnimation(.easeInOut(duration: 0.2)) { vm.delete(tag: tag) }
                                },
                                onToggleFavorite: { tag in
                                    withAnimation(.easeInOut(duration: 0.2)) { vm.toggleFavorite(tag: tag) }
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    vm.selectedTag = pair.tag
                                    onSelect(pair.tag)
                                }
                            }
                            .contextMenu {
                                Button("Delete") { vm.delete(tag: pair.tag) }
                            }
                        }
                    }
                }
            }
            .onAppear { vm.reload() }
            .animation(.easeInOut(duration: 0.2), value: vm.items.map { $0.tag })
        }
        .padding(.leading, 16)
        .padding(.trailing, vm.items.count < 10 ? 8 : 4)
    }
}

