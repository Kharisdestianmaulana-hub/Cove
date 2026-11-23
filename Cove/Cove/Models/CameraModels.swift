import Foundation

/// Top-level navigation sections in Cove's main window.
enum AppSection: String, CaseIterable, Identifiable {
    case camera
    case adjust
    case looks
    case composition
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: return "Camera"
        case .adjust: return "Adjust"
        case .looks: return "Looks"
        case .composition: return "Composition"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: return "camera"
        case .adjust: return "slider.horizontal.3"
        case .looks: return "camera.filters"
        case .composition: return "square.grid.3x3"
        case .settings: return "gearshape"
        }
    }
}

/// Capture mode supported by the main camera interface.
enum CaptureMode: String, CaseIterable, Identifiable, Codable {
    case photo
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        }
    }

    var systemImage: String {
        switch self {
        case .photo: return "camera.fill"
        case .video: return "video.fill"
        }
    }
}

/// Represents a discovered camera hardware device.
struct CameraDevice: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let isBuiltIn: Bool
    let isConnected: Bool
}

/// Represents a discovered microphone hardware device (built-in or external).
struct AudioDevice: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let isBuiltIn: Bool
    let isConnected: Bool
}

/// Represents the current authorization state for camera access.
enum CameraPermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Represents the lifecycle state of the camera preview session.
enum CameraSessionState: Equatable {
    case idle
    case initializing
    case running
    case unavailable
    case permissionDenied
    case error(String)
}

/// Modular capture configuration kept Codable-ready for future presets/profiles.
struct CaptureConfiguration: Codable, Equatable {
    var captureMode: CaptureMode = .photo
    var photoFormat: PhotoFormat = .jpeg
    var videoResolution: VideoResolution = .hd1080p
    var videoFrameRate: Int = 30

    enum PhotoFormat: String, CaseIterable, Codable {
        case jpeg
        case heif

        var displayName: String {
            switch self {
            case .jpeg: return "JPEG"
            case .heif: return "HEIF"
            }
        }
    }

    enum VideoResolution: String, CaseIterable, Codable {
        case hd720p
        case hd1080p
        case uhd4k

        var displayName: String {
            switch self {
            case .hd720p: return "720p"
            case .hd1080p: return "1080p"
            case .uhd4k: return "4K"
            }
        }
    }
}

/// Virtual background mode supported during Video capture.
enum VideoBackgroundMode: String, CaseIterable, Identifiable, Codable {
    case off
    case blur
    case greenScreen
    case customImage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .blur: return "Blur"
        case .greenScreen: return "Green"
        case .customImage: return "Image"
        }
    }
}

/// Composition overlay guides displayed over the live preview.
enum CompositionGuide: String, CaseIterable, Identifiable, Codable {
    case none
    case ruleOfThirds
    case centerCrosshair
    case squareGrid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Off"
        case .ruleOfThirds: return "Rule of Thirds"
        case .centerCrosshair: return "Center"
        case .squareGrid: return "Square Grid"
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "rectangle"
        case .ruleOfThirds: return "square.grid.3x3"
        case .centerCrosshair: return "plus"
        case .squareGrid: return "grid"
        }
    }
}

/// Preview framing aspect ratio options.
enum PreviewAspectRatio: String, CaseIterable, Identifiable, Codable {
    case defaultRatio
    case ratio1x1
    case ratio4x3
    case ratio16x9

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultRatio: return "Default"
        case .ratio1x1: return "1:1"
        case .ratio4x3: return "4:3"
        case .ratio16x9: return "16:9"
        }
    }

    var numericRatio: CGFloat? {
        switch self {
        case .defaultRatio: return nil
        case .ratio1x1: return 1.0
        case .ratio4x3: return 4.0 / 3.0
        case .ratio16x9: return 16.0 / 9.0
        }
    }
}

/// Countdown timer durations supported before photo capture.
enum CountdownDuration: Int, CaseIterable, Identifiable, Codable {
    case off = 0
    case three = 3
    case five = 5
    case ten = 10

    var id: Int { rawValue }

    var seconds: Int { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .three: return "3s"
        case .five: return "5s"
        case .ten: return "10s"
        }
    }
}

/// Image adjustment values applied to the live preview and captured photos.
struct AdjustmentState: Codable, Equatable {
    var brightness: Double = 0.0      // -0.4 ... 0.4
    var contrast: Double = 1.0        // 0.5 ... 1.5
    var saturation: Double = 1.0      // 0.0 ... 2.0
    var exposure: Double = 0.0        // -2.0 ... 2.0
    var highlights: Double = 1.0      // 0.0 ... 1.0
    var shadows: Double = 0.0         // -1.0 ... 1.0
    var sharpness: Double = 0.0       // 0.0 ... 1.5
    var temperature: Double = 6500.0  // 3500 ... 9500
    var tint: Double = 0.0            // -50 ... 50

