import SpriteKit
import SharedUtil

extension UniverseSceneRenderer {

    // MARK: - Reconcile Galaxies (State → SKNode)

    func reconcileGalaxies(_ galaxies: [String: UniverseSceneFeature.GalaxyNodeState]) {
        let newKeys = Set(galaxies.keys)
        let oldKeys = Set(renderedGalaxies.keys)

        for key in oldKeys.subtracting(newKeys) {
            renderedGalaxies[key]?.removeFromParent()
            renderedGalaxies.removeValue(forKey: key)
        }

        for key in newKeys.subtracting(oldKeys) {
            guard let state = galaxies[key] else { continue }
            let node = createGalaxyNode(from: state)
            addChild(node)
            renderedGalaxies[key] = node
        }

        for key in newKeys.intersection(oldKeys) {
            guard let state = galaxies[key], let node = renderedGalaxies[key] else { continue }
            updateGalaxyNode(node, with: state)
        }
    }

    // MARK: - Create Galaxy Node

    private func createGalaxyNode(from state: UniverseSceneFeature.GalaxyNodeState) -> SKNode {
        let container = SKNode()
        container.position = state.position
        container.zPosition = 5
        container.name = "galaxy_\(state.yearMonth)"

        let r = state.diameter / 2
        let color = state.color.uiColor

        let sprite = SKSpriteNode(color: .white, size: CGSize(width: r * 4, height: r * 4))
        sprite.name = "galaxySprite"
        sprite.shader = galaxyShader
        sprite.blendMode = .add
        sprite.zRotation = state.tilt
        applyGalaxyShaderAttributes(sprite, state: state)
        container.addChild(sprite)

        let orbitNode = SKNode()
        orbitNode.name = "orbitNode"
        populateOrbitStars(orbitNode, state: state, radius: r, color: color)

        let rotDuration = 30.0 + Double(state.diameter) * 0.15
        orbitNode.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: rotDuration)))

        let tiltContainer = SKNode()
        tiltContainer.name = "tiltContainer"
        tiltContainer.yScale = state.ellipticity
        tiltContainer.zRotation = state.tilt
        tiltContainer.addChild(orbitNode)
        container.addChild(tiltContainer)

        let label = SKLabelNode(text: FormatHelper.yearMonthLabel(state.yearMonth))
        label.fontName = "AppleSDGothicNeo-Light"
        label.fontSize = 44
        label.setScale(0.25)
        label.fontColor = color.withAlphaComponent(0.5)
        label.position = CGPoint(x: 0, y: -r * state.ellipticity - 16)
        label.zPosition = 6
        label.name = "galaxyLabel"
        container.addChild(label)

        return container
    }

    // MARK: - Update Existing Galaxy Node

    private func updateGalaxyNode(_ node: SKNode, with state: UniverseSceneFeature.GalaxyNodeState) {
        node.position = state.position

        let r = state.diameter / 2
        let color = state.color.uiColor

        if let sprite = node.childNode(withName: "galaxySprite") as? SKSpriteNode {
            applyGalaxyShaderAttributes(sprite, state: state)
            sprite.size = CGSize(width: r * 4, height: r * 4)
        }

        if let tilt = node.childNode(withName: "tiltContainer") {
            tilt.yScale = state.ellipticity
            tilt.zRotation = state.tilt

            if let orbit = tilt.childNode(withName: "orbitNode") {
                let currentStarCount = orbit.children.filter { $0.name == "recordStar" }.count
                if currentStarCount != state.recordCount {
                    orbit.removeAllChildren()
                    populateOrbitStars(orbit, state: state, radius: r, color: color)
                }
            }
        }

        if let label = node.childNode(withName: "galaxyLabel") as? SKLabelNode {
            label.fontColor = color.withAlphaComponent(0.5)
            label.position = CGPoint(x: 0, y: -r * state.ellipticity - 16)
        }
    }

    // MARK: - Orbit Stars

    private func populateOrbitStars(
        _ orbitNode: SKNode,
        state: UniverseSceneFeature.GalaxyNodeState,
        radius: CGFloat,
        color: UIColor
    ) {
        let goldenAngle: CGFloat = .pi * (3 - sqrt(5))
        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
        color.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)

        for i in 0..<state.recordCount {
            let angle = CGFloat(i) * goldenAngle
            let dist = radius * 0.5 + sqrt(CGFloat(i + 1)) * radius * 0.22
            let sz = CGFloat.random(in: 6...14)
            let dot = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
            dot.position = CGPoint(x: dist * cos(angle), y: dist * sin(angle))
            dot.zPosition = 1
            dot.alpha = CGFloat.random(in: 0.4...0.9)
            dot.shader = starShader
            dot.blendMode = .add
            dot.name = "recordStar"
            let bright = Float.random(in: 0.8...1.0)
            dot.setValue(
                SKAttributeValue(vectorFloat4: vector_float4(
                    Float(cr) * bright, Float(cg) * bright, Float(cb) * bright, 1
                )),
                forAttribute: "a_color"
            )
            orbitNode.addChild(dot)
        }

        let decoCount = max(5, 10 - state.recordCount)
        for _ in 0..<decoCount {
            let a = CGFloat.random(in: 0...(2 * .pi))
            let d = CGFloat.random(in: radius * 0.08...radius * 0.85)
            let sz = CGFloat.random(in: 2...4)
            let dot = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
            dot.position = CGPoint(x: d * cos(a), y: d * sin(a))
            dot.alpha = CGFloat.random(in: 0.2...0.5)
            dot.shader = starShader
            dot.blendMode = .add
            let bright = Float.random(in: 0.8...1.0)
            dot.setValue(
                SKAttributeValue(vectorFloat4: vector_float4(
                    min(Float(cr) + 0.2, 1) * bright,
                    min(Float(cg) + 0.2, 1) * bright,
                    min(Float(cb) + 0.2, 1) * bright, 1
                )),
                forAttribute: "a_color"
            )
            orbitNode.addChild(dot)
        }
    }

    // MARK: - Shader Attributes

    private func applyGalaxyShaderAttributes(
        _ sprite: SKSpriteNode,
        state: UniverseSceneFeature.GalaxyNodeState
    ) {
        let c = state.color
        sprite.setValue(
            SKAttributeValue(vectorFloat4: vector_float4(Float(c.r), Float(c.g), Float(c.b), Float(c.a))),
            forAttribute: "a_color"
        )
        sprite.setValue(SKAttributeValue(float: Float(state.arms)), forAttribute: "a_arm_count")
        sprite.setValue(SKAttributeValue(float: Float(state.wind)), forAttribute: "a_wind")
        sprite.setValue(SKAttributeValue(float: Float(state.ellipticity)), forAttribute: "a_ellipticity")
    }
}

// MARK: - RGBA → UIColor

extension UniverseSceneFeature.RGBA {
    var uiColor: UIColor {
        UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
