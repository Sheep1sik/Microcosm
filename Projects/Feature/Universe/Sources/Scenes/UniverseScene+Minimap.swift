import SpriteKit
import DomainEntity

extension UniverseScene {

    // MARK: - Minimap Setup

    func setupMinimap() {
        let node = SKNode(); node.zPosition = 100; node.alpha = 0
        let bg = SKShapeNode(rectOf: CGSize(width: mmSize, height: mmSize), cornerRadius: 4)
        bg.fillColor = UIColor(white: 0, alpha: 0.5)
        bg.strokeColor = UIColor(white: 1, alpha: 0.15); bg.lineWidth = 0.5
        node.addChild(bg)

        let vp = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
        vp.fillColor = UIColor(white: 1, alpha: 0.08)
        vp.strokeColor = UIColor(white: 1, alpha: 0.5); vp.lineWidth = 0.5
        node.addChild(vp)
        minimapViewport = vp

        cameraNode.addChild(node)
        minimapNode = node
    }

    func refreshMinimapDots() {
        for dot in minimapDots { dot.removeFromParent() }
        minimapDots.removeAll()
        guard let minimapNode else { return }

        let sc = mmSize / worldSize.width
        for galaxy in activeGalaxies.values {
            let dot = SKShapeNode(circleOfRadius: max(1.5, galaxy.diameter * sc * 0.3))
            dot.fillColor = galaxy.color; dot.strokeColor = .clear
            dot.position = CGPoint(x: (galaxy.position.x - worldSize.width / 2) * sc,
                                   y: (galaxy.position.y - worldSize.height / 2) * sc)
            minimapNode.addChild(dot)
            minimapDots.append(dot)
        }
    }

    func updateMinimap() {
        guard let minimapNode, let minimapViewport else { return }
        // 미니맵이 보이지 않고 활동도 없으면 스킵
        let isActive = lastTouchPos != nil || pinchStartDist > 0
            || abs(velocity.dx) > 0.05 || abs(velocity.dy) > 0.05
        if minimapNode.alpha < 0.01 && !isActive { return }

        let margin: CGFloat = 20
        let tabBarHeight: CGFloat = 90
        minimapNode.position = CGPoint(x: -size.width / 2 + margin + mmSize / 2,
                                       y: -size.height / 2 + margin + mmSize / 2 + tabBarHeight)

        if sceneState == .galaxyDetail {
            guard let key = currentGalaxyKey, let galaxy = activeGalaxies[key] else { return }

            let sc = (mmSize / 2) / galaxyMinimapExtent
            galaxyMinimapContainer?.setScale(sc)

            minimapViewport.alpha = 1
            let camScale = cameraNode.xScale
            let rawW = size.width * camScale * sc
            let rawH = size.height * camScale * sc
            let dx = (cameraNode.position.x - galaxy.position.x) * sc
            let dy = (cameraNode.position.y - galaxy.position.y) * sc

            let halfMM = mmSize / 2 - 1
            let left   = max(dx - rawW / 2, -halfMM)
            let right  = min(dx + rawW / 2,  halfMM)
            let bottom = max(dy - rawH / 2, -halfMM)
            let top    = min(dy + rawH / 2,  halfMM)
            let clampW = max(right - left, 0)
            let clampH = max(top - bottom, 0)
            let cx = (left + right) / 2
            let cy = (bottom + top) / 2

            minimapViewport.path = CGPath(rect: CGRect(x: -clampW / 2, y: -clampH / 2,
                                                        width: clampW, height: clampH), transform: nil)
            minimapViewport.position = CGPoint(x: cx, y: cy)

            let active = lastTouchPos != nil || pinchStartDist > 0
                || abs(velocity.dx) > 0.05 || abs(velocity.dy) > 0.05
            let target: CGFloat = active ? 0.8 : 0
            minimapNode.alpha += (target - minimapNode.alpha) * 0.1
        } else {
            let sc = mmSize / worldSize.width
            let s = cameraNode.xScale
            let vpW = size.width * s * sc
            let vpH = size.height * s * sc
            minimapViewport.path = CGPath(rect: CGRect(x: -vpW / 2, y: -vpH / 2, width: vpW, height: vpH), transform: nil)
            minimapViewport.position = CGPoint(
                x: (cameraNode.position.x - worldSize.width / 2) * sc,
                y: (cameraNode.position.y - worldSize.height / 2) * sc)

            let active = lastTouchPos != nil || pinchStartDist > 0
                || abs(velocity.dx) > 0.5 || abs(velocity.dy) > 0.5
            let target: CGFloat = active ? 0.8 : 0
            minimapNode.alpha += (target - minimapNode.alpha) * 0.1
        }
    }

    // MARK: - Galaxy Minimap (기존 왼쪽 미니맵 재활용)

    func switchMinimapToGalaxy(galaxy: DynamicGalaxy, records: [Record]) {
        for dot in minimapDots { dot.removeFromParent() }
        minimapDots.removeAll()

        galaxyMinimapExtent = 150

        let positions = resolvePositions(records: records, yearMonth: galaxy.yearMonth)
        let container = SKNode()
        for (i, record) in records.enumerated() {
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.fillColor = record.resolvedProfile.primaryColor.uiColor
            dot.strokeColor = .clear
            dot.position = positions[i]
            container.addChild(dot)
        }
        minimapNode?.addChild(container)
        galaxyMinimapContainer = container
    }

    func switchMinimapToUniverse() {
        galaxyMinimapContainer?.removeFromParent()
        galaxyMinimapContainer = nil

        minimapViewport?.alpha = 1
        refreshMinimapDots()
    }
}
