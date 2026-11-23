import Combine
import SwiftUI

/// Isolated state for the teleprompter so word-by-word ticks never re-render MainWindowView or MetalPreviewView.
final class TeleprompterController: ObservableObject {
    @Published var isPlaying = false
    @Published var currentWordIndex = 0
    @Published private(set) var words: [String] = []
    @Published private(set) var chunks: [(id: Int, range: Range<Int>)] = []
    @Published private(set) var autoStopRemainingSeconds: Int?

    var isRecordingActive: (() -> Bool)?
    var onAutoStopRecording: (() -> Void)?

    private var wordTimer: Timer?
    private var autoStopTimer: Timer?
    private var autoStopDelaySeconds: Int? = 1
    private var currentWPM: Double = 140
    private let wordsPerChunk = 8

    func updateAutoStopDelay(_ delaySeconds: Int?) {
        autoStopDelaySeconds = delaySeconds
        if delaySeconds == nil {
            cancelAutoStop()
        }
    }

    func updateScript(_ script: String) {
        let parsed = script.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parsed != words else { return }
        cancelAutoStop()
        words = parsed
        currentWordIndex = 0

        var builtChunks: [(Int, Range<Int>)] = []
        var start = 0
        var chunkID = 0
        while start < parsed.count {
            let end = min(start + wordsPerChunk, parsed.count)
            builtChunks.append((chunkID, start..<end))
            start = end
            chunkID += 1
        }
        chunks = builtChunks
    }

    func updateWPM(_ wpm: Double) {
        currentWPM = wpm
        if isPlaying {
            startTimer()
        }
    }

    func startFromBeginning() {
        guard !words.isEmpty else { return }
        cancelAutoStop()
        currentWordIndex = 0
        isPlaying = true
        startTimer()
    }

    func togglePlayPause() {
        guard !words.isEmpty else { return }
        cancelAutoStop()
        if isPlaying {
            pause()
        } else {
            if currentWordIndex >= words.count - 1 {
                currentWordIndex = 0
            }
            isPlaying = true
            startTimer()
        }
    }

    func pause() {
        isPlaying = false
        stopTimer()
        cancelAutoStop()
    }

    func reset() {
        isPlaying = false
        stopTimer()
        cancelAutoStop()
        currentWordIndex = 0
    }

    func cancelAutoStop() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        if autoStopRemainingSeconds != nil {
            autoStopRemainingSeconds = nil
        }
    }

    var activeChunkID: Int {
        guard !words.isEmpty else { return 0 }
        let clamped = min(max(0, currentWordIndex), words.count - 1)
        return clamped / wordsPerChunk
    }

    private func startTimer() {
        stopTimer()
        guard isPlaying, !words.isEmpty else { return }
        let interval = max(0.15, 60.0 / max(40.0, currentWPM))
        wordTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.currentWordIndex < self.words.count - 1 {
                self.currentWordIndex += 1
            } else {
                self.isPlaying = false
                self.stopTimer()
                self.handleScriptFinished()
            }
        }
    }

    private func handleScriptFinished() {
        guard isRecordingActive?() == true, let delay = autoStopDelaySeconds else { return }
        cancelAutoStop()

        if delay <= 0 {
            onAutoStopRecording?()
            return
        }

        autoStopRemainingSeconds = delay
        autoStopTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            guard self.isRecordingActive?() == true else {
                self.cancelAutoStop()
                return
            }
            let next = (self.autoStopRemainingSeconds ?? 1) - 1
            if next <= 0 {
                self.cancelAutoStop()
                self.onAutoStopRecording?()
            } else {
                self.autoStopRemainingSeconds = next
            }
        }
    }

    private func stopTimer() {
        wordTimer?.invalidate()
        wordTimer = nil
    }

    deinit {
        stopTimer()
        autoStopTimer?.invalidate()
    }
}

/// Draggable, resizable, camera-aligned teleprompter overlay with word-by-word highlighting and auto-scroll.
struct TeleprompterOverlayView: View {
    static let defaultWidth: CGFloat = 440
    static let defaultHeight: CGFloat = 156
    static let minWidth: CGFloat = 280
    static let maxWidth: CGFloat = 780
    static let minHeight: CGFloat = 110
    static let maxHeight: CGFloat = 420
    static let defaultFontSize: CGFloat = 19
    static let minFontSize: CGFloat = 12
    static let maxFontSize: CGFloat = 42

