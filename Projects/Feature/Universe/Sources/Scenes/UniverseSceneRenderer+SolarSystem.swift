import SpriteKit

extension UniverseSceneRenderer {

    // MARK: - Setup

    func setupSolarSystem() {
        let ws = UniverseSceneFeature.CameraState.worldSize
        let center = CGPoint(x: ws.width / 2, y: ws.height / 2 + 200)

        let container = SKNode()
        container.position = center
        container.zPosition = 8
        container.name = "sunNode"

        if let sunImage = UIImage(named: "Sun") {
            let sprite = SKSpriteNode(
                texture: SKTexture(image: sunImage),
                size: CGSize(width: 64, height: 64)
            )
            sprite.zPosition = 2
            sprite.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 120)))
            container.addChild(sprite)
        }

        addChild(container)
        sunNode = container

        let orbitSystem = SKNode()
        orbitSystem.position = center
        orbitSystem.zPosition = 7
        orbitSystem.zRotation = 0.25
        addChild(orbitSystem)

        let ellipseRatio: CGFloat = 0.45
        let tiltAngle: CGFloat = 0.25

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
            let orbitPath = SKShapeNode(ellipseOf: CGSize(
                width: planet.orbit * 2,
                height: planet.orbit * ellipseRatio * 2
            ))
            orbitPath.strokeColor = UIColor(white: 1, alpha: 0.03)
            orbitPath.fillColor = .clear
            orbitPath.lineWidth = 0.5
            orbitSystem.addChild(orbitPath)

            let startAngle = CGFloat.random(in: 0...(2 * .pi))

            let planetNode = SKNode()
            planetNode.position = CGPoint(
                x: planet.orbit * cos(startAngle),
                y: planet.orbit * ellipseRatio * sin(startAngle)
            )

            if let img = UIImage(named: planet.image) {
                let sprite = SKSpriteNode(
                    texture: SKTexture(image: img),
                    size: CGSize(width: planet.size, height: planet.size)
                )
                sprite.name = "planetSprite_\(planet.name)"
                sprite.zRotation = -tiltAngle
                planetNode.addChild(sprite)
            }

            orbitSystem.addChild(planetNode)

            planetOrbits.append(PlanetOrbitData(
                node: planetNode,
                orbit: planet.orbit,
                ellipseRatio: ellipseRatio,
                period: planet.period,
                startAngle: startAngle
            ))
        }
    }

    // MARK: - Update Orbits (called every frame)

    func updatePlanetOrbits(deltaTime: TimeInterval) {
        planetElapsedTime += deltaTime
        for data in planetOrbits {
            let angle = data.startAngle + CGFloat(planetElapsedTime / data.period) * .pi * 2
            data.node.position = CGPoint(
                x: data.orbit * cos(angle),
                y: data.orbit * data.ellipseRatio * sin(angle)
            )
        }
    }
}
