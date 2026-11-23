import AppKit
import AVFoundation
import Combine
import CoreImage
import Foundation
import Metal

/// Manages camera discovery, permissions, selection, live AVCaptureSession, and photo/video capture.
final class CameraManager: NSObject, ObservableObject {
    @Published private(set) var availableCameras: [CameraDevice] = []
    @Published private(set) var selectedCamera: CameraDevice?
    @Published private(set) var availableMicrophones: [AudioDevice] = []
    @Published private(set) var selectedMicrophone: AudioDevice?
    @Published private(set) var permissionStatus: CameraPermissionStatus = .notDetermined
    @Published private(set) var microphonePermissionStatus: CameraPermissionStatus = .notDetermined
    @Published private(set) var sessionState: CameraSessionState = .idle

    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var isCapturingPhoto = false
    @Published private(set) var isBurstCapturing = false
    @Published private(set) var burstProgressText: String?
    @Published private(set) var countdownRemaining: Int?
    @Published private(set) var latestMediaURL: URL?
    @Published private(set) var latestThumbnail: NSImage?
    @Published private(set) var latestMediaIsVideo = false
    @Published private(set) var statusBannerMessage: String?

    @Published var adjustments = AdjustmentState() {
        didSet {
            adjustmentsLock.lock()
            activeAdjustments = adjustments
            adjustmentsLock.unlock()
        }
    }
    @Published var isMirrored: Bool = false {
        didSet {
            adjustmentsLock.lock()
            activeMirrorState = isMirrored
            adjustmentsLock.unlock()
        }
    }
    @Published var shutterSoundEnabled: Bool = true
    @Published private(set) var activeLook: LookPreset = .natural
    @Published private(set) var customPresets: [CustomPreset] = []
    @Published private(set) var activeCustomPresetID: UUID?

    let session = AVCaptureSession()
    let metalDevice: MTLDevice?
    let imageProcessor: ImageProcessor
    let metalRenderer: MetalFrameRenderer

    private let sessionQueue = DispatchQueue(label: "com.studiokharis.cove.camera.session", qos: .userInitiated)
    private let videoOutputQueue = DispatchQueue(label: "com.studiokharis.cove.video.output", qos: .userInteractive)
    private let audioOutputQueue = DispatchQueue(label: "com.studiokharis.cove.audio.output", qos: .userInitiated)
    private let storageManager = MediaStorageManager()
    private let videoRecorder: VideoRecorder

    private let adjustmentsLock = NSLock()
    private var activeAdjustments = AdjustmentState()
    private var activeMirrorState = false
    private var previewVisibleState = true
    private var activeBackgroundMode: VideoBackgroundMode = .off
    private var activeBackgroundBlurRadius: Double = 18.0
    private var activeCustomBackgroundImage: CIImage?
    private var currentFrameWidth = 1280
    private var currentFrameHeight = 720

    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentAudioInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()

    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false
    private var pendingPhotoFormat: CaptureConfiguration.PhotoFormat = .jpeg
    private var pendingCropAspectRatio: CGFloat?
    private var totalBurstCount = 1
    private var remainingBurstCount = 0
    private var preferredVideoResolution: CaptureConfiguration.VideoResolution = .hd1080p
    private let customPresetsStorageKey = "cove.customPresets"
    private var recordingTimer: Timer?
    private var recordingStartDate: Date?
    private var countdownTimer: Timer?
    private var statusClearWorkItem: DispatchWorkItem?

    override init() {
        let device = MTLCreateSystemDefaultDevice()
        let processor = ImageProcessor(metalDevice: device)
        self.metalDevice = device
        self.imageProcessor = processor
        self.metalRenderer = MetalFrameRenderer(metalDevice: device, ciContext: processor.context)
        self.videoRecorder = VideoRecorder(ciContext: processor.context)
        super.init()
        loadCustomPresets()
        syncPermissionStatus()
        refreshMicrophones()
        observeDeviceNotifications()
        refreshLatestMedia()
    }