    var isIdentity: Bool {
        abs(brightness) < 0.001
            && abs(contrast - 1.0) < 0.001
            && abs(saturation - 1.0) < 0.001
            && abs(exposure) < 0.001
            && abs(highlights - 1.0) < 0.001
            && abs(shadows) < 0.001
            && abs(sharpness) < 0.001
            && abs(temperature - 6500.0) < 1.0
            && abs(tint) < 0.01
    }
}

/// Visual presets ("Looks") that configure practical adjustment combinations.
enum LookPreset: String, CaseIterable, Identifiable, Codable {
    case natural
    case warm
    case cool
    case cinema
    case mono
    case soft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natural: return "Natural"
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .cinema: return "Cinema"
        case .mono: return "Mono"
        case .soft: return "Soft"
        }
    }

    var subtitle: String {
        switch self {
        case .natural: return "Balanced, true-to-life"
        case .warm: return "Golden highlights, cozy tone"
        case .cool: return "Crisp, clean cool cast"
        case .cinema: return "Subtle contrast & rich depth"
        case .mono: return "Classic monochrome"
        case .soft: return "Gentle contrast & lifted shadows"
        }
    }

    var adjustments: AdjustmentState {
        switch self {
        case .natural:
            return AdjustmentState()
        case .warm:
            return AdjustmentState(
                contrast: 1.05,
                saturation: 1.12,
                temperature: 8000,
                tint: 4
            )
        case .cool:
            return AdjustmentState(
                contrast: 1.06,
                saturation: 0.96,
                temperature: 4700,
                tint: -6
            )
        case .cinema:
            return AdjustmentState(
                brightness: -0.02,
                contrast: 1.16,
                saturation: 0.86,
                highlights: 0.82,
                shadows: -0.10,
                sharpness: 0.25,
                temperature: 5800
            )
        case .mono:
            return AdjustmentState(
                contrast: 1.15,
                saturation: 0.0,
                highlights: 0.88,
                sharpness: 0.2
            )
        case .soft:
            return AdjustmentState(
                brightness: 0.04,
                contrast: 0.88,
                saturation: 0.92,
                highlights: 0.90,
                shadows: 0.25,
                temperature: 6900
            )
        }
    }
}

/// User-saved custom adjustment preset stored locally.
struct CustomPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var adjustments: AdjustmentState

    init(id: UUID = UUID(), name: String, adjustments: AdjustmentState) {
        self.id = id
        self.name = name
        self.adjustments = adjustments
    }
}

/// Burst capture frame count options for Photo mode.
enum BurstMode: Int, CaseIterable, Identifiable, Codable {
    case off = 0
    case three = 3
    case five = 5

    var id: Int { rawValue }

    var count: Int { max(1, rawValue) }

    var title: String {
        switch self {
        case .off: return "Off"
        case .three: return "3×"
        case .five: return "5×"
        }
    }
}

/// Text size options for the video teleprompter overlay.
enum TeleprompterTextSize: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small: return 15
        case .medium: return 19
        case .large: return 24
        }
    }
}

/// Auto-stop video recording delay after the teleprompter finishes the last word.
enum TeleprompterAutoStopOption: Int, CaseIterable, Identifiable, Codable {
    case off = -1
    case instant = 0
    case oneSecond = 1
    case twoSeconds = 2
    case threeSeconds = 3
    case fiveSeconds = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .instant: return "0s"
        case .oneSecond: return "1s"
        case .twoSeconds: return "2s"
        case .threeSeconds: return "3s"
        case .fiveSeconds: return "5s"
        }
    }

    var delaySeconds: Int? {
        rawValue >= 0 ? rawValue : nil
    }
}

/// Presets for configuring teleprompter pacing and readability in Video mode.
enum TeleprompterPreset: String, CaseIterable, Identifiable, Codable {
    case calm
    case natural
    case fast
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: return "Calm"
        case .natural: return "Natural"
        case .fast: return "Fast"
        case .large: return "Large"
        }
    }

    var wpm: Double {
        switch self {
        case .calm: return 110
        case .natural: return 140
        case .fast: return 175
        case .large: return 125
        }
    }

    var textSize: TeleprompterTextSize {
        switch self {
        case .calm, .natural, .fast: return .medium
        case .large: return .large
        }
    }
}

/// Represents a locally captured photo or video item in Cove's media library.
struct MediaItem: Identifiable, Equatable, Hashable {
    let id: URL
    let url: URL
    let isVideo: Bool
    let createdAt: Date
    let fileSizeBytes: Int64

    var fileName: String {
        url.lastPathComponent
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var formattedDate: String {
        Self.dateFormatter.string(from: createdAt)
    }
}
