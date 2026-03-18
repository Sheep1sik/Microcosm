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
            if pinchStartDist > 10 {
                let newScale = pinchStartScale * (pinchStartDist / dist)
                if sceneState == .universe {
                    cameraNode.setScale(max(0.5, min(3.0, newScale)))
                } else {
                    cameraNode.setScale(max(0.06, min(0.35, newScale)))
                }
            }
        } else if active.count == 1, let touch = active.first {
            let cur = touch.location(in: view)
            if let last = lastTouchPos {
                let dx = cur.x - last.x
                let dy = cur.y - last.y
                let s = cameraNode.xScale
                cameraNode.position.x -= dx * s
                cameraNode.position.y += dy * s
                velocity = CGVector(dx: -dx * s, dy: dy * s)
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
            if dist < 10 && elapsed < 0.3 {
                let scenePos = convertPoint(fromView: endPos)
                handleTap(at: scenePos)
            } else if dist > 50 && elapsed < 0.6 {
                if sceneState == .recordDetail {
                    dismissRecordDetail()
                }
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
        // 어디를 탭하든 키보드 내리기
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
                let hitRect = CGRect(x: back.position.x - 15, y: back.position.y - 20,
                                     width: 60, height: 44)
                if hitRect.contains(localPos) { zoomOut() }
            }
        case .recordDetail:
            dismissRecordDetail()
        default:
            break
        }
    }

    func hitTestDetailStar(at scenePos: CGPoint) -> Int? {
        var bestIndex: Int?
        var bestDist: CGFloat = .greatestFiniteMagnitude
        for node in detailNodes {
            guard let name = node.name, name.hasPrefix("detailStar_") else { continue }
            let dist = hypot(scenePos.x - node.position.x, scenePos.y - node.position.y)
            if dist < 25 && dist < bestDist {
                bestDist = dist
                bestIndex = Int(name.replacingOccurrences(of: "detailStar_", with: ""))
            }
        }
        return bestIndex
    }

    func hitTestGalaxy(at scenePos: CGPoint) -> String? {
        var bestKey: String?
        var bestDist: CGFloat = .greatestFiniteMagnitude
        for (key, galaxy) in activeGalaxies {
            let dist = hypot(scenePos.x - galaxy.position.x, scenePos.y - galaxy.position.y)
            if dist < galaxy.diameter && dist < bestDist {
                bestDist = dist
                bestKey = key
            }
        }
        return bestKey
    }
}
