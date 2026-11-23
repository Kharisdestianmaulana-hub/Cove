<p align="center">
  <img src="Logo%20Cove.png" width="96" alt="Cove Logo" />
</p>

<h1 align="center">Cove</h1>

<p align="center">
  A quiet, native macOS camera application for crisp photography and focused video recording — built with SwiftUI, AVFoundation, Core Image, Metal, and Vision.
</p>

---

## Overview

**Cove** is designed around a distraction-free, *Quiet Premium* macOS interface. All processing runs locally on your Mac with hardware-accelerated Metal rendering, zero telemetry, and local-only storage.

- **Platform:** macOS 12.7+ (Universal Binary: Apple Silicon `arm64` and Intel `x86_64`)
- **Tech Stack:** Swift 5, SwiftUI, AppKit, AVFoundation, Core Image, MetalKit, Vision, AVKit

---

## Key Features

### Live Camera & Metal Preview
- Real-time 30fps `MTKView` Metal rendering pipeline with low-overhead Core Image filtering.
- Multi-camera discovery and hot-plug switching for built-in and external cameras.
- Horizontal mirror toggle for preview, captured photos, and recorded videos.
- Composition guides (`Rule of Thirds`, `Center`, `Square Grid`) and aspect ratio framing (`Default`, `1:1`, `4:3`, `16:9`) with optional photo cropping.
- Automatic camera session shutdown when switching to Gallery or Settings so the camera hardware and indicator LED turn off when not in use.

### Photo & Video Capture
- **Photo Mode:** JPEG or HEIF output, countdown timer (`Off`, `3s`, `5s`, `10s`), and burst capture (`Off`, `3x`, `5x`).
- **Video Mode:** `720p`, `1080p`, or `4K` capture (with automatic hardware fallback) and AAC audio recording matched to the active microphone format.
- **Microphone Selection:** Automatic detection and hot-plug switching between internal and external microphones.

### Looks & Color Adjustments
- Built-in visual presets: `Natural`, `Warm`, `Cool`, `Cinema`, `Mono`, and `Soft`.
- Live sliders for Exposure, Brightness, Contrast, Saturation, Highlights, Shadows, Sharpness, Temperature, and Tint.
- Save and manage custom adjustment presets locally.

### Video Teleprompter
- Draggable and corner-resizable overlay (`280-780 px` width, `110-420 px` height) with synchronized numeric pixel inputs in the sidebar.
- Word-by-word highlighting with auto-scrolling chunks.
- Quick `A-` / `A+` font size controls (`12-42 px`), WPM speed presets (`Calm`, `Natural`, `Fast`, `Large`), and a one-click `Center Under Camera` alignment reset.
- Configurable **Auto-Stop** delay (`Off`, `0s`, `1s`, `2s`, `3s`, `5s`) to stop video recording automatically after the script finishes.

### Virtual Video Background
- Real-time person segmentation powered by Apple `Vision` (`VNGeneratePersonSegmentationRequest`) running asynchronously to preserve 30fps preview smoothness.
- Modes: `Off`, `Blur` (adjustable intensity), `Green` (Green Screen `#00FF00`), and `Image` (custom background image).

### Integrated Media Gallery
- Filmstrip browser for all locally captured photos and videos.
- Native `AVPlayerView` video playback and downsampled high-resolution photo inspection with double-click zoom.
- Non-destructive Look and Adjustment editor with `Save Copy`, clipboard copy, Reveal in Finder, and Move to Trash.

### First-Launch Onboarding
- Two-column macOS-native setup walkthrough covering privacy, Camera & Microphone permissions, appearance (`System`, `Light`, `Dark`), and local save folder selection.

---

## Keyboard Shortcuts

| Context | Shortcut | Action |
| :--- | :--- | :--- |
| Camera / Video | `Space` or `Return` | Capture photo or start/stop video recording |
| Camera / Video | `Esc` | Cancel active photo countdown |
| Gallery | `Left` / `Right` Arrow | Navigate between captured items |
| Gallery | `Esc` | Exit editor or return to Camera |

---

## Project Structure

```text
Cove/
├── Cove/
│   ├── CoveApp.swift                  # App entry point & appearance mode
│   ├── ContentView.swift              # Root view wrapper
│   ├── Models/CameraModels.swift      # Shared state models, presets, and enums
│   ├── DesignSystem/CoveTheme.swift   # Colors, spacing, radius, and vibrancy helpers
│   ├── CameraEngine/
│   │   ├── CameraManager.swift        # AVCaptureSession, device discovery, capture flow
│   │   └── VideoRecorder.swift        # AVAssetWriter H.264 + AAC recorder
│   ├── ImageProcessing/
│   │   └── ImageProcessor.swift       # Core Image filters & Vision background segmentation
│   ├── Storage/
│   │   └── MediaStorageManager.swift  # Local Pictures/Cove storage & thumbnail generation
│   └── UI/
│       ├── MainWindowView.swift       # Main workspace, controls, and shortcuts
│       ├── MetalPreviewView.swift     # MTKView real-time renderer
│       ├── CameraPreviewView.swift    # Fallback AVCaptureVideoPreviewLayer
│       ├── CompositionOverlayView.swift
│       ├── TeleprompterOverlayView.swift
│       ├── GalleryView.swift          # Media viewer & non-destructive editor
│       ├── SettingsView.swift         # App preferences & storage settings
│       └── OnboardingView.swift       # Two-column first-launch setup guide
├── CoveTests/
├── CoveUITests/
└── Cove.xcodeproj/
```

---

## Building from Source

### Requirements
- macOS 12.7 or later
- Xcode 14.1 or later

### Build & Run
1. Open `Cove/Cove.xcodeproj` in Xcode.
2. Select the **Cove** scheme and run with `Cmd + R`.

Or build from the terminal:

```bash
xcodebuild -project Cove/Cove.xcodeproj -scheme Cove -configuration Release build
```

---

## Documentation
- [PRD.md](PRD.md) — Product Requirements Document
- [SRS.md](SRS.md) — Software Requirements Specification
- [Design_System.md](Design_System.md) — Visual & Interaction Design System
