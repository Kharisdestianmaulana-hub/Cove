# Cove

## Software Requirements Specification (SRS)

**Version:** 0.2  
**Platform:** macOS 12 Monterey and later  
**Application Type:** Native macOS Camera Application  
**Primary Language:** Swift  
**UI Framework:** SwiftUI  
**Purpose:** Personal use, non-commercial

---

## 1. Overview

### 1.1 Product Description

Cove is a native macOS camera application designed to provide a clean, intuitive, and refined camera experience.

The application focuses on photography and video capture with accessible camera controls, image adjustments, visual composition tools, and a lightweight local media library.

Cove is designed to feel calm, minimal, and native to macOS. It prioritizes the camera preview and captured content rather than overwhelming users with unnecessary controls.

Cove is intended for personal use and will not include advertisements, subscriptions, accounts, or cloud-dependent features.

### 1.2 Product Goals

- Provide a comfortable and intuitive camera experience on macOS.
- Offer photo and video capture.
- Provide useful manual camera and image controls.
- Allow users to adjust captured images without relying on external editing software.
- Provide composition guides to help users capture better photos.
- Store captured media locally.
- Maintain a minimal, premium, and native macOS interface.
- Support macOS 12 Monterey and later.

### 1.3 Target Users

Cove is designed for individual macOS users who want:

- A simple but capable camera application.
- Easy access to photo and video capture.
- Basic manual adjustments.
- Minimal and distraction-free camera UI.
- Local media storage without cloud services.
- A camera application without advertisements or subscription restrictions.

### 1.4 Scope

Cove will include:

- Live camera preview.
- Photo capture.
- Video recording.
- Camera selection.
- Basic camera configuration.
- Image adjustment tools.
- Visual looks and presets.
- Composition guides.
- Local gallery.
- Media preview.
- Local file management.
- Application preferences.

### 1.5 Out of Scope

The initial release will not include:

- Cloud storage.
- User accounts.
- Social media integrations.
- Online sharing platform.
- Subscription features.
- Advertisement systems.
- AI-based image generation.
- Professional video editing timeline.
- Advanced multi-camera recording.
- App Store distribution requirements.

---

## 2. Technology Stack

### 2.1 Core Technologies

| Technology   | Purpose                                                  |
| ------------ | -------------------------------------------------------- |
| Swift        | Primary programming language                             |
| SwiftUI      | User interface and application structure                 |
| AVFoundation | Camera preview, capture, recording, camera configuration |
| Core Image   | Image processing and visual effects                      |
| AppKit       | macOS-specific functionality and integration             |
| FileManager  | Local media and file management                          |

### 2.2 Platform Requirements

- macOS 12 Monterey or later.
- Support for built-in and compatible external cameras.
- Support for camera and microphone permissions.
- Local storage access.

### 2.3 Architectural Principles

Cove should follow these principles:

- Native macOS development.
- Lightweight application architecture.
- Separation of UI and camera logic.
- Modular camera functionality.
- Reusable UI components.
- Local-first processing.
- Avoid unnecessary dependencies.
- Avoid unnecessary third-party libraries.

---

## 3. System Architecture

### 3.1 Architecture Overview

The application should separate its primary responsibilities.

#### UI Layer

Responsible for:

- Application navigation.
- Camera interface.
- Controls and panels.
- Settings.
- Gallery interface.
- UI state management.

#### Camera Engine

Responsible for:

- Camera discovery.
- Camera selection.
- Live preview.
- Capture session management.
- Photo capture.
- Video recording.
- Camera configuration.
- Camera permissions.

#### Image Processing Engine

Responsible for:

- Image adjustments.
- Preset processing.
- Color adjustments.
- Image enhancement.
- Preview processing.

#### Media Library

Responsible for:

- Saving photos.
- Saving videos.
- Loading media.
- Managing thumbnails.
- Deleting media.
- Opening media.
- File location management.

#### macOS Integration

Responsible for:

- Native menus.
- Window behavior.
- System permissions.
- Finder integration.
- Keyboard shortcuts.
- macOS-specific features.

---

## 4. User Interface Requirements

### 4.1 UI Design Philosophy

Cove uses a design philosophy called **Quiet Premium**.

The UI should feel:

- Minimal.
- Calm.
- Refined.
- Modern.
- Native.
- Cinematic.
- Comfortable to use.

The application should prioritize the camera preview and avoid excessive UI elements.

### 4.2 Main Layout

The main window should consist of the following regions:

1. Top Navigation.
2. Main Camera Preview.
3. Right Camera Control Panel.
4. Bottom-right Media Gallery Access.

