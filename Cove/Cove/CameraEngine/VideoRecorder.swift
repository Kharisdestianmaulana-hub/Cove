import AVFoundation
import CoreImage
import Foundation

/// Records processed CIImage video frames and optional audio sample buffers using AVAssetWriter.
final class VideoRecorder {
    private let ciContext: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let writerQueue = DispatchQueue(label: "com.studiokharis.cove.video.writer", qos: .userInitiated)

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?

    private var outputURL: URL?
    private var hasStartedSession = false
    private(set) var isRecording = false

    init(ciContext: CIContext) {
        self.ciContext = ciContext
    }

    func start(
        outputURL: URL,
        width: Int,
        height: Int,
        includeAudio: Bool,
        audioSettings: [String: Any]? = nil,
        onStarted: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        writerQueue.async { [weak self] in
            guard let self = self, !self.isRecording else { return }

            do {
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }

                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height
                ]
                let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                vInput.expectsMediaDataInRealTime = true

                let adaptorAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height
                ]
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: vInput,
                    sourcePixelBufferAttributes: adaptorAttributes
                )

                guard writer.canAdd(vInput) else {
                    throw NSError(
                        domain: "com.studiokharis.cove.recorder",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot attach video writer input."]
                    )
                }
                writer.add(vInput)

                var aInput: AVAssetWriterInput?
                if includeAudio {
                    let resolvedAudioSettings: [String: Any] = audioSettings ?? [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVNumberOfChannelsKey: 1,
                        AVSampleRateKey: 48000,
                        AVEncoderBitRateKey: 128000
                    ]
                    let input = AVAssetWriterInput(mediaType: .audio, outputSettings: resolvedAudioSettings)
                    input.expectsMediaDataInRealTime = true
                    if writer.canAdd(input) {
                        writer.add(input)
                        aInput = input
                    }
                }

                guard writer.startWriting() else {
                    throw writer.error ?? NSError(
                        domain: "com.studiokharis.cove.recorder",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to start AVAssetWriter."]
                    )
                }

                self.assetWriter = writer
                self.videoInput = vInput
                self.pixelBufferAdaptor = adaptor
                self.audioInput = aInput
                self.outputURL = outputURL
                self.hasStartedSession = false
                self.isRecording = true

                DispatchQueue.main.async {
                    onStarted()
                }
            } catch {
                self.resetState()
                DispatchQueue.main.async {
                    onError(error)
                }
            }
        }
    }

    private let renderStateLock = NSLock()
    private var isRenderingVideoFrame = false

    func appendVideoImage(_ image: CIImage, at presentationTime: CMTime) {
        renderStateLock.lock()
        if isRenderingVideoFrame {
            renderStateLock.unlock()
            return
        }
        isRenderingVideoFrame = true
        renderStateLock.unlock()

        writerQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                self.renderStateLock.lock()
                self.isRenderingVideoFrame = false
                self.renderStateLock.unlock()
            }

            guard self.isRecording,
                  let writer = self.assetWriter,
                  let vInput = self.videoInput,
                  let adaptor = self.pixelBufferAdaptor,
                  writer.status == .writing else {
                return
            }

            if !self.hasStartedSession {
                writer.startSession(atSourceTime: presentationTime)
                self.hasStartedSession = true
            }

            guard vInput.isReadyForMoreMediaData,
                  let pool = adaptor.pixelBufferPool else {
                return
            }

            var pixelBufferOut: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBufferOut)
            guard status == kCVReturnSuccess, let buffer = pixelBufferOut else {
                return
            }

            let bounds = CGRect(
                x: 0,
                y: 0,
                width: CVPixelBufferGetWidth(buffer),
                height: CVPixelBufferGetHeight(buffer)
            )
            self.ciContext.render(image, to: buffer, bounds: bounds, colorSpace: self.colorSpace)
            adaptor.append(buffer, withPresentationTime: presentationTime)
        }
    }

    func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        writerQueue.async { [weak self] in
            guard let self = self,
                  self.isRecording,
                  self.hasStartedSession,
                  let writer = self.assetWriter,
                  let aInput = self.audioInput,
                  writer.status == .writing,
                  aInput.isReadyForMoreMediaData else {
                return
            }
            aInput.append(sampleBuffer)
        }
    }

    func finish(completion: @escaping (Result<URL, Error>) -> Void) {
        writerQueue.async { [weak self] in
            guard let self = self,
                  self.isRecording,
                  let writer = self.assetWriter,
                  let url = self.outputURL else {
                return
            }

            self.isRecording = false
            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()

            writer.finishWriting { [weak self] in
                let error = writer.error
                let status = writer.status
                self?.resetState()

                DispatchQueue.main.async {
                    if status == .completed {
                        completion(.success(url))
                    } else {
                        completion(.failure(error ?? NSError(
                            domain: "com.studiokharis.cove.recorder",
                            code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "Video recording did not complete cleanly."]
                        )))
                    }
                }
            }
        }
    }

    private func resetState() {
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        audioInput = nil
        outputURL = nil
        hasStartedSession = false
        isRecording = false
    }
}
