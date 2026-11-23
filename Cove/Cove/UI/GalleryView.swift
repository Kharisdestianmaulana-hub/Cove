import AVKit
import ImageIO
import SwiftUI

/// Integrated camera-style media viewer: full photo/video preview on top, thumbnail filmstrip bar at the bottom.
struct GalleryView: View {
    let cameraManager: CameraManager
    let onClose: () -> Void

    @State private var mediaItems: [MediaItem] = []
    @State private var selectedItem: MediaItem?
    @State private var fullImage: NSImage?
    @State private var editSourceCIImage: CIImage?
    @State private var editRenderWorkItem: DispatchWorkItem?
    @State private var videoPlayer: AVPlayer?
    @State private var isLoading = true
    @State private var itemPendingDeletion: MediaItem?
    @State private var isEditing = false
    @State private var editAdjustments = AdjustmentState()
    @State private var editLook: LookPreset = .natural
    @State private var editedPreviewImage: NSImage?
    @State private var isExportingCopy = false
    @State private var exportFeedback: String?
    @State private var isZoomed = false
    @State private var copyFeedback: String?

    var body: some View {
        VStack(spacing: CoveSpacing.m) {
            galleryHeader

            if isLoading {
                loadingState
            } else if mediaItems.isEmpty {
                emptyState
            } else {
                VStack(spacing: CoveSpacing.m) {
                    mainPreviewArea
                    bottomFilmstripBar
                }
            }
        }
        .padding(CoveSpacing.l)
        .background(
            RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous)
                .fill(CoveColors.surfaceSecondary.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous)
                .stroke(CoveColors.borderSubtle, lineWidth: 1)
        )
        .onAppear {
            loadMedia()
        }
        .background(
            GalleryKeyMonitorView(
                onLeftArrow: { selectPrevious() },
                onRightArrow: { selectNext() },
                onEscape: {
                    if isEditing {
                        withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                            isEditing = false
                        }
                    } else {
                        onClose()
                    }
                }
            )
        )
        .onDisappear {
            editRenderWorkItem?.cancel()
            editRenderWorkItem = nil
            videoPlayer?.pause()
            videoPlayer = nil
        }
        .onChange(of: selectedItem) { newItem in
            isEditing = false
            isZoomed = false
            editAdjustments = AdjustmentState()
            editLook = .natural
            exportFeedback = nil
            copyFeedback = nil
            preparePreview(for: newItem)
        }
        .onChange(of: editAdjustments) { _ in
            if isEditing {
                refreshEditedPreview()
            }
        }
        .alert("Move to Trash?", isPresented: Binding(
            get: { itemPendingDeletion != nil },
            set: { if !$0 { itemPendingDeletion = nil } }
        )) {
            Button("Move to Trash", role: .destructive) {
                if let item = itemPendingDeletion {
                    deleteItem(item)
                }
                itemPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                itemPendingDeletion = nil
            }
        } message: {
            Text(itemPendingDeletion?.fileName ?? "This item will be moved to the Trash.")
        }
    }

    // MARK: - Header

    private var galleryHeader: some View {
        HStack(spacing: CoveSpacing.m) {
            Button {
                onClose()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Camera")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, CoveSpacing.m)
                .padding(.vertical, 6)
                .foregroundColor(CoveColors.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                        .fill(CoveColors.surfaceSecondary.opacity(0.65))
                )
            }
            .buttonStyle(.plain)

            if let selected = selectedItem {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selected.fileName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(CoveColors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(selected.isVideo ? "Video" : "Photo")
                        Text("•")
                        Text(selected.formattedFileSize)
                        Text("•")
                        Text(selected.formattedDate)
                    }
                    .font(.caption2)
                    .foregroundColor(CoveColors.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Media Library")
                        .font(.headline)
                        .foregroundColor(CoveColors.textPrimary)
                    Text("\(mediaItems.count) \(mediaItems.count == 1 ? "item" : "items")")
                        .font(.caption)
                        .foregroundColor(CoveColors.textSecondary)
                }
            }

            Spacer()

            if let copyFeedback = copyFeedback {
                Text(copyFeedback)
                    .font(.caption)
                    .foregroundColor(CoveColors.accent)
                    .padding(.horizontal, CoveSpacing.s)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(CoveColors.surfaceSecondary.opacity(0.65)))
                    .transition(.opacity)
            }

            if let selected = selectedItem {
                HStack(spacing: CoveSpacing.s) {
                    if !selected.isVideo {
                        Button {
                            copySelectedPhoto()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut("c", modifiers: .command)
                        .help("Copy Photo (⌘C)")
                    }

                    Button {
                        withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                            isEditing.toggle()
                            if isEditing {
                                refreshEditedPreview()
                            } else {
                                editedPreviewImage = nil
                                if selected.isVideo {
                                    preparePreview(for: selected)
                                }
                            }
                        }
                    } label: {
                        Label(isEditing ? "Done" : "Edit", systemImage: "slider.horizontal.3")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        cameraManager.revealInFinder(selected)
                    } label: {
                        Label("Finder", systemImage: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        cameraManager.openWithSystem(selected)
                    } label: {
                        Label("Open", systemImage: "arrow.up.forward.app")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        itemPendingDeletion = selected
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("Move to Trash")
                }
            }

            Button {
                loadMedia()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(CoveColors.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                            .fill(CoveColors.surfaceSecondary.opacity(0.65))
                    )
            }
            .buttonStyle(.plain)
            .help("Refresh Gallery")
        }
    }

    // MARK: - Main Full Preview + Optional Side Editor

    private var mainPreviewArea: some View {
        HStack(spacing: CoveSpacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                    .fill(Color.black)

                if let item = selectedItem {
                    if item.isVideo, let player = videoPlayer {
                        NativeAVPlayerView(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous))
                    } else if isEditing, let edited = editedPreviewImage {
                        Image(nsImage: edited)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(isZoomed ? 2.0 : 1.0)
                            .clipShape(RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous))
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    isZoomed.toggle()
                                }
                            }
                    } else if let fullImage = fullImage {
                        Image(nsImage: fullImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(isZoomed ? 2.0 : 1.0)
                            .clipShape(RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous))
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    isZoomed.toggle()
                                }
                            }
                    } else {
                        ProgressView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(navigationOverlayButtons)
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                    .stroke(CoveColors.borderSubtle, lineWidth: 1)
            )

            if isEditing, let item = selectedItem {
                galleryEditorPanel(for: item)
                    .frame(width: 248)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var navigationOverlayButtons: some View {
        if mediaItems.count >= 2 {
            HStack {
                Button {
                    selectPrevious()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(!canSelectPrevious)
                .opacity(canSelectPrevious ? 1.0 : 0.25)
                .help("Previous (←)")

                Spacer()

                Button {
                    selectNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(!canSelectNext)
                .opacity(canSelectNext ? 1.0 : 0.25)
                .help("Next (→)")
            }
            .padding(.horizontal, CoveSpacing.l)
        }
    }

    private var selectedIndex: Int? {
        guard let selected = selectedItem else { return nil }
        return mediaItems.firstIndex(where: { $0.id == selected.id })
    }

    private var canSelectPrevious: Bool {
        guard let index = selectedIndex else { return false }
        return index > 0
    }

    private var canSelectNext: Bool {
        guard let index = selectedIndex else { return false }
        return index < mediaItems.count - 1
    }

    private func selectPrevious() {
        guard let index = selectedIndex, index > 0 else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            selectedItem = mediaItems[index - 1]
        }
    }

    private func selectNext() {
        guard let index = selectedIndex, index < mediaItems.count - 1 else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            selectedItem = mediaItems[index + 1]
        }
    }

    // MARK: - Bottom Horizontal Filmstrip Bar (Active Item Always Locked at Center)

    private var bottomFilmstripBar: some View {
        let activeIndex = selectedIndex ?? max(0, mediaItems.count - 1)

        return GeometryReader { geometry in
            let halfWidth = geometry.size.width / 2

            ZStack {
                ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                    let delta = index - activeIndex
                    let extraGap: CGFloat = delta == 0 ? 0 : (delta > 0 ? 10 : -10)
                    let xOffset = CGFloat(delta) * 78 + extraGap

                    if abs(xOffset) <= halfWidth + 90 {
                        filmstripThumbnail(for: item, isSelected: delta == 0)
                            .offset(x: xOffset)
                            .zIndex(delta == 0 ? 10 : Double(max(0, 10 - abs(delta))))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: activeIndex)
        }
        .frame(height: 88)
        .background(
            RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                .fill(CoveColors.surfaceSecondary.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                .stroke(CoveColors.borderSubtle, lineWidth: 1)
        )
    }

    private func filmstripThumbnail(for item: MediaItem, isSelected: Bool) -> some View {
        GalleryFilmstripThumbnailCell(
            item: item,
            isSelected: isSelected,
            cameraManager: cameraManager
        ) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                selectedItem = item
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: CoveSpacing.s) {
            ProgressView()
            Text("Loading captured media…")
                .font(.callout)
                .foregroundColor(CoveColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: CoveSpacing.m) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34))
                .foregroundColor(CoveColors.textSecondary)
            Text("No Captured Media Yet")
                .font(.title3)
                .foregroundColor(CoveColors.textPrimary)
            Text("Photos and videos you capture with Cove will appear here.")
                .font(.callout)
                .foregroundColor(CoveColors.textSecondary)
            Button("Return to Camera") {
                onClose()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func loadMedia() {
        isLoading = true
        cameraManager.loadGalleryMedia { items in
            // Order oldest-on-left to newest-on-right so newest opens centered with older items to the left.
            let chronological = Array(items.reversed())
            self.mediaItems = chronological
            self.isLoading = false
            if let current = self.selectedItem, chronological.contains(where: { $0.id == current.id }) {
                self.selectedItem = current
            } else {
                self.selectedItem = chronological.last
            }
        }
    }

    private func preparePreview(for item: MediaItem?) {
        editRenderWorkItem?.cancel()
        editRenderWorkItem = nil
        videoPlayer?.pause()
        videoPlayer = nil
        fullImage = nil
        editSourceCIImage = nil
        editedPreviewImage = nil

        guard let item = item else { return }

        if item.isVideo {
            videoPlayer = AVPlayer(url: item.url)
        } else {
            let url = item.url
            DispatchQueue.global(qos: .userInitiated).async {
                let downsampledCG = Self.loadDownsampledCGImage(at: url, maxPixelSize: 1600)
                let previewNSImage: NSImage?
                let previewCIImage: CIImage?
                if let cgImage = downsampledCG {
                    previewNSImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    previewCIImage = CIImage(cgImage: cgImage)
                } else {
                    previewNSImage = NSImage(contentsOf: url)
                    previewCIImage = CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
                }

                DispatchQueue.main.async {
                    if self.selectedItem?.url == url {
                        self.fullImage = previewNSImage
                        self.editSourceCIImage = previewCIImage
                    }
                }
            }
        }
    }

    private static func loadDownsampledCGImage(at url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func deleteItem(_ item: MediaItem) {
        do {
            try cameraManager.deleteMedia(item)
            GalleryThumbnailCache.shared.remove(for: item.url)
            mediaItems.removeAll { $0.id == item.id }
            if selectedItem?.id == item.id {
                selectedItem = mediaItems.last
            }
        } catch {
            // Keep item if Trash operation fails.
        }
    }

    // MARK: - Non-Destructive Editor Panel

    private func galleryEditorPanel(for item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: CoveSpacing.m) {
            Text("EDIT LOOK & ADJUST")
                .font(.caption)
                .foregroundColor(CoveColors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(LookPreset.allCases) { preset in
                        Button {
                            editLook = preset
                            editAdjustments = preset.adjustments
                        } label: {
                            Text(preset.title)
                                .font(.caption2.weight(editLook == preset ? .semibold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .foregroundColor(editLook == preset ? CoveColors.textPrimary : CoveColors.textSecondary)
                                .background(
                                    Capsule()
                                        .fill(editLook == preset ? CoveColors.surfaceElevated : CoveColors.surfaceSecondary.opacity(0.6))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ScrollView {
                VStack(spacing: CoveSpacing.s) {
                    compactSlider("Exposure", value: $editAdjustments.exposure, range: -2.0...2.0)
                    compactSlider("Brightness", value: $editAdjustments.brightness, range: -0.4...0.4)
                    compactSlider("Contrast", value: $editAdjustments.contrast, range: 0.5...1.5)
                    compactSlider("Saturation", value: $editAdjustments.saturation, range: 0.0...2.0)
                    compactSlider("Highlights", value: $editAdjustments.highlights, range: 0.0...1.0)
                    compactSlider("Shadows", value: $editAdjustments.shadows, range: -1.0...1.0)
                    compactSlider("Sharpness", value: $editAdjustments.sharpness, range: 0.0...1.5)
                    compactSlider("Temp", value: $editAdjustments.temperature, range: 3500...9500)
                    compactSlider("Tint", value: $editAdjustments.tint, range: -50...50)
                }
            }

            if let feedback = exportFeedback {
                Text(feedback)
                    .font(.caption2)
                    .foregroundColor(CoveColors.textSecondary)
            }

            HStack {
                Button("Reset") {
                    editLook = .natural
                    editAdjustments = AdjustmentState()
                }
                .font(.caption)
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    saveEditedCopy(of: item)
                } label: {
                    if isExportingCopy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Save Copy")
                    }
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .disabled(isExportingCopy || editAdjustments.isIdentity)
            }
        }
        .padding(CoveSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                .fill(CoveColors.surfaceSecondary.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                .stroke(CoveColors.borderSubtle, lineWidth: 1)
        )
    }

    private func compactSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(CoveColors.textSecondary)
            Slider(value: value, in: range)
                .controlSize(.mini)
        }
    }

    private func refreshEditedPreview() {
        guard let item = selectedItem else { return }

        editRenderWorkItem?.cancel()

        if item.isVideo {
            let adj = editAdjustments
            let processor = cameraManager.imageProcessor
            let workItem = DispatchWorkItem { [weak videoPlayer] in
                let asset = AVAsset(url: item.url)
                let composition = AVMutableVideoComposition(asset: asset) { request in
                    let source = request.sourceImage.clampedToExtent()
                    let output = processor.apply(to: source, adjustments: adj)
                        .cropped(to: request.sourceImage.extent)
                    request.finish(with: output, context: processor.context)
                }
                let playerItem = AVPlayerItem(asset: asset)
                playerItem.videoComposition = composition
                DispatchQueue.main.async {
                    videoPlayer?.replaceCurrentItem(with: playerItem)
                }
            }
            editRenderWorkItem = workItem
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.09, execute: workItem)
            return
        }

        if editAdjustments.isIdentity {
            editedPreviewImage = nil
            return
        }

        guard let ciImage = editSourceCIImage else { return }

        let adj = editAdjustments
        let processor = cameraManager.imageProcessor
        let workItem = DispatchWorkItem {
            let processed = processor.apply(to: ciImage, adjustments: adj)
            guard let cgImage = processor.context.createCGImage(processed, from: processed.extent) else { return }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            DispatchQueue.main.async {
                if self.selectedItem?.id == item.id && self.isEditing {
                    self.editedPreviewImage = nsImage
                }
            }
        }
        editRenderWorkItem = workItem
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.035, execute: workItem)
    }

    private func saveEditedCopy(of item: MediaItem) {
        isExportingCopy = true
        exportFeedback = nil
        cameraManager.exportEditedCopy(of: item, adjustments: editAdjustments) { result in
            isExportingCopy = false
            switch result {
            case .success(let newURL):
                exportFeedback = "Saved \(newURL.lastPathComponent)"
                loadMedia()
            case .failure(let error):
                exportFeedback = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func copySelectedPhoto() {
        guard let selected = selectedItem, !selected.isVideo else { return }
        let imageToCopy = (isEditing ? editedPreviewImage : nil) ?? fullImage
        guard let image = imageToCopy else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])

        withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
            copyFeedback = "Copied"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                self.copyFeedback = nil
            }
        }
    }
}

/// Captures Left/Right arrow and Escape key presses reliably while GalleryView is active on macOS.
private struct GalleryKeyMonitorView: NSViewRepresentable {
    let onLeftArrow: () -> Void
    let onRightArrow: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyMonitorNSView {
        let view = KeyMonitorNSView()
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyMonitorNSView, context: Context) {
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow
        nsView.onEscape = onEscape
    }

    final class KeyMonitorNSView: NSView {
        var onLeftArrow: (() -> Void)?
        var onRightArrow: (() -> Void)?
        var onEscape: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if monitor == nil, window != nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self = self, event.window === self.window else { return event }
                    switch event.keyCode {
                    case 123: // Left Arrow
                        self.onLeftArrow?()
                        return nil
                    case 124: // Right Arrow
                        self.onRightArrow?()
                        return nil
                    case 53: // Escape
                        self.onEscape?()
                        return nil
                    default:
                        return event
                    }
                }
            }
        }

        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

/// Bounded in-memory thumbnail cache for Gallery filmstrip items.
private final class GalleryThumbnailCache {
    static let shared = GalleryThumbnailCache()

    private let cache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 120
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: NSImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: max(1, cost))
    }

    func remove(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}

/// Self-contained filmstrip thumbnail cell so loading one thumbnail only updates that cell.
private struct GalleryFilmstripThumbnailCell: View {
    let item: MediaItem
    let isSelected: Bool
    let cameraManager: CameraManager
    let onSelect: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                    .fill(CoveColors.surfaceSecondary.opacity(0.6))
                    .frame(width: 72, height: 64)

                if let image = thumbnail ?? GalleryThumbnailCache.shared.image(for: item.url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 64)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous))
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 72, height: 64)
                        .onAppear {
                            loadThumbnailIfNeeded()
                        }
                }

                if item.isVideo {
                    Image(systemName: "video.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(Color.black.opacity(0.65)))
                        .padding(4)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                    .stroke(isSelected ? Color.white : CoveColors.borderSubtle, lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.12 : 0.82)
            .opacity(isSelected ? 1.0 : 0.55)
            .shadow(color: isSelected ? Color.black.opacity(0.35) : .clear, radius: 6, y: 2)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func loadThumbnailIfNeeded() {
        if let cached = GalleryThumbnailCache.shared.image(for: item.url) {
            thumbnail = cached
            return
        }
        let targetURL = item.url
        cameraManager.loadThumbnail(for: item) { image in
            guard let image = image else { return }
            GalleryThumbnailCache.shared.set(image, for: targetURL)
            self.thumbnail = image
        }
    }
}

/// Native AppKit AVPlayerView wrapper that avoids the macOS _AVKit_SwiftUI metadata crash in Release builds.
private struct NativeAVPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = true
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
