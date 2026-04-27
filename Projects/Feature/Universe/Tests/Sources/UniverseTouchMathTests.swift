import XCTest
import CoreGraphics
@testable import FeatureUniverse

final class UniverseTouchMathTests: XCTestCase {

    // MARK: - classifyGesture

    func test_classifyGesture_짧은거리_짧은시간이면_tap() {
        XCTAssertEqual(
            UniverseTouchMath.classifyGesture(distance: 5, elapsed: 0.1),
            .tap
        )
    }

    func test_classifyGesture_tap_경계값포함여부_거리10은_tap아님() {
        // 조건이 < 10, < 0.3 이므로 정확히 10은 tap 아님
        XCTAssertEqual(
            UniverseTouchMath.classifyGesture(distance: 10, elapsed: 0.1),
            .none
        )
    }

    func test_classifyGesture_tap_시간초과면_none() {
        XCTAssertEqual(
            UniverseTouchMath.classifyGesture(distance: 5, elapsed: 0.5),
            .none
        )
    }

    func test_classifyGesture_긴거리_짧은시간이면_swipe() {
        XCTAssertEqual(
            UniverseTouchMath.classifyGesture(distance: 80, elapsed: 0.3),
            .swipe
        )
    }

    func test_classifyGesture_swipe_시간초과면_none() {
        XCTAssertEqual(
            UniverseTouchMath.classifyGesture(distance: 80, elapsed: 0.8),
            .none
        )
    }

    func test_classifyGesture_중간거리_none() {
        // tap(10)도 swipe(50)도 아닌 영역
        XCTAssertEqual(
            UniverseTouchMath.classifyGesture(distance: 30, elapsed: 0.2),
            .none
        )
    }

    // MARK: - pinchScale

    func test_pinchScale_startDist_10이하면_현재스케일유지() {
        let s = UniverseTouchMath.pinchScale(
            startScale: 1.0, startDist: 5, currentDist: 50,
            currentScale: 2.0, range: 0.5...3.0
        )
        XCTAssertEqual(s, 2.0)
    }

    func test_pinchScale_currentDist_0이면_현재스케일유지() {
        let s = UniverseTouchMath.pinchScale(
            startScale: 1.0, startDist: 50, currentDist: 0,
            currentScale: 2.0, range: 0.5...3.0
        )
        XCTAssertEqual(s, 2.0)
    }

    func test_pinchScale_두손가락벌리면_스케일감소() {
        // startDist=50 -> currentDist=100 => raw = 1.0 * 0.5 = 0.5 (더 가까이 보이게 = 작은 scale)
        let s = UniverseTouchMath.pinchScale(
            startScale: 1.0, startDist: 50, currentDist: 100,
            currentScale: 1.0, range: 0.5...3.0
        )
        XCTAssertEqual(s, 0.5, accuracy: 0.001)
    }

    func test_pinchScale_두손가락좁히면_스케일증가() {
        // startDist=100 -> currentDist=50 => raw = 1.0 * 2.0 = 2.0
        let s = UniverseTouchMath.pinchScale(
            startScale: 1.0, startDist: 100, currentDist: 50,
            currentScale: 1.0, range: 0.5...3.0
        )
        XCTAssertEqual(s, 2.0, accuracy: 0.001)
    }

    func test_pinchScale_상한초과시_상한으로_클램프() {
        let s = UniverseTouchMath.pinchScale(
            startScale: 2.0, startDist: 100, currentDist: 20,
            currentScale: 1.0, range: 0.5...3.0
        )
        XCTAssertEqual(s, 3.0)
    }

    func test_pinchScale_하한미달시_하한으로_클램프() {
        let s = UniverseTouchMath.pinchScale(
            startScale: 0.5, startDist: 50, currentDist: 500,
            currentScale: 1.0, range: 0.5...3.0
        )
        XCTAssertEqual(s, 0.5)
    }

    // MARK: - panDelta

