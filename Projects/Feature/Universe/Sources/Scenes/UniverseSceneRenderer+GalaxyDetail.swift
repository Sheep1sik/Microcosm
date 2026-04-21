import SpriteKit
import SharedUtil

extension UniverseSceneRenderer {

    // MARK: - Phase Reconciliation

    func reconcilePhase(_ phase: UniverseSceneFeature.ScenePhase) {
        switch phase {
        case let .zoomingIn(galaxyKey):
            guard !isAnimatingZoom else { return }
            animateZoomIn(galaxyKey: galaxyKey)

        case .galaxyDetail:
            break

        case .zoomingOut:
            guard !isAnimatingZoom else { return }
            animateZoomOut()

        case .universe, .recordDetail:
            break
        }
    }

    // MARK: - Zoom In Animation

    private func animateZoomIn(galaxyKey: String) {
        guard let galaxy = store.galaxies[galaxyKey],
              let galaxyNode = renderedGalaxies[galaxyKey] else { return }
        isAnimatingZoom = true
        zoomedGalaxyKey = galaxyKey

        let targetScale = UniverseSceneFeature.galaxyDetailScale

        let move = SKAction.move(to: galaxy.position, duration: 1.0)
        let scale = SKAction.scale(to: targetScale, duration: 1.0)
        move.timingMode = .easeIn
        scale.timingMode = .easeIn

        galaxyNode.childNode(withName: "galaxySprite")?.run(.sequence([
            .wait(forDuration: 0.6),
            .fadeAlpha(to: 0, duration: 0.4),
        ]))
        galaxyNode.childNode(withName: "tiltContainer")?.run(.sequence([
            .wait(forDuration: 0.6),
            .fadeAlpha(to: 0, duration: 0.4),
        ]))
        galaxyNode.childNode(withName: "galaxyLabel")?.run(.sequence([
            .wait(forDuration: 0.4),
            .fadeAlpha(to: 0, duration: 0.3),
        ]))

        cameraNode.run(.group([move, scale])) { [weak self] in
            guard let self else { return }
            self.isAnimatingZoom = false
            self.showBackButton(galaxyKey: galaxyKey)
            self.store.send(.zoomInCompleted)
        }
    }

    // MARK: - Zoom Out Animation

    private func animateZoomOut() {
        isAnimatingZoom = true

        clearDetailNodes()
        removeBackButton()

        let savedPos = store.camera.savedPosition
        let savedScale = store.camera.savedScale

        if let key = zoomedGalaxyKey {
            restoreGalaxyNodeVisibility(galaxyKey: key)
            zoomedGalaxyKey = nil
        }

        let move = SKAction.move(to: savedPos, duration: 0.8)
        let scale = SKAction.scale(to: savedScale, duration: 0.8)
        move.timingMode = .easeOut
        scale.timingMode = .easeOut

        cameraNode.run(.group([move, scale])) { [weak self] in
            self?.isAnimatingZoom = false
            self?.store.send(.zoomOutCompleted)
        }
    }

    private func restoreGalaxyNodeVisibility(galaxyKey: String) {
        guard let node = renderedGalaxies[galaxyKey] else { return }

        if let sprite = node.childNode(withName: "galaxySprite") as? SKSpriteNode,
           let state = store.galaxies[galaxyKey] {
            let c = state.color
            sprite.setValue(
                SKAttributeValue(vectorFloat4: vector_float4(Float(c.r), Float(c.g), Float(c.b), Float(c.a))),
                forAttribute: "a_color"
            )
            sprite.run(.fadeAlpha(to: 1.0, duration: 0.6))
        }
        node.childNode(withName: "tiltContainer")?.run(.fadeAlpha(to: 1.0, duration: 0.6))
        node.childNode(withName: "galaxyLabel")?.run(.fadeAlpha(to: 1.0, duration: 0.6))
    }

    // MARK: - Detail Stars Reconciliation

    func reconcileDetailStars(_ stars: [UniverseSceneFeature.DetailStarState]) {
        guard stars != lastRenderedStars else { return }
        lastRenderedStars = stars

        clearDetailNodes()

        guard !stars.isEmpty else { return }
        createDetailStarNodes(stars)
        addDetailDustStars()
    }

