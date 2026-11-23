import CoreImage
import MetalKit
import SwiftUI

/// Thread-safe Metal renderer that pulls the latest CIImage on MTKView's display link without flooding the main thread.
final class MetalFrameRenderer: NSObject, MTKViewDelegate {
    private let ciContext: CIContext
    private let commandQueue: MTLCommandQueue?
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let frameLock = NSLock()
    private var latestImage: CIImage?
    private var latestFrameID: UInt64 = 0
    private var lastRenderedFrameID: UInt64 = 0

    init(metalDevice: MTLDevice?, ciContext: CIContext) {
        self.ciContext = ciContext
        self.commandQueue = metalDevice?.makeCommandQueue()
        super.init()
    }

    func enqueue(image: CIImage) {
        frameLock.lock()
        latestImage = image
        latestFrameID &+= 1
        frameLock.unlock()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        frameLock.lock()
        let image = latestImage
        let frameID = latestFrameID
        frameLock.unlock()

        guard let image = image,
              frameID != lastRenderedFrameID,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let drawable = view.currentDrawable else {
            return
        }

        let drawableSize = view.drawableSize
        guard drawableSize.width > 0, drawableSize.height > 0,
              image.extent.width > 0, image.extent.height > 0 else {
            return
        }

        lastRenderedFrameID = frameID

        // Aspect-fit scaling centered inside the MTKView drawable.
        let scale = min(drawableSize.width / image.extent.width, drawableSize.height / image.extent.height)
        let scaledWidth = image.extent.width * scale
        let scaledHeight = image.extent.height * scale
        let offsetX = (drawableSize.width - scaledWidth) / 2.0
        let offsetY = (drawableSize.height - scaledHeight) / 2.0

        let transform = CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: offsetX / scale, y: offsetY / scale)

        let transformedImage = image.transformed(by: transform)

        // Clear the drawable in hardware via an empty render pass instead of compositing a full-screen CIImage.
        if let passDescriptor = view.currentRenderPassDescriptor,
           let clearEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) {
            clearEncoder.endEncoding()
        }

        ciContext.render(
            transformedImage,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: CGRect(origin: .zero, size: drawableSize),
            colorSpace: colorSpace
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

/// SwiftUI wrapper around MTKView for smooth real-time Core Image camera preview.
struct MetalPreviewView: NSViewRepresentable {
    let renderer: MetalFrameRenderer
    let metalDevice: MTLDevice?

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: metalDevice)
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 30
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.delegate = renderer
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        if nsView.delegate !== renderer {
            nsView.delegate = renderer
        }
    }
}