    /// Applies a visual Look preset and updates the active adjustment values.
    func selectLook(_ look: LookPreset) {
        activeLook = look
        activeCustomPresetID = nil
        adjustments = look.adjustments
    }

    /// Applies a user-saved custom preset.
    func selectCustomPreset(_ preset: CustomPreset) {
        activeCustomPresetID = preset.id
        adjustments = preset.adjustments
    }

    /// Saves the current adjustment values as a local custom preset.
    func saveCustomPreset(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let preset = CustomPreset(name: trimmed, adjustments: adjustments)
        customPresets.append(preset)
        activeCustomPresetID = preset.id
        persistCustomPresets()
    }

    /// Deletes a saved custom preset.
    func deleteCustomPreset(_ preset: CustomPreset) {
        customPresets.removeAll { $0.id == preset.id }
        if activeCustomPresetID == preset.id {
            activeCustomPresetID = nil
        }
        persistCustomPresets()
    }

    /// Resets all image adjustments and returns to the Natural look.
    func resetAdjustments() {
        activeLook = .natural
        activeCustomPresetID = nil
        adjustments = AdjustmentState()
    }

    private func loadCustomPresets() {
        guard let data = UserDefaults.standard.data(forKey: customPresetsStorageKey),
              let decoded = try? JSONDecoder().decode([CustomPreset].self, from: data) else {
            return
        }
        customPresets = decoded
    }

    private func persistCustomPresets() {
        guard let data = try? JSONEncoder().encode(customPresets) else { return }
        UserDefaults.standard.set(data, forKey: customPresetsStorageKey)
    }

