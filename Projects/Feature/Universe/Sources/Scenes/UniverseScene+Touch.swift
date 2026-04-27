import SpriteKit

extension UniverseScene {

    // MARK: - Touch Handling (View coords, correct direction)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard sceneState == .universe || sceneState == .galaxyDetail || sceneState == .recordDetail else { return }
        guard let view = self.view, let all = event?.allTouches else { return }
        let active = all.filter { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }

        if active.count >= 2, (sceneState == .universe || sceneState == .galaxyDetail) {
            let arr = Array(active)
            let p1 = arr[0].location(in: view); let p2 = arr[1].location(in: view)
            pinchStartDist = hypot(p2.x - p1.x, p2.y - p1.y)
            pinchStartScale = cameraNode.xScale
            lastTouchPos = nil; velocity = .zero
            touchStartPos = nil
        } else if let touch = touches.first {
            lastTouchPos = touch.location(in: view)
            touchStartPos = touch.location(in: view)
            touchStartTime = touch.timestamp
            velocity = .zero
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard sceneState == .universe || sceneState == .galaxyDetail else { return }
        guard let view = self.view, let all = event?.allTouches else { return }
        let active = all.filter { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }

        if active.count >= 2, (sceneState == .universe || sceneState == .galaxyDetail) {
            let arr = Array(active)
            let p1 = arr[0].location(in: view); let p2 = arr[1].location(in: view)
            let dist = hypot(p2.x - p1.x, p2.y - p1.y)
            let range: ClosedRange<CGFloat> = (sceneState == .universe)
                ? UniverseTouchMath.universeScaleRange
                : UniverseTouchMath.galaxyDetailScaleRange
            let newScale = UniverseTouchMath.pinchScale(
                startScale: pinchStartScale,
                startDist: pinchStartDist,
                currentDist: dist,
                currentScale: cameraNode.xScale,
                range: range
            )
            cameraNode.setScale(newScale)
        } else if active.count == 1, let touch = active.first {
            let cur = touch.location(in: view)
            if let last = lastTouchPos {
                let result = UniverseTouchMath.panDelta(
                    current: cur,
                    last: last,
                    cameraScale: cameraNode.xScale
                )
                cameraNode.position.x += result.cameraDelta.dx
                cameraNode.position.y += result.cameraDelta.dy
                velocity = result.velocity
            }
            lastTouchPos = cur
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = self.view, let all = event?.allTouches else { return }
        let active = all.filter { $0.phase != .ended && $0.phase != .cancelled }

        if let touch = touches.first, let startPos = touchStartPos,
           active.isEmpty, touches.count == 1 {
            let endPos = touch.location(in: view)
            let dist = hypot(endPos.x - startPos.x, endPos.y - startPos.y)
            let elapsed = touch.timestamp - touchStartTime
            switch UniverseTouchMath.classifyGesture(distance: dist, elapsed: elapsed) {
            case .tap:
                let scenePos = convertPoint(fromView: endPos)
                handleTap(at: scenePos)
            case .swipe:
                if sceneState == .recordDetail {
                    dismissRecordDetail()
                }
            case .none:
                break
            }
        }
        touchStartPos = nil

        if active.isEmpty {
            lastTouchPos = nil; pinchStartDist = 0
        } else if active.count == 1 {
            lastTouchPos = active.first?.location(in: view); pinchStartDist = 0
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPos = nil; pinchStartDist = 0; velocity = .zero; touchStartPos = nil
    }

    // MARK: - Tap → Zoom

    func handleTap(at scenePos: CGPoint) {
        sceneDelegate?.didTapEmptyArea()

        switch sceneState {
        case .universe:
            if let key = hitTestGalaxy(at: scenePos) {
                zoomInToGalaxy(key: key)
            }
        case .galaxyDetail:
            if let starIndex = hitTestDetailStar(at: scenePos),
               starIndex < detailRecords.count {
                showRecordDetail(record: detailRecords[starIndex])
                return
            }
            if let back = backButton {
                let localPos = cameraNode.convert(scenePos, from: self)
                let hitRect = UniverseTouchMath.backButtonHitRect(center: back.position)
                if hitRect.contains(localPos) { zoomOut() }
            }
        case .recordDetail:
            dismissRecordDetail()
        default:
            break
        }
    }

    func hitTestDetailStar(at scenePos: CGPoint) -> Int? {
        var candidates: [UniverseTouchMath.DetailStarHitCandidate] = []
        for node in detailNodes {
            guard let name = node.name, name.hasPrefix("detailStar_"),
                  let index = Int(name.replacingOccurrences(of: "detailStar_", with: "")) else { continue }
            candidates.append(.init(index: index, position: node.position))
        }
        return UniverseTouchMath.hitTestDetailStar(at: scenePos, candidates: candidates)
    }

    func hitTestGalaxy(at scenePos: CGPoint) -> String? {
        let candidates = activeGalaxies.map { key, galaxy in
            UniverseTouchMath.GalaxyHitCandidate(
                key: key,
                position: galaxy.position,
                diameter: galaxy.diameter
            )
        }
        return UniverseTouchMath.hitTestGalaxy(at: scenePos, candidates: candidates)
    }
}
