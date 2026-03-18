import SpriteKit

extension UniverseScene {

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

    // MARK: - Nebulae (다층 그라디언트 — 유기적 형태)

    func setupNebulae() {
        let data: [(p: CGPoint, w: CGFloat, h: CGFloat, c: UIColor, a: CGFloat)] = [
            (CGPoint(x: 500, y: 3500), 600, 420, UIColor(red: 0.345, green: 0.11, blue: 0.53, alpha: 1), 0.20),
            (CGPoint(x: 3000, y: 1200), 680, 500, UIColor(red: 0.118, green: 0.227, blue: 0.541, alpha: 1), 0.18),
            (CGPoint(x: 1500, y: 2700), 520, 380, UIColor(red: 0.49, green: 0.827, blue: 0.988, alpha: 1), 0.12),
            (CGPoint(x: 1000, y: 800), 480, 340, UIColor(red: 0.976, green: 0.659, blue: 0.831, alpha: 1), 0.15),
            (CGPoint(x: 2500, y: 3700), 440, 320, UIColor(red: 0.369, green: 0.918, blue: 0.824, alpha: 1), 0.12),
            (CGPoint(x: 1800, y: 1500), 400, 380, UIColor(red: 0.769, green: 0.710, blue: 0.992, alpha: 1), 0.10),
            (CGPoint(x: 3500, y: 2800), 560, 380, UIColor(red: 0.2, green: 0.15, blue: 0.45, alpha: 1), 0.16),
            (CGPoint(x: 700, y: 1600), 440, 300, UIColor(red: 0.1, green: 0.3, blue: 0.5, alpha: 1), 0.13),
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

    // MARK: - Bright Stars (GPU 셰이더: 렌즈 플레어 + 회절 스파이크 + 색수차)

    func setupBrightStars() {
        let stars: [(p: CGPoint, r: CGFloat, c: UIColor)] = [
            (CGPoint(x: 1600, y: 3600), 30, UIColor(red: 0.49, green: 0.827, blue: 0.988, alpha: 1)),
            (CGPoint(x: 3200, y: 2500), 36, UIColor(red: 0.976, green: 0.659, blue: 0.831, alpha: 1)),
            (CGPoint(x: 400, y: 3200), 26, UIColor(red: 0.49, green: 0.827, blue: 0.988, alpha: 1)),
            (CGPoint(x: 3600, y: 900), 22, UIColor(red: 0.369, green: 0.918, blue: 0.824, alpha: 1)),
            (CGPoint(x: 2200, y: 3300), 30, UIColor(red: 0.769, green: 0.710, blue: 0.992, alpha: 1)),
            (CGPoint(x: 2800, y: 1800), 18, UIColor.white),
            (CGPoint(x: 900, y: 3700), 18, UIColor(red: 0.49, green: 0.827, blue: 0.988, alpha: 1)),
            (CGPoint(x: 1200, y: 2200), 14, UIColor(red: 0.976, green: 0.82, blue: 0.65, alpha: 1)),
            (CGPoint(x: 3400, y: 1600), 16, UIColor(red: 0.85, green: 0.85, blue: 1.0, alpha: 1)),
            (CGPoint(x: 700, y: 1200), 12, UIColor(red: 0.95, green: 0.9, blue: 0.75, alpha: 1)),
        ]
        for d in stars {
            let sz = d.r * 2
            let sprite = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
            sprite.position = d.p; sprite.zPosition = 1
            sprite.shader = starShader
            sprite.blendMode = .add

            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
            d.c.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
            sprite.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(cr), Float(cg), Float(cb), 1)),
                            forAttribute: "a_color")
            addChild(sprite)
        }
    }

    // MARK: - Distant Tiny Galaxies

    func setupDistantGalaxies() {
        let data: [(p: CGPoint, s: CGSize, c: UIColor, r: CGFloat, a: CGFloat)] = [
            (CGPoint(x: 800, y: 3800), CGSize(width: 12, height: 7), UIColor(red: 0.78, green: 0.74, blue: 1, alpha: 1), .pi / 6, 0.12),
            (CGPoint(x: 1600, y: 3400), CGSize(width: 10, height: 6), UIColor(red: 1, green: 0.78, blue: 0.7, alpha: 1), -.pi / 12, 0.10),
            (CGPoint(x: 3800, y: 1200), CGSize(width: 8, height: 5), UIColor(red: 0.7, green: 0.86, blue: 1, alpha: 1), .pi / 4, 0.08),
            (CGPoint(x: 3400, y: 3700), CGSize(width: 11, height: 6), UIColor(red: 1, green: 0.7, blue: 0.78, alpha: 1), .pi / 3, 0.10),
            (CGPoint(x: 3600, y: 200), CGSize(width: 9, height: 5), UIColor(red: 0.7, green: 1, blue: 0.9, alpha: 1), -.pi / 6, 0.09),
            (CGPoint(x: 200, y: 600), CGSize(width: 10, height: 6), UIColor(red: 0.85, green: 0.8, blue: 1, alpha: 1), .pi / 5, 0.08),
            (CGPoint(x: 2600, y: 500), CGSize(width: 8, height: 5), UIColor(red: 1, green: 0.85, blue: 0.75, alpha: 1), -.pi / 8, 0.07),
            (CGPoint(x: 3200, y: 2000), CGSize(width: 13, height: 7), UIColor(red: 0.75, green: 0.85, blue: 1, alpha: 1), .pi / 4, 0.11),
        ]
        for d in data {
            let g = SKShapeNode(ellipseOf: d.s)
            g.fillColor = d.c; g.strokeColor = .clear
            g.position = d.p; g.zRotation = d.r; g.alpha = d.a; g.zPosition = -3; g.glowWidth = 3
            addChild(g)
        }
    }
}