### 4.3 Main Camera Preview

The camera preview should be the primary visual element.

Requirements:

- Display the active camera feed.
- Maintain an appropriate preview aspect ratio.
- Support preview resizing.
- Display composition guides.
- Display camera status when necessary.
- Provide unobtrusive camera error states.
- Avoid excessive UI overlays.

### 4.4 Right Control Panel

The right-side panel should contain the primary capture controls.

Elements:

- Capture button.
- Capture mode selector.
- Camera selector.
- Camera configuration access.
- Basic camera settings.
- Recording status.
- Timer controls where applicable.

The panel should remain visually compact.

### 4.5 Capture Button

The capture button should:

- Capture photos in photo mode.
- Start video recording in video mode.
- Stop video recording when recording is active.
- Display a clear recording state.
- Provide visual feedback when capturing.
- Use a subtle gradient or highlight when appropriate.

### 4.6 Capture Mode Selector

Supported modes:

- Photo.
- Video.

The mode selector should allow users to switch between supported capture modes.

### 4.7 Gallery Access

A recent media thumbnail should be displayed in the bottom-right region of the main interface.

Requirements:

- Display the most recently captured media.
- Provide quick access to the media gallery.
- Display a thumbnail preview.
- Open the gallery or media viewer when selected.

### 4.8 Top Navigation

The top navigation should provide access to the main application features.

Initial navigation:

- Camera.
- Adjust.
- Looks.
- Composition.
- Settings.

Navigation should remain visually lightweight and unobtrusive.

---

## 5. Camera Functional Requirements

### 5.1 Camera Discovery

The application must:

- Detect available cameras.
- Support built-in cameras.
- Support compatible external cameras.
- Allow camera selection.
- Handle unavailable cameras.
- Update camera availability when devices change.

### 5.2 Live Preview

The application must:

- Display live camera feed.
- Initialize the selected camera.
- Update preview when camera selection changes.
- Handle camera initialization errors.
- Maintain responsive UI interactions.
- Avoid unnecessary preview processing overhead.

### 5.3 Photo Capture

The application must:

- Capture still images.
- Save captured images locally.
- Support configurable image format where technically available.
- Display capture feedback.
- Handle capture errors.
- Allow users to access captured media.

Initial supported formats:

- JPEG.
- HEIF/HEIC where supported.
- PNG where appropriate for processed exports.

Format availability may depend on the capture pipeline and system support.

### 5.4 Video Recording

The application must:

- Start video recording.
- Stop video recording.
- Save recorded video locally.
- Display recording status.
- Display recording duration.
- Handle recording errors.
- Handle interruption where possible.

Initial video configuration options:

- Resolution.
- Frame rate.
- Audio recording toggle.
- Microphone selection where supported.

### 5.5 Camera Selection

Users must be able to select from available cameras.

The camera selector should:

- Display camera names.
- Display selected camera.
- Switch camera when selected.
- Handle unavailable cameras.

### 5.6 Camera Configuration

The application should expose camera settings supported by the selected camera device.

Potential settings:

- Resolution.
- Frame rate.
- Exposure.
- Focus.
- White balance.
- Zoom where supported.

Unavailable controls should not be presented as functional controls.

### 5.7 Countdown Timer

The application should support a capture countdown.

Initial options:

- Off.
- 3 seconds.
- 5 seconds.
- 10 seconds.

The countdown should provide visual feedback before capture.

### 5.8 Burst Capture

Burst capture may be implemented as an optional feature.

Requirements if implemented:

- Allow multiple consecutive photos.
- Provide configurable burst behavior.
- Avoid blocking the UI.
- Handle storage and processing efficiently.

Burst capture is considered a lower-priority feature.

---

## 6. Image Adjustment Requirements

### 6.1 Adjustments Overview

Cove should provide accessible image adjustment tools without attempting to become a full professional image editing application.

### 6.2 Basic Adjustments

Initial adjustment tools:

- Brightness.
- Contrast.
- Saturation.
- Exposure.
- Highlights.
- Shadows.
- Sharpness.

### 6.3 White Balance

The application should provide white balance adjustments where supported by the processing pipeline.

Potential controls:

- Temperature.
- Tint.

### 6.4 Adjustment Interface

The adjustment interface should:

- Use sliders.
- Display adjustment values.
- Allow resetting individual adjustments.
- Allow resetting all adjustments.
- Update the preview when values change.
- Avoid excessive UI complexity.

### 6.5 Processing Behavior

- Adjustments should be previewed in real time where performance allows.
- Original media should remain preserved.
- Processing should not permanently modify original captured files unless explicitly exported.
- Processing should be separated from camera capture logic.

