import SpriteKit
import DomainEntity

extension ConstellationScene {

    // MARK: - Zoom In

    func zoomInToConstellation(id: String) {
        guard let rendered = renderedConstellations[id] else { return }
        sceneState = .zoomingIn
        currentConstellationId = id
        velocity = .zero

        savedCameraPos = cameraNode.position
        savedCameraScale = cameraNode.xScale

        let constellationPos = rendered.containerNode.position
        // 별자리 전체가 화면에 보이도록 줌 스케일 계산
        let uniformSpan: CGFloat = 250
        let padding: CGFloat = 1.3 // 30% 여백
        let fitScale = uniformSpan * padding / min(size.width, size.height)
        let targetScale: CGFloat = max(0.1, fitScale)

        // 별자리가 네비바 아래 상단 영역에 오도록 카메라를 아래로 오프셋
        // 0.15 → 화면 상단에서 약 35% 지점에 별자리 배치
        let verticalOffset = size.height * targetScale * 0.15
        let targetPos = CGPoint(x: constellationPos.x, y: constellationPos.y - verticalOffset)

        let move = SKAction.move(to: targetPos, duration: 0.8)
        let scale = SKAction.scale(to: targetScale, duration: 0.8)
        move.timingMode = .easeInEaseOut
        scale.timingMode = .easeInEaseOut

        // 모든 별자리 라벨 숨기기 + 선택한 별자리 외 나머지 숨기기
        for (otherId, other) in renderedConstellations {
            other.labelNode?.run(SKAction.fadeAlpha(to: 0, duration: 0.4))
            if otherId != id {
                other.containerNode.run(SKAction.fadeAlpha(to: 0, duration: 0.5))
            }
        }

        cameraNode.run(SKAction.group([move, scale])) { [weak self] in
            self?.detailMaxScale = targetScale
            self?.showConstellationDetail(id: id)
        }
    }

    func showConstellationDetail(id: String) {
        sceneState = .constellationDetail
        sceneDelegate?.didEnterConstellationDetail(id: id)

        guard let def = ConstellationCatalog.find(id) else { return }

        // 연결선 강조
        if let rendered = renderedConstellations[id] {
            for lineNode in rendered.lineNodes {
                lineNode.run(SKAction.customAction(withDuration: 0.5) { node, elapsed in
                    let t = elapsed / 0.5
                    (node as? SKShapeNode)?.strokeColor = UIColor(white: 1, alpha: 0.06 + 0.14 * t)
                })
            }
        }

        showBackButton(title: def.nameKO)
    }

    // MARK: - Zoom Out

    func zoomOut() {
        sceneState = .zoomingOut
        sceneDelegate?.didExitConstellationDetail()

        // 연결선/라벨 복원 (완성된 별자리는 밝은 선 유지)
        if let id = currentConstellationId, let rendered = renderedConstellations[id] {
            let restoreAlpha = completedConstellationLineAlpha(for: id)
            for lineNode in rendered.lineNodes {
                let targetAlpha = restoreAlpha
                lineNode.run(SKAction.customAction(withDuration: 0.3) { node, elapsed in
                    let t = elapsed / 0.3
                    let current: CGFloat = 0.20
                    let alpha = current + (targetAlpha - current) * t
                    (node as? SKShapeNode)?.strokeColor = UIColor(white: 1, alpha: alpha)
                })
            }
            rendered.labelNode?.run(SKAction.fadeAlpha(to: 0.25, duration: 0.3))
        }

        // 뒤로가기 버튼 제거
        for node in detailNodes {
            node.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 0, duration: 0.2),
                SKAction.removeFromParent(),
            ]))
        }
        detailNodes.removeAll()
        backButton = nil

        // 나머지 별자리 다시 보이기 + 모든 라벨 복원
        for (otherId, rendered) in renderedConstellations {
            rendered.labelNode?.run(SKAction.fadeAlpha(to: 0.25, duration: 0.4))
            if otherId != currentConstellationId {
                rendered.containerNode.run(SKAction.fadeAlpha(to: 1, duration: 0.4))
            }
        }

        let move = SKAction.move(to: savedCameraPos, duration: 0.6)
        let scale = SKAction.scale(to: savedCameraScale, duration: 0.6)
        move.timingMode = .easeOut
        scale.timingMode = .easeOut

        cameraNode.run(SKAction.group([move, scale])) { [weak self] in
            self?.sceneState = .overview
            self?.currentConstellationId = nil
        }
    }

    // MARK: - Back Button

    func showBackButton(title: String) {
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

        let titleLabel = SKLabelNode(text: title)
        titleLabel.fontName = "AppleSDGothicNeo-Medium"
        titleLabel.fontSize = 17
        titleLabel.fontColor = UIColor(white: 1, alpha: 0.85)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: size.height / 2 - 90)
        titleLabel.zPosition = 100
        titleLabel.alpha = 0
        cameraNode.addChild(titleLabel)
        detailNodes.append(titleLabel)
        titleLabel.run(SKAction.fadeAlpha(to: 1, duration: 0.3))
    }
}
