import AppKit
import SwiftUI

/// Full-window two-column onboarding experience matching macOS Setup Assistant & Quiet Premium style.
struct OnboardingView: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var appearanceMode: CoveAppearanceMode
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var savePathDisplay = ""
    @State private var hasCustomFolder = false

    private let steps: [(title: String, subtitle: String, icon: String)] = [
        ("Welcome", "Meet Cove", "sparkles"),
        ("Permissions", "Camera & Mic", "camera.fill"),
        ("Setup", "Theme & Storage", "slider.horizontal.3"),
        ("Ready", "Quick Highlights", "checkmark.circle.fill")
    ]

    var body: some View {
        ZStack {
            CoveVisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                leftSidebar
                    .frame(width: 270)
                    .background(CoveColors.surfaceSecondary.opacity(0.32))

                Divider()
                    .opacity(0.4)

                VStack(spacing: 0) {
                    stepContent
                        .frame(maxWidth: 560, maxHeight: .infinity)
                        .padding(.horizontal, CoveSpacing.xxxl)
                        .padding(.top, CoveSpacing.xxxl)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()
                        .opacity(0.4)

                    bottomBar
                        .padding(.horizontal, CoveSpacing.xxl)
                        .padding(.vertical, CoveSpacing.l)
                }
            }
            .overlay(alignment: .top) {
                TitlebarInteractionView()
                    .frame(height: 36)
            }
        }
        .onAppear {
            savePathDisplay = cameraManager.currentSaveDirectoryPath
            hasCustomFolder = cameraManager.hasCustomSaveDirectory
        }
    }

    // MARK: - Left Sidebar

    private var leftSidebar: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.xl) {
            HStack(spacing: CoveSpacing.m) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cove")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(CoveColors.textPrimary)
                    Text("Setup Guide")
                        .font(.caption)
                        .foregroundColor(CoveColors.textSecondary)
                }
            }
            .padding(.top, CoveSpacing.xxxl)

            VStack(alignment: .leading, spacing: CoveSpacing.s) {
                ForEach(0..<steps.count, id: \.self) { index in
                    sidebarStepRow(index: index)
                }
            }

            Spacer()

            Text("100% local & private on your Mac.")
                .font(.caption2)
                .foregroundColor(CoveColors.textTertiary)
        }
        .padding(CoveSpacing.xl)
    }

    private func sidebarStepRow(index: Int) -> some View {
        let step = steps[index]
        let isActive = index == currentStep
        let isCompleted = index < currentStep

        return Button {
            withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                currentStep = index
            }
        } label: {
            HStack(spacing: CoveSpacing.m) {
                ZStack {
                    Circle()
                        .fill(
                            isActive
                                ? CoveColors.accent
                                : (isCompleted ? CoveColors.success.opacity(0.2) : CoveColors.surfaceElevated.opacity(0.55))
                        )
                        .frame(width: 28, height: 28)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(CoveColors.success)
                    } else {
                        Image(systemName: step.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isActive ? .white : CoveColors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(step.title)
                        .font(.callout.weight(isActive ? .semibold : .medium))
                        .foregroundColor(isActive ? CoveColors.textPrimary : CoveColors.textSecondary)
                    Text(step.subtitle)
                        .font(.caption2)
                        .foregroundColor(CoveColors.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, CoveSpacing.s)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                    .fill(isActive ? CoveColors.surfaceElevated.opacity(0.7) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            welcomeStep
        case 1:
            permissionsStep
        case 2:
            setupStep
        default:
            highlightsStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.xl) {
            Spacer()

            VStack(alignment: .leading, spacing: CoveSpacing.s) {
                Text("Welcome to Cove")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(CoveColors.textPrimary)

                Text("A quiet, native macOS camera for crisp photos and focused video recording — built to stay lightweight and completely private.")
                    .font(.body)
                    .foregroundColor(CoveColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: CoveSpacing.m) {
                highlightRow(
                    icon: "lock.shield",
                    title: "100% Local Storage",
                    detail: "No cloud uploads or accounts. Every photo and video stays directly in your Mac folders."
                )
                highlightRow(
                    icon: "bolt",
                    title: "Metal Accelerated",
                    detail: "Real-time looks, color adjustments, and virtual backgrounds powered by native macOS graphics."
                )
                highlightRow(
                    icon: "sparkles",
                    title: "Quiet Premium Design",
                    detail: "Focused controls that stay out of your way while framing and recording."
                )
            }

            Spacer()
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.xl) {
            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text("Camera & Microphone Access")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(CoveColors.textPrimary)
                Text("Cove needs camera and microphone permissions to preview, capture photos, and record videos with sound.")
                    .font(.callout)
                    .foregroundColor(CoveColors.textSecondary)
            }

            VStack(spacing: CoveSpacing.m) {
                permissionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    subtitle: "Required for live Metal preview, photos, and videos.",
                    status: cameraManager.permissionStatus
                )
                Divider().opacity(0.4)
                permissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    subtitle: "Optional — used when recording video with internal or external mics.",
                    status: cameraManager.microphonePermissionStatus
                )
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

            if cameraManager.permissionStatus == .denied || cameraManager.microphonePermissionStatus == .denied {
                Button("Open System Privacy Settings") {
                    cameraManager.openSystemPrivacySettings()
                }
                .buttonStyle(.bordered)
            } else if cameraManager.permissionStatus != .authorized || cameraManager.microphonePermissionStatus != .authorized {
                Button("Grant Camera & Mic Access") {
                    cameraManager.requestOnboardingPermissions {}
                }
                .buttonStyle(.borderedProminent)
            } else {
                Label("All permissions granted", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundColor(CoveColors.success)
            }

            Spacer()
        }
    }

    private var setupStep: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.xl) {
            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text("Appearance & Storage")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(CoveColors.textPrimary)
                Text("Pick your preferred look and where Cove saves your captured photos and videos.")
                    .font(.callout)
                    .foregroundColor(CoveColors.textSecondary)
            }

            VStack(spacing: CoveSpacing.l) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .font(.callout.weight(.medium))
                            .foregroundColor(CoveColors.textPrimary)
                        Text("Follow macOS or choose Light / Dark.")
                            .font(.caption)
                            .foregroundColor(CoveColors.textSecondary)
                    }
                    Spacer()
                    Picker("Theme", selection: $appearanceMode) {
                        ForEach(CoveAppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                }

                Divider().opacity(0.4)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save Folder")
                            .font(.callout.weight(.medium))
                            .foregroundColor(CoveColors.textPrimary)
                        Text(savePathDisplay)
                            .font(.caption)
                            .foregroundColor(CoveColors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    HStack(spacing: CoveSpacing.s) {
                        Button("Choose…") {
                            if cameraManager.chooseCustomSaveDirectory() != nil {
                                savePathDisplay = cameraManager.currentSaveDirectoryPath
                                hasCustomFolder = cameraManager.hasCustomSaveDirectory
                            }
                        }
                        .buttonStyle(.bordered)

                        if hasCustomFolder {
                            Button("Default") {
                                cameraManager.resetSaveDirectoryToDefault()
                                savePathDisplay = cameraManager.currentSaveDirectoryPath
                                hasCustomFolder = cameraManager.hasCustomSaveDirectory
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
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

            Spacer()
        }
    }

    private var highlightsStep: some View {
        VStack(alignment: .leading, spacing: CoveSpacing.xl) {
            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text("Ready to Capture")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(CoveColors.textPrimary)
                Text("Everything you need is right in the main window.")
                    .font(.callout)
                    .foregroundColor(CoveColors.textSecondary)
            }

            VStack(spacing: CoveSpacing.m) {
                highlightRow(
                    icon: "keyboard",
                    title: "Quick Capture Shortcut",
                    detail: "Press Space or Return anytime to snap a photo or start/stop video recording."
                )
                highlightRow(
                    icon: "text.bubble",
                    title: "Video Teleprompter & Auto-Stop",
                    detail: "Drag, resize, adjust font size, and auto-stop recording after your script finishes."
                )
                highlightRow(
                    icon: "person.crop.rectangle",
                    title: "Virtual Video Background",
                    detail: "Switch between Blur, Green Screen, or a custom background image in Video mode."
                )
                highlightRow(
                    icon: "camera.filters",
                    title: "Looks, Adjustments & Gallery",
                    detail: "Fine-tune exposure and color live, or edit captured photos and videos non-destructively."
                )
            }

            Spacer()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Button("Skip") {
                    onComplete()
                }
                .buttonStyle(.plain)
                .foregroundColor(CoveColors.textSecondary)
            }

            Spacer()

            if currentStep < steps.count - 1 {
                Button("Continue") {
                    withAnimation(.easeInOut(duration: CoveMotion.smallInteraction)) {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Helpers

    private func permissionRow(icon: String, title: String, subtitle: String, status: CameraPermissionStatus) -> some View {
        HStack(spacing: CoveSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(CoveColors.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundColor(CoveColors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)
            }

            Spacer()

            statusBadge(for: status)
        }
    }

    private func statusBadge(for status: CameraPermissionStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .authorized: return ("Allowed", CoveColors.success)
            case .notDetermined: return ("Pending", CoveColors.textSecondary)
            case .denied, .restricted: return ("Denied", CoveColors.warning)
            }
        }()

        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color.opacity(0.15))
            )
    }

    private func highlightRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: CoveSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(CoveColors.accent)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(CoveColors.accent.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundColor(CoveColors.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(CoveColors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, CoveSpacing.m)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: CoveRadius.button, style: .continuous)
                .fill(CoveColors.surfaceSecondary.opacity(0.45))
        )
    }
}