    @ObservedObject var controller: TeleprompterController
    let wpm: Double
    @Binding var fontSize: CGFloat
    @Binding var offset: CGSize
    @Binding var width: CGFloat
    @Binding var height: CGFloat
    let onResetPosition: () -> Void
    let onEditScript: () -> Void

    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var resizeDelta: CGSize = .zero
    @State private var isHoveringResizeHandle = false

    private var isResizing: Bool {
        resizeDelta != .zero
    }

    private var effectiveWidth: CGFloat {
        Self.clampWidth(width + resizeDelta.width)
    }

    private var effectiveHeight: CGFloat {
        Self.clampHeight(height + resizeDelta.height)
    }

    static func clampWidth(_ value: CGFloat) -> CGFloat {
        min(max(value, minWidth), maxWidth)
    }

    static func clampHeight(_ value: CGFloat) -> CGFloat {
        min(max(value, minHeight), maxHeight)
    }

    static func clampFontSize(_ value: CGFloat) -> CGFloat {
        min(max(value, minFontSize), maxFontSize)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Keep text & ScrollView at committed (width, height) during drag so 120Hz mouse moves
            // never trigger expensive text re-wrapping or freeze the live Metal camera preview.
            VStack(spacing: 0) {
                teleprompterHeader

                Divider()
                    .background(Color.white.opacity(0.12))

                if controller.words.isEmpty {
                    emptyScriptPrompt
                } else {
                    scriptScrollBody
                }
            }
            .frame(width: width, height: height)
            .frame(width: effectiveWidth, height: effectiveHeight, alignment: .top)
            .clipped()
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                    .fill(Color.black.opacity(0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                    .stroke(
                        isResizing ? CoveColors.accent.opacity(0.8) : Color.white.opacity(0.18),
                        lineWidth: isResizing ? 1.5 : 1
                    )
            )

            if isResizing {
                Text("\(Int(effectiveWidth.rounded())) × \(Int(effectiveHeight.rounded())) px")
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.85)))
                    .padding(.trailing, 26)
                    .padding(.bottom, 7)
                    .allowsHitTesting(false)
            }

            cornerResizeHandle
        }
        .frame(width: effectiveWidth, height: effectiveHeight)
        .offset(x: offset.width + dragDelta.width, y: offset.height + dragDelta.height)
        .gesture(
            DragGesture(coordinateSpace: .global)
                .updating($dragDelta) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                }
        )
    }

    private var cornerResizeHandle: some View {
        Path { path in
            // Two subtle diagonal grip lines at bottom-right corner
            path.move(to: CGPoint(x: 10, y: 15))
            path.addLine(to: CGPoint(x: 15, y: 10))
            path.move(to: CGPoint(x: 6, y: 15))
            path.addLine(to: CGPoint(x: 15, y: 6))
        }
        .stroke(
            Color.white.opacity(isHoveringResizeHandle || isResizing ? 0.88 : 0.38),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
        )
        .frame(width: 22, height: 22)
        .contentShape(Rectangle())
        .padding(4)
        .onHover { hovering in
            isHoveringResizeHandle = hovering
        }
        .help("Drag to resize teleprompter")
        .highPriorityGesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .updating($resizeDelta) { value, state, _ in
                    // Multiply width delta by 2 when centered so symmetrical expansion matches cursor travel.
                    let widthMultiplier: CGFloat = (offset == .zero) ? 2.0 : 1.0
                    state = CGSize(
                        width: value.translation.width * widthMultiplier,
                        height: value.translation.height
                    )
                }
                .onEnded { value in
                    let widthMultiplier: CGFloat = (offset == .zero) ? 2.0 : 1.0
                    width = Self.clampWidth(width + value.translation.width * widthMultiplier)
                    height = Self.clampHeight(height + value.translation.height)
                }
        )
    }

    // MARK: - Header

    private var teleprompterHeader: some View {
        HStack(spacing: CoveSpacing.s) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))

            Text("Teleprompter")
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.85))

            Text("• \(Int(wpm)) WPM")
                .font(.caption2.monospacedDigit())
                .foregroundColor(.white.opacity(0.55))

            if let remaining = controller.autoStopRemainingSeconds {
                Text("• Stopping in \(remaining)s")
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundColor(CoveColors.warning)
            }

            Spacer()

            HStack(spacing: 2) {
                Button {
                    fontSize = Self.clampFontSize(fontSize - 2)
                } label: {
                    Text("A-")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(fontSize <= Self.minFontSize ? .white.opacity(0.32) : .white.opacity(0.85))
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(fontSize <= Self.minFontSize)
                .help("Decrease Font Size")

                Button {
                    fontSize = Self.clampFontSize(fontSize + 2)
                } label: {
                    Text("A+")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(fontSize >= Self.maxFontSize ? .white.opacity(0.32) : .white.opacity(0.9))
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(fontSize >= Self.maxFontSize)
                .help("Increase Font Size")
            }

            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(controller.words.isEmpty)
            .help(controller.isPlaying ? "Pause Teleprompter" : "Play Teleprompter")

            Button {
                controller.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(controller.words.isEmpty)
            .help("Reset to Start")

            if offset != .zero {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        onResetPosition()
                    }
                } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 11))
                        .foregroundColor(CoveColors.accent)
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .help("Center Under Camera")
            }

            Button {
                onEditScript()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .help("Edit Script")
        }
        .padding(.horizontal, CoveSpacing.m)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Script Body

    private var emptyScriptPrompt: some View {
        VStack(spacing: CoveSpacing.s) {
            Text("No teleprompter script yet.")
                .font(.callout)
                .foregroundColor(.white.opacity(0.75))
            Button("Add Script…") {
                onEditScript()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scriptScrollBody: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(controller.chunks, id: \.id) { chunk in
                        let localActiveIndex: Int? = {
                            let idx = controller.currentWordIndex
                            if idx < chunk.range.lowerBound {
                                return -1
                            } else if idx >= chunk.range.upperBound {
                                return chunk.range.count
                            } else {
                                return idx - chunk.range.lowerBound
                            }
                        }()

                        TeleprompterChunkRow(
                            words: Array(controller.words[chunk.range]),
                            localActiveState: localActiveIndex ?? -1,
                            fontSize: fontSize
                        )
                        .equatable()
                        .id(chunk.id)
                    }
                }
                .padding(.horizontal, CoveSpacing.l)
                .padding(.vertical, CoveSpacing.m)
            }
            .onChange(of: controller.activeChunkID) { newChunk in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newChunk, anchor: .center)
                }
            }
            .onChange(of: controller.currentWordIndex) { newIndex in
                if newIndex == 0 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(0, anchor: .top)
                    }
                }
            }
        }
    }
}

