//
//  ImageBlockView.swift
//  TextEditor
//
//  Image block with resizable container, zoom slider, and pan controls.
//

import SwiftUI
import SwiftData
import SDWebImageSwiftUI

struct ImageBlockView: View {
    @Bindable var imageData: ImageData
    var onDelete: () -> Void = {}
    @Environment(\.modelContext) var context

    @State private var isHovering = false
    @State private var showZoomSlider = false

    // Drag state for live preview
    @State private var dragWidth: Double?
    @State private var dragHeight: Double?
    @State private var dragOffsetX: Double?
    @State private var dragOffsetY: Double?
    @State private var dragScale: Double?

    // Track if currently panning image
    @State private var isPanning = false

    // Computed display values (drag preview or persisted)
    private var displayWidth: Double {
        dragWidth ?? imageData.width ?? 300
    }

    private var displayHeight: Double {
        dragHeight ?? imageData.height ?? 200
    }

    private var displayOffsetX: Double {
        dragOffsetX ?? imageData.offsetX ?? 0
    }

    private var displayOffsetY: Double {
        dragOffsetY ?? imageData.offsetY ?? 0
    }

    private var displayScale: Double {
        dragScale ?? imageData.scale ?? 1.0
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // Main container
            ZStack {
                imageContainer
            }
            .frame(maxWidth: (imageData.isFullWidth ?? false) ? .infinity : CGFloat(displayWidth))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            // Alt text caption
            if let alt = imageData.altText, !alt.isEmpty {
                Text(alt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .opacity(isHovering ? 1 : 0)
                    .frame(height: isHovering ? 20 : 0)
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Image", systemImage: "trash")
            }

            Button {
                resetImagePosition()
            } label: {
                Label("Reset Position & Zoom", systemImage: "arrow.counterclockwise")
            }
            
            Divider()
            
            Button {
                if let url = URL(string: imageData.urlString ?? "") {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(imageData.urlString ?? "", forType: .string)
                    #else
                    UIPasteboard.general.string = imageData.urlString ?? ""
                    #endif
                }
            } label: {
                Label("Copy Image URL", systemImage: "link")
            }
            
            Button {
                 if let url = URL(string: imageData.urlString ?? "") {
                     #if os(macOS)
                     NSWorkspace.shared.open(url)
                     #else
                     UIApplication.shared.open(url)
                     #endif
                 }
            } label: {
                Label("Open in Browser (Download)", systemImage: "arrow.down.circle")
            }
        }
    }

    // MARK: - Image Container

