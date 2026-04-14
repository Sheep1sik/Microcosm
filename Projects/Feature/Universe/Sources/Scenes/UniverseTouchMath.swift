import CoreGraphics
import Foundation

/// UniverseScene 의 터치/핏테스트 계산을 분리한 순수 함수 모음.
/// SpriteKit/UIKit 의존 없이 값 기반으로만 동작하여 단위 테스트가 가능하다.
enum UniverseTouchMath {

    // MARK: - Tap / Swipe 분류

    struct TapClassifierThresholds {
        let tapMaxDistance: CGFloat
        let tapMaxElapsed: TimeInterval
        let swipeMinDistance: CGFloat
        let swipeMaxElapsed: TimeInterval

        static let `default` = TapClassifierThresholds(
            tapMaxDistance: 10,
            tapMaxElapsed: 0.3,
            swipeMinDistance: 50,
            swipeMaxElapsed: 0.6
        )
    }

    enum TouchGesture: Equatable {
        case tap
        case swipe
        case none
    }

    /// 시작점 → 끝점 사이의 거리/시간을 기반으로 제스처를 분류.
    static func classifyGesture(
        distance: CGFloat,
        elapsed: TimeInterval,
        thresholds: TapClassifierThresholds = .default
    ) -> TouchGesture {
        if distance < thresholds.tapMaxDistance && elapsed < thresholds.tapMaxElapsed {
            return .tap
        }
        if distance > thresholds.swipeMinDistance && elapsed < thresholds.swipeMaxElapsed {
            return .swipe
        }
        return .none
    }

    // MARK: - Pinch Zoom

    /// Universe 뷰의 줌 허용 범위.
    static let universeScaleRange: ClosedRange<CGFloat> = 0.5...3.0
    /// Galaxy detail 뷰의 줌 허용 범위.
    static let galaxyDetailScaleRange: ClosedRange<CGFloat> = 0.06...0.35

    /// 두 손가락 거리 비율로 카메라 스케일을 계산하고 허용 범위로 클램프한다.
    /// startDist 가 너무 작아 노이즈가 예상되는 경우(10 이하) 기존 scale 을 유지한다.
    static func pinchScale(
        startScale: CGFloat,
        startDist: CGFloat,
        currentDist: CGFloat,
        currentScale: CGFloat,
        range: ClosedRange<CGFloat>
    ) -> CGFloat {
        guard startDist > 10, currentDist > 0 else { return currentScale }
        let raw = startScale * (startDist / currentDist)
        return min(max(raw, range.lowerBound), range.upperBound)
    }

    // MARK: - Pan Delta

    struct PanResult: Equatable {
        let cameraDelta: CGVector
        let velocity: CGVector
    }

    /// 터치 이동량을 카메라 이동량과 velocity 로 변환.
    /// 화면 좌표계(y 아래 증가)를 SpriteKit 좌표계(y 위 증가)로 변환하며,
    /// 카메라 스케일을 곱해 월드 좌표로 매핑한다.
    static func panDelta(
        current: CGPoint,
        last: CGPoint,
        cameraScale: CGFloat
    ) -> PanResult {
        let dx = current.x - last.x
        let dy = current.y - last.y
        return PanResult(
            cameraDelta: CGVector(dx: -dx * cameraScale, dy: dy * cameraScale),
            velocity: CGVector(dx: -dx * cameraScale, dy: dy * cameraScale)
        )
    }

    // MARK: - Hit Test

    struct GalaxyHitCandidate {
        let key: String
        let position: CGPoint
        let diameter: CGFloat
    }

    /// tap 좌표와 가장 가까운 갤럭시 키를 반환. diameter 반경 바깥이면 nil.
    static func hitTestGalaxy(
        at point: CGPoint,
        candidates: [GalaxyHitCandidate]
    ) -> String? {
        var best: String?
        var bestDist = CGFloat.greatestFiniteMagnitude
        for candidate in candidates {
            let dist = hypot(point.x - candidate.position.x, point.y - candidate.position.y)
            if dist < candidate.diameter && dist < bestDist {
                bestDist = dist
                best = candidate.key
            }
        }
        return best
    }

    struct DetailStarHitCandidate {
        let index: Int
        let position: CGPoint
    }

    /// tap 좌표와 가장 가까운 detailStar 인덱스를 반환. 25pt 바깥이면 nil.
    static func hitTestDetailStar(
        at point: CGPoint,
        candidates: [DetailStarHitCandidate],
        maxDistance: CGFloat = 25
    ) -> Int? {
        var best: Int?
        var bestDist = CGFloat.greatestFiniteMagnitude
        for candidate in candidates {
            let dist = hypot(point.x - candidate.position.x, point.y - candidate.position.y)
            if dist < maxDistance && dist < bestDist {
                bestDist = dist
                best = candidate.index
            }
        }
        return best
    }

    /// back button 중심 기준으로 `(x-15, y-20, 60, 44)` 히트 영역 체크.
    static func backButtonHitRect(center: CGPoint) -> CGRect {
        CGRect(x: center.x - 15, y: center.y - 20, width: 60, height: 44)
    }
}
