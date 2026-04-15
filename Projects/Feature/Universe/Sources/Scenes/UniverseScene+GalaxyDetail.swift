import SpriteKit
import DomainEntity
import SharedDesignSystem
import SharedRecordVisuals

extension UniverseScene {

    // MARK: - Zoom In / Out

    func zoomInToGalaxy(key: String) {
        guard let galaxy = activeGalaxies[key] else { return }
        sceneState = .zoomingIn
        currentGalaxyKey = key
        velocity = .zero

        savedCameraPos = cameraNode.position
        savedCameraScale = cameraNode.xScale

        let targetScale: CGFloat = 0.15

        let move = SKAction.move(to: galaxy.position, duration: 1.0)
        let scale = SKAction.scale(to: targetScale, duration: 1.0)
        move.timingMode = .easeIn
        scale.timingMode = .easeIn

        if let node = galaxy.node {
            node.childNode(withName: "galaxySprite")?.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.6),
                SKAction.fadeAlpha(to: 0, duration: 0.4),
            ]))
            node.childNode(withName: "tiltContainer")?.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.6),
                SKAction.fadeAlpha(to: 0, duration: 0.4),
            ]))
            node.childNode(withName: "galaxyLabel")?.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.4),
                SKAction.fadeAlpha(to: 0, duration: 0.3),
            ]))
        }

        cameraNode.run(SKAction.group([move, scale])) { [weak self] in
            self?.showGalaxyDetail(key: key)
        }
    }

    func showGalaxyDetail(key: String) {
        sceneState = .galaxyDetail
        guard let galaxy = activeGalaxies[key] else { return }

        let records = fetchRecords(forKey: key)
        detailRecords = records
        sceneDelegate?.didEnterGalaxyDetail(key: key, records: records)
        createDetailRecordStars(for: records, around: galaxy)

        showBackButton(yearMonth: key)
        switchMinimapToGalaxy(galaxy: galaxy, records: records)

        if let record = pendingStarRecord {
            pendingStarRecord = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.navigateToStar(record: record)
            }
        }
    }

    func zoomOut() {
        sceneState = .zoomingOut
        sceneDelegate?.didExitGalaxyDetail()

        for node in detailNodes {
            node.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 0, duration: 0.3),
                SKAction.removeFromParent(),
            ]))
        }
        detailNodes.removeAll()
        detailRecords.removeAll()
        backButton = nil
        switchMinimapToUniverse()

        if let key = currentGalaxyKey, let galaxy = activeGalaxies[key], let node = galaxy.node {
            if let sprite = node.childNode(withName: "galaxySprite") as? SKSpriteNode {
                var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
                galaxy.color.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
                sprite.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(cr), Float(cg), Float(cb), 1)),
                                forAttribute: "a_color")
                sprite.run(SKAction.fadeAlpha(to: 1.0, duration: 0.6))
            }
            node.childNode(withName: "tiltContainer")?.run(
                SKAction.fadeAlpha(to: 1.0, duration: 0.6))
            node.childNode(withName: "galaxyLabel")?.run(
                SKAction.fadeAlpha(to: 1.0, duration: 0.6))
        }

        let move = SKAction.move(to: savedCameraPos, duration: 0.8)
        let scale = SKAction.scale(to: savedCameraScale, duration: 0.8)
        move.timingMode = .easeOut
        scale.timingMode = .easeOut

        cameraNode.run(SKAction.group([move, scale])) { [weak self] in
            self?.sceneState = .universe
            self?.currentGalaxyKey = nil
            self?.refreshGalaxies()
        }
    }

    // MARK: - Detail Stars

    func createDetailRecordStars(for records: [Record], around galaxy: DynamicGalaxy, animateFrom: Int = 0) {
        guard !records.isEmpty else {
            addDetailDustStars(around: galaxy)
            return
        }

        let positions = resolvePositions(records: records, yearMonth: galaxy.yearMonth)
        for (i, record) in records.enumerated() {
            let profile = record.resolvedProfile
            let pos = positions[i]
            let x = galaxy.position.x + pos.x
            let y = galaxy.position.y + pos.y

            let isNew = i >= animateFrom

            let container = SKNode()
            container.position = CGPoint(x: x, y: y)
            container.zPosition = 15
            container.name = "detailStar_\(i)"
            container.alpha = isNew ? 0 : 1
            container.setScale(isNew ? 0.3 : 1.0)

            // 크기: 프로필 기반 (8~22pt)
            let sz: CGFloat = 8.0 + CGFloat(profile.size) * 14.0
            let star = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
            star.shader = starShader
            star.blendMode = .add
            // 밝기: 프로필 기반
            star.alpha = 0.4 + CGFloat(profile.brightness) * 0.6

            let color = profile.primaryColor.uiColor
            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
            color.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
            star.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(cr), Float(cg), Float(cb), 1)),
                          forAttribute: "a_color")
            container.addChild(star)

            let displayName = record.starName.isEmpty ? "★" : record.starName
            let label = SKLabelNode(text: displayName)
            label.fontName = "AppleSDGothicNeo-Medium"
            label.fontSize = 10
            label.fontColor = UIColor(white: 1, alpha: 0.6)
            label.setScale(0.15)
            label.verticalAlignmentMode = .top
            label.position = CGPoint(x: 0, y: -sz / 2 - 0.5)
            container.addChild(label)

            let dateLabel = SKLabelNode(text: FormatHelper.shortDate(record.createdAt))
            dateLabel.fontName = "AppleSDGothicNeo-Light"
            dateLabel.fontSize = 8
            dateLabel.fontColor = UIColor(white: 1, alpha: 0.35)
            dateLabel.setScale(0.15)
            dateLabel.verticalAlignmentMode = .top
            dateLabel.position = CGPoint(x: 0, y: -sz / 2 - 2.0)
            container.addChild(dateLabel)

            addChild(container)
            detailNodes.append(container)

            if isNew {
                let delay = Double(i - animateFrom) * 0.12
                container.run(SKAction.sequence([
                    SKAction.wait(forDuration: delay),
                    SKAction.group([
                        SKAction.fadeAlpha(to: 0.2, duration: 0.2),
                        SKAction.scale(to: 0.6, duration: 0.2),
                    ]),
                    SKAction.group([
                        SKAction.fadeAlpha(to: 1.2, duration: 0.25),
                        SKAction.scale(to: 1.35, duration: 0.25),
                    ]),
                    SKAction.group([
                        SKAction.fadeAlpha(to: 0.85, duration: 0.3),
                        SKAction.scale(to: 1.0, duration: 0.3),
                    ]),
                ]))
            }

            // 반짝임 애니메이션: 프로필 기반
            let twinkleRange = 0.15 + CGFloat(profile.twinkleIntensity) * 0.35  // 0.15~0.50
            let twinkleDuration = 2.0 - Double(profile.twinkleSpeed) * 1.5       // 0.5~2.0초
            let baseAlpha = star.alpha
            star.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: max(0.1, baseAlpha - twinkleRange), duration: twinkleDuration),
                SKAction.fadeAlpha(to: min(1.0, baseAlpha + twinkleRange), duration: twinkleDuration),
            ])), withKey: "twinkle")

            // 움직임: 프로필 기반
            let motionRange = 0.3 + CGFloat(profile.motionAmplitude) * 1.0  // 0.3~1.3pt
            let motionDur = 5.0 - Double(profile.motionSpeed) * 3.0          // 2.0~5.0초
            container.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: motionRange, y: motionRange * 0.7, duration: motionDur),
                SKAction.moveBy(x: -motionRange, y: -motionRange * 0.7, duration: motionDur),
            ])))
        }

        addDetailDustStars(around: galaxy)
    }

    func addDetailDustStars(around galaxy: DynamicGalaxy) {
        let dustCount = 100
        let spread: CGFloat = 250
        for _ in 0..<dustCount {
            let x = galaxy.position.x + CGFloat.random(in: -spread...spread)
            let y = galaxy.position.y + CGFloat.random(in: -spread...spread)
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
            dot.setValue(SKAttributeValue(vectorFloat4: vector_float4(r, g, b, 1)),
                         forAttribute: "a_color")

            addChild(dot)
            detailNodes.append(dot)

            dot.run(SKAction.sequence([
                SKAction.wait(forDuration: Double.random(in: 0.2...0.8)),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.15...0.5), duration: 0.6),
            ]))

            let mx = CGFloat.random(in: -0.3...0.3)
            let my = CGFloat.random(in: -0.3...0.3)
            dot.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.moveBy(x: mx, y: my, duration: Double.random(in: 4...7)),
                SKAction.moveBy(x: -mx, y: -my, duration: Double.random(in: 4...7)),
            ])))
        }
    }

    // MARK: - Navigation

    func navigateToGalaxy(yearMonth: String) {
        guard sceneState == .universe, activeGalaxies[yearMonth] != nil else { return }
        zoomInToGalaxy(key: yearMonth)
    }

    func navigateToGalaxyThenStar(yearMonth: String, record: Record) {
        guard sceneState == .universe, activeGalaxies[yearMonth] != nil else { return }
        pendingStarRecord = record
        zoomInToGalaxy(key: yearMonth)
    }

    func navigateToStar(record: Record) {
        guard sceneState == .galaxyDetail,
              let key = currentGalaxyKey,
              let galaxy = activeGalaxies[key] else { return }

        guard let idx = detailRecords.firstIndex(where: { $0.id == record.id }) else { return }
        let positions = resolvePositions(records: detailRecords, yearMonth: galaxy.yearMonth)
        guard idx < positions.count else { return }
        let pos = positions[idx]
        let worldPos = CGPoint(x: galaxy.position.x + pos.x, y: galaxy.position.y + pos.y)

        let move = SKAction.move(to: worldPos, duration: 0.5)
        move.timingMode = .easeInEaseOut
        cameraNode.run(move)

        if let container = children.first(where: { $0.name == "detailStar_\(idx)" }) {
            container.run(SKAction.sequence([
                SKAction.scale(to: 1.5, duration: 0.2),
                SKAction.scale(to: 1.0, duration: 0.3),
            ]))
        }
    }

    // MARK: - Preview Star

    func showPreviewStar(color: RecordColor) {
        previewStarNode?.removeFromParent()
        previewStarConfirmed = false

        guard let key = currentGalaxyKey, let galaxy = activeGalaxies[key] else { return }

        let existingPositions = resolvePositions(records: detailRecords, yearMonth: galaxy.yearMonth)
        let previewPos = generateSinglePosition(avoiding: existingPositions, yearMonth: galaxy.yearMonth)
        pendingPreviewPosition = previewPos
        let nextPos = previewPos.cgPoint

        let worldPos = CGPoint(x: galaxy.position.x + nextPos.x,
                               y: galaxy.position.y + nextPos.y)

        let sz: CGFloat = 14
        let star = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
        star.position = worldPos
        star.zPosition = 20
        star.shader = starShader
        star.blendMode = .add
        star.alpha = 0
        star.name = "previewStar"

        let uiColor = color.uiColor
        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
        uiColor.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
        star.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(cr), Float(cg), Float(cb), 1)),
                      forAttribute: "a_color")

        addChild(star)
        previewStarNode = star

        star.setScale(0.5)
        star.run(SKAction.group([
            SKAction.fadeAlpha(to: 0.7, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5),
        ]))
        star.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 1.2),
            SKAction.fadeAlpha(to: 0.8, duration: 1.2),
        ])), withKey: "pulse")

        let visibleHeight = self.size.height * cameraNode.yScale
        let offsetY = visibleHeight * 0.22
        let targetCam = CGPoint(x: worldPos.x, y: worldPos.y - offsetY)
        let moveAction = SKAction.move(to: targetCam, duration: 0.5)
        moveAction.timingMode = .easeInEaseOut
        cameraNode.run(moveAction)
    }

    func updatePreviewColor(_ color: RecordColor) {
        guard let star = previewStarNode else { return }
        let uiColor = color.uiColor
        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
        uiColor.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
        star.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(cr), Float(cg), Float(cb), 1)),
                      forAttribute: "a_color")
    }

    func confirmPreviewStar() {
        previewStarConfirmed = true
        previewStarNode?.removeAction(forKey: "pulse")
        previewStarNode?.run(SKAction.fadeAlpha(to: 1.0, duration: 0.2))
    }

    func dismissPreviewStar() {
        guard !previewStarConfirmed, let star = previewStarNode else {
            previewStarNode = nil
            return
        }
        star.removeAction(forKey: "pulse")
        star.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeAlpha(to: 0, duration: 0.8),
                SKAction.scale(to: 0.3, duration: 0.8),
            ]),
            SKAction.removeFromParent(),
        ]))
        previewStarNode = nil
    }

    // MARK: - Record Detail Overlay

    func showRecordDetail(record: Record) {
        sceneState = .recordDetail

        let overlay = SKShapeNode(rectOf: CGSize(width: 10000, height: 10000))
        overlay.fillColor = UIColor(white: 0, alpha: 0.5)
        overlay.strokeColor = .clear
        overlay.zPosition = 90
        cameraNode.addChild(overlay)
        recordDetailNodes.append(overlay)

        let cardW: CGFloat = size.width * 0.75
        let cardH: CGFloat = 180
        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 12)
        card.fillColor = AppColors.surfaceElevatedUI
        card.strokeColor = UIColor(white: 1, alpha: 0.08)
        card.lineWidth = 0.5
        card.zPosition = 91
        cameraNode.addChild(card)
        recordDetailNodes.append(card)

        let recordUIColor = record.resolvedProfile.primaryColor.uiColor
        let emotionBar = SKShapeNode(rectOf: CGSize(width: cardW - 24, height: 3), cornerRadius: 1.5)
        emotionBar.fillColor = recordUIColor
        emotionBar.strokeColor = .clear
        emotionBar.position = CGPoint(x: 0, y: cardH / 2 - 14)
        emotionBar.zPosition = 92
        cameraNode.addChild(emotionBar)
        recordDetailNodes.append(emotionBar)

        // 별 이름
        if !record.starName.isEmpty {
            let nameLabel = SKLabelNode(text: "「\(record.starName)」")
            nameLabel.fontName = "AppleSDGothicNeo-Bold"
            nameLabel.fontSize = 15
            nameLabel.fontColor = recordUIColor
            nameLabel.position = CGPoint(x: 0, y: cardH / 2 - 36)
            nameLabel.zPosition = 92
            cameraNode.addChild(nameLabel)
            recordDetailNodes.append(nameLabel)
        }

        // 날짜/시간
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.MM.dd HH:mm"
        let dateLabel = SKLabelNode(text: dateFormatter.string(from: record.createdAt))
        dateLabel.fontName = "AppleSDGothicNeo-Regular"
        dateLabel.fontSize = 11
        dateLabel.fontColor = UIColor(white: 1, alpha: 0.4)
        let dateY: CGFloat = record.starName.isEmpty ? (cardH / 2 - 36) : (cardH / 2 - 54)
        dateLabel.position = CGPoint(x: 0, y: dateY)
        dateLabel.zPosition = 92
        cameraNode.addChild(dateLabel)
        recordDetailNodes.append(dateLabel)

        // 기록 내용
        let contentY: CGFloat = record.starName.isEmpty ? (cardH / 2 - 54) : (cardH / 2 - 72)
        let content = SKLabelNode(text: record.content)
        content.fontName = "AppleSDGothicNeo-Regular"
        content.fontSize = 15
        content.fontColor = UIColor(white: 1, alpha: 0.9)
        content.preferredMaxLayoutWidth = cardW - 40
        content.numberOfLines = 0
        content.verticalAlignmentMode = .top
        content.position = CGPoint(x: 0, y: contentY)
        content.zPosition = 92
        cameraNode.addChild(content)
        recordDetailNodes.append(content)

        let hint = SKLabelNode(text: "탭하여 닫기")
        hint.fontName = "AppleSDGothicNeo-Light"
        hint.fontSize = 11
        hint.fontColor = UIColor(white: 1, alpha: 0.3)
        hint.position = CGPoint(x: 0, y: -cardH / 2 + 16)
        hint.zPosition = 92
        cameraNode.addChild(hint)
        recordDetailNodes.append(hint)

        for node in recordDetailNodes {
            let original = node.alpha
            node.alpha = 0
            node.run(SKAction.fadeAlpha(to: original, duration: 0.25))
        }
    }

    func dismissRecordDetail() {
        sceneState = .galaxyDetail
        for node in recordDetailNodes {
            node.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 0, duration: 0.2),
                SKAction.removeFromParent(),
            ]))
        }
        recordDetailNodes.removeAll()
    }

    // MARK: - Back Button & Title

    func showBackButton(yearMonth: String) {
        let btn = SKLabelNode(text: "<")
        btn.fontName = "AppleSDGothicNeo-Medium"
        btn.fontSize = 22
        btn.fontColor = UIColor(white: 1, alpha: 0.8)
        btn.horizontalAlignmentMode = .left
        btn.verticalAlignmentMode = .center
        btn.position = CGPoint(x: -size.width / 2 + 20, y: size.height / 2 - 90)
        btn.zPosition = 100
        btn.alpha = 0
        cameraNode.addChild(btn)
        backButton = btn
        detailNodes.append(btn)
        btn.run(SKAction.fadeAlpha(to: 1, duration: 0.3))

        let title = SKLabelNode(text: FormatHelper.yearMonthLabel(yearMonth))
        title.fontName = "AppleSDGothicNeo-Medium"
        title.fontSize = 17
        title.fontColor = UIColor(white: 1, alpha: 0.85)
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: size.height / 2 - 90)
        title.zPosition = 100
        title.alpha = 0
        cameraNode.addChild(title)
        detailNodes.append(title)
        title.run(SKAction.fadeAlpha(to: 1, duration: 0.3))
    }
}
