import SpriteKit
import DomainEntity

extension UniverseScene {

    // MARK: - Birth Animations

    func animateGalaxyBirth(yearMonth: String, galaxy: DynamicGalaxy,
                            records: [Record], queueIndex: Int) {
        let node = createGalaxyNode(galaxy: galaxy, records: records, animated: true)
        addChild(node)
        activeGalaxies[yearMonth]?.node = node

        let sprite = node.childNode(withName: "galaxySprite") as? SKSpriteNode
        let tiltC = node.childNode(withName: "tiltContainer")
        let label = node.childNode(withName: "galaxyLabel")
        sprite?.alpha = 0
        tiltC?.alpha = 0
        label?.alpha = 0

        let r = galaxy.diameter / 2
        let cloud = SKSpriteNode(texture: nebulaTexture,
                                  size: CGSize(width: r * 4, height: r * galaxy.ellipticity * 4))
        cloud.color = galaxy.color
        cloud.colorBlendFactor = 1.0
        cloud.zPosition = 4
        cloud.alpha = 0
        cloud.setScale(1.5)
        cloud.zRotation = galaxy.tilt
        cloud.blendMode = .add
        node.addChild(cloud)

        let totalDelay = Double(queueIndex) * 3.5

        cloud.run(SKAction.sequence([
            SKAction.wait(forDuration: totalDelay),
            SKAction.group([
                SKAction.fadeAlpha(to: 0.25, duration: 0.8),
            ]),
            SKAction.group([
                SKAction.scale(to: 0.8, duration: 1.0),
                SKAction.fadeAlpha(to: 0.5, duration: 1.0),
            ]),
            SKAction.fadeAlpha(to: 0.7, duration: 0.5),
            SKAction.fadeAlpha(to: 0, duration: 0.7),
            SKAction.removeFromParent(),
        ]))

        sprite?.run(SKAction.sequence([
            SKAction.wait(forDuration: totalDelay + 1.8),
            SKAction.fadeAlpha(to: 1.0, duration: 1.2),
        ]))

        tiltC?.run(SKAction.sequence([
            SKAction.wait(forDuration: totalDelay + 2.3),
            SKAction.fadeAlpha(to: 1.0, duration: 0.7),
        ]))

        if let orbit = tiltC?.childNode(withName: "orbitNode") {
            let recordStars = orbit.children.filter { $0.name == "recordStar" }
            for (i, star) in recordStars.enumerated() {
                if let s = star as? SKSpriteNode {
                    let starDelay = totalDelay + 2.5 + Double(i) * 0.1
                    animateStarBirth(sprite: s, delay: starDelay)
                }
            }
        }

        label?.run(SKAction.sequence([
            SKAction.wait(forDuration: totalDelay + 2.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
            SKAction.run { [weak self] in
                DispatchQueue.main.async {
                    self?.sceneDelegate?.galaxyBirthCompleted()
                }
            },
        ]))
    }

    func animateStarBirth(sprite: SKSpriteNode, delay: TimeInterval) {
        sprite.alpha = 0
        sprite.setScale(0.3)
        sprite.run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.group([
                SKAction.fadeAlpha(to: 0.15, duration: 0.3),
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: 1.0, duration: 0.4),
                SKAction.scale(to: 1.3, duration: 0.4),
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.5...0.8), duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5),
            ]),
        ]))
    }
}
