import SwiftUI

/// Renders non-destructive composition guides and aspect ratio framing overlays above the live preview.
struct CompositionOverlayView: View {
    let guide: CompositionGuide
    let aspectRatio: PreviewAspectRatio

    var body: some View {
        GeometryReader { geometry in
            let activeRect = framedRect(in: geometry.size)

            ZStack {
                if aspectRatio != .defaultRatio {
                    aspectMask(in: geometry.size, activeRect: activeRect)
                }

                guideLines(in: activeRect)
            }
        }
        .allowsHitTesting(false)
    }

    private func framedRect(in size: CGSize) -> CGRect {
        guard let targetRatio = aspectRatio.numericRatio, size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }

        let currentRatio = size.width / size.height
        let frameSize: CGSize
        if currentRatio > targetRatio {
            frameSize = CGSize(width: size.height * targetRatio, height: size.height)
        } else {
            frameSize = CGSize(width: size.width, height: size.width / targetRatio)
        }

        let origin = CGPoint(
            x: (size.width - frameSize.width) / 2,
            y: (size.height - frameSize.height) / 2
        )
        return CGRect(origin: origin, size: frameSize)
    }

    @ViewBuilder
    private func aspectMask(in containerSize: CGSize, activeRect: CGRect) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: containerSize))
            path.addRect(activeRect)
        }
        .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))

        Rectangle()
            .stroke(Color.white.opacity(0.32), lineWidth: 1)
            .frame(width: activeRect.width, height: activeRect.height)
            .position(x: activeRect.midX, y: activeRect.midY)
    }

    @ViewBuilder
    private func guideLines(in rect: CGRect) -> some View {
        switch guide {
        case .none:
            EmptyView()

        case .ruleOfThirds:
            gridPath(in: rect, divisions: 3)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)

        case .squareGrid:
            gridPath(in: rect, divisions: 4)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)

        case .centerCrosshair:
            Path { path in
                let arm: CGFloat = 14
                path.move(to: CGPoint(x: rect.midX - arm, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.midX + arm, y: rect.midY))
                path.move(to: CGPoint(x: rect.midX, y: rect.midY - arm))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.midY + arm))
            }
            .stroke(Color.white.opacity(0.55), lineWidth: 1.25)
        }
    }

    private func gridPath(in rect: CGRect, divisions: Int) -> Path {
        Path { path in
            guard divisions > 1 else { return }
            for index in 1..<divisions {
                let fraction = CGFloat(index) / CGFloat(divisions)
                let x = rect.minX + rect.width * fraction
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))

                let y = rect.minY + rect.height * fraction
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
    }
}