---

## 7. Looks and Presets

### 7.1 Preset Overview

Cove should provide simple visual presets to quickly change the appearance of captured images.

### 7.2 Initial Presets

Initial preset suggestions:

- Natural.
- Warm.
- Cool.
- Cinema.
- Mono.
- Soft.

Presets should remain subtle and practical.

### 7.3 Preset Behavior

- Presets should apply predefined adjustment values.
- Users should be able to modify preset results.
- Original media should remain unchanged.
- Preset preview should update efficiently.

### 7.4 Custom Presets

Custom preset saving may be implemented in a future version.

---

## 8. Composition Tools

### 8.1 Composition Overview

Composition tools should help users frame their subjects.

### 8.2 Composition Guides

Initial supported guides:

- Rule of thirds.
- Center crosshair.
- Square grid.

### 8.3 Aspect Ratio

The preview and capture interface should support configurable aspect ratios where the capture pipeline permits.

Initial aspect ratio options:

- Default camera ratio.
- 1:1.
- 4:3.
- 16:9.

Actual capture dimensions may depend on camera capabilities.

### 8.4 Level Indicator

A level indicator may be implemented if supported through available sensor or device information.

### 8.5 Safe Areas

Optional composition guides may include safe framing boundaries.

---

## 9. Media Library

### 9.1 Gallery Overview

Cove should provide a simple local gallery for captured photos and videos.

The gallery should be accessible from the main camera interface.

### 9.2 Media Display

The gallery should:

- Display photo thumbnails.
- Display video thumbnails where available.
- Display captured media in a grid.
- Identify photo and video content.
- Provide a media preview.

### 9.3 Media Preview

Users should be able to:

- Open photos.
- Preview videos.
- Navigate between media.
- View basic media information.

### 9.4 Media Management

Users should be able to:

- Delete media.
- Reveal media in Finder.
- Open media using the system.
- View file information.

### 9.5 Local Storage

Captured media should be stored locally.

Requirements:

- Default save location should be easy to access.
- Users should be able to change the save location.
- Storage operations should be reliable.
- Save errors should be handled gracefully.

### 9.6 Media Metadata

Where available, media information may include:

- Capture date.
- File name.
- File size.
- Resolution.
- Video duration.
- Capture format.

---

## 10. Settings

### 10.1 General Settings

Settings should provide access to application preferences.

### 10.2 Appearance

Appearance options:

- System.
- Light.
- Dark.

### 10.3 Storage

Storage options:

- Default save location.
- Custom save location.

### 10.4 Capture Settings

Capture preferences may include:

- Photo format.
- Video resolution.
- Frame rate.
- Microphone.
- Audio recording.
- Countdown timer default.

### 10.5 Interface Preferences

Interface preferences may include:

- Default composition guide.
- Default aspect ratio.
- Preview behavior.

### 10.6 Reset Settings

Users should be able to restore application settings to default values.

---

## 11. Privacy and Permissions

### 11.1 Camera Permission

The application must request camera access through macOS permission mechanisms.

### 11.2 Microphone Permission

The application must request microphone access only when microphone functionality is required.

### 11.3 Privacy Principles

- No user account.
- No cloud uploads.
- No analytics by default.
- No advertisement tracking.
- No unnecessary data collection.
- Local media storage.

### 11.4 Permission Errors

The application should provide clear guidance when camera or microphone access is denied.

---

## 12. Error Handling

The application should handle:

- Camera unavailable.
- Camera disconnected.
- Camera permission denied.
- Microphone permission denied.
- Capture failure.
- Recording failure.
- File save failure.
- Insufficient storage.
- Invalid configuration.
- Media loading failure.

Errors should be communicated clearly without interrupting the entire application unnecessarily.

---

## 13. Non-Functional Requirements

### 13.1 Performance

- The UI should remain responsive.
- Camera preview should be smooth where hardware permits.
- Image processing should not unnecessarily block the UI.
- Media loading should be asynchronous where appropriate.
- Resource usage should be reasonable.

### 13.2 Reliability

- Camera initialization should be handled safely.
- Capture operations should avoid unnecessary conflicts.
- Recording should save files reliably.
- Application errors should not unnecessarily terminate the app.

### 13.3 Usability

- The interface should remain simple.
- Controls should be easy to understand.
- Important actions should be accessible.
- UI feedback should be clear.
- Avoid excessive menus and nested settings.

### 13.4 Maintainability

- Modular architecture.
- Clear separation of responsibilities.
- Reusable components.
- Consistent naming.
- Minimal external dependencies.

