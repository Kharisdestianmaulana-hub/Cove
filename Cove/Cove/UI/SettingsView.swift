import SwiftUI

/// Native Quiet Premium settings panel for Appearance, Capture, Composition defaults, Storage, and Reset.
struct SettingsView: View {
    let cameraManager: CameraManager
    @Binding var appearanceMode: CoveAppearanceMode
    @Binding var photoFormat: CaptureConfiguration.PhotoFormat
    @Binding var videoResolution: CaptureConfiguration.VideoResolution
    @Binding var recordAudio: Bool
    @Binding var shutterSoundEnabled: Bool
    @Binding var mirrorPreview: Bool
    @Binding var compositionGuide: CompositionGuide
    @Binding var aspectRatio: PreviewAspectRatio
    @Binding var cropToAspectRatio: Bool
    @Binding var countdownDuration: CountdownDuration
    let onResetDefaults: () -> Void
    let onShowOnboarding: () -> Void

    @State private var savePathDisplay: String = ""
    @State private var hasCustomFolder: Bool = false
    @State private var isConfirmingReset: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CoveSpacing.xl) {
                headerSection

                settingsCard(title: "Appearance") {
                    settingsRow(label: "Theme", description: "Choose Light, Dark, or follow macOS.") {
                        Picker("Theme", selection: $appearanceMode) {
                            ForEach(CoveAppearanceMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 240)
                    }
                }

                settingsCard(title: "Capture") {
                    settingsRow(label: "Photo Format", description: "Default format for captured still photos.") {
                        Picker("Photo Format", selection: $photoFormat) {
                            ForEach(CaptureConfiguration.PhotoFormat.allCases, id: \.rawValue) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    Divider().opacity(0.4)

                    settingsRow(
                        label: "Video Resolution",
                        description: "Falls back automatically if hardware does not support the selected resolution."
                    ) {
                        Picker("Video Resolution", selection: $videoResolution) {
                            ForEach(CaptureConfiguration.VideoResolution.allCases, id: \.rawValue) { res in
                                Text(res.displayName).tag(res)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 200)
                    }

                    Divider().opacity(0.4)

                    settingsRow(label: "Record Audio", description: "Include microphone audio when recording video.") {
                        Toggle("", isOn: $recordAudio)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider().opacity(0.4)

                    settingsRow(label: "Shutter Sound", description: "Play a subtle camera shutter sound when capturing photos.") {
                        Toggle("", isOn: $shutterSoundEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider().opacity(0.4)

                    settingsRow(label: "Mirror Camera", description: "Flip preview, photos, and videos horizontally.") {
                        Toggle("", isOn: $mirrorPreview)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                settingsCard(title: "Interface Defaults") {
                    settingsRow(label: "Composition Guide", description: "Overlay displayed on the live camera preview.") {
                        Picker("Composition Guide", selection: $compositionGuide) {
                            ForEach(CompositionGuide.allCases) { guide in
                                Text(guide.title).tag(guide)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }

                    Divider().opacity(0.4)

                    settingsRow(label: "Aspect Ratio", description: "Preview framing guide.") {
                        Picker("Aspect Ratio", selection: $aspectRatio) {
                            ForEach(PreviewAspectRatio.allCases) { ratio in
                                Text(ratio.title).tag(ratio)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    Divider().opacity(0.4)

                    settingsRow(label: "Crop Photos to Ratio", description: "Automatically crop captured photos to the active aspect ratio.") {
                        Toggle("", isOn: $cropToAspectRatio)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Divider().opacity(0.4)

                    settingsRow(label: "Countdown Timer", description: "Default timer before photo capture.") {
                        Picker("Countdown Timer", selection: $countdownDuration) {
                            ForEach(CountdownDuration.allCases) { duration in
                                Text(duration.title).tag(duration)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 200)
                    }
                }

                settingsCard(title: "Storage") {
                    settingsRow(label: "Save Location", description: savePathDisplay) {
                        HStack(spacing: CoveSpacing.s) {
                            Button("Choose Folder…") {
                                if cameraManager.chooseCustomSaveDirectory() != nil {
                                    refreshStorageDisplay()
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Open") {
                                cameraManager.openSaveDirectoryInFinder()
                            }
                            .buttonStyle(.bordered)

                            if hasCustomFolder {
                                Button("Default") {
                                    cameraManager.resetSaveDirectoryToDefault()
                                    refreshStorageDisplay()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                settingsCard(title: "Reset") {
                    settingsRow(
                        label: "Welcome Guide",
                        description: "View the first-launch onboarding walkthrough again."
                    ) {
                        Button("Open Guide") {
                            onShowOnboarding()
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider().opacity(0.4)

                    settingsRow(
                        label: "Restore Defaults",
                        description: "Reset appearance, capture format, composition, and storage location."
                    ) {
                        Button("Reset Settings", role: .destructive) {
                            isConfirmingReset = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(CoveSpacing.xl)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous)
                .fill(CoveColors.surfaceSecondary.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CoveRadius.windowContent, style: .continuous)
                .stroke(CoveColors.borderSubtle, lineWidth: 1)
        )
        .onAppear {
            refreshStorageDisplay()
        }
        .alert("Reset All Settings?", isPresented: $isConfirmingReset) {
            Button("Reset", role: .destructive) {
                onResetDefaults()
                refreshStorageDisplay()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All Cove preferences and custom save folder selection will be restored to default values.")
        }
    }

    // MARK: - Helpers

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.title2.weight(.semibold))
                .foregroundColor(CoveColors.textPrimary)
            Text("Configure Cove appearance, capture format, composition defaults, and local storage.")
                .font(.callout)
                .foregroundColor(CoveColors.textSecondary)
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CoveSpacing.m) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(CoveColors.textSecondary)

            VStack(spacing: CoveSpacing.m) {
                content()
            }
            .padding(CoveSpacing.l)
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                    .fill(CoveColors.surfaceSecondary.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CoveRadius.floatingPanel, style: .continuous)
                    .stroke(CoveColors.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func settingsRow<Control: View>(
        label: String,
        description: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: CoveSpacing.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.callout.weight(.medium))
                    .foregroundColor(CoveColors.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            control()
        }
    }

    private func refreshStorageDisplay() {
        savePathDisplay = cameraManager.currentSaveDirectoryPath
        hasCustomFolder = cameraManager.hasCustomSaveDirectory
    }
}
