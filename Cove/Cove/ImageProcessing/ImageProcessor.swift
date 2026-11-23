import CoreImage
import Foundation
import Metal
import Vision

/// Core Image processing pipeline for real-time camera preview and photo export.
final class ImageProcessor {
    let context: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let targetNeutralVector = CIVector(x: 6500, y: 0)

    // Reusable filter instances exclusively for the serial live-preview video output queue.
    private lazy var liveExposureFilter = CIFilter(name: "CIExposureAdjust")
    private lazy var liveColorControlsFilter = CIFilter(name: "CIColorControls")
    private lazy var liveHighlightShadowFilter = CIFilter(name: "CIHighlightShadowAdjust")
    private lazy var liveTemperatureFilter = CIFilter(name: "CITemperatureAndTint")
    private lazy var liveSharpenFilter = CIFilter(name: "CISharpenLuminance")

    // Reusable Vision & Core Image objects for real-time person segmentation.
    private let segmentationQueue = DispatchQueue(label: "com.studiokharis.cove.vision.segmentation", qos: .userInitiated)
    private let maskLock = NSLock()
    private var isSegmentingFrame = false
    private var latestMaskImage: CIImage?
    private lazy var sequenceHandler = VNSequenceRequestHandler()
    private lazy var segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .fast
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }()
    private lazy var maskBlurFilter = CIFilter(name: "CIGaussianBlur")
    private lazy var backgroundBlurFilter = CIFilter(name: "CIGaussianBlur")
    private lazy var blendWithMaskFilter = CIFilter(name: "CIBlendWithMask")

    init(metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        if let device = metalDevice {
            self.context = CIContext(mtlDevice: device)
        } else {
            self.context = CIContext(options: [.useSoftwareRenderer: false])
        }
    }

    /// Applies real-time person segmentation and virtual background (blur, green screen, or custom image)
    /// without blocking the 30fps video output queue. Vision segmentation runs asynchronously on its own queue
    /// while the GPU composites the latest mask at full frame rate.
    func applyVideoBackground(
        to inputImage: CIImage,
        pixelBuffer: CVPixelBuffer,
        mode: VideoBackgroundMode,
        blurRadius: Double,
        customBackgroundImage: CIImage?
    ) -> CIImage {
        guard mode != .off else {
            maskLock.lock()
            latestMaskImage = nil
            maskLock.unlock()
            return inputImage
        }

        scheduleAsyncSegmentationIfIdle(pixelBuffer: pixelBuffer)

        maskLock.lock()
        let rawMask = latestMaskImage
        maskLock.unlock()

        guard let rawMask = rawMask else {
            return inputImage
        }

        let extent = inputImage.extent
        let scaleX = extent.width / max(rawMask.extent.width, 1)
        let scaleY = extent.height / max(rawMask.extent.height, 1)
        var maskImage = rawMask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        if let maskBlur = maskBlurFilter {
            maskBlur.setValue(maskImage.clampedToExtent(), forKey: kCIInputImageKey)
            maskBlur.setValue(1.5, forKey: kCIInputRadiusKey)
            if let blurredMask = maskBlur.outputImage {
                maskImage = blurredMask.cropped(to: extent)
            }
        }

        let backgroundImage: CIImage
        switch mode {
        case .off:
            return inputImage

        case .blur:
            if let bgBlur = backgroundBlurFilter {
                // Downscale 4x before Gaussian blur and scale back up for ~16x faster GPU blur at 30fps.
                let downscale: CGFloat = 0.25
                let smallInput = inputImage
                    .transformed(by: CGAffineTransform(scaleX: downscale, y: downscale))
                    .clampedToExtent()
                bgBlur.setValue(smallInput, forKey: kCIInputImageKey)
                bgBlur.setValue(max(1.0, blurRadius * downscale), forKey: kCIInputRadiusKey)
                if let blurredSmall = bgBlur.outputImage {
                    let upscale = 1.0 / downscale
                    backgroundImage = blurredSmall
                        .transformed(by: CGAffineTransform(scaleX: upscale, y: upscale))
                        .cropped(to: extent)
                } else {
                    backgroundImage = inputImage
                }
            } else {
                backgroundImage = inputImage
            }

        case .greenScreen:
            backgroundImage = CIImage(color: CIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))
                .cropped(to: extent)

        case .customImage:
            if let custom = customBackgroundImage, custom.extent.width > 0, custom.extent.height > 0 {
                let fillScale = max(extent.width / custom.extent.width, extent.height / custom.extent.height)
                let scaledWidth = custom.extent.width * fillScale
                let scaledHeight = custom.extent.height * fillScale
                let offsetX = extent.minX + (extent.width - scaledWidth) / 2.0
                let offsetY = extent.minY + (extent.height - scaledHeight) / 2.0
                let transform = CGAffineTransform(translationX: -custom.extent.minX, y: -custom.extent.minY)
                    .scaledBy(x: fillScale, y: fillScale)
                    .translatedBy(x: offsetX / fillScale, y: offsetY / fillScale)
                backgroundImage = custom.transformed(by: transform).cropped(to: extent)
            } else {
                backgroundImage = CIImage(color: CIColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1.0))
                    .cropped(to: extent)
            }
        }

        guard let blendFilter = blendWithMaskFilter else { return inputImage }
        blendFilter.setValue(inputImage, forKey: kCIInputImageKey)
        blendFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)
        return (blendFilter.outputImage ?? inputImage).cropped(to: extent)
    }

    private func scheduleAsyncSegmentationIfIdle(pixelBuffer: CVPixelBuffer) {
        maskLock.lock()
        if isSegmentingFrame {
            maskLock.unlock()
            return
        }
        isSegmentingFrame = true
        maskLock.unlock()

        segmentationQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                self.maskLock.lock()
                self.isSegmentingFrame = false
                self.maskLock.unlock()
            }

            do {
                try self.sequenceHandler.perform([self.segmentationRequest], on: pixelBuffer)
                if let maskPixelBuffer = self.segmentationRequest.results?.first?.pixelBuffer {
                    let maskCI = CIImage(cvPixelBuffer: maskPixelBuffer)
                    self.maskLock.lock()
                    self.latestMaskImage = maskCI
                    self.maskLock.unlock()
                }
            } catch {
                // Keep previous mask on transient Vision failure.
            }
        }
    }

    /// Low-allocation pipeline for real-time 30fps preview on the serial video output queue.
    func applyForLivePreview(
        to input: CIImage,
        adjustments: AdjustmentState,
        isMirrored: Bool = false,
        targetAspectRatio: CGFloat? = nil
    ) -> CIImage {
        applyInternal(
            to: input,
            adjustments: adjustments,
            isMirrored: isMirrored,
            targetAspectRatio: targetAspectRatio,
            reuseLiveFilters: true
        )
    }

    /// Thread-safe Core Image pipeline for still photo capture, gallery preview, and export.
    func apply(
        to input: CIImage,
        adjustments: AdjustmentState,
        isMirrored: Bool = false,
        targetAspectRatio: CGFloat? = nil
    ) -> CIImage {
        applyInternal(
            to: input,
            adjustments: adjustments,
            isMirrored: isMirrored,
            targetAspectRatio: targetAspectRatio,
            reuseLiveFilters: false
        )
    }

    private func applyInternal(
        to input: CIImage,
        adjustments: AdjustmentState,
        isMirrored: Bool,
        targetAspectRatio: CGFloat?,
        reuseLiveFilters: Bool
    ) -> CIImage {
        guard !adjustments.isIdentity || isMirrored || targetAspectRatio != nil else { return input }

        var output = input

        if abs(adjustments.exposure) >= 0.001,
           let filter = reuseLiveFilters ? liveExposureFilter : CIFilter(name: "CIExposureAdjust") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(adjustments.exposure, forKey: kCIInputEVKey)
            if let result = filter.outputImage {
                output = result
            }
        }

        if abs(adjustments.brightness) >= 0.001
            || abs(adjustments.contrast - 1.0) >= 0.001
            || abs(adjustments.saturation - 1.0) >= 0.001,
           let filter = reuseLiveFilters ? liveColorControlsFilter : CIFilter(name: "CIColorControls") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(adjustments.brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(adjustments.contrast, forKey: kCIInputContrastKey)
            filter.setValue(adjustments.saturation, forKey: kCIInputSaturationKey)
            if let result = filter.outputImage {
                output = result
            }
        }

        if abs(adjustments.highlights - 1.0) >= 0.001 || abs(adjustments.shadows) >= 0.001,
           let filter = reuseLiveFilters ? liveHighlightShadowFilter : CIFilter(name: "CIHighlightShadowAdjust") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(adjustments.highlights, forKey: "inputHighlightAmount")
            filter.setValue(adjustments.shadows, forKey: "inputShadowAmount")
            if let result = filter.outputImage {
                output = result
            }
        }

        if abs(adjustments.temperature - 6500.0) >= 1.0 || abs(adjustments.tint) >= 0.01,
           let filter = reuseLiveFilters ? liveTemperatureFilter : CIFilter(name: "CITemperatureAndTint") {
            filter.setValue(output, forKey: kCIInputImageKey)
            // Higher inputNeutral Kelvin warms the image; lower inputNeutral Kelvin cools (blue) the image.
            filter.setValue(CIVector(x: adjustments.temperature, y: adjustments.tint), forKey: "inputNeutral")
            filter.setValue(targetNeutralVector, forKey: "inputTargetNeutral")
            if let result = filter.outputImage {
                output = result
            }
        }

        if adjustments.sharpness >= 0.01,
           let filter = reuseLiveFilters ? liveSharpenFilter : CIFilter(name: "CISharpenLuminance") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(adjustments.sharpness, forKey: kCIInputSharpnessKey)
            if let result = filter.outputImage {
                output = result.cropped(to: input.extent)
            }
        }

        if isMirrored {
            let mirrorTransform = CGAffineTransform(translationX: input.extent.maxX + input.extent.minX, y: 0)
                .scaledBy(x: -1, y: 1)
            output = output.transformed(by: mirrorTransform)
        }

        var finalExtent = input.extent
        if let ratio = targetAspectRatio, ratio > 0 {
            finalExtent = centerCropRect(for: input.extent, aspectRatio: ratio)
        }

        return output.cropped(to: finalExtent)
    }

    private func centerCropRect(for extent: CGRect, aspectRatio: CGFloat) -> CGRect {
        guard extent.width > 0, extent.height > 0 else { return extent }
        let currentRatio = extent.width / extent.height
        let cropWidth: CGFloat
        let cropHeight: CGFloat
        if currentRatio > aspectRatio {
            cropHeight = extent.height
            cropWidth = cropHeight * aspectRatio
        } else {
            cropWidth = extent.width
            cropHeight = cropWidth / aspectRatio
        }
        let originX = extent.midX - cropWidth / 2
        let originY = extent.midY - cropHeight / 2
        return CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight).integral
    }

    /// Processes captured photo data with active adjustments, mirror, and optional aspect crop.
    func renderProcessedPhotoData(
        from originalData: Data,
        adjustments: AdjustmentState,
        isMirrored: Bool = false,
        targetAspectRatio: CGFloat? = nil,
        format: CaptureConfiguration.PhotoFormat
    ) -> Data? {
        guard !adjustments.isIdentity || isMirrored || targetAspectRatio != nil else { return originalData }
        guard let ciImage = CIImage(data: originalData, options: [.applyOrientationProperty: true]) else {
            return nil
        }

        let processed = apply(
            to: ciImage,
            adjustments: adjustments,
            isMirrored: isMirrored,
            targetAspectRatio: targetAspectRatio
        )

        switch format {
        case .heif:
            if let heif = context.heifRepresentation(
                of: processed,
                format: .RGBA8,
                colorSpace: colorSpace,
                options: [:]
            ) {
                return heif
            }
            return context.jpegRepresentation(of: processed, colorSpace: colorSpace, options: [:])
        case .jpeg:
            return context.jpegRepresentation(of: processed, colorSpace: colorSpace, options: [:])
        }
    }
}
