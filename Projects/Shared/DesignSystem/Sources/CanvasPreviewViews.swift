import SwiftUI
import DomainEntity

public struct GalaxyPreview: View {
    let color: Color
    var arms: Int = 3

    public init(color: Color, arms: Int = 3) {
        self.color = color
        self.arms = arms
    }

    public var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2, cy = size.height / 2
            let maxR = min(cx, cy)

            let glowGrad = Gradient(colors: [color.opacity(0.35), color.opacity(0.08), .clear])
            ctx.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)),
                     with: .radialGradient(glowGrad, center: CGPoint(x: cx, y: cy),
                                           startRadius: 0, endRadius: maxR))

            let armCount = max(2, arms)
            for arm in 0..<armCount {
                let baseAngle = CGFloat(arm) * (.pi * 2 / CGFloat(armCount))
                var path = Path()
                for step in 0..<40 {
                    let t = CGFloat(step) / 39.0
                    let r = t * maxR * 0.85
                    let angle = baseAngle + t * 2.5
                    let x = cx + r * cos(angle)
                    let y = cy + r * sin(angle) * 0.65
                    if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(path, with: .color(color.opacity(0.5 - Double(arm) * 0.05)),
                           lineWidth: 1.5)
            }

            let coreGrad = Gradient(colors: [.white.opacity(0.9), color.opacity(0.7), .clear])
            ctx.fill(Path(ellipseIn: CGRect(x: cx - maxR * 0.2, y: cy - maxR * 0.2,
                                             width: maxR * 0.4, height: maxR * 0.4)),
                     with: .radialGradient(coreGrad, center: CGPoint(x: cx, y: cy),
                                           startRadius: 0, endRadius: maxR * 0.2))
        }
        .frame(width: 40, height: 40)
        .drawingGroup()
    }
}

public struct StarPreview: View {
    let color: Color

    public init(color: Color) {
        self.color = color
    }

    public var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2, cy = size.height / 2
            let maxR = min(cx, cy)

            let outerGrad = Gradient(colors: [color.opacity(0.4), color.opacity(0.1), .clear])
            ctx.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)),
                     with: .radialGradient(outerGrad, center: CGPoint(x: cx, y: cy),
                                           startRadius: 0, endRadius: maxR))

            for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 2) {
                var spike = Path()
                spike.move(to: CGPoint(x: cx, y: cy))
                let len = maxR * 0.85
                spike.addLine(to: CGPoint(x: cx + len * cos(angle), y: cy + len * sin(angle)))
                ctx.stroke(spike, with: .color(color.opacity(0.35)), lineWidth: 0.8)
            }

            let coreGrad = Gradient(colors: [.white, color.opacity(0.9), .clear])
            let coreR = maxR * 0.3
            ctx.fill(Path(ellipseIn: CGRect(x: cx - coreR, y: cy - coreR,
                                             width: coreR * 2, height: coreR * 2)),
                     with: .radialGradient(coreGrad, center: CGPoint(x: cx, y: cy),
                                           startRadius: 0, endRadius: coreR))
        }
        .frame(width: 36, height: 36)
        .drawingGroup()
    }
}
