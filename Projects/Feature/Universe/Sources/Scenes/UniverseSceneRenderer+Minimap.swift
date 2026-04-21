import SpriteKit

extension UniverseSceneRenderer {

    // MARK: - Constants

    private var mmSize: CGFloat { 60 }

    // MARK: - Setup

    func setupMinimap() {
        let node = SKNode()
        node.zPosition = 100
        node.alpha = 0

        let bg = SKShapeNode(rectOf: CGSize(width: mmSize, height: mmSize), cornerRadius: 4)
        bg.fillColor = UIColor(white: 0, alpha: 0.5)
        bg.strokeColor = UIColor(white: 1, alpha: 0.15)
        bg.lineWidth = 0.5
        node.addChild(bg)

        let vp = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
        vp.fillColor = UIColor(white: 1, alpha: 0.08)
        vp.strokeColor = UIColor(white: 1, alpha: 0.5)
        vp.lineWidth = 0.5
        node.addChild(vp)
        minimapViewport = vp

        cameraNode.addChild(node)
        minimapNode = node
    }

    // MARK: - Dots Refresh

    func refreshMinimapDots() {
        for dot in minimapDots { dot.removeFromParent() }
        minimapDots.removeAll()
        guard let minimapNode else { return }

        let ws = UniverseSceneFeature.CameraState.worldSize
        let sc = mmSize / ws.width

        for (_, galaxy) in store.galaxies {
            let dot = SKShapeNode(circleOfRadius: max(1.5, galaxy.diameter * sc * 0.3))
            dot.fillColor = galaxy.color.uiColor
            dot.strokeColor = .clear
            dot.position = CGPoint(
                x: (galaxy.position.x - ws.width / 2) * sc,
                y: (galaxy.position.y - ws.height / 2) * sc
            )
            minimapNode.addChild(dot)
            minimapDots.append(dot)
        }
    }

    // MARK: - Update (called every frame from update loop)

    func updateMinimap() {
        guard let minimapNode, let minimapViewport else { return }

        let cam = store.camera
        let isTouching = store.touch.lastPoint != nil || store.touch.pinchStartDist > 0
        let hasVelocity = abs(cam.velocity.dx) > 0.05 || abs(cam.velocity.dy) > 0.05
        let isActive = isTouching || hasVelocity

        if minimapNode.alpha < 0.01 && !isActive { return }

        let margin: CGFloat = 20
        let tabBarHeight: CGFloat = 90
        minimapNode.position = CGPoint(
            x: -size.width / 2 + margin + mmSize / 2,
            y: -size.height / 2 + margin + mmSize / 2 + tabBarHeight
        )

        switch store.phase {
        case let .galaxyDetail(galaxyKey):
            guard let galaxy = store.galaxies[galaxyKey] else { return }
            for dot in minimapDots { dot.isHidden = true }

            let detailExtent: CGFloat = 150
            let sc = (mmSize / 2) / detailExtent

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

            minimapViewport.path = CGPath(
                rect: CGRect(x: -clampW / 2, y: -clampH / 2, width: clampW, height: clampH),
                transform: nil
            )
            minimapViewport.position = CGPoint(x: cx, y: cy)

            let target: CGFloat = isActive ? 0.8 : 0
            minimapNode.alpha += (target - minimapNode.alpha) * 0.1

        case .universe:
            for dot in minimapDots { dot.isHidden = false }
            let ws = UniverseSceneFeature.CameraState.worldSize
            let sc = mmSize / ws.width
            let s = cameraNode.xScale
            let vpW = size.width * s * sc
            let vpH = size.height * s * sc
            minimapViewport.path = CGPath(
                rect: CGRect(x: -vpW / 2, y: -vpH / 2, width: vpW, height: vpH),
                transform: nil
            )
            minimapViewport.position = CGPoint(
                x: (cameraNode.position.x - ws.width / 2) * sc,
                y: (cameraNode.position.y - ws.height / 2) * sc
            )

            let universeThreshold = abs(cam.velocity.dx) > 0.5 || abs(cam.velocity.dy) > 0.5
            let target: CGFloat = (isTouching || universeThreshold) ? 0.8 : 0
            minimapNode.alpha += (target - minimapNode.alpha) * 0.1

        default:
            minimapNode.alpha += (0 - minimapNode.alpha) * 0.1
        }
    }
}
