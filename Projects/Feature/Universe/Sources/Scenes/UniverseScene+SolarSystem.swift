import SpriteKit

extension UniverseScene {

    // MARK: - Solar System (Decorative)

    func setupSun() {
        let center = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2 + 200)

        let container = SKNode()
        container.position = center
        container.zPosition = 8
        container.name = "sunNode"

        // Sun image
        if let sunImage = UIImage(named: "Sun") {
            let sprite = SKSpriteNode(texture: SKTexture(image: sunImage),
                                      size: CGSize(width: 64, height: 64))
            sprite.zPosition = 2
            sprite.run(SKAction.repeatForever(
                SKAction.rotate(byAngle: .pi * 2, duration: 120)))
            container.addChild(sprite)
        }

        addChild(container)
        sunNode = container

        // 궤도 시스템 — yScale 압축 없이 타원 궤도 직접 계산 (행성 찌그러짐 방지)
        let orbitSystem = SKNode()
        orbitSystem.position = center
        orbitSystem.zPosition = 7
        orbitSystem.zRotation = 0.25  // ~14° tilt (3D 느낌)
        addChild(orbitSystem)

        let ellipseRatio: CGFloat = 0.45  // y축 비율 (타원형)
        let tiltAngle: CGFloat = 0.25     // orbitSystem의 회전과 동일

        // Planet definitions (자전 없음, 공전만)
        let planets: [(name: String, image: String, size: CGFloat, orbit: CGFloat, period: TimeInterval)] = [
            ("mercury", "Mercury",   8,   80,  14),
            ("venus",   "Venus",    13,  120,  22),
            ("earth",   "Earth",    14,  165,  30),
            ("mars",    "Mars",     10,  210,  42),
            ("jupiter", "Jupiter",  28,  300,  65),
            ("saturn",  "Saturn",   24,  390,  85),
            ("uranus",  "Uranus",   18,  475, 110),
            ("neptune", "Neptune",  16,  550, 140),
        ]

        for planet in planets {
            // 타원 궤도 경로 (직접 그리기)
            let orbitPath = SKShapeNode(ellipseOf: CGSize(width: planet.orbit * 2,
                                                          height: planet.orbit * ellipseRatio * 2))
            orbitPath.strokeColor = UIColor(white: 1, alpha: 0.03)
            orbitPath.fillColor = .clear
            orbitPath.lineWidth = 0.5
            orbitSystem.addChild(orbitPath)

            let startAngle = CGFloat.random(in: 0...(2 * .pi))

            let planetNode = SKNode()
            planetNode.position = CGPoint(x: planet.orbit * cos(startAngle),
                                          y: planet.orbit * ellipseRatio * sin(startAngle))

            if let img = UIImage(named: planet.image) {
                let sprite = SKSpriteNode(texture: SKTexture(image: img),
                                          size: CGSize(width: planet.size, height: planet.size))
                sprite.name = "planetSprite_\(planet.name)"
                // 부모 회전 상쇄하여 행성이 항상 똑바로 보이게
                sprite.zRotation = -tiltAngle
                planetNode.addChild(sprite)
            }

            orbitSystem.addChild(planetNode)

            // update()에서 위치 갱신 (customAction 반복 경계 끊김 방지)
            planetOrbits.append(PlanetOrbitData(
                node: planetNode,
                orbit: planet.orbit,
                ellipseRatio: ellipseRatio,
                period: planet.period,
                startAngle: startAngle
            ))
        }
    }
}
