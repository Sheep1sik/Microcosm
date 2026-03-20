import SpriteKit
import DomainEntity

extension ConstellationScene {

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard sceneState == .overview || sceneState == .constellationDetail else { return }
        guard let view = self.view, let all = event?.allTouches else { return }
        let active = all.filter { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }

        if active.count >= 2 {
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
        guard sceneState == .overview || sceneState == .constellationDetail else { return }
        guard let view = self.view, let all = event?.allTouches else { return }
        let active = all.filter { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }

        if active.count >= 2 {
            let arr = Array(active)
            let p1 = arr[0].location(in: view); let p2 = arr[1].location(in: view)
            let dist = hypot(p2.x - p1.x, p2.y - p1.y)
            if pinchStartDist > 10 {
                let newScale = pinchStartScale * (pinchStartDist / dist)
                if sceneState == .constellationDetail {
                    // 디테일: 줌인만 가능 (줌아웃 한계 = 진입 시 스케일)
                    cameraNode.setScale(max(0.03, min(detailMaxScale, newScale)))
                } else {
                    cameraNode.setScale(max(0.5, min(3.0, newScale)))
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
                if sceneState == .overview {
                    velocity = CGVector(dx: -dx * s, dy: dy * s)
                }
            }
            lastTouchPos = cur
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = self.view, let all = event?.allTouches else { return }
        let active = all.filter { $0.phase != .ended && $0.phase != .cancelled }

        // 탭 판정
        if let touch = touches.first, let startPos = touchStartPos,
           active.isEmpty, touches.count == 1 {
            let endPos = touch.location(in: view)
            let dist = hypot(endPos.x - startPos.x, endPos.y - startPos.y)
            let elapsed = touch.timestamp - touchStartTime
            if dist < 10 && elapsed < 0.3 {
                let scenePos = convertPoint(fromView: endPos)
                handleTap(at: scenePos)
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

    // MARK: - Tap Handling

    func handleTap(at scenePos: CGPoint) {
        sceneDelegate?.didTapEmptyArea()

        switch sceneState {
        case .overview:
            if let id = hitTestConstellation(at: scenePos) {
                zoomInToConstellation(id: id)
            }
        case .constellationDetail:
            // 먼저 뒤로가기 버튼 체크
            if let back = backButton {
                let localPos = cameraNode.convert(scenePos, from: self)
                let hitRect = CGRect(x: back.position.x - 15, y: back.position.y - 20,
                                     width: 60, height: 44)
                if hitRect.contains(localPos) {
                    zoomOut()
                    return
                }
            }
            // 별 탭 체크
            if let (constellationId, starIndex) = hitTestStar(at: scenePos) {
                sceneDelegate?.didTapStar(constellationId: constellationId, starIndex: starIndex)
                return
            }
        default:
            break
        }
    }

    // MARK: - Hit Testing

    func hitTestConstellation(at scenePos: CGPoint) -> String? {
        let spans = ConstellationCatalog.constellationSpans

        var bestId: String?
        var bestDist: CGFloat = .greatestFiniteMagnitude

        for (id, rendered) in renderedConstellations {
            let span = spans[id] ?? ConstellationCatalog.defaultSpan
            let hitRadius = span * 0.6
            let pos = rendered.containerNode.position
            let dist = hypot(scenePos.x - pos.x, scenePos.y - pos.y)
            if dist < hitRadius && dist < bestDist {
                bestDist = dist
                bestId = id
            }
        }
        return bestId
    }

    func hitTestStar(at scenePos: CGPoint) -> (constellationId: String, starIndex: Int)? {
        guard let constellationId = currentConstellationId,
              let rendered = renderedConstellations[constellationId] else { return nil }

        let containerPos = rendered.containerNode.position
        var bestIndex: Int?
        var bestDist: CGFloat = .greatestFiniteMagnitude

        for (i, starNode) in rendered.starNodes.enumerated() {
            let worldPos = CGPoint(
                x: containerPos.x + starNode.position.x,
                y: containerPos.y + starNode.position.y
            )
            let dist = hypot(scenePos.x - worldPos.x, scenePos.y - worldPos.y)
            // 줌인 상태이므로 히트 영역은 작게 (15pt)
            if dist < 15 && dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        if let index = bestIndex {
            return (constellationId, index)
        }
        return nil
    }
}
