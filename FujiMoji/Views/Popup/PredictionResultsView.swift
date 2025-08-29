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
    let onTap: (T) -> Void
    let height: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            
            HorizontalMouseScrollView {
                HStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element) { index, item in
                        Button(action: {
                            onTap(item)
                        }) {
                            TagPill(
                                text: displayText(item),
                                isHighlighted: isHighlighted(index, item)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 12)
                .padding(.leading, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Horizontal scroll with mouse wheel support
struct HorizontalMouseScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
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
        if let hosting = nsView.documentView?.subviews.first as? NSHostingView<Content> {
            hosting.rootView = content
        }
    }
}

private class MouseWheelScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // Only convert vertical to horizontal for non-precise scrolling (mouse wheel)
        // Trackpad has precise scrolling and should handle horizontal scrolling naturally
        if event.scrollingDeltaX == 0 && event.scrollingDeltaY != 0 && !event.hasPreciseScrollingDeltas {
            guard let documentView = self.documentView else { return }
            let clipView = self.contentView
            let isNatural = event.isDirectionInvertedFromDevice
            let factor: CGFloat = 10.0  // Mouse wheel factor
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

// MARK: - TagPill Component
struct TagPill: View {
    let text: String
    let isHighlighted: Bool
    @State private var isHovering: Bool = false
    
    init(text: String, isHighlighted: Bool = false) {
        self.text = text
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
            let highlightColor = Color(red: 255/255, green: 226/255, blue: 99/255)
        Text(text)
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHighlighted ? highlightColor.opacity(0.2) : isHovering ? Color.primary.opacity(0.12) : Color.primary.opacity(0.08))
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isHighlighted ? highlightColor : Color.primary.opacity(0.15), lineWidth: 1)
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .frame(height: 34)
    }
}

