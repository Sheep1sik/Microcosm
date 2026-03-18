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
    var seed: Double = 0

    public init(color: Color, seed: Double = 0) {
        self.color = color
        self.seed = seed
    }

    public var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let maxR = min(cx, cy)
            let center = CGPoint(x: cx, y: cy)
            let baseAngle = seed * .pi * 0.3

            drawHalo(&ctx, center: center, maxR: maxR)
            drawInnerGlow(&ctx, center: center, maxR: maxR)
            drawMainSpikes(&ctx, cx: cx, cy: cy, maxR: maxR, baseAngle: baseAngle)
            drawDiagonalSpikes(&ctx, cx: cx, cy: cy, maxR: maxR, baseAngle: baseAngle)
            drawAiryRing(&ctx, cx: cx, cy: cy, maxR: maxR)
            drawChromaticAberration(&ctx, cx: cx, cy: cy, maxR: maxR)
            drawCore(&ctx, center: center, maxR: maxR)
        }
        .frame(width: 36, height: 36)
        .drawingGroup()
    }

    private func drawHalo(_ ctx: inout GraphicsContext, center: CGPoint, maxR: CGFloat) {
        let grad = Gradient(colors: [
            color.opacity(0.25), color.opacity(0.12),
            color.opacity(0.04), Color.clear
        ])
        let rect = CGRect(
            x: center.x - maxR * 1.1, y: center.y - maxR * 0.9,
            width: maxR * 2.2, height: maxR * 1.8
        )
        ctx.fill(Path(ellipseIn: rect),
                 with: .radialGradient(grad, center: center, startRadius: 0, endRadius: maxR))
    }

    private func drawInnerGlow(_ ctx: inout GraphicsContext, center: CGPoint, maxR: CGFloat) {
        let grad = Gradient(colors: [color.opacity(0.5), color.opacity(0.2), Color.clear])
        let r = maxR * 0.5
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect),
                 with: .radialGradient(grad, center: center, startRadius: 0, endRadius: r))
    }

    private func drawMainSpikes(_ ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat, maxR: CGFloat, baseAngle: Double) {
        let len = maxR * 0.88
        for i in 0..<4 {
            let angle = CGFloat(baseAngle + Double(i) * (.pi / 2))
            var spike = Path()
            spike.move(to: CGPoint(x: cx, y: cy))
            spike.addLine(to: CGPoint(x: cx + len * cos(angle), y: cy + len * sin(angle)))
            ctx.stroke(spike, with: .color(color.opacity(0.4)), lineWidth: 1.0)
        }
    }

    private func drawDiagonalSpikes(_ ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat, maxR: CGFloat, baseAngle: Double) {
        let len = maxR * 0.5
        for i in 0..<4 {
            let angle = CGFloat(baseAngle + Double(i) * (.pi / 2) + .pi / 4)
            var spike = Path()
            spike.move(to: CGPoint(x: cx, y: cy))
            spike.addLine(to: CGPoint(x: cx + len * cos(angle), y: cy + len * sin(angle)))
            ctx.stroke(spike, with: .color(color.opacity(0.2)), lineWidth: 0.5)
        }
    }

    private func drawAiryRing(_ ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat, maxR: CGFloat) {
        let r = maxR * 0.45
        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        ctx.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.1)), lineWidth: 0.4)
    }

    private func drawChromaticAberration(_ ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat, maxR: CGFloat) {
        let r = maxR * 0.18
        let offset: CGFloat = 0.8

        let redGrad = Gradient(colors: [Color.red.opacity(0.15), Color.clear])
        let redRect = CGRect(x: cx - r + offset, y: cy - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: redRect),
                 with: .radialGradient(redGrad, center: CGPoint(x: cx + offset, y: cy), startRadius: 0, endRadius: r))

        let blueGrad = Gradient(colors: [Color.blue.opacity(0.12), Color.clear])
        let blueRect = CGRect(x: cx - r - offset, y: cy - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: blueRect),
                 with: .radialGradient(blueGrad, center: CGPoint(x: cx - offset, y: cy), startRadius: 0, endRadius: r))
    }

    private func drawCore(_ ctx: inout GraphicsContext, center: CGPoint, maxR: CGFloat) {
        let grad = Gradient(colors: [Color.white, Color.white.opacity(0.9), color.opacity(0.8), Color.clear])
        let r = maxR * 0.15
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect),
                 with: .radialGradient(grad, center: center, startRadius: 0, endRadius: r))
    }
}
