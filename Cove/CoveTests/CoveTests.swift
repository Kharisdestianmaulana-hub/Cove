import CoreImage
import XCTest
@testable import Cove

final class CoveTests: XCTestCase {

    func testAdjustmentStateIdentityAndReset() {
        var state = AdjustmentState()
        XCTAssertTrue(state.isIdentity)

        state.contrast = 1.2
        XCTAssertFalse(state.isIdentity)

        state = AdjustmentState()
        XCTAssertTrue(state.isIdentity)
    }

    func testLookPresetAdjustments() {
        XCTAssertTrue(LookPreset.natural.adjustments.isIdentity)
        XCTAssertLessThan(LookPreset.cool.adjustments.temperature, 6500)
        XCTAssertGreaterThan(LookPreset.warm.adjustments.temperature, 6500)
        XCTAssertEqual(LookPreset.mono.adjustments.saturation, 0.0, accuracy: 0.001)
    }

    func testImageProcessorIdentityMirrorAndAspectCrop() {
        let processor = ImageProcessor(metalDevice: nil)
        let extent = CGRect(x: 0, y: 0, width: 160, height: 90)
        let sample = CIImage(color: .red).cropped(to: extent)

        let unchanged = processor.apply(to: sample, adjustments: AdjustmentState(), isMirrored: false)
        XCTAssertEqual(unchanged.extent, extent)

        let mirrored = processor.apply(to: sample, adjustments: AdjustmentState(), isMirrored: true)
        XCTAssertEqual(mirrored.extent, extent)

        let squareCropped = processor.apply(
            to: sample,
            adjustments: AdjustmentState(),
            isMirrored: false,
            targetAspectRatio: 1.0
        )
        XCTAssertEqual(squareCropped.extent.width, 90, accuracy: 1.0)
        XCTAssertEqual(squareCropped.extent.height, 90, accuracy: 1.0)
    }

    func testCustomPresetCodableRoundTrip() throws {
        let adjustments = AdjustmentState(brightness: 0.1, contrast: 1.15, temperature: 5200)
        let preset = CustomPreset(name: "Studio Cool", adjustments: adjustments)

        let encoded = try JSONEncoder().encode([preset])
        let decoded = try JSONDecoder().decode([CustomPreset].self, from: encoded)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.name, "Studio Cool")
        XCTAssertEqual(decoded.first?.adjustments, adjustments)
    }
}
