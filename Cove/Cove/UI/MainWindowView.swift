import SwiftUI

/// Main Quiet Premium window layout:
/// - Unified translucent top + right chrome (Apple-like vibrancy)
/// - Camera preview on the left with floating bottom-center mode pill
/// - Right control strip with camera selector, centered shutter, and large recent media thumbnail
struct MainWindowView: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var appearanceMode: CoveAppearanceMode

    @State private var selectedSection: AppSection = .camera
    @State private var captureMode: CaptureMode = .photo
    @State private var isShowingGallery = false
    @State private var showLooksPopover = false
    @State private var showAdjustPopover = false
    @State private var showCompositionPopover = false
    @State private var isShowingSavePresetAlert = false
    @State private var newPresetName = ""
    @StateObject private var teleprompterController = TeleprompterController()
    @State private var teleprompterOffset: CGSize = .zero
    @State private var isShowingTeleprompterEditor = false

    @AppStorage("cove.compositionGuide") private var compositionGuideRaw = CompositionGuide.none.rawValue
    @AppStorage("cove.aspectRatio") private var aspectRatioRaw = PreviewAspectRatio.defaultRatio.rawValue
    @AppStorage("cove.cropToAspectRatio") private var cropToAspectRatio: Bool = false
    @AppStorage("cove.countdownDuration") private var countdownRaw = CountdownDuration.off.rawValue
    @AppStorage("cove.burstMode") private var burstModeRaw = BurstMode.off.rawValue
    @AppStorage("cove.teleprompterEnabled") private var teleprompterEnabled: Bool = false
    @AppStorage("cove.teleprompterScript") private var teleprompterScript: String = ""
    @AppStorage("cove.teleprompterWPM") private var teleprompterWPM: Double = 140
    @AppStorage("cove.teleprompterFontSize") private var teleprompterFontSize: Double = Double(TeleprompterOverlayView.defaultFontSize)
    @AppStorage("cove.teleprompterPreset") private var teleprompterPresetRaw: String = TeleprompterPreset.natural.rawValue
    @AppStorage("cove.teleprompterWidth") private var teleprompterWidth: Double = Double(TeleprompterOverlayView.defaultWidth)
    @AppStorage("cove.teleprompterHeight") private var teleprompterHeight: Double = Double(TeleprompterOverlayView.defaultHeight)
    @AppStorage("cove.teleprompterAutoStop") private var teleprompterAutoStopRaw: Int = TeleprompterAutoStopOption.oneSecond.rawValue
    @AppStorage("cove.videoBackgroundMode") private var videoBackgroundModeRaw: String = VideoBackgroundMode.off.rawValue
    @AppStorage("cove.videoBackgroundBlurRadius") private var videoBackgroundBlurRadius: Double = 18.0
    @AppStorage("cove.videoBackgroundImagePath") private var videoBackgroundImagePath: String = ""
    @AppStorage("cove.videoBackgroundImageName") private var videoBackgroundImageName: String = ""
    @AppStorage("cove.photoFormat") private var photoFormatRaw = CaptureConfiguration.PhotoFormat.jpeg.rawValue
    @AppStorage("cove.videoResolution") private var videoResolutionRaw = CaptureConfiguration.VideoResolution.hd1080p.rawValue
    @AppStorage("cove.recordAudio") private var recordAudio: Bool = true
    @AppStorage("cove.shutterSound") private var shutterSoundEnabled: Bool = true
    @AppStorage("cove.mirrorPreview") private var mirrorPreview: Bool = false
    @AppStorage("cove.hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    private var compositionGuide: CompositionGuide {
        get { CompositionGuide(rawValue: compositionGuideRaw) ?? .none }
    }

    private var aspectRatio: PreviewAspectRatio {
        get { PreviewAspectRatio(rawValue: aspectRatioRaw) ?? .defaultRatio }
    }

    private var countdownDuration: CountdownDuration {
        get { CountdownDuration(rawValue: countdownRaw) ?? .off }
    }

    private var burstMode: BurstMode {
        get { BurstMode(rawValue: burstModeRaw) ?? .off }
    }

    private var activeCropRatio: CGFloat? {
        cropToAspectRatio ? aspectRatio.numericRatio : nil
    }

    private var teleprompterPreset: TeleprompterPreset? {
        TeleprompterPreset(rawValue: teleprompterPresetRaw)
    }

    private var teleprompterAutoStop: TeleprompterAutoStopOption {
        TeleprompterAutoStopOption(rawValue: teleprompterAutoStopRaw) ?? .oneSecond
    }

    private var videoBackgroundMode: VideoBackgroundMode {
        VideoBackgroundMode(rawValue: videoBackgroundModeRaw) ?? .off
    }

    private var photoFormat: CaptureConfiguration.PhotoFormat {
        get { CaptureConfiguration.PhotoFormat(rawValue: photoFormatRaw) ?? .jpeg }
    }

    private var videoResolution: CaptureConfiguration.VideoResolution {
        get { CaptureConfiguration.VideoResolution(rawValue: videoResolutionRaw) ?? .hd1080p }
    }

    var body: some View {
        ZStack {
            CoveVisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            if !hasCompletedOnboarding {
                OnboardingView(
                    cameraManager: cameraManager,
                    appearanceMode: $appearanceMode
                ) {
                    withAnimation(.easeInOut(duration: CoveMotion.panelTransition)) {
                        hasCompletedOnboarding = true
                    }
                    cameraManager.start()
                    cameraManager.prepareAudioForVideoMode(enabled: captureMode == .video && recordAudio)
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    topNavigationBar
                        .padding(.horizontal, CoveSpacing.l)
                        .padding(.top, CoveSpacing.s)
                        .padding(.bottom, CoveSpacing.m)
                        .background(TitlebarInteractionView())

                    if isShowingGallery {
                        GalleryView(cameraManager: cameraManager) {
                            withAnimation(.easeInOut(duration: CoveMotion.panelTransition)) {
                                isShowingGallery = false
                            }
                        }
                        .padding([.horizontal, .bottom], CoveSpacing.l)
                    } else if selectedSection == .camera
                                || selectedSection == .composition
                                || selectedSection == .adjust
                                || selectedSection == .looks {
                        cameraWorkspace
                    } else if selectedSection == .settings {
                        SettingsView(
                            cameraManager: cameraManager,
                            appearanceMode: $appearanceMode,
                            photoFormat: Binding(
                                get: { photoFormat },
                                set: { photoFormatRaw = $0.rawValue }
                            ),
                            videoResolution: Binding(
                                get: { videoResolution },
                                set: {
                                    videoResolutionRaw = $0.rawValue
                                    cameraManager.updateVideoResolution($0)
                                }
                            ),
                            recordAudio: $recordAudio,
                            shutterSoundEnabled: $shutterSoundEnabled,
                            mirrorPreview: $mirrorPreview,
                            compositionGuide: Binding(
                                get: { compositionGuide },
                                set: { compositionGuideRaw = $0.rawValue }
                            ),
                            aspectRatio: Binding(
                                get: { aspectRatio },
                                set: { aspectRatioRaw = $0.rawValue }
                            ),
                            cropToAspectRatio: $cropToAspectRatio,
                            countdownDuration: Binding(
                                get: { countdownDuration },
                                set: { countdownRaw = $0.rawValue }
                            ),
                            onResetDefaults: resetAllSettings,
                            onShowOnboarding: {
                                hasCompletedOnboarding = false
                                cameraManager.stop()
                            }
                        )
                        .padding([.horizontal, .bottom], CoveSpacing.l)
                    } else {
                        sectionPlaceholderView(for: selectedSection)
                            .padding([.horizontal, .bottom], CoveSpacing.l)
                    }
                }
            }
        }
        .onAppear {
            cameraManager.updateVideoResolution(videoResolution)
            cameraManager.isMirrored = mirrorPreview
            cameraManager.shutterSoundEnabled = shutterSoundEnabled
            cameraManager.setPreviewVisible(!isShowingGallery && selectedSection != .settings)
            teleprompterController.updateScript(teleprompterScript)
            teleprompterController.updateWPM(teleprompterWPM)
            teleprompterController.updateAutoStopDelay(teleprompterAutoStop.delaySeconds)
            teleprompterController.isRecordingActive = { cameraManager.isRecording }
            teleprompterController.onAutoStopRecording = {
                if cameraManager.isRecording {
                    cameraManager.toggleVideoRecording(includeAudio: recordAudio)
                }
            }
            if hasCompletedOnboarding {
                cameraManager.start()
                cameraManager.prepareAudioForVideoMode(enabled: captureMode == .video && recordAudio)
            }
            syncVideoBackground()
        }
        .onChange(of: teleprompterAutoStopRaw) { _ in
            teleprompterController.updateAutoStopDelay(teleprompterAutoStop.delaySeconds)
        }
        .onChange(of: captureMode) { mode in
            cameraManager.prepareAudioForVideoMode(enabled: mode == .video && recordAudio)
            syncVideoBackground()
        }
        .onChange(of: videoBackgroundModeRaw) { _ in
            syncVideoBackground()
        }
        .onChange(of: videoBackgroundBlurRadius) { _ in
            syncVideoBackground()
        }
        .onChange(of: videoBackgroundImagePath) { _ in
            syncVideoBackground()
        }
        .onChange(of: recordAudio) { enabled in
            cameraManager.prepareAudioForVideoMode(enabled: captureMode == .video && enabled)
        }
        .onChange(of: isShowingGallery) { showingGallery in
            cameraManager.setPreviewVisible(!showingGallery && selectedSection != .settings)
        }
        .onChange(of: selectedSection) { newSection in
            cameraManager.setPreviewVisible(!isShowingGallery && newSection != .settings)
        }
        .onChange(of: teleprompterScript) { newScript in
            teleprompterController.updateScript(newScript)
        }
        .onChange(of: teleprompterWPM) { newWPM in
            teleprompterController.updateWPM(newWPM)
        }
        .onChange(of: mirrorPreview) { newValue in
            cameraManager.isMirrored = newValue
        }
        .onChange(of: shutterSoundEnabled) { newValue in
            cameraManager.shutterSoundEnabled = newValue
        }
        .onDisappear {
            cameraManager.stop()
        }
        .background(
            CameraKeyMonitorView(
                isEnabled: hasCompletedOnboarding
                    && !isShowingGallery
                    && selectedSection != .settings
                    && !isShowingTeleprompterEditor
                    && !isShowingSavePresetAlert,
                onCaptureTrigger: {
                    if captureMode == .photo {
                        cameraManager.triggerPhotoCapture(
                            countdown: countdownDuration,
                            format: photoFormat,
                            burstMode: burstMode,
                            cropAspectRatio: activeCropRatio
                        )
                    } else {
                        cameraManager.toggleVideoRecording(includeAudio: recordAudio)
                    }
                },
                onEscape: {
                    if cameraManager.countdownRemaining != nil {
                        cameraManager.cancelCountdown()
                    }
                }
            )
        )
        .alert("Save Custom Look", isPresented: $isShowingSavePresetAlert) {
            TextField("Look Name", text: $newPresetName)
            Button("Save") {
                cameraManager.saveCustomPreset(name: newPresetName)
                newPresetName = ""
            }
            Button("Cancel", role: .cancel) {
                newPresetName = ""
            }
        } message: {
            Text("Save your current Adjust settings as a reusable Look preset.")
        }
        .sheet(isPresented: $isShowingTeleprompterEditor) {
            TeleprompterScriptSheet(script: $teleprompterScript)
        }
        .onChange(of: cameraManager.isRecording) { recording in
            if recording {
                if teleprompterEnabled && !teleprompterController.words.isEmpty {
                    teleprompterController.startFromBeginning()
                }
            } else {
                teleprompterController.reset()
            }
        }
        .onChange(of: captureMode) { mode in
            if mode != .video {
                teleprompterController.pause()
            }
        }
    }

    // MARK: - Top Navigation (Unified with Right Panel)

    private var topNavigationBar: some View {
        HStack(spacing: CoveSpacing.m) {
            HStack(spacing: CoveSpacing.s) {
                Image("CoveLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("Cove")
                    .font(.headline)
                    .foregroundColor(CoveColors.textPrimary)
            }
            .fixedSize()

            Spacer(minLength: 16)

            HStack(spacing: CoveSpacing.xs) {
                ForEach(Array(AppSection.allCases.enumerated()), id: \.element.id) { index, section in
                    Button {
                        withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                            isShowingGallery = false
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 12, weight: .medium))
                            Text(section.title)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        .fixedSize()
                        .padding(.horizontal, CoveSpacing.m)
                        .padding(.vertical, 6)
                        .foregroundColor((!isShowingGallery && selectedSection == section) ? CoveColors.textPrimary : CoveColors.textSecondary)
                        .background(
                            RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                .fill((!isShowingGallery && selectedSection == section) ? CoveColors.surfaceElevated.opacity(0.85) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            .fixedSize()
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .fill(CoveColors.surfaceSecondary.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .stroke(CoveColors.borderSubtle, lineWidth: 1)
            )

            appearanceMenu
        }
    }

    private var appearanceMenu: some View {
        Menu {
            ForEach(CoveAppearanceMode.allCases) { mode in
                Button {
                    appearanceMode = mode
                } label: {
                    HStack {
                        Text(mode.displayName)
                        if appearanceMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: appearanceIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(CoveColors.textSecondary)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                        .fill(CoveColors.surfaceSecondary.opacity(0.6))
                )
        }
        .menuStyle(.borderlessButton)
        .frame(width: 34)
        .help("Appearance: \(appearanceMode.displayName)")
    }

    private var appearanceIcon: String {
        switch appearanceMode {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    // MARK: - Camera Workspace (Seamless Unified Top + Right)

    private var cameraWorkspace: some View {
        HStack(spacing: 0) {
            previewArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, CoveSpacing.l)
                .padding(.bottom, CoveSpacing.l)

            if selectedSection == .composition {
                compositionControlPanel
                    .frame(width: 224)
            } else if selectedSection == .adjust {
                adjustControlPanel
                    .frame(width: 248)
            } else if selectedSection == .looks {
                looksControlPanel
                    .frame(width: 224)
            } else {
                rightControlPanel
                    .frame(width: 204)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous)
                .fill(Color.black)

            if cameraManager.sessionState == .running || cameraManager.sessionState == .initializing {
                if cameraManager.metalDevice != nil {
                    MetalPreviewView(renderer: cameraManager.metalRenderer, metalDevice: cameraManager.metalDevice)
                        .clipShape(RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous))
                } else {
                    CameraPreviewView(session: cameraManager.session)
                        .clipShape(RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous))
                }
            }

            if cameraManager.sessionState == .running {
                CompositionOverlayView(guide: compositionGuide, aspectRatio: aspectRatio)
                    .clipShape(RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous))
            }

            if let remaining = cameraManager.countdownRemaining {
                Text("\(remaining)")
                    .font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .frame(width: 112, height: 112)
                    .background(Circle().fill(Color.black.opacity(0.55)))
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5))
                    .transition(.scale.combined(with: .opacity))
            }

            if cameraManager.isCapturingPhoto {
                RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous)
                    .fill(Color.white.opacity(0.25))
                    .transition(.opacity)
            }

            previewTopOverlay
            previewBottomModeOverlay

            if captureMode == .video && teleprompterEnabled && cameraManager.sessionState == .running {
                TeleprompterOverlayView(
                    controller: teleprompterController,
                    wpm: teleprompterWPM,
                    fontSize: Binding(
                        get: { CGFloat(teleprompterFontSize) },
                        set: { teleprompterFontSize = Double($0) }
                    ),
                    offset: $teleprompterOffset,
                    width: Binding(
                        get: { CGFloat(teleprompterWidth) },
                        set: { teleprompterWidth = Double($0) }
                    ),
                    height: Binding(
                        get: { CGFloat(teleprompterHeight) },
                        set: { teleprompterHeight = Double($0) }
                    ),
                    onResetPosition: { teleprompterOffset = .zero },
                    onEditScript: { isShowingTeleprompterEditor = true }
                )
                .padding(.top, CoveSpacing.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            previewStateOverlay
        }
        .overlay(
            RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous)
                .stroke(CoveColors.borderSubtle, lineWidth: 1)
        )
    }

    private var previewTopOverlay: some View {
        VStack {
            HStack {
                if cameraManager.isRecording {
                    HStack(spacing: CoveSpacing.xs) {
                        Circle()
                            .fill(CoveColors.recording)
                            .frame(width: 8, height: 8)
                        Text(formattedDuration(cameraManager.recordingDuration))
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, CoveSpacing.m)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                } else if let burstText = cameraManager.burstProgressText {
                    Text(burstText)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, CoveSpacing.m)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                }

                Spacer()

                if let banner = cameraManager.statusBannerMessage {
                    Text(banner)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, CoveSpacing.m)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                        .transition(.opacity)
                }
            }
            .padding(CoveSpacing.m)

            Spacer()
        }
    }

    private var previewBottomModeOverlay: some View {
        VStack {
            Spacer()

            ZStack {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        ForEach(CaptureMode.allCases) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                                    captureMode = mode
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: mode.systemImage)
                                        .font(.system(size: 11, weight: .medium))
                                    Text(mode.title)
                                        .font(.system(size: 12, weight: captureMode == mode ? .semibold : .medium))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .foregroundColor(captureMode == mode ? .white : .white.opacity(0.72))
                                .background(
                                    Capsule()
                                        .fill(captureMode == mode ? Color.white.opacity(0.22) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(cameraManager.isRecording)
                        }
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 1, height: 18)
                        .padding(.horizontal, 2)

                    HStack(spacing: 4) {
                        quickControlButton(
                            systemImage: "camera.filters",
                            isActive: cameraManager.activeLook != .natural || cameraManager.activeCustomPresetID != nil,
                            helpText: "Looks"
                        ) {
                            showLooksPopover.toggle()
                        }
                        .popover(isPresented: $showLooksPopover, arrowEdge: .top) {
                            looksQuickPopover
                        }

                        quickControlButton(
                            systemImage: "slider.horizontal.3",
                            isActive: !cameraManager.adjustments.isIdentity,
                            helpText: "Adjust"
                        ) {
                            showAdjustPopover.toggle()
                        }
                        .popover(isPresented: $showAdjustPopover, arrowEdge: .top) {
                            adjustQuickPopover
                        }

                        quickControlButton(
                            systemImage: "square.grid.3x3",
                            isActive: compositionGuide != .none || aspectRatio != .defaultRatio,
                            helpText: "Composition"
                        ) {
                            showCompositionPopover.toggle()
                        }
                        .popover(isPresented: $showCompositionPopover, arrowEdge: .top) {
                            compositionQuickPopover
                        }
                    }
                }
                .padding(4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.62))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

                HStack {
                    Spacer()
                    floatingMirrorButton
                }
                .padding(.trailing, CoveSpacing.l)
            }
            .padding(.bottom, CoveSpacing.l)
        }
    }

    private var floatingMirrorButton: some View {
        Button {
            withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                mirrorPreview.toggle()
            }
        } label: {
            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(mirrorPreview ? CoveColors.accent : .white.opacity(0.88))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.black.opacity(mirrorPreview ? 0.72 : 0.62))
                )
                .overlay(
                    Circle()
                        .stroke(mirrorPreview ? CoveColors.accent.opacity(0.7) : Color.white.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(mirrorPreview ? "Mirror: On" : "Mirror: Off")
        .accessibilityLabel("Mirror Camera")
    }

    private func quickControlButton(
        systemImage: String,
        isActive: Bool,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? CoveColors.accent : .white.opacity(0.85))
                .frame(width: 30, height: 28)
                .background(
                    Circle()
                        .fill(isActive ? Color.white.opacity(0.18) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var looksQuickPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOOKS")
                .font(.caption)
                .foregroundColor(CoveColors.textSecondary)

            ForEach(LookPreset.allCases) { preset in
                let isSelected = cameraManager.activeCustomPresetID == nil && cameraManager.activeLook == preset
                Button {
                    cameraManager.selectLook(preset)
                } label: {
                    HStack {
                        Text(preset.title)
                            .font(.callout)
                            .foregroundColor(CoveColors.textPrimary)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(CoveColors.accent)
                        }
                    }
                    .padding(.horizontal, CoveSpacing.s)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                            .fill(isSelected ? CoveColors.surfaceSecondary : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            if !cameraManager.customPresets.isEmpty {
                Divider()
                    .padding(.vertical, 2)

                Text("CUSTOM")
                    .font(.caption2)
                    .foregroundColor(CoveColors.textSecondary)

                ForEach(cameraManager.customPresets) { preset in
                    let isSelected = cameraManager.activeCustomPresetID == preset.id
                    HStack(spacing: 4) {
                        Button {
                            cameraManager.selectCustomPreset(preset)
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .font(.callout)
                                    .foregroundColor(CoveColors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(CoveColors.accent)
                                }
                            }
                            .padding(.horizontal, CoveSpacing.s)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                    .fill(isSelected ? CoveColors.surfaceSecondary : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            cameraManager.deleteCustomPreset(preset)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(CoveColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Delete \(preset.name)")
                    }
                }
            }
        }
        .padding(CoveSpacing.m)
        .frame(width: 205)
    }

    private var adjustQuickPopover: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.m) {
            HStack {
                Text("ADJUST")
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)
                Spacer()
                if !cameraManager.adjustments.isIdentity {
                    Button("Save…") {
                        showAdjustPopover = false
                        newPresetName = ""
                        isShowingSavePresetAlert = true
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(CoveColors.accent)
                }
                Button("Reset") {
                    cameraManager.resetAdjustments()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(cameraManager.adjustments.isIdentity ? CoveColors.textTertiary : CoveColors.accent)
                .disabled(cameraManager.adjustments.isIdentity)
            }

            adjustmentSlider(
                title: "Exposure",
                value: $cameraManager.adjustments.exposure,
                range: -2.0...2.0,
                defaultValue: 0.0,
                format: "%+.2f"
            )
            adjustmentSlider(
                title: "Brightness",
                value: $cameraManager.adjustments.brightness,
                range: -0.4...0.4,
                defaultValue: 0.0,
                format: "%+.2f"
            )
            adjustmentSlider(
                title: "Contrast",
                value: $cameraManager.adjustments.contrast,
                range: 0.5...1.5,
                defaultValue: 1.0,
                format: "%.2f"
            )
            adjustmentSlider(
                title: "Saturation",
                value: $cameraManager.adjustments.saturation,
                range: 0.0...2.0,
                defaultValue: 1.0,
                format: "%.2f"
            )
            adjustmentSlider(
                title: "Temperature",
                value: $cameraManager.adjustments.temperature,
                range: 3500...9500,
                defaultValue: 6500,
                format: "%.0fK"
            )
        }
        .padding(CoveSpacing.m)
        .frame(width: 240)
    }

    private var compositionQuickPopover: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GUIDE")
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)

                ForEach(CompositionGuide.allCases) { guide in
                    let isSelected = compositionGuide == guide
                    Button {
                        compositionGuideRaw = guide.rawValue
                    } label: {
                        HStack(spacing: CoveSpacing.s) {
                            Image(systemName: guide.systemImage)
                                .font(.system(size: 12))
                                .frame(width: 16)
                            Text(guide.title)
                                .font(.callout)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(CoveColors.accent)
                            }
                        }
                        .padding(.horizontal, CoveSpacing.s)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                .fill(isSelected ? CoveColors.surfaceSecondary : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("ASPECT RATIO")
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)

                HStack(spacing: 4) {
                    ForEach(PreviewAspectRatio.allCases) { ratio in
                        Button {
                            aspectRatioRaw = ratio.rawValue
                        } label: {
                            Text(ratio.title)
                                .font(.caption.monospacedDigit())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .foregroundColor(aspectRatio == ratio ? CoveColors.textPrimary : CoveColors.textSecondary)
                                .background(
                                    RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                        .fill(aspectRatio == ratio ? CoveColors.surfaceSecondary : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if aspectRatio != .defaultRatio {
                    Toggle("Crop Photo to Ratio", isOn: $cropToAspectRatio)
                        .font(.caption)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .padding(.top, 4)
                }
            }
        }
        .padding(CoveSpacing.m)
        .frame(width: 220)
    }

    @ViewBuilder
    private var previewStateOverlay: some View {
        switch cameraManager.sessionState {
        case .idle, .initializing:
            VStack(spacing: CoveSpacing.s) {
                ProgressView()
                    .controlSize(.regular)
                Text("Initializing camera…")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(CoveSpacing.l)
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                    .fill(Color.black.opacity(0.55))
            )

        case .permissionDenied:
            VStack(spacing: CoveSpacing.m) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.85))
                Text("Camera Access Required")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Allow Cove to access your camera in System Settings to show the live preview.")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                HStack(spacing: CoveSpacing.s) {
                    Button("Open System Settings") {
                        cameraManager.openSystemPrivacySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Retry") {
                        cameraManager.retry()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(CoveSpacing.xl)

        case .unavailable:
            VStack(spacing: CoveSpacing.m) {
                Image(systemName: "video.slash")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.8))
                Text("No Camera Available")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Connect a compatible built-in or external camera to begin.")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                Button("Retry") {
                    cameraManager.retry()
                }
                .buttonStyle(.bordered)
            }
            .padding(CoveSpacing.xl)

        case .error(let message):
            VStack(spacing: CoveSpacing.m) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(CoveColors.warning)
                Text("Camera Error")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(message)
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                Button("Retry") {
                    cameraManager.retry()
                }
                .buttonStyle(.bordered)
            }
            .padding(CoveSpacing.xl)

        case .running:
            EmptyView()
        }
    }

    // MARK: - Right Control Panel (Seamless with Top Bar)

    private var rightControlPanel: some View {
        VStack(spacing: CoveSpacing.m) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: CoveSpacing.l) {
                    cameraSelectorGroup

                    if captureMode == .photo {
                        timerQuickSelector
                        burstQuickSelector
                    } else {
                        microphoneSelectorGroup
                        backgroundControlGroup
                        teleprompterControlGroup
                    }
                }
            }

            captureButtonSection
                .padding(.bottom, CoveSpacing.xs)

            largeRecentMediaCard
        }
        .padding(.horizontal, CoveSpacing.l)
        .padding(.top, CoveSpacing.xs)
        .padding(.bottom, CoveSpacing.l)
    }

    private var timerQuickSelector: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.s) {
            Text("TIMER")
                .font(.caption)
                .foregroundColor(CoveColors.textSecondary)

            HStack(spacing: 4) {
                ForEach(CountdownDuration.allCases) { duration in
                    Button {
                        countdownRaw = duration.rawValue
                    } label: {
                        Text(duration.title)
                            .font(.caption.monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .foregroundColor(countdownDuration == duration ? CoveColors.textPrimary : CoveColors.textSecondary)
                            .background(
                                RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                    .fill(countdownDuration == duration ? CoveColors.surfaceElevated.opacity(0.85) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .fill(CoveColors.surfaceSecondary.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .stroke(CoveColors.borderSubtle, lineWidth: 1)
            )
        }
    }

    private var burstQuickSelector: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.s) {
            Text("BURST")
                .font(.caption)
                .foregroundColor(CoveColors.textSecondary)

            HStack(spacing: 4) {
                ForEach(BurstMode.allCases) { mode in
                    Button {
                        burstModeRaw = mode.rawValue
                    } label: {
                        Text(mode.title)
                            .font(.caption.monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .foregroundColor(burstMode == mode ? CoveColors.textPrimary : CoveColors.textSecondary)
                            .background(
                                RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                    .fill(burstMode == mode ? CoveColors.surfaceElevated.opacity(0.85) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .fill(CoveColors.surfaceSecondary.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .stroke(CoveColors.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func syncVideoBackground() {
        let effectiveMode: VideoBackgroundMode = (captureMode == .video) ? videoBackgroundMode : .off
        cameraManager.setVideoBackground(
            mode: effectiveMode,
            blurRadius: videoBackgroundBlurRadius,
            customImagePath: videoBackgroundImagePath
        )
    }

    private var backgroundControlGroup: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.s) {
            Text("BACKGROUND")
                .font(.caption)
                .foregroundColor(CoveColors.textSecondary)

            VStack(alignment: .leading, spacing: CoveSpacing.s) {
                HStack(spacing: 3) {
                    ForEach(VideoBackgroundMode.allCases) { mode in
                        let isSelected = videoBackgroundMode == mode
                        Button {
                            videoBackgroundModeRaw = mode.rawValue
                        } label: {
                            Text(mode.title)
                                .font(.caption2.weight(isSelected ? .semibold : .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .foregroundColor(isSelected ? CoveColors.textPrimary : CoveColors.textSecondary)
                                .background(
                                    RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                        .fill(isSelected ? CoveColors.surfaceElevated.opacity(0.85) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if videoBackgroundMode == .blur {
                    VStack(spacing: 2) {
                        HStack {
                            Text("Blur Intensity")
                                .font(.caption2)
                                .foregroundColor(CoveColors.textSecondary)
                            Spacer()
                            Text("\(Int(videoBackgroundBlurRadius.rounded()))")
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(CoveColors.textSecondary)
                        }
                        Slider(value: $videoBackgroundBlurRadius, in: 6...34, step: 1)
                            .controlSize(.mini)
                    }
                } else if videoBackgroundMode == .customImage {
                    HStack(spacing: 6) {
                        Button {
                            if let picked = cameraManager.chooseCustomBackgroundImage() {
                                videoBackgroundImagePath = picked.path
                                videoBackgroundImageName = picked.fileName
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "photo")
                                    .font(.system(size: 11))
                                Text(videoBackgroundImageName.isEmpty ? "Choose Image…" : videoBackgroundImageName)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                            .padding(.horizontal, CoveSpacing.s)
                            .padding(.vertical, 5)
                            .foregroundColor(CoveColors.textPrimary)
                            .background(
                                RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                    .fill(CoveColors.surfaceElevated.opacity(0.65))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .fill(CoveColors.surfaceSecondary.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .stroke(CoveColors.borderSubtle, lineWidth: 1)
            )
        }
    }

    private var teleprompterControlGroup: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.s) {
            HStack {
                Text("TELEPROMPTER")
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)
                Spacer()
                Toggle("", isOn: $teleprompterEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }

            if teleprompterEnabled {
                VStack(alignment: .leading, spacing: CoveSpacing.s) {
                    Button {
                        isShowingTeleprompterEditor = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.plaintext")
                                .font(.system(size: 12))
                            Text(teleprompterScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add Script…" : "Edit Script…")
                                .font(.caption)
                            Spacer()
                        }
                        .padding(.horizontal, CoveSpacing.s)
                        .padding(.vertical, 6)
                        .foregroundColor(CoveColors.textPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                .fill(CoveColors.surfaceElevated.opacity(0.65))
                        )
                    }
                    .buttonStyle(.plain)

                    Text("PRESET")
                        .font(.caption2)
                        .foregroundColor(CoveColors.textSecondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(TeleprompterPreset.allCases) { preset in
                            let isSelected = teleprompterPreset == preset
                                && Int(teleprompterWPM) == Int(preset.wpm)
                                && Int(teleprompterFontSize.rounded()) == Int(preset.textSize.fontSize)
                            Button {
                                teleprompterPresetRaw = preset.rawValue
                                teleprompterWPM = preset.wpm
                                teleprompterFontSize = Double(preset.textSize.fontSize)
                            } label: {
                                Text(preset.title)
                                    .font(.caption2.weight(isSelected ? .semibold : .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .foregroundColor(isSelected ? CoveColors.textPrimary : CoveColors.textSecondary)
                                    .background(
                                        RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                            .fill(isSelected ? CoveColors.surfaceElevated.opacity(0.85) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(spacing: 2) {
                        HStack {
                            Text("Speed")
                                .font(.caption2)
                                .foregroundColor(CoveColors.textSecondary)
                            Spacer()
                            Text("\(Int(teleprompterWPM)) WPM")
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(CoveColors.textSecondary)
                        }
                        Slider(value: $teleprompterWPM, in: 80...220, step: 5)
                            .controlSize(.mini)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Font Size")
                                .font(.caption2)
                                .foregroundColor(CoveColors.textSecondary)
                            Spacer()
                            ForEach(TeleprompterTextSize.allCases) { size in
                                let isSelected = Int(teleprompterFontSize.rounded()) == Int(size.fontSize)
                                Button {
                                    teleprompterFontSize = Double(size.fontSize)
                                } label: {
                                    Text(size.shortTitle)
                                        .font(.caption2)
                                        .frame(width: 22, height: 20)
                                        .foregroundColor(isSelected ? CoveColors.textPrimary : CoveColors.textSecondary)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(isSelected ? CoveColors.surfaceElevated.opacity(0.85) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 6) {
                            TeleprompterDimensionField(
                                label: "px",
                                value: $teleprompterFontSize,
                                range: Double(TeleprompterOverlayView.minFontSize)...Double(TeleprompterOverlayView.maxFontSize)
                            )
                            .frame(width: 58)
                            Slider(
                                value: $teleprompterFontSize,
                                in: Double(TeleprompterOverlayView.minFontSize)...Double(TeleprompterOverlayView.maxFontSize),
                                step: 1
                            )
                            .controlSize(.mini)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Box (px)")
                                .font(.caption2)
                                .foregroundColor(CoveColors.textSecondary)
                            Spacer()
                            if Int(teleprompterWidth.rounded()) != Int(TeleprompterOverlayView.defaultWidth)
                                || Int(teleprompterHeight.rounded()) != Int(TeleprompterOverlayView.defaultHeight) {
                                Button("Reset") {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                        teleprompterWidth = Double(TeleprompterOverlayView.defaultWidth)
                                        teleprompterHeight = Double(TeleprompterOverlayView.defaultHeight)
                                    }
                                }
                                .font(.caption2)
                                .buttonStyle(.plain)
                                .foregroundColor(CoveColors.accent)
                            }
                        }

                        HStack(spacing: 6) {
                            TeleprompterDimensionField(
                                label: "W",
                                value: $teleprompterWidth,
                                range: Double(TeleprompterOverlayView.minWidth)...Double(TeleprompterOverlayView.maxWidth)
                            )
                            TeleprompterDimensionField(
                                label: "H",
                                value: $teleprompterHeight,
                                range: Double(TeleprompterOverlayView.minHeight)...Double(TeleprompterOverlayView.maxHeight)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-Stop")
                            .font(.caption2)
                            .foregroundColor(CoveColors.textSecondary)

                        HStack(spacing: 3) {
                            ForEach(TeleprompterAutoStopOption.allCases) { option in
                                let isSelected = teleprompterAutoStop == option
                                Button {
                                    teleprompterAutoStopRaw = option.rawValue
                                } label: {
                                    Text(option.title)
                                        .font(.caption2.monospacedDigit().weight(isSelected ? .semibold : .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                        .foregroundColor(isSelected ? CoveColors.textPrimary : CoveColors.textSecondary)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(isSelected ? CoveColors.surfaceElevated.opacity(0.85) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if teleprompterOffset != .zero {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                teleprompterOffset = .zero
                            }
                        } label: {
                            Label("Center Under Camera", systemImage: "scope")
                                .font(.caption2)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(CoveSpacing.s)
                .background(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .fill(CoveColors.surfaceSecondary.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .stroke(CoveColors.borderSubtle, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Composition Control Panel

    private var compositionControlPanel: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.l) {
            VStack(alignment: .leading, spacing: CoveSpacing.s) {
                Text("GUIDE OVERLAY")
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)

                VStack(spacing: 4) {
                    ForEach(CompositionGuide.allCases) { guide in
                        Button {
                            withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                                compositionGuideRaw = guide.rawValue
                            }
                        } label: {
                            HStack(spacing: CoveSpacing.s) {
                                Image(systemName: guide.systemImage)
                                    .font(.system(size: 13))
                                    .frame(width: 18)
                                Text(guide.title)
                                    .font(.callout)
                                Spacer()
                                if compositionGuide == guide {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(CoveColors.accent)
                                }
                            }
                            .padding(.horizontal, CoveSpacing.m)
                            .padding(.vertical, 8)
                            .foregroundColor(compositionGuide == guide ? CoveColors.textPrimary : CoveColors.textSecondary)
                            .background(
                                RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                    .fill(compositionGuide == guide ? CoveColors.surfaceElevated.opacity(0.75) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .fill(CoveColors.surfaceSecondary.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .stroke(CoveColors.borderSubtle, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: CoveSpacing.s) {
                Text("ASPECT RATIO")
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)

                HStack(spacing: 4) {
                    ForEach(PreviewAspectRatio.allCases) { ratio in
                        Button {
                            withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                                aspectRatioRaw = ratio.rawValue
                            }
                        } label: {
                            Text(ratio.title)
                                .font(.caption.monospacedDigit())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .foregroundColor(aspectRatio == ratio ? CoveColors.textPrimary : CoveColors.textSecondary)
                                .background(
                                    RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                        .fill(aspectRatio == ratio ? CoveColors.surfaceElevated.opacity(0.85) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .fill(CoveColors.surfaceSecondary.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .stroke(CoveColors.borderSubtle, lineWidth: 1)
                )
                if aspectRatio != .defaultRatio {
                    Toggle("Crop Photo to Ratio", isOn: $cropToAspectRatio)
                        .font(.caption)
                        .foregroundColor(CoveColors.textPrimary)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .padding(.top, 4)
                }
            }

            timerQuickSelector

            Spacer()

            captureButtonSection
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, CoveSpacing.l)
        .padding(.bottom, CoveSpacing.l)
    }

    // MARK: - Adjust Control Panel

    private var adjustControlPanel: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.m) {
            HStack {
                Text("ADJUSTMENTS")
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)
                Spacer()
                if !cameraManager.adjustments.isIdentity {
                    Button("Save Look…") {
                        newPresetName = ""
                        isShowingSavePresetAlert = true
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(CoveColors.accent)
                }
                Button("Reset All") {
                    withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                        cameraManager.resetAdjustments()
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(cameraManager.adjustments.isIdentity ? CoveColors.textTertiary : CoveColors.accent)
                .disabled(cameraManager.adjustments.isIdentity)
            }

            ScrollView {
                VStack(spacing: CoveSpacing.m) {
                    adjustmentSlider(
                        title: "Exposure",
                        value: $cameraManager.adjustments.exposure,
                        range: -2.0...2.0,
                        defaultValue: 0.0,
                        format: "%+.2f"
                    )
                    adjustmentSlider(
                        title: "Brightness",
                        value: $cameraManager.adjustments.brightness,
                        range: -0.4...0.4,
                        defaultValue: 0.0,
                        format: "%+.2f"
                    )
                    adjustmentSlider(
                        title: "Contrast",
                        value: $cameraManager.adjustments.contrast,
                        range: 0.5...1.5,
                        defaultValue: 1.0,
                        format: "%.2f"
                    )
                    adjustmentSlider(
                        title: "Saturation",
                        value: $cameraManager.adjustments.saturation,
                        range: 0.0...2.0,
                        defaultValue: 1.0,
                        format: "%.2f"
                    )
                    adjustmentSlider(
                        title: "Highlights",
                        value: $cameraManager.adjustments.highlights,
                        range: 0.0...1.0,
                        defaultValue: 1.0,
                        format: "%.2f"
                    )
                    adjustmentSlider(
                        title: "Shadows",
                        value: $cameraManager.adjustments.shadows,
                        range: -1.0...1.0,
                        defaultValue: 0.0,
                        format: "%+.2f"
                    )
                    adjustmentSlider(
                        title: "Sharpness",
                        value: $cameraManager.adjustments.sharpness,
                        range: 0.0...1.5,
                        defaultValue: 0.0,
                        format: "%.2f"
                    )
                    adjustmentSlider(
                        title: "Temperature",
                        value: $cameraManager.adjustments.temperature,
                        range: 3500...9500,
                        defaultValue: 6500,
                        format: "%.0fK"
                    )
                    adjustmentSlider(
                        title: "Tint",
                        value: $cameraManager.adjustments.tint,
                        range: -50...50,
                        defaultValue: 0.0,
                        format: "%+.0f"
                    )
                }
                .padding(CoveSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .fill(CoveColors.surfaceSecondary.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .stroke(CoveColors.borderSubtle, lineWidth: 1)
                )
            }

            captureButtonSection
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, CoveSpacing.l)
        .padding(.bottom, CoveSpacing.l)
    }

    private func adjustmentSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        defaultValue: Double,
        format: String
    ) -> some View {
        let isModified = abs(value.wrappedValue - defaultValue) >= 0.005

        return VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(CoveColors.textPrimary)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(CoveColors.textSecondary)
                if isModified {
                    Button {
                        value.wrappedValue = defaultValue
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10))
                            .foregroundColor(CoveColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reset \(title)")
                }
            }

            Slider(value: value, in: range)
                .controlSize(.small)
        }
    }

    // MARK: - Looks Control Panel

    private var looksControlPanel: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.m) {
            Text("LOOKS & PRESETS")
                .font(.caption)
                .foregroundColor(CoveColors.textSecondary)

            VStack(spacing: 6) {
                ForEach(LookPreset.allCases) { preset in
                    let isSelected = cameraManager.activeCustomPresetID == nil && cameraManager.activeLook == preset

                    Button {
                        withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                            cameraManager.selectLook(preset)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.title)
                                    .font(.callout.weight(.medium))
                                    .foregroundColor(CoveColors.textPrimary)
                                Text(preset.subtitle)
                                    .font(.caption2)
                                    .foregroundColor(CoveColors.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(CoveColors.accent)
                            }
                        }
                        .padding(.horizontal, CoveSpacing.m)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                .fill(isSelected ? CoveColors.surfaceElevated.opacity(0.8) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .fill(CoveColors.surfaceSecondary.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .stroke(CoveColors.borderSubtle, lineWidth: 1)
            )

            if !cameraManager.customPresets.isEmpty {
                Text("CUSTOM LOOKS")
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)

                VStack(spacing: 4) {
                    ForEach(cameraManager.customPresets) { preset in
                        let isSelected = cameraManager.activeCustomPresetID == preset.id
                        HStack(spacing: 4) {
                            Button {
                                withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                                    cameraManager.selectCustomPreset(preset)
                                }
                            } label: {
                                HStack {
                                    Text(preset.name)
                                        .font(.callout.weight(.medium))
                                        .foregroundColor(CoveColors.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(CoveColors.accent)
                                    }
                                }
                                .padding(.horizontal, CoveSpacing.m)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: CoveRadius.smallElement, style: .continuous)
                                        .fill(isSelected ? CoveColors.surfaceElevated.opacity(0.8) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                cameraManager.deleteCustomPreset(preset)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(CoveColors.textSecondary)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                            .help("Delete \(preset.name)")
                        }
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .fill(CoveColors.surfaceSecondary.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .stroke(CoveColors.borderSubtle, lineWidth: 1)
                )
            }

            Spacer()

            captureButtonSection
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, CoveSpacing.l)
        .padding(.bottom, CoveSpacing.l)
    }

    private var cameraSelectorGroup: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.s) {
            Text("CAMERA")
                .font(.caption)
                .foregroundColor(CoveColors.textSecondary)

            if cameraManager.availableCameras.isEmpty {
                HStack(spacing: CoveSpacing.s) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 13))
                        .foregroundColor(CoveColors.textSecondary)
                    Text("No camera detected")
                        .font(.callout)
                        .foregroundColor(CoveColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CoveSpacing.m)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                        .fill(CoveColors.surfaceSecondary.opacity(0.55))
                )
            } else {
                Menu {
                    ForEach(cameraManager.availableCameras) { camera in
                        Button {
                            cameraManager.selectCamera(camera)
                        } label: {
                            HStack {
                                Text(camera.name)
                                if cameraManager.selectedCamera?.id == camera.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "camera")
                            .font(.system(size: 13))
                            .foregroundColor(CoveColors.textSecondary)
                        Text(cameraManager.selectedCamera?.name ?? "Select Camera")
                            .font(.callout)
                            .foregroundColor(CoveColors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11))
                            .foregroundColor(CoveColors.textSecondary)
                    }
                    .padding(.horizontal, CoveSpacing.m)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                            .fill(CoveColors.surfaceSecondary.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                            .stroke(CoveColors.borderSubtle, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    private var microphoneSelectorGroup: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.s) {
            HStack {
                Text("MICROPHONE")
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)
                Spacer()
                Toggle("", isOn: $recordAudio)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .disabled(cameraManager.isRecording)
            }

            if recordAudio {
                if cameraManager.microphonePermissionStatus == .denied
                    || cameraManager.microphonePermissionStatus == .restricted {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "mic.slash")
                                .font(.system(size: 12))
                                .foregroundColor(CoveColors.warning)
                            Text("Microphone access denied")
                                .font(.caption)
                                .foregroundColor(CoveColors.textSecondary)
                        }
                        Button("Open Privacy Settings") {
                            cameraManager.openMicrophonePrivacySettings()
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CoveSpacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                            .fill(CoveColors.surfaceSecondary.opacity(0.55))
                    )
                } else if cameraManager.availableMicrophones.isEmpty {
                    HStack(spacing: CoveSpacing.s) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 13))
                            .foregroundColor(CoveColors.textSecondary)
                        Text("No microphone detected")
                            .font(.callout)
                            .foregroundColor(CoveColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, CoveSpacing.m)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                            .fill(CoveColors.surfaceSecondary.opacity(0.55))
                    )
                } else {
                    Menu {
                        ForEach(cameraManager.availableMicrophones) { mic in
                            Button {
                                cameraManager.selectMicrophone(mic)
                            } label: {
                                HStack {
                                    Text(mic.isBuiltIn ? "\(mic.name) (Internal)" : "\(mic.name) (External)")
                                    if cameraManager.selectedMicrophone?.id == mic.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "mic")
                                .font(.system(size: 13))
                                .foregroundColor(CoveColors.textSecondary)
                            Text(cameraManager.selectedMicrophone?.name ?? "Select Microphone")
                                .font(.callout)
                                .foregroundColor(CoveColors.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11))
                                .foregroundColor(CoveColors.textSecondary)
                        }
                        .padding(.horizontal, CoveSpacing.m)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                                .fill(CoveColors.surfaceSecondary.opacity(0.55))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                                .stroke(CoveColors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(cameraManager.isRecording)
                }
            }
        }
    }

    private var captureButtonSection: some View {
        VStack(spacing: CoveSpacing.s) {
            Button {
                if captureMode == .photo {
                    cameraManager.triggerPhotoCapture(
                        countdown: countdownDuration,
                        format: photoFormat,
                        burstMode: burstMode,
                        cropAspectRatio: activeCropRatio
                    )
                } else {
                    cameraManager.toggleVideoRecording(includeAudio: recordAudio)
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            (cameraManager.isRecording || cameraManager.countdownRemaining != nil)
                                ? CoveColors.recording.opacity(0.65)
                                : CoveColors.textSecondary.opacity(0.45),
                            lineWidth: 3
                        )
                        .frame(width: 72, height: 72)

                    if cameraManager.isRecording {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(CoveColors.recording)
                            .frame(width: 26, height: 26)
                    } else if cameraManager.countdownRemaining != nil {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(CoveColors.recording)
                    } else {
                        Circle()
                            .fill(captureMode == .video ? CoveColors.recording : CoveColors.textPrimary)
                            .frame(width: 58, height: 58)
                    }
                }
                .animation(.easeInOut(duration: CoveMotion.smallInteraction), value: cameraManager.isRecording)
            }
            .buttonStyle(.plain)
            .disabled(cameraManager.sessionState != .running)
            .opacity(cameraManager.sessionState == .running ? 1.0 : 0.45)
            .accessibilityLabel(
                cameraManager.countdownRemaining != nil
                    ? "Cancel Countdown"
                    : (cameraManager.isRecording
                        ? "Stop Video Recording"
                        : (captureMode == .photo ? "Capture Photo" : "Start Video Recording"))
            )
            .help(
                cameraManager.countdownRemaining != nil
                    ? "Cancel Countdown"
                    : (cameraManager.isRecording
                        ? "Stop Recording"
                        : (captureMode == .photo ? "Capture Photo" : "Start Recording"))
            )

            Text(captureStatusLabel)
                .font(.caption.monospacedDigit())
                .foregroundColor(
                    (cameraManager.isRecording || cameraManager.countdownRemaining != nil)
                        ? CoveColors.recording
                        : CoveColors.textSecondary
                )
        }
    }

    private var captureStatusLabel: String {
        if let remaining = cameraManager.countdownRemaining {
            return "Capturing in \(remaining)s"
        }
        if cameraManager.isRecording {
            return formattedDuration(cameraManager.recordingDuration)
        }
        return captureMode == .photo ? "Photo" : "Video"
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var largeRecentMediaCard: some View {
        Button {
            withAnimation(.easeInOut(duration: CoveMotion.panelTransition)) {
                isShowingGallery = true
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: CoveRadius.controlGroup, style: .continuous)
                    .fill(CoveColors.surfaceSecondary.opacity(0.5))

                if let thumbnail = cameraManager.latestThumbnail {
                    GeometryReader { geo in
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CoveRadius.controlGroup, style: .continuous))

                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.clear],
                        startPoint: .bottom,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CoveRadius.controlGroup, style: .continuous))

                    HStack {
                        Text(cameraManager.latestMediaIsVideo ? "Video" : "Photo")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: cameraManager.latestMediaIsVideo ? "play.circle.fill" : "arrow.up.forward.app")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, CoveSpacing.m)
                    .padding(.vertical, CoveSpacing.s)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22))
                            .foregroundColor(CoveColors.textSecondary)
                        Text("Recent Media")
                            .font(.caption)
                            .foregroundColor(CoveColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .clipShape(RoundedRectangle(cornerRadius: CoveRadius.controlGroup, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.controlGroup, style: .continuous)
                    .stroke(CoveColors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Open Media Gallery")
    }

    private func resetAllSettings() {
        appearanceMode = .system
        photoFormatRaw = CaptureConfiguration.PhotoFormat.jpeg.rawValue
        videoResolutionRaw = CaptureConfiguration.VideoResolution.hd1080p.rawValue
        recordAudio = true
        shutterSoundEnabled = true
        mirrorPreview = false
        compositionGuideRaw = CompositionGuide.none.rawValue
        aspectRatioRaw = PreviewAspectRatio.defaultRatio.rawValue
        cropToAspectRatio = false
        countdownRaw = CountdownDuration.off.rawValue
        burstModeRaw = BurstMode.off.rawValue
        cameraManager.resetSaveDirectoryToDefault()
        cameraManager.updateVideoResolution(.hd1080p)
    }

    // MARK: - Placeholder for Post-Phase 1 Sections

    private func sectionPlaceholderView(for section: AppSection) -> some View {
        VStack(spacing: CoveSpacing.m) {
            Image(systemName: section.systemImage)
                .font(.system(size: 32))
                .foregroundColor(CoveColors.textSecondary)
            Text(section.title)
                .font(.title2)
                .foregroundColor(CoveColors.textPrimary)
            Text("Planned for a later development phase.")
                .font(.callout)
                .foregroundColor(CoveColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous)
                .fill(CoveColors.surfaceSecondary.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous)
                .stroke(CoveColors.borderSubtle, lineWidth: 1)
        )
    }
}

/// Native AppKit view enabling titlebar double-click zoom and window dragging on the top bar and traffic-light strip.
struct TitlebarInteractionView: NSViewRepresentable {
    func makeNSView(context: Context) -> TitlebarNSView {
        TitlebarNSView()
    }

    func updateNSView(_ nsView: TitlebarNSView, context: Context) {}

    final class TitlebarNSView: NSView {
        private var eventMonitor: Any?

        override var mouseDownCanMoveWindow: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if eventMonitor == nil, window != nil {
                eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                    guard let self = self,
                          let targetWindow = self.window,
                          event.window === targetWindow,
                          event.clickCount == 2 else {
                        return event
                    }

                    let yFromTop = targetWindow.frame.height - event.locationInWindow.y
                    let x = event.locationInWindow.x
                    // Catch double-clicks on the native traffic-light titlebar strip (excluding traffic lights themselves).
                    if yFromTop >= 0 && yFromTop <= 32 && x > 78 {
                        targetWindow.performZoom(nil)
                        return nil
                    }
                    return event
                }
            }
        }

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                window?.performZoom(nil)
            } else {
                super.mouseDown(with: event)
            }
        }

        deinit {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

/// Captures Space/Return for shutter trigger and Escape for countdown cancel while in camera workspace.
private struct CameraKeyMonitorView: NSViewRepresentable {
    let isEnabled: Bool
    let onCaptureTrigger: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> KeyNSView {
        let view = KeyNSView()
        view.isEnabled = isEnabled
        view.onCaptureTrigger = onCaptureTrigger
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyNSView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onCaptureTrigger = onCaptureTrigger
        nsView.onEscape = onEscape
    }

    final class KeyNSView: NSView {
        var isEnabled = true
        var onCaptureTrigger: (() -> Void)?
        var onEscape: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if monitor == nil, window != nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self = self,
                          self.isEnabled,
                          event.window === self.window,
                          !(self.window?.firstResponder is NSTextView),
                          event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
                        return event
                    }

                    switch event.keyCode {
                    case 49, 36, 76: // Space, Return, Enter
                        self.onCaptureTrigger?()
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

/// Compact numeric pixel input for teleprompter width/height that commits on Return or focus loss.
private struct TeleprompterDimensionField: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    @State private var draftText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(CoveColors.textSecondary)

            TextField("", text: $draftText)
                .textFieldStyle(.plain)
                .font(.caption2.monospacedDigit())
                .foregroundColor(CoveColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .onSubmit {
                    commitDraft()
                }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(CoveColors.surfaceElevated.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isFocused ? CoveColors.accent.opacity(0.7) : CoveColors.borderSubtle, lineWidth: 1)
        )
        .onAppear {
            draftText = "\(Int(value.rounded()))"
        }
        .onChange(of: value) { newValue in
            if !isFocused {
                draftText = "\(Int(newValue.rounded()))"
            }
        }
        .onChange(of: isFocused) { focused in
            if !focused {
                commitDraft()
            }
        }
    }

    private func commitDraft() {
        let filtered = draftText.filter { $0.isNumber }
        if let parsed = Double(filtered) {
            let clamped = min(max(parsed, range.lowerBound), range.upperBound)
            value = clamped
            draftText = "\(Int(clamped.rounded()))"
        } else {
            draftText = "\(Int(value.rounded()))"
        }
    }
}