    /// Checks camera permission and initializes the live preview session.
    func start() {
        syncPermissionStatus()

        switch permissionStatus {
        case .authorized:
            configureAndStartSession()
        case .notDetermined:
            updateSessionState(.initializing)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.syncPermissionStatus()
                    if granted {
                        self.configureAndStartSession()
                    } else {
                        self.updateSessionState(.permissionDenied)
                    }
                }
            }
        case .denied, .restricted:
            updateSessionState(.permissionDenied)
        }
    }

    /// Stops the active camera session without blocking the main thread.
    func stop() {
        cancelCountdown()
        stopRecordingTimer()
        if isRecording {
            stopVideoRecording()
        }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    /// Switches the active input device to the selected camera.
    func selectCamera(_ device: CameraDevice) {
        guard device.id != selectedCamera?.id, !isRecording else { return }
        DispatchQueue.main.async {
            self.selectedCamera = device
        }
        sessionQueue.async { [weak self] in
            self?.switchToDevice(id: device.id)
        }
    }

    /// Switches the active microphone input device (built-in or external).
    func selectMicrophone(_ device: AudioDevice) {
        guard device.id != selectedMicrophone?.id, !isRecording else { return }
        DispatchQueue.main.async {
            self.selectedMicrophone = device
        }
        sessionQueue.async { [weak self] in
            guard let self = self, self.currentAudioInput != nil else { return }
            self.switchToAudioDevice(id: device.id)
        }
    }

    /// Pre-attaches or detaches audio input when switching between Photo and Video modes.
    func prepareAudioForVideoMode(enabled: Bool) {
        syncPermissionStatus()
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isRecording else { return }
            if enabled, AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                self.attachSelectedAudioInputIfNeeded()
                self.attachAudioDataOutputIfNeeded()
            } else {
                self.detachAudioInputIfNeeded()
            }
        }
    }

    /// Re-attempts permission check, device discovery, and session startup.
    func retry() {
        start()
    }

    /// Opens macOS Privacy & Security settings for Camera access.
    func openSystemPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Opens macOS Privacy & Security settings for Microphone access.
    func openMicrophonePrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Requests Camera and Microphone permissions during onboarding without starting the session yet.
    func requestOnboardingPermissions(completion: @escaping () -> Void) {
        let requestAudio: () -> Void = { [weak self] in
            let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            if audioStatus == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { _ in
                    DispatchQueue.main.async {
                        self?.syncPermissionStatus()
                        self?.refreshMicrophones()
                        completion()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.syncPermissionStatus()
                    self?.refreshMicrophones()
                    completion()
                }
            }
        }

        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if videoStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async {
                    self.syncPermissionStatus()
                    requestAudio()
                }
            }
        } else {
            requestAudio()
        }
    }

    /// Reveals the most recently captured media item in Finder.
    func revealLatestMediaInFinder() {
        guard let url = latestMediaURL else { return }
        storageManager.revealInFinder(url)
    }

    private func playShutterSoundIfEnabled() {
        guard shutterSoundEnabled else { return }
        let shutterPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Shutter.aif"
        if let sound = NSSound(contentsOfFile: shutterPath, byReference: true) {
            sound.play()
        } else {
            NSSound(named: "Pop")?.play()
        }
    }

    /// Refreshes the Recent Media card from the local Cove save directory.
    func refreshLatestMedia() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let items = self.storageManager.loadCapturedMedia()
            if let latest = items.first {
                let thumb = self.storageManager.generateThumbnail(for: latest.url, isVideo: latest.isVideo)
                DispatchQueue.main.async {
                    self.latestMediaURL = latest.url
                    self.latestThumbnail = thumb
                    self.latestMediaIsVideo = latest.isVideo
                }
            } else {
                DispatchQueue.main.async {
                    self.latestMediaURL = nil
                    self.latestThumbnail = nil
                    self.latestMediaIsVideo = false
                }
            }
        }
    }

    /// Loads all locally captured media items asynchronously.
    func loadGalleryMedia(completion: @escaping ([MediaItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let items = self.storageManager.loadCapturedMedia()
            DispatchQueue.main.async {
                completion(items)
            }
        }
    }

    /// Generates a thumbnail asynchronously for a gallery item.
    func loadThumbnail(for item: MediaItem, completion: @escaping (NSImage?) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let image = self?.storageManager.generateThumbnail(for: item.url, isVideo: item.isVideo, maxPixelSize: 320)
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    /// Moves a media item to the Trash and updates Recent Media if needed.
    func deleteMedia(_ item: MediaItem) throws {
        try storageManager.trashMedia(item)
        if item.url == latestMediaURL {
            refreshLatestMedia()
        }
    }

    func revealInFinder(_ item: MediaItem) {
        storageManager.revealInFinder(item.url)
    }

    func openWithSystem(_ item: MediaItem) {
        storageManager.openWithSystem(item.url)
    }

    /// Exports a non-destructive edited copy of a photo or video from the gallery.
    func exportEditedCopy(
        of item: MediaItem,
        adjustments: AdjustmentState,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if !item.isVideo {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                do {
                    let originalData = try Data(contentsOf: item.url)
                    let ext = item.url.pathExtension.lowercased() == "heic" ? "heic" : "jpg"
                    let format: CaptureConfiguration.PhotoFormat = (ext == "heic") ? .heif : .jpeg
                    let rendered = self.imageProcessor.renderProcessedPhotoData(
                        from: originalData,
                        adjustments: adjustments,
                        format: format
                    ) ?? originalData
                    let savedURL = try self.storageManager.savePhotoData(rendered, fileExtension: ext)
                    self.refreshLatestMedia()
                    DispatchQueue.main.async {
                        completion(.success(savedURL))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
            return
        }

        let asset = AVAsset(url: item.url)
        let processor = self.imageProcessor
        let composition = AVMutableVideoComposition(asset: asset) { request in
            let source = request.sourceImage.clampedToExtent()
            let output = processor.apply(to: source, adjustments: adjustments)
                .cropped(to: request.sourceImage.extent)
            request.finish(with: output, context: processor.context)
        }

        do {
            let destination = try storageManager.makeMediaURL(fileExtension: "mov")
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                completion(.failure(NSError(
                    domain: "com.studiokharis.cove.export",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to create video export session."]
                )))
                return
            }
            exportSession.outputURL = destination
            exportSession.outputFileType = .mov
            exportSession.videoComposition = composition
            exportSession.exportAsynchronously { [weak self] in
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        self?.refreshLatestMedia()
                        completion(.success(destination))
                    default:
                        completion(.failure(exportSession.error ?? NSError(
                            domain: "com.studiokharis.cove.export",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Video export failed."]
                        )))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    var currentSaveDirectoryPath: String {
        storageManager.currentSaveDirectoryDisplayPath()
    }

    var hasCustomSaveDirectory: Bool {
        storageManager.hasCustomSaveDirectory
    }

    @discardableResult
    func chooseCustomSaveDirectory() -> URL? {
        let selected = storageManager.chooseCustomSaveDirectory()
        if selected != nil {
            refreshLatestMedia()
        }
        return selected
    }

    func resetSaveDirectoryToDefault() {
        storageManager.resetSaveDirectoryToDefault()
        refreshLatestMedia()
    }

    func openSaveDirectoryInFinder() {
        if let url = try? storageManager.saveDirectoryURL() {
            NSWorkspace.shared.open(url)
        }
    }

    /// Applies preferred video resolution to the active capture session when supported.
    func updateVideoResolution(_ resolution: CaptureConfiguration.VideoResolution) {
        preferredVideoResolution = resolution
        guard isConfigured else { return }

        sessionQueue.async { [weak self] in
            guard let self = self, !self.isRecording else { return }
            self.session.beginConfiguration()
            self.applyPreferredSessionPreset()
            self.session.commitConfiguration()
        }
    }

    // MARK: - Capture Actions

    /// Starts a countdown if configured, or captures photo(s) immediately (supporting single and burst mode).
    func triggerPhotoCapture(
        countdown: CountdownDuration,
        format: CaptureConfiguration.PhotoFormat = .jpeg,
        burstMode: BurstMode = .off,
        cropAspectRatio: CGFloat? = nil
    ) {
        guard sessionState == .running, !isCapturingPhoto, !isBurstCapturing, !isRecording else { return }

        if countdownRemaining != nil {
            cancelCountdown()
            return
        }

        let shotCount = burstMode.count
        if countdown == .off {
            startPhotoCaptureSequence(count: shotCount, format: format, cropAspectRatio: cropAspectRatio)
            return
        }

        countdownTimer?.invalidate()
        countdownRemaining = countdown.seconds

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            guard let current = self.countdownRemaining else {
                timer.invalidate()
                return
            }

            if current <= 1 {
                timer.invalidate()
                self.countdownTimer = nil
                self.countdownRemaining = nil
                self.startPhotoCaptureSequence(count: shotCount, format: format, cropAspectRatio: cropAspectRatio)
            } else {
                self.countdownRemaining = current - 1
            }
        }
    }

    private func startPhotoCaptureSequence(
        count: Int,
        format: CaptureConfiguration.PhotoFormat,
        cropAspectRatio: CGFloat?
    ) {
        totalBurstCount = max(1, count)
        remainingBurstCount = totalBurstCount
        pendingCropAspectRatio = cropAspectRatio
        if totalBurstCount > 1 {
            isBurstCapturing = true
            burstProgressText = "Burst 1/\(totalBurstCount)"
        }
        capturePhoto(format: format)
    }

    /// Captures a single still photo and saves it locally.
    func capturePhoto(format: CaptureConfiguration.PhotoFormat = .jpeg) {
        guard sessionState == .running, !isCapturingPhoto, !isRecording else { return }

        DispatchQueue.main.async {
            self.isCapturingPhoto = true
            self.playShutterSoundIfEnabled()
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.pendingPhotoFormat = format

            let settings: AVCapturePhotoSettings
            if format == .heif, self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Cancels an active photo countdown timer.
    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        DispatchQueue.main.async {
            self.countdownRemaining = nil
        }
    }

    /// Starts or stops video recording, requesting microphone permission only when needed.
    func toggleVideoRecording(includeAudio: Bool = true) {
        guard sessionState == .running else { return }

        if isRecording {
            stopVideoRecording()
            return
        }

        guard includeAudio else {
            startVideoRecording(includeAudio: false)
            return
        }

        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch audioStatus {
        case .authorized:
            startVideoRecording(includeAudio: true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.syncPermissionStatus()
                    self?.startVideoRecording(includeAudio: granted)
                }
            }
        case .denied, .restricted:
            syncPermissionStatus()
            showStatusBanner("Microphone access denied — recording video without sound.")
            startVideoRecording(includeAudio: false)
        @unknown default:
            startVideoRecording(includeAudio: false)
        }
    }

    private func startVideoRecording(includeAudio: Bool) {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.videoRecorder.isRecording else { return }

            if includeAudio {
                self.attachSelectedAudioInputIfNeeded()
                self.attachAudioDataOutputIfNeeded()
            } else {
                self.detachAudioInputIfNeeded()
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

            let width = max(self.currentFrameWidth, 640)
            let height = max(self.currentFrameHeight, 360)
            let hasAudio = includeAudio && self.currentAudioInput != nil
            let recommendedAudioSettings = hasAudio
                ? self.audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov)
                : nil

            self.videoRecorder.start(
                outputURL: tempURL,
                width: width,
                height: height,
                includeAudio: hasAudio,
                audioSettings: recommendedAudioSettings,
                onStarted: { [weak self] in
                    self?.isRecording = true
                    self?.startRecordingTimer()
                },
                onError: { [weak self] error in
                    self?.isRecording = false
                    self?.showStatusBanner("Recording failed: \(error.localizedDescription)")
                }
            )
        }
    }

    private func stopVideoRecording() {
        stopRecordingTimer()
        videoRecorder.finish { [weak self] result in
            guard let self = self else { return }
            self.isRecording = false

            switch result {
            case .success(let tempURL):
                do {
                    let savedURL = try self.storageManager.moveRecordedVideo(from: tempURL)
                    let thumbnail = self.storageManager.generateThumbnail(for: savedURL, isVideo: true)
                    self.latestMediaURL = savedURL
                    self.latestThumbnail = thumbnail
                    self.latestMediaIsVideo = true
                    self.showStatusBanner("Video saved to Pictures/Cove")
                } catch {
                    self.showStatusBanner("Failed to save video: \(error.localizedDescription)")
                }
            case .failure(let error):
                self.showStatusBanner("Recording failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Session Setup

    private func syncPermissionStatus() {
        permissionStatus = mapAuthorizationStatus(AVCaptureDevice.authorizationStatus(for: .video))
        microphonePermissionStatus = mapAuthorizationStatus(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    private func mapAuthorizationStatus(_ status: AVAuthorizationStatus) -> CameraPermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    private func observeDeviceNotifications() {
        let center = NotificationCenter.default

        center.publisher(for: .AVCaptureDeviceWasConnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                let device = notification.object as? AVCaptureDevice
                if device?.hasMediaType(.audio) == true {
                    self.refreshMicrophones()
                } else {
                    self.refreshCamerasAndEnsureSelection()
                }
            }
            .store(in: &cancellables)

        center.publisher(for: .AVCaptureDeviceWasDisconnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                let device = notification.object as? AVCaptureDevice
                let disconnectedID = device?.uniqueID
                if device?.hasMediaType(.audio) == true {
                    self.refreshMicrophones(disconnectedID: disconnectedID)
                } else {
                    self.refreshCamerasAndEnsureSelection(disconnectedID: disconnectedID)
                }
            }
            .store(in: &cancellables)

        center.publisher(for: .AVCaptureSessionRuntimeError)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
                let message = error?.localizedDescription ?? "An unexpected camera session error occurred."
                self.updateSessionState(.error(message))
            }
            .store(in: &cancellables)
    }

    private func configureAndStartSession() {
        updateSessionState(.initializing)

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let devices = self.discoverVideoDevices()

            DispatchQueue.main.async {
                self.availableCameras = devices
            }

            guard let targetDevice = self.resolveTargetDevice(from: devices) else {
                DispatchQueue.main.async {
                    self.selectedCamera = nil
                    self.sessionState = .unavailable
                }
                return
            }

            DispatchQueue.main.async {
                self.selectedCamera = targetDevice
            }

            self.switchToDevice(id: targetDevice.id)
            guard self.currentVideoInput != nil else { return }
            self.attachOutputsIfNeeded()

            if !self.session.isRunning {
                self.session.startRunning()
            }

            self.isConfigured = true
            self.updateSessionState(.running)
        }
    }

    private func attachOutputsIfNeeded() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        if !session.outputs.contains(videoDataOutput) {
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
            }
        }
    }

    /// Updates whether the live camera preview is currently visible on screen.
    /// When hidden (e.g. in Gallery or Settings) and not recording, stops the capture session so the
    /// camera hardware and green LED turn off completely.
    func setPreviewVisible(_ visible: Bool) {
        adjustmentsLock.lock()
        previewVisibleState = visible
        adjustmentsLock.unlock()

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if visible {
                if self.isConfigured,
                   !self.session.isRunning,
                   self.permissionStatus == .authorized,
                   self.selectedCamera != nil {
                    self.session.startRunning()
                    self.updateSessionState(.running)
                }
            } else if !self.isRecording, self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    /// Updates virtual background settings for real-time video segmentation.
    func setVideoBackground(mode: VideoBackgroundMode, blurRadius: Double, customImagePath: String) {
        let loadedCIImage: CIImage?
        if mode == .customImage, !customImagePath.isEmpty {
            let url = URL(fileURLWithPath: customImagePath)
            loadedCIImage = CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
        } else {
            loadedCIImage = nil
        }

        adjustmentsLock.lock()
        activeBackgroundMode = mode
        activeBackgroundBlurRadius = blurRadius
        if mode == .customImage {
            activeCustomBackgroundImage = loadedCIImage
        } else {
            activeCustomBackgroundImage = nil
        }
        adjustmentsLock.unlock()
    }

    /// Prompts the user to pick a custom background image and copies it into Cove's Application Support folder.
    func chooseCustomBackgroundImage() -> (path: String, fileName: String)? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Select Background"
        panel.message = "Choose an image to use as your video background."

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return nil }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let coveDir = appSupport.appendingPathComponent("Cove", isDirectory: true)
        try? FileManager.default.createDirectory(at: coveDir, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destURL = coveDir.appendingPathComponent("custom-background.\(ext)")
        try? FileManager.default.removeItem(at: destURL)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return (destURL.path, sourceURL.lastPathComponent)
        } catch {
            return nil
        }
    }

    private func attachAudioDataOutputIfNeeded() {
        guard !session.outputs.contains(audioDataOutput) else { return }
        session.beginConfiguration()
        audioDataOutput.setSampleBufferDelegate(self, queue: audioOutputQueue)
        if session.canAddOutput(audioDataOutput) {
            session.addOutput(audioDataOutput)
        }
        session.commitConfiguration()
    }

    private func attachSelectedAudioInputIfNeeded() {
        if let existing = currentAudioInput {
            if let selectedID = selectedMicrophone?.id, existing.device.uniqueID != selectedID {
                switchToAudioDevice(id: selectedID)
            }
            return
        }

        let targetDevice: AVCaptureDevice?
        if let selectedID = selectedMicrophone?.id, let matched = AVCaptureDevice(uniqueID: selectedID) {
            targetDevice = matched
        } else {
            targetDevice = AVCaptureDevice.default(for: .audio)
        }

        guard let audioDevice = targetDevice,
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            return
        }

        session.beginConfiguration()
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
            currentAudioInput = audioInput
        }
        session.commitConfiguration()
    }

    private func switchToAudioDevice(id: String) {
        guard let audioDevice = AVCaptureDevice(uniqueID: id),
              let newInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            return
        }

        session.beginConfiguration()
        if let existing = currentAudioInput {
            session.removeInput(existing)
            currentAudioInput = nil
        }
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            currentAudioInput = newInput
        }
        session.commitConfiguration()
    }

    /// Discovers connected built-in and external microphones and updates `availableMicrophones`.
    func refreshMicrophones(disconnectedID: String? = nil) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let devices = self.discoverAudioDevices()
            let defaultAudioID = AVCaptureDevice.default(for: .audio)?.uniqueID

            DispatchQueue.main.async {
                self.availableMicrophones = devices
                let needsReselection = self.selectedMicrophone == nil
                    || (disconnectedID != nil && self.selectedMicrophone?.id == disconnectedID)
                    || !devices.contains(where: { $0.id == self.selectedMicrophone?.id })

                if needsReselection {
                    self.selectedMicrophone = devices.first(where: { $0.id == defaultAudioID }) ?? devices.first
                }
            }
        }
    }

    private func discoverAudioDevices() -> [AudioDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )

        return discovery.devices
            .filter { $0.isConnected }
            .map { device in
                AudioDevice(
                    id: device.uniqueID,
                    name: device.localizedName,
                    isBuiltIn: device.deviceType == .builtInMicrophone,
                    isConnected: device.isConnected
                )
            }
    }

    private func detachAudioInputIfNeeded() {
        guard let existingAudio = currentAudioInput else { return }
        session.beginConfiguration()
        session.removeInput(existingAudio)
        currentAudioInput = nil
        session.commitConfiguration()
    }

    private func refreshCamerasAndEnsureSelection(disconnectedID: String? = nil) {
        guard permissionStatus == .authorized else { return }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let devices = self.discoverVideoDevices()

            DispatchQueue.main.async {
                self.availableCameras = devices
            }

            if devices.isEmpty {
                if self.session.isRunning {
                    self.session.stopRunning()
                }
                DispatchQueue.main.async {
                    self.selectedCamera = nil
                    self.sessionState = .unavailable
                }
                return
            }

            let needsReselection = self.selectedCamera == nil
                || (disconnectedID != nil && self.selectedCamera?.id == disconnectedID)
                || !devices.contains(where: { $0.id == self.selectedCamera?.id })

            if needsReselection, let fallback = devices.first {
                DispatchQueue.main.async {
                    self.selectedCamera = fallback
                }
                self.switchToDevice(id: fallback.id)
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                self.updateSessionState(.running)
            } else if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
                self.updateSessionState(.running)
            }
        }
    }

    private func discoverVideoDevices() -> [CameraDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )

        return discovery.devices
            .filter { $0.isConnected }
            .map { device in
                CameraDevice(
                    id: device.uniqueID,
                    name: device.localizedName,
                    isBuiltIn: device.deviceType == .builtInWideAngleCamera,
                    isConnected: device.isConnected
                )
            }
    }

    private func resolveTargetDevice(from devices: [CameraDevice]) -> CameraDevice? {
        if let current = selectedCamera, let match = devices.first(where: { $0.id == current.id }) {
            return match
        }
        return devices.first(where: { $0.isBuiltIn }) ?? devices.first
    }

    private func switchToDevice(id: String) {
        guard let captureDevice = AVCaptureDevice(uniqueID: id) else {
            updateSessionState(.unavailable)
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let existingInput = currentVideoInput {
            session.removeInput(existingInput)
            currentVideoInput = nil
        }

        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            if session.canAddInput(input) {
                session.addInput(input)
                currentVideoInput = input
                applyPreferredSessionPreset()
            } else {
                updateSessionState(.error("Unable to attach the selected camera to the capture session."))
            }
        } catch {
            updateSessionState(.error("Failed to initialize camera: \(error.localizedDescription)"))
        }
    }

    private func applyPreferredSessionPreset() {
        let targetPreset: AVCaptureSession.Preset
        switch preferredVideoResolution {
        case .hd720p:
            targetPreset = .hd1280x720
        case .hd1080p:
            targetPreset = .hd1920x1080
        case .uhd4k:
            targetPreset = .hd4K3840x2160
        }

        if session.canSetSessionPreset(targetPreset) {
            session.sessionPreset = targetPreset
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
    }

    private func updateSessionState(_ state: CameraSessionState) {
        DispatchQueue.main.async {
            self.sessionState = state
        }
    }

    private func showStatusBanner(_ message: String) {
        DispatchQueue.main.async {
            self.statusClearWorkItem?.cancel()
            self.statusBannerMessage = message

            let workItem = DispatchWorkItem { [weak self] in
                self?.statusBannerMessage = nil
            }
            self.statusClearWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
        }
    }

    private func startRecordingTimer() {
        DispatchQueue.main.async {
            self.recordingStartDate = Date()
            self.recordingDuration = 0
            self.recordingTimer?.invalidate()
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self, let start = self.recordingStartDate else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopRecordingTimer() {
        DispatchQueue.main.async {
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            self.recordingStartDate = nil
            self.recordingDuration = 0
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer {
            DispatchQueue.main.async {
                self.isCapturingPhoto = false
            }
        }

        if let error = error {
            showStatusBanner("Photo capture failed: \(error.localizedDescription)")
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            showStatusBanner("Unable to read captured photo data.")
            return
        }

        let ext = pendingPhotoFormat == .heif ? "heic" : "jpg"
        let finalData = imageProcessor.renderProcessedPhotoData(
            from: data,
            adjustments: adjustments,
            isMirrored: isMirrored,
            targetAspectRatio: pendingCropAspectRatio,
            format: pendingPhotoFormat
        ) ?? data

        do {
            let savedURL = try storageManager.savePhotoData(finalData, fileExtension: ext)
            let thumbnail = storageManager.generateThumbnail(for: savedURL, isVideo: false)
            DispatchQueue.main.async {
                self.latestMediaURL = savedURL
                self.latestThumbnail = thumbnail
                self.latestMediaIsVideo = false
            }

            remainingBurstCount = max(0, remainingBurstCount - 1)
            if remainingBurstCount > 0 {
                let nextIndex = totalBurstCount - remainingBurstCount + 1
                DispatchQueue.main.async {
                    self.burstProgressText = "Burst \(nextIndex)/\(self.totalBurstCount)"
                }
                let nextFormat = pendingPhotoFormat
                sessionQueue.asyncAfter(deadline: .now() + 0.16) { [weak self] in
                    self?.capturePhoto(format: nextFormat)
                }
            } else {
                let completedBurst = totalBurstCount > 1
                let count = totalBurstCount
                totalBurstCount = 1
                DispatchQueue.main.async {
                    self.isBurstCapturing = false
                    self.burstProgressText = nil
                }
                showStatusBanner(completedBurst ? "Saved \(count) burst photos" : "Photo saved to Pictures/Cove")
            }
        } catch {
            remainingBurstCount = 0
            totalBurstCount = 1
            DispatchQueue.main.async {
                self.isBurstCapturing = false
                self.burstProgressText = nil
            }
            showStatusBanner("Failed to save photo: \(error.localizedDescription)")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & Audio

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if output === audioDataOutput {
            if videoRecorder.isRecording {
                videoRecorder.appendAudioSampleBuffer(sampleBuffer)
            }
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        currentFrameWidth = CVPixelBufferGetWidth(pixelBuffer)
        currentFrameHeight = CVPixelBufferGetHeight(pixelBuffer)

        let recordingActive = videoRecorder.isRecording

        adjustmentsLock.lock()
        let previewVisible = previewVisibleState
        let currentAdjustments = activeAdjustments
        let mirrored = activeMirrorState
        let bgMode = activeBackgroundMode
        let bgBlurRadius = activeBackgroundBlurRadius
        let bgCustomImage = activeCustomBackgroundImage
        adjustmentsLock.unlock()

        guard previewVisible || recordingActive else { return }

        var inputImage = CIImage(cvPixelBuffer: pixelBuffer)
        if bgMode != .off {
            inputImage = imageProcessor.applyVideoBackground(
                to: inputImage,
                pixelBuffer: pixelBuffer,
                mode: bgMode,
                blurRadius: bgBlurRadius,
                customBackgroundImage: bgCustomImage
            )
        }
        let processed = imageProcessor.applyForLivePreview(
            to: inputImage,
            adjustments: currentAdjustments,
            isMirrored: mirrored
        )

        if previewVisible {
            metalRenderer.enqueue(image: processed)
        }

        if recordingActive {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            videoRecorder.appendVideoImage(processed, at: pts)
        }
    }
}