### 13.5 Accessibility

- Support system accessibility features.
- Use accessible labels.
- Maintain sufficient contrast.
- Support keyboard interaction where practical.
- Respect Reduce Motion preferences.

---

## 14. Design Requirements

### 14.1 Design Direction

**Quiet Premium**

The application should feel like a carefully designed native macOS application.

### 14.2 Color Palette

| Color             | Hex     | Usage                       |
| ----------------- | ------- | --------------------------- |
| Deep Graphite     | #171719 | Dark backgrounds            |
| Elevated Graphite | #242426 | Elevated surfaces           |
| Soft White        | #F5F5F7 | Light text and backgrounds  |
| Silver            | #E8E8ED | Secondary surfaces          |
| System Accent     | System  | Selected states and accents |

### 14.3 Color Usage

- Neutral colors should dominate.
- Gradients should be used sparingly.
- Red should primarily indicate recording.
- Status colors should only be used when meaningful.
- Avoid excessive colorful UI elements.

### 14.4 Materials

Use macOS translucent materials selectively.

Potential usage:

- Floating controls.
- Navigation elements.
- Popovers.
- Overlay panels.

Materials should not reduce preview clarity.

### 14.5 Typography

Use native system typography and SF-based system fonts where appropriate.

### 14.6 Corner Radius

Suggested radius:

| Element         | Radius   |
| --------------- | -------- |
| Main Window     | 16–20    |
| Floating Panels | 14–18    |
| Tabs            | 12–16    |
| Buttons         | 10–14    |
| Capture Button  | Circular |

### 14.7 Motion

Motion should be subtle and purposeful.

- Typical transition duration: 150–250 ms.
- Avoid excessive animations.
- Respect Reduce Motion.

### 14.8 Appearance

The application must support:

- Light mode.
- Dark mode.
- System appearance.

---

## 15. Development Priorities

### Phase 1 — Camera Foundation

- Application window.
- Camera discovery.
- Camera permission.
- Live camera preview.
- Camera selection.
- Basic camera session management.

### Phase 2 — Capture

- Photo capture.
- Photo saving.
- Video recording.
- Recording status.
- Video saving.

### Phase 3 — Main UI

- Main layout.
- Top navigation.
- Right control panel.
- Capture button.
- Gallery access.
- Appearance support.

### Phase 4 — Adjustments

- Brightness.
- Contrast.
- Saturation.
- Exposure.
- Highlights.
- Shadows.
- Sharpness.
- White balance.

### Phase 5 — Looks

- Presets.
- Preset preview.
- Preset application.

### Phase 6 — Composition

- Rule of thirds.
- Center guide.
- Square grid.
- Aspect ratio options.
- Level indicator if feasible.

### Phase 7 — Media Library

- Gallery.
- Thumbnails.
- Media preview.
- Delete.
- Reveal in Finder.

### Phase 8 — Settings and Refinement

- Capture settings.
- Storage settings.
- Appearance settings.
- Error handling.
- UI polish.
- Performance refinement.

---

## 16. Acceptance Criteria

The initial application should be considered functional when:

- The application launches on supported macOS versions.
- The camera can be detected.
- Live camera preview works.
- Users can select a camera.
- Users can capture photos.
- Captured photos can be saved locally.
- Users can record videos.
- Recorded videos can be saved locally.
- Users can access captured media.
- Camera errors are handled appropriately.
- The interface supports light and dark appearance.
- Basic composition tools work.
- Basic adjustments work where implemented.
- Application UI remains responsive during capture operations.

---

## 17. Initial Release Definition

The initial release of Cove should prioritize a stable and usable camera experience.

### Must Have

- Native macOS application.
- Live preview.
- Camera selection.
- Photo capture.
- Video recording.
- Local saving.
- Basic gallery.
- Light and dark mode.
- Camera permission handling.
- Minimal and polished UI.

### Should Have

- Basic image adjustments.
- Composition guides.
- Countdown timer.
- Video audio configuration.
- Camera configuration.

### Could Have

- Looks and presets.
- Burst capture.
- Custom presets.
- Level indicator.
- Advanced camera profiles.

---

## 18. Product Identity

**Product Name:** Cove

**Product Type:** Native macOS Camera Application

**Platform:** macOS 12+

**Primary Language:** Swift

**UI Framework:** SwiftUI

**Design Direction:** Quiet Premium

**Product Philosophy:**

Cove is a personal camera space designed to make capturing moments on macOS feel simple, natural, and refined.

It should provide enough control to improve the capture experience without turning the camera into a complicated editing workspace.