    @ViewBuilder
    private var imageContainer: some View {
        ZStack {
            // Clipped image view
            WebImage(url: URL(string: imageData.urlString ?? ""))
                .resizable()
                .indicator(.activity)
                .transition(.fade(duration: 0.5))
                .aspectRatio(contentMode: .fill)
                .scaleEffect(displayScale)
                .offset(x: displayOffsetX, y: displayOffsetY)
                .frame(width: (imageData.isFullWidth ?? false) ? nil : CGFloat(displayWidth),
                       height: CGFloat(displayHeight))
                .clipped()
                .contentShape(Rectangle())
                .gesture(panGesture)
                .onHover { hovering in
                    updateCursor(hovering: hovering, isPanning: isPanning)
                }
        }
        .frame(width: (imageData.isFullWidth ?? false) ? nil : CGFloat(displayWidth),
               height: CGFloat(displayHeight))
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(isHovering ? 0.4 : 0.15), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            topRightControls
        }
        .overlay(alignment: .bottom) {
            zoomSliderOverlay
        }
        .overlay(alignment: .bottomTrailing) {
            resizeHandle
        }
        .overlay(alignment: .trailing) {
            widthResizeHandle
        }
        .overlay(alignment: .bottom) {
            heightResizeHandle
        }
    }

    // MARK: - Pan Gesture

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isPanning {
                    isPanning = true
                    #if os(macOS)
                    NSCursor.closedHand.push()
                    #endif
                }
                dragOffsetX = (imageData.offsetX ?? 0) + value.translation.width
                dragOffsetY = (imageData.offsetY ?? 0) + value.translation.height
            }
            .onEnded { _ in
                commitPan()
            }
    }

    private func commitPan() {
        imageData.offsetX = dragOffsetX ?? imageData.offsetX ?? 0
        imageData.offsetY = dragOffsetY ?? imageData.offsetY ?? 0
        dragOffsetX = nil
        dragOffsetY = nil
        isPanning = false
        #if os(macOS)
        NSCursor.pop()
        #endif
        try? context.save()
    }

    // MARK: - Top Right Controls

    @ViewBuilder
    private var topRightControls: some View {
        HStack(spacing: 6) {
            // Full width toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    imageData.isFullWidth = !(imageData.isFullWidth ?? false)
                    if !(imageData.isFullWidth ?? false) && imageData.width == nil {
                        imageData.width = 300
                    }
                    try? context.save()
                }
            } label: {
                Image(systemName: (imageData.isFullWidth ?? false) ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help((imageData.isFullWidth ?? false) ? "Shrink to fixed width" : "Expand to full width")

            // Zoom toggle (shows/hides slider)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showZoomSlider.toggle()
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(showZoomSlider ? .blue : .primary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Toggle zoom slider")
        }
        .padding(8)
        .opacity(isHovering ? 1 : 0)
    }

    // MARK: - Zoom Slider

    @ViewBuilder
    private var zoomSliderOverlay: some View {
        if showZoomSlider {
            HStack(spacing: 8) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Slider(value: Binding(
                    get: { displayScale },
                    set: { newValue in
                        dragScale = newValue
                    }
                ), in: 0.1...3.0, step: 0.1)
                .frame(width: 120)
                .onChange(of: dragScale) { _, newScale in
                    if let scale = newScale {
                        imageData.scale = scale
                        dragScale = nil
                        try? context.save()
                    }
                }

                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text(String(format: "%.0f%%", displayScale * 100))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 8)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Resize Handles

    @ViewBuilder
    private var resizeHandle: some View {
        if !(imageData.isFullWidth ?? false) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .padding(8)
                .opacity(isHovering ? 1 : 0)
                .gesture(cornerResizeGesture)
                .onHover { hovering in
                    #if os(macOS)
                    if hovering {
                        NSCursor.resizeDiagonal.push()
                    } else {
                        NSCursor.pop()
                    }
                    #endif
                }
        }
    }

    @ViewBuilder
    private var widthResizeHandle: some View {
        if !(imageData.isFullWidth ?? false) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 8)
                .contentShape(Rectangle())
                .gesture(widthResizeGesture)
                .onHover { hovering in
                    #if os(macOS)
                    if hovering {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                    #endif
                }
                .opacity(isHovering ? 1 : 0)
        }
    }

    @ViewBuilder
    private var heightResizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(heightResizeGesture)
            .onHover { hovering in
                #if os(macOS)
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
                #endif
            }
            .opacity(isHovering ? 1 : 0)
    }

    // MARK: - Resize Gestures

    private var cornerResizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let baseWidth = imageData.width ?? 300
                let baseHeight = imageData.height ?? 200
                dragWidth = max(baseWidth + value.translation.width, 100)
                dragHeight = max(baseHeight + value.translation.height, 80)
            }
            .onEnded { _ in
                commitResize()
            }
    }

    private var widthResizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let baseWidth = imageData.width ?? 300
                dragWidth = max(baseWidth + value.translation.width, 100)
            }
            .onEnded { _ in
                commitResize()
            }
    }

    private var heightResizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let baseHeight = imageData.height ?? 200
                dragHeight = max(baseHeight + value.translation.height, 80)
            }
            .onEnded { _ in
                commitResize()
            }
    }

    private func commitResize() {
        if let w = dragWidth {
            imageData.width = w
        }
        if let h = dragHeight {
            imageData.height = h
        }
        dragWidth = nil
        dragHeight = nil
        try? context.save()
    }

    // MARK: - Helpers

    private func resetImagePosition() {
        imageData.offsetX = 0
        imageData.offsetY = 0
        imageData.scale = 1.0
        try? context.save()
    }

    private func updateCursor(hovering: Bool, isPanning: Bool) {
        #if os(macOS)
        if isPanning {
            return // Don't change cursor while panning
        }
        if hovering {
            NSCursor.openHand.push()
        } else {
            NSCursor.pop()
        }
        #endif
    }
}

// MARK: - Cursor Extensions

#if os(macOS)
extension NSCursor {
    static var resizeDiagonal: NSCursor {
        // Use the system resize cursor
        return NSCursor(image: NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil)!, hotSpot: NSPoint(x: 8, y: 8))
    }
}
#endif