    private func createDetailStarNodes(_ stars: [UniverseSceneFeature.DetailStarState]) {
        for star in stars {
            let container = SKNode()
            container.position = star.position
            container.zPosition = 15
            container.name = "detailStar_\(star.index)"
            container.alpha = 0
            container.setScale(0.3)

            let sz = star.size
            let sprite = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
            sprite.shader = starShader
            sprite.blendMode = .add
            sprite.alpha = 0.4 + star.brightness * 0.6

            let c = star.color
            sprite.setValue(
                SKAttributeValue(vectorFloat4: vector_float4(Float(c.r), Float(c.g), Float(c.b), Float(c.a))),
                forAttribute: "a_color"
            )
            container.addChild(sprite)

            let nameLabel = SKLabelNode(text: star.starName.isEmpty ? "★" : star.starName)
            nameLabel.fontName = "AppleSDGothicNeo-Medium"
            nameLabel.fontSize = 10
            nameLabel.fontColor = UIColor(white: 1, alpha: 0.6)
            nameLabel.setScale(0.15)
            nameLabel.verticalAlignmentMode = .top
            nameLabel.position = CGPoint(x: 0, y: -sz / 2 - 0.5)
            container.addChild(nameLabel)

            let dateLabel = SKLabelNode(text: star.dateText)
            dateLabel.fontName = "AppleSDGothicNeo-Light"
            dateLabel.fontSize = 8
            dateLabel.fontColor = UIColor(white: 1, alpha: 0.35)
            dateLabel.setScale(0.15)
            dateLabel.verticalAlignmentMode = .top
            dateLabel.position = CGPoint(x: 0, y: -sz / 2 - 2.0)
            container.addChild(dateLabel)

            addChild(container)
            detailNodes.append(container)

            let delay = Double(star.index) * 0.12
            container.run(.sequence([
                .wait(forDuration: delay),
                .group([.fadeAlpha(to: 0.2, duration: 0.2), .scale(to: 0.6, duration: 0.2)]),
                .group([.fadeAlpha(to: 1.2, duration: 0.25), .scale(to: 1.35, duration: 0.25)]),
                .group([.fadeAlpha(to: 0.85, duration: 0.3), .scale(to: 1.0, duration: 0.3)]),
            ]))

            let twinkleRange = 0.15 + star.twinkleIntensity * 0.35
            let twinkleDur = 2.0 - Double(star.twinkleSpeed) * 1.5
            let baseAlpha = sprite.alpha
            sprite.run(.repeatForever(.sequence([
                .fadeAlpha(to: max(0.1, baseAlpha - twinkleRange), duration: twinkleDur),
                .fadeAlpha(to: min(1.0, baseAlpha + twinkleRange), duration: twinkleDur),
            ])), withKey: "twinkle")

            let motionRange = 0.3 + star.motionAmplitude * 1.0
            let motionDur = 5.0 - Double(star.motionSpeed) * 3.0
            container.run(.repeatForever(.sequence([
                .moveBy(x: motionRange, y: motionRange * 0.7, duration: motionDur),
                .moveBy(x: -motionRange, y: -motionRange * 0.7, duration: motionDur),
            ])))
        }
    }

    private func addDetailDustStars() {
        let camPos = cameraNode.position
        let spread: CGFloat = 250
        for _ in 0..<100 {
            let x = camPos.x + CGFloat.random(in: -spread...spread)
            let y = camPos.y + CGFloat.random(in: -spread...spread)
            let sz = CGFloat.random(in: 1.0...3.0)
            let dot = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
            dot.position = CGPoint(x: x, y: y)
            dot.zPosition = 12
            dot.alpha = 0
            dot.shader = starShader
            dot.blendMode = .add

            let temp = Float.random(in: 0...1)
            let r: Float = temp < 0.5 ? 0.7 + temp : 1.0
            let g: Float = 0.85 + temp * 0.15
            let b: Float = temp < 0.5 ? 1.0 : 1.0 - (temp - 0.5) * 0.4
            dot.setValue(
                SKAttributeValue(vectorFloat4: vector_float4(r, g, b, 1)),
                forAttribute: "a_color"
            )
            addChild(dot)
            detailNodes.append(dot)

            dot.run(.sequence([
                .wait(forDuration: Double.random(in: 0.2...0.8)),
                .fadeAlpha(to: CGFloat.random(in: 0.15...0.5), duration: 0.6),
            ]))

            let mx = CGFloat.random(in: -0.3...0.3)
            let my = CGFloat.random(in: -0.3...0.3)
            dot.run(.repeatForever(.sequence([
                .moveBy(x: mx, y: my, duration: Double.random(in: 4...7)),
                .moveBy(x: -mx, y: -my, duration: Double.random(in: 4...7)),
            ])))
        }
    }

    // MARK: - Back Button

    private func showBackButton(galaxyKey: String) {
        let back = SKLabelNode(text: "〈")
        back.fontName = "AppleSDGothicNeo-Regular"
        back.fontSize = 24
        back.fontColor = UIColor(white: 1, alpha: 0.7)
        back.horizontalAlignmentMode = .left
        back.verticalAlignmentMode = .center
        back.name = "backButton"
        back.alpha = 0

        let title = SKLabelNode(text: FormatHelper.yearMonthLabel(galaxyKey))
        title.fontName = "AppleSDGothicNeo-Medium"
        title.fontSize = 16
        title.fontColor = UIColor(white: 1, alpha: 0.8)
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.name = "detailTitle"
        title.alpha = 0

        let scale = cameraNode.xScale
        let viewHalfW = size.width / 2
        let viewHalfH = size.height / 2
        let padding: CGFloat = 16

        back.position = CGPoint(x: -viewHalfW * scale + padding * scale,
                                 y: viewHalfH * scale - padding * scale * 3)
        back.setScale(scale)

        title.position = CGPoint(x: back.position.x + 20 * scale,
                                  y: back.position.y)
        title.setScale(scale)

        cameraNode.addChild(back)
        cameraNode.addChild(title)
        detailNodes.append(back)
        detailNodes.append(title)
        backButtonNode = back

        back.run(.fadeAlpha(to: 1.0, duration: 0.3))
        title.run(.fadeAlpha(to: 1.0, duration: 0.3))
    }

    private func removeBackButton() {
        backButtonNode = nil
    }

    // MARK: - Cleanup

    func clearDetailNodes() {
        for node in detailNodes {
            node.run(.sequence([
                .fadeAlpha(to: 0, duration: 0.3),
                .removeFromParent(),
            ]))
        }
        detailNodes.removeAll()
        backButtonNode = nil
        lastRenderedStars = []
    }

    // MARK: - Camera Node Accessor

    var currentCameraNode: SKCameraNode { cameraNode }
}
