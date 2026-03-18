import SpriteKit

extension ConstellationScene {

    // MARK: - Dust Field (GPU 셰이더 별: 확대해도 영롱)

    func setupDustField() {
        let colors: [UIColor] = [
            .white,
            UIColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 1),
            UIColor(red: 0.9, green: 0.92, blue: 1.0, alpha: 1),
            UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1),
            UIColor(red: 1.0, green: 0.85, blue: 0.6, alpha: 1),
            UIColor(red: 0.85, green: 0.88, blue: 1.0, alpha: 1),
        ]
        for i in 0..<600 {
            let sz = CGFloat.random(in: 3...8)
            let sprite = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
            sprite.position = CGPoint(x: CGFloat.random(in: 0...worldSize.width),
                                      y: CGFloat.random(in: 0...worldSize.height))
            sprite.alpha = CGFloat.random(in: 0.06...0.3)
            sprite.zPosition = -5
            sprite.shader = starShader
            sprite.blendMode = .add

            let c = colors.randomElement()!
            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
            c.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
            sprite.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(cr), Float(cg), Float(cb), 1)),
                            forAttribute: "a_color")

            if i % 3 == 0 {
                sprite.run(SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: CGFloat.random(in: 0.03...0.1), duration: Double.random(in: 3...6)),
                    SKAction.fadeAlpha(to: CGFloat.random(in: 0.12...0.3), duration: Double.random(in: 3...6)),
                ])))
            }
            addChild(sprite)
        }
    }

    // MARK: - Nebulae (다층 그라디언트 — 별자리 탭 전용 색상/위치)

    func setupNebulae() {
        let data: [(p: CGPoint, w: CGFloat, h: CGFloat, c: UIColor, a: CGFloat)] = [
            (CGPoint(x: 600, y: 3400), 580, 400, UIColor(red: 0.20, green: 0.12, blue: 0.50, alpha: 1), 0.18),
            (CGPoint(x: 2800, y: 1400), 650, 480, UIColor(red: 0.10, green: 0.20, blue: 0.50, alpha: 1), 0.16),
            (CGPoint(x: 1400, y: 2600), 500, 360, UIColor(red: 0.30, green: 0.70, blue: 0.90, alpha: 1), 0.11),
            (CGPoint(x: 1100, y: 900), 460, 320, UIColor(red: 0.90, green: 0.55, blue: 0.75, alpha: 1), 0.14),
            (CGPoint(x: 2600, y: 3600), 420, 300, UIColor(red: 0.25, green: 0.80, blue: 0.72, alpha: 1), 0.11),
            (CGPoint(x: 1900, y: 1600), 380, 360, UIColor(red: 0.65, green: 0.60, blue: 0.92, alpha: 1), 0.09),
            (CGPoint(x: 3400, y: 2900), 540, 360, UIColor(red: 0.15, green: 0.12, blue: 0.40, alpha: 1), 0.15),
            (CGPoint(x: 800, y: 1700), 420, 280, UIColor(red: 0.08, green: 0.25, blue: 0.45, alpha: 1), 0.12),
        ]
        for d in data {
            let layerCount = Int.random(in: 3...5)
            for _ in 0..<layerCount {
                let sw = d.w * CGFloat.random(in: 0.5...1.2)
                let sh = d.h * CGFloat.random(in: 0.5...1.2)
                let sprite = SKSpriteNode(texture: nebulaTexture, size: CGSize(width: sw, height: sh))
                sprite.color = d.c
                sprite.colorBlendFactor = 1.0
                sprite.alpha = d.a * CGFloat.random(in: 0.4...0.7)
                sprite.position = CGPoint(
                    x: d.p.x + CGFloat.random(in: -d.w * 0.2...d.w * 0.2),
                    y: d.p.y + CGFloat.random(in: -d.h * 0.2...d.h * 0.2))
                sprite.zRotation = CGFloat.random(in: 0...(.pi * 2))
                sprite.zPosition = -4
                sprite.blendMode = .add
                sprite.run(SKAction.repeatForever(SKAction.sequence([
                    SKAction.moveBy(x: CGFloat.random(in: -8...8),
                                    y: CGFloat.random(in: -4...4), duration: 12),
                    SKAction.moveBy(x: CGFloat.random(in: -8...8),
                                    y: CGFloat.random(in: -4...4), duration: 12),
                ])))
                addChild(sprite)
            }
        }
    }

}