/// Equatable chunk row so only the chunk(s) affected by the active word re-render on each word tick.
private struct TeleprompterChunkRow: View, Equatable {
    let words: [String]
    /// -1: all upcoming; 0..<words.count: active word inside this chunk; >= words.count: all spoken.
    let localActiveState: Int
    let fontSize: CGFloat

    var body: some View {
        chunkText
            .font(.system(size: fontSize, weight: .medium))
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chunkText: Text {
        if localActiveState < 0 {
            return Text(words.joined(separator: " "))
                .foregroundColor(.white.opacity(0.92))
        }
        if localActiveState >= words.count {
            return Text(words.joined(separator: " "))
                .foregroundColor(.white.opacity(0.38))
        }

        var combined = Text("")
        for index in 0..<words.count {
            let word = words[index]
            let suffix = (index < words.count - 1) ? " " : ""
            let styled: Text
            if index < localActiveState {
                styled = Text(word + suffix)
                    .foregroundColor(.white.opacity(0.38))
            } else if index == localActiveState {
                styled = Text(word + suffix)
                    .foregroundColor(.yellow)
                    .fontWeight(.bold)
            } else {
                styled = Text(word + suffix)
                    .foregroundColor(.white.opacity(0.92))
            }
            combined = combined + styled
        }
        return combined
    }
}

/// Modal sheet for editing the teleprompter script text.
struct TeleprompterScriptSheet: View {
    @Binding var script: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Teleprompter Script")
                        .font(.headline)
                        .foregroundColor(CoveColors.textPrimary)
                    Text("Enter or paste your speaking script. Words highlight automatically while recording.")
                        .font(.caption)
                        .foregroundColor(CoveColors.textSecondary)
                }
                Spacer()
            }

            TextEditor(text: $script)
                .font(.body)
                .padding(8)
                .frame(minHeight: 220)
                .background(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .fill(CoveColors.surfaceSecondary.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .stroke(CoveColors.borderSubtle, lineWidth: 1)
                )

            HStack {
                Button("Clear") {
                    script = ""
                }
                .buttonStyle(.bordered)
                .disabled(script.isEmpty)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(CoveSpacing.xl)
        .frame(width: 480, height: 340)
    }
}