    func test_panDelta_우측이동시_카메라x음수() {
        // 오른쪽으로 20 이동 -> 월드는 왼쪽으로 20 (카메라 position.x 감소)
        let r = UniverseTouchMath.panDelta(
            current: CGPoint(x: 20, y: 0),
            last: CGPoint(x: 0, y: 0),
            cameraScale: 1.0
        )
        XCTAssertEqual(r.cameraDelta.dx, -20)
        XCTAssertEqual(r.cameraDelta.dy, 0)
        XCTAssertEqual(r.velocity.dx, -20)
    }

    func test_panDelta_아래로이동시_y반전() {
        // view y는 아래증가, SpriteKit y는 위증가. dy가 +10이면 cameraDelta.dy 도 +10 (위로).
        let r = UniverseTouchMath.panDelta(
            current: CGPoint(x: 0, y: 10),
            last: CGPoint(x: 0, y: 0),
            cameraScale: 1.0
        )
        XCTAssertEqual(r.cameraDelta.dy, 10)
    }

    func test_panDelta_카메라스케일_곱해짐() {
        let r = UniverseTouchMath.panDelta(
            current: CGPoint(x: 10, y: 0),
            last: CGPoint(x: 0, y: 0),
            cameraScale: 2.0
        )
        XCTAssertEqual(r.cameraDelta.dx, -20)
    }

    // MARK: - hitTestGalaxy

    func test_hitTestGalaxy_반경내_가까운순으로_선택() {
        let candidates: [UniverseTouchMath.GalaxyHitCandidate] = [
            .init(key: "A", position: CGPoint(x: 0, y: 0), diameter: 100),
            .init(key: "B", position: CGPoint(x: 20, y: 0), diameter: 100),
        ]
        let hit = UniverseTouchMath.hitTestGalaxy(
            at: CGPoint(x: 15, y: 0),
            candidates: candidates
        )
        XCTAssertEqual(hit, "B")
    }

    func test_hitTestGalaxy_반경바깥이면_nil() {
        let candidates: [UniverseTouchMath.GalaxyHitCandidate] = [
            .init(key: "A", position: CGPoint(x: 0, y: 0), diameter: 10),
        ]
        let hit = UniverseTouchMath.hitTestGalaxy(
            at: CGPoint(x: 50, y: 0),
            candidates: candidates
        )
        XCTAssertNil(hit)
    }

    func test_hitTestGalaxy_빈배열이면_nil() {
        XCTAssertNil(UniverseTouchMath.hitTestGalaxy(at: .zero, candidates: []))
    }

    // MARK: - hitTestDetailStar

    func test_hitTestDetailStar_25pt이내_가까운것_선택() {
        let candidates: [UniverseTouchMath.DetailStarHitCandidate] = [
            .init(index: 0, position: CGPoint(x: 0, y: 0)),
            .init(index: 1, position: CGPoint(x: 10, y: 0)),
        ]
        let hit = UniverseTouchMath.hitTestDetailStar(
            at: CGPoint(x: 8, y: 0),
            candidates: candidates
        )
        XCTAssertEqual(hit, 1)
    }

    func test_hitTestDetailStar_25pt_초과면_nil() {
        let candidates: [UniverseTouchMath.DetailStarHitCandidate] = [
            .init(index: 0, position: CGPoint(x: 0, y: 0)),
        ]
        let hit = UniverseTouchMath.hitTestDetailStar(
            at: CGPoint(x: 30, y: 0),
            candidates: candidates
        )
        XCTAssertNil(hit)
    }

    // MARK: - backButtonHitRect

    func test_backButtonHitRect_중심기준_60x44_offset() {
        let rect = UniverseTouchMath.backButtonHitRect(center: CGPoint(x: 100, y: 100))
        XCTAssertEqual(rect, CGRect(x: 85, y: 80, width: 60, height: 44))
    }

    func test_backButtonHitRect_contains_판정() {
        let rect = UniverseTouchMath.backButtonHitRect(center: CGPoint(x: 100, y: 100))
        XCTAssertTrue(rect.contains(CGPoint(x: 90, y: 90)))
        XCTAssertFalse(rect.contains(CGPoint(x: 50, y: 50)))
    }
}
