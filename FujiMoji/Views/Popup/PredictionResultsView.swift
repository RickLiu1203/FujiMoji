//
//  PredictionResultsView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-28.
//

import SwiftUI

struct PredictionResultsView<T: Hashable>: View {
    let title: String
    let items: [T]
    let displayText: (T) -> String
    let isHighlighted: (Int, T) -> Bool
    let isFavorite: (T) -> Bool
    let onTap: (T) -> Void
    let highlightedIndex: Int
    let height: CGFloat = 60
    @State private var didPerformInitialScroll: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.element) { index, item in
                            Button(action: {
                                onTap(item)
                            }) {
                                TagPill(
                                    text: displayText(item),
                                    isHighlighted: isHighlighted(index, item),
                                    isFavorite: isFavorite(item)
                                )
                            }
                            .buttonStyle(.plain)
                            .id("pill_\(index)")
                        }
                    }
                    .padding(.trailing, 12)
                    .padding(.leading, 2)
                }
                .scrollDisabled(true) // Only allow programmatic scrolling
                .onAppear {
                    // Keep initial content left-aligned; don't scroll if highlighting first item
                    guard highlightedIndex > 0, !items.isEmpty, highlightedIndex < items.count else { return }
                    var transaction = Transaction(animation: nil)
                    withTransaction(transaction) {
                        proxy.scrollTo("pill_\(highlightedIndex)", anchor: .leading)
                    }
                    didPerformInitialScroll = true
                }
                .onChange(of: items) { _ in
                    // Avoid any jump when data swaps; only align if highlight not at start
                    didPerformInitialScroll = false
                    guard highlightedIndex > 0, !items.isEmpty, highlightedIndex < items.count else { return }
                    var transaction = Transaction(animation: nil)
                    withTransaction(transaction) {
                        proxy.scrollTo("pill_\(highlightedIndex)", anchor: .leading)
                    }
                    didPerformInitialScroll = true
                }
                .onChange(of: highlightedIndex) { newIndex in
                    guard !items.isEmpty, newIndex >= 0, newIndex < items.count else { return }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo("pill_\(newIndex)", anchor: .leading)
                    }
                }
            }
        }
        .transaction { transaction in transaction.animation = nil }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - TagPill Component
struct TagPill: View {
    let text: String
    let isHighlighted: Bool
    let isFavorite: Bool
    @State private var isHovering: Bool = false
    
    init(text: String, isHighlighted: Bool = false, isFavorite: Bool = false) {
        self.text = text
        self.isHighlighted = isHighlighted
        self.isFavorite = isFavorite
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHighlighted ? .accentColor.opacity(0.2) : isHovering ? Color.primary.opacity(0.12) : Color.primary.opacity(0.08))
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isHighlighted ? .accentColor : Color.primary.opacity(0.15), lineWidth: 1)
            )
            .overlay(
                Group {
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
                .offset(x: 5, y: -5), // Position in top-right corner
                alignment: .topTrailing
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .frame(height: 36)
    }
}

