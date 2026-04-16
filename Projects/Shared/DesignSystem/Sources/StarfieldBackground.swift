import SwiftUI
import SharedUtil

public struct StarfieldBackground: View {
    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    private let stars: [Star] = {
        var rng = SplitMix64(seed: 42)
        return (0..<120).map { _ in
            Star(
                x: CGFloat.random(in: 0...1, using: &rng),
                y: CGFloat.random(in: 0...1, using: &rng),
                size: CGFloat.random(in: 0.5...2.0, using: &rng),
                opacity: Double.random(in: 0.1...0.6, using: &rng)
            )
        }
    }()

    public init() {}

    public var body: some View {
        Canvas { ctx, size in
            for star in stars {
                let point = CGPoint(x: star.x * size.width, y: star.y * size.height)
                let rect = CGRect(
                    x: point.x - star.size / 2,
                    y: point.y - star.size / 2,
                    width: star.size,
                    height: star.size
                )
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.opacity)))

                // 밝은 별에 작은 glow 추가
                if star.opacity > 0.35 {
                    let glowR = star.size * 3
                    let glowRect = CGRect(
                        x: point.x - glowR / 2,
                        y: point.y - glowR / 2,
                        width: glowR,
                        height: glowR
                    )
                    let grad = Gradient(colors: [
                        .white.opacity(star.opacity * 0.3),
                        .clear
                    ])
                    ctx.fill(
                        Path(ellipseIn: glowRect),
                        with: .radialGradient(grad, center: point, startRadius: 0, endRadius: glowR / 2)
                    )
                }
            }
        }
        .drawingGroup()
    }
}
