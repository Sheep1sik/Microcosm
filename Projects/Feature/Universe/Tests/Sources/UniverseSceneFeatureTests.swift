import XCTest
import ComposableArchitecture
@testable import FeatureUniverse

@MainActor
final class UniverseSceneFeatureTests: XCTestCase {

    // MARK: - Initial State

    func test_초기상태_universe_phase() {
        let state = UniverseSceneFeature.State()
        XCTAssertEqual(state.phase, .universe)
        XCTAssertEqual(state.camera, .initial)
        XCTAssertTrue(state.needsInitialFocus)
        XCTAssertTrue(state.galaxies.isEmpty)
    }

    // MARK: - Camera Inertia (universe)

    func test_tick_universe_velocity적용_friction감쇠() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                camera: UniverseSceneFeature.CameraState(
                    position: CGPoint(x: 2000, y: 2000),
                    scale: 1.0,
                    velocity: CGVector(dx: 10, dy: 10)
                ),
                viewportSize: CGSize(width: 100, height: 100)
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.tick(deltaTime: 1.0 / 60.0)) {
            $0.camera.position.x = 2010
            $0.camera.position.y = 2010
            $0.camera.velocity.dx = 10 * 0.92
            $0.camera.velocity.dy = 10 * 0.92
        }
    }

    func test_tick_universe_낮은velocity_관성무시_velocity영점화() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                camera: UniverseSceneFeature.CameraState(
                    position: CGPoint(x: 2000, y: 2000),
                    scale: 1.0,
                    velocity: CGVector(dx: 0.05, dy: 0.05)
                ),
                viewportSize: CGSize(width: 100, height: 100)
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.tick(deltaTime: 1.0 / 60.0)) {
            $0.camera.velocity = .zero
        }
    }

    func test_tick_universe_경계클램핑() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                camera: UniverseSceneFeature.CameraState(
                    position: CGPoint(x: -100, y: 5000),
                    scale: 1.0,
                    velocity: .zero
                ),
                viewportSize: CGSize(width: 200, height: 200)
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.tick(deltaTime: 1.0 / 60.0)) {
            $0.camera.position.x = 100
            $0.camera.position.y = 3900
        }
    }

    func test_tick_universe_터치중_관성비적용() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                camera: UniverseSceneFeature.CameraState(
                    position: CGPoint(x: 2000, y: 2000),
                    scale: 1.0,
                    velocity: CGVector(dx: 10, dy: 10)
                ),
                touch: UniverseSceneFeature.TouchState(lastPoint: CGPoint(x: 100, y: 100)),
                viewportSize: CGSize(width: 100, height: 100)
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.tick(deltaTime: 1.0 / 60.0))
    }

    // MARK: - Camera Inertia (galaxyDetail)

    func test_tick_galaxyDetail_friction088() async {
        let galaxy = UniverseSceneFeature.GalaxyNodeState(
            yearMonth: "2026-04",
            position: CGPoint(x: 1000, y: 1000)
        )
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                phase: .galaxyDetail(galaxyKey: "2026-04"),
                camera: UniverseSceneFeature.CameraState(
                    position: CGPoint(x: 1000, y: 1000),
                    scale: 0.1,
                    velocity: CGVector(dx: 5, dy: 5)
                ),
                galaxies: ["2026-04": galaxy]
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.tick(deltaTime: 1.0 / 60.0)) {
            $0.camera.position.x = 1005
            $0.camera.position.y = 1005
            $0.camera.velocity.dx = 5 * 0.88
            $0.camera.velocity.dy = 5 * 0.88
        }
    }

    func test_tick_galaxyDetail_maxDrift_클램핑() async {
        let galaxy = UniverseSceneFeature.GalaxyNodeState(
            yearMonth: "2026-04",
            position: CGPoint(x: 1000, y: 1000)
        )
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                phase: .galaxyDetail(galaxyKey: "2026-04"),
                camera: UniverseSceneFeature.CameraState(
                    position: CGPoint(x: 1000, y: 1000),
                    scale: 0.1,
                    velocity: CGVector(dx: 200, dy: 0)
                ),
                galaxies: ["2026-04": galaxy]
            )
        ) {
            UniverseSceneFeature()
        }

        // velocity 200 적용 → position.x = 1200 → drift = 200 > 150 → 클램핑
        await store.send(.tick(deltaTime: 1.0 / 60.0)) {
            $0.camera.position.x = 1200
            $0.camera.velocity.dx = 200 * 0.88
            $0.camera.velocity.dy = 0 * 0.88
            // clamp: dist = 200, ratio = 150/200 = 0.75
            // x = 1000 + 200 * 0.75 = 1150
            $0.camera.position.x = 1150
            $0.camera.velocity = .zero
        }
    }

    // MARK: - No-op Phases

    func test_tick_zoomingIn_변경없음() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                phase: .zoomingIn(galaxyKey: "2026-04"),
                camera: .init(position: .init(x: 1000, y: 1000), scale: 1.0, velocity: .init(dx: 10, dy: 10))
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.tick(deltaTime: 1.0 / 60.0))
    }

    func test_tick_zoomingOut_변경없음() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                phase: .zoomingOut,
                camera: .init(position: .init(x: 1000, y: 1000), scale: 1.0, velocity: .init(dx: 10, dy: 10))
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.tick(deltaTime: 1.0 / 60.0))
    }

    // MARK: - CameraState

    func test_cameraState_initial_값확인() {
        let initial = UniverseSceneFeature.CameraState.initial
        XCTAssertEqual(initial.position, CGPoint(x: 2000, y: 2000))
        XCTAssertEqual(initial.scale, 2.0)
        XCTAssertEqual(initial.velocity, .zero)
    }

    func test_cameraState_worldSize() {
        let ws = UniverseSceneFeature.CameraState.worldSize
        XCTAssertEqual(ws.width, 4000)
        XCTAssertEqual(ws.height, 4000)
    }

    // MARK: - Touch: Single Pan

    func test_touch_beganSingle_시작점기록_velocity초기화() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                camera: .init(position: .init(x: 2000, y: 2000), scale: 1.0, velocity: .init(dx: 5, dy: 5))
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.touch(.beganSingle(viewPoint: CGPoint(x: 200, y: 300), timestamp: 1.0))) {
            $0.touch.startPoint = CGPoint(x: 200, y: 300)
            $0.touch.startTime = 1.0
            $0.touch.lastPoint = CGPoint(x: 200, y: 300)
            $0.camera.velocity = .zero
        }
    }

    func test_touch_movedSingle_panDelta적용() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                camera: .init(position: .init(x: 2000, y: 2000), scale: 1.0, velocity: .zero),
                touch: .init(startPoint: .init(x: 200, y: 300), startTime: 1.0, lastPoint: .init(x: 200, y: 300))
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.touch(.movedSingle(viewPoint: CGPoint(x: 210, y: 305)))) {
            $0.camera.position.x = 2000 + (-10 * 1.0)
            $0.camera.position.y = 2000 + (5 * 1.0)
            $0.camera.velocity = CGVector(dx: -10, dy: 5)
            $0.touch.lastPoint = CGPoint(x: 210, y: 305)
        }
    }

    func test_touch_movedSingle_zoomingIn단계_무시() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                phase: .zoomingIn(galaxyKey: "2026-04"),
                touch: .init(lastPoint: .init(x: 200, y: 300))
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.touch(.movedSingle(viewPoint: CGPoint(x: 210, y: 300))))
    }

    // MARK: - Touch: Pinch

    func test_touch_beganPinch_시작거리_스케일기록() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                camera: .init(position: .init(x: 2000, y: 2000), scale: 1.5, velocity: .init(dx: 3, dy: 3)),
                touch: .init(startPoint: .init(x: 100, y: 100), startTime: 1.0, lastPoint: .init(x: 100, y: 100))
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.touch(.beganPinch(distance: 200))) {
            $0.touch.pinchStartDist = 200
            $0.touch.pinchStartScale = 1.5
            $0.touch.lastPoint = nil
            $0.touch.startPoint = nil
            $0.camera.velocity = .zero
        }
    }

    func test_touch_movedPinch_universe_스케일변경() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                camera: .init(position: .init(x: 2000, y: 2000), scale: 1.5, velocity: .zero),
                touch: .init(pinchStartDist: 200, pinchStartScale: 1.5)
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.touch(.movedPinch(distance: 100))) {
            $0.camera.scale = 3.0
        }
    }

    func test_touch_movedPinch_galaxyDetail_스케일범위() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                phase: .galaxyDetail(galaxyKey: "2026-04"),
                camera: .init(position: .init(x: 1000, y: 1000), scale: 0.1, velocity: .zero),
                touch: .init(pinchStartDist: 200, pinchStartScale: 0.1)
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.touch(.movedPinch(distance: 400))) {
            $0.camera.scale = 0.06
        }
    }

    // MARK: - Touch: Ended (Gesture Classification + Hit Test)

    func test_touch_ended_tap_은하히트_delegate발행() async {
        let galaxy = UniverseSceneFeature.GalaxyNodeState(
            yearMonth: "2026-04",
            position: CGPoint(x: 1500, y: 2500),
            diameter: 100
        )
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                touch: .init(startPoint: .init(x: 200, y: 300), startTime: 1.0, lastPoint: .init(x: 200, y: 300)),
                galaxies: ["2026-04": galaxy]
            )
        ) {
            UniverseSceneFeature()
        }

        // scenePoint가 은하 반경 내 → tappedGalaxy
        await store.send(.touch(.ended(
            viewPoint: CGPoint(x: 203, y: 304),
            scenePoint: CGPoint(x: 1510, y: 2510),
            timestamp: 1.1
        ))) {
            $0.touch.startPoint = nil
            $0.touch.lastPoint = nil
            $0.touch.pinchStartDist = 0
        }
        await store.receive(.delegate(.tappedGalaxy(key: "2026-04")))
    }

    func test_touch_ended_tap_빈영역_delegate발행() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                touch: .init(startPoint: .init(x: 200, y: 300), startTime: 1.0, lastPoint: .init(x: 200, y: 300))
            )
        ) {
            UniverseSceneFeature()
        }

        // 은하 없음 → tappedEmptyArea
        await store.send(.touch(.ended(
            viewPoint: CGPoint(x: 203, y: 304),
            scenePoint: CGPoint(x: 1500, y: 2500),
            timestamp: 1.1
        ))) {
            $0.touch.startPoint = nil
            $0.touch.lastPoint = nil
            $0.touch.pinchStartDist = 0
        }
        await store.receive(.delegate(.tappedEmptyArea(scenePoint: CGPoint(x: 1500, y: 2500))))
    }

    func test_touch_ended_swipe_delegate발행() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                touch: .init(startPoint: .init(x: 200, y: 300), startTime: 1.0, lastPoint: .init(x: 200, y: 300))
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.touch(.ended(
            viewPoint: CGPoint(x: 260, y: 300),
            scenePoint: CGPoint(x: 1500, y: 2500),
            timestamp: 1.3
        ))) {
            $0.touch.startPoint = nil
            $0.touch.lastPoint = nil
            $0.touch.pinchStartDist = 0
        }
        await store.receive(.delegate(.swiped))
    }

    func test_touch_ended_none_delegate없음() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                touch: .init(startPoint: .init(x: 200, y: 300), startTime: 1.0, lastPoint: .init(x: 200, y: 300))
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.touch(.ended(
            viewPoint: CGPoint(x: 230, y: 300),
            scenePoint: CGPoint(x: 1500, y: 2500),
            timestamp: 1.5
        ))) {
            $0.touch.startPoint = nil
            $0.touch.lastPoint = nil
            $0.touch.pinchStartDist = 0
        }
    }

    func test_touch_ended_startPoint없으면_분류안함() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                touch: .init(lastPoint: .init(x: 200, y: 300))
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.touch(.ended(
            viewPoint: CGPoint(x: 200, y: 300),
            scenePoint: CGPoint(x: 1500, y: 2500),
            timestamp: 1.1
        ))) {
            $0.touch.lastPoint = nil
            $0.touch.pinchStartDist = 0
        }
    }

    // MARK: - Touch: Cancelled

    func test_touch_cancelled_전체초기화() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(
                camera: .init(position: .init(x: 2000, y: 2000), scale: 1.0, velocity: .init(dx: 5, dy: 5)),
                touch: .init(startPoint: .init(x: 100, y: 100), startTime: 1.0, lastPoint: .init(x: 150, y: 150), pinchStartDist: 200, pinchStartScale: 1.5)
            )
        ) {
            UniverseSceneFeature()
        }

        await store.send(.touch(.cancelled)) {
            $0.touch = UniverseSceneFeature.TouchState()
            $0.camera.velocity = .zero
        }
    }

    // MARK: - Viewport Resize

    func test_viewportResized_크기반영() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State()
        ) {
            UniverseSceneFeature()
        }

        await store.send(.viewportResized(CGSize(width: 428, height: 926))) {
            $0.viewportSize = CGSize(width: 428, height: 926)
        }
    }

    // MARK: - Galaxies

    func test_galaxiesUpdated_은하반영() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(needsInitialFocus: false)
        ) {
            UniverseSceneFeature()
        }

        let galaxy = UniverseSceneFeature.GalaxyNodeState(
            yearMonth: "2026-04",
            position: CGPoint(x: 1200, y: 3000),
            diameter: 120
        )
        await store.send(.galaxiesUpdated(["2026-04": galaxy])) {
            $0.galaxies = ["2026-04": galaxy]
        }
    }

    func test_galaxiesUpdated_initialFocus_현재월로_카메라이동() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(needsInitialFocus: true)
        ) {
            UniverseSceneFeature()
        }

        let cal = Calendar.current
        let now = Date()
        let currentKey = String(format: "%04d-%02d",
                                cal.component(.year, from: now),
                                cal.component(.month, from: now))
        let galaxy = UniverseSceneFeature.GalaxyNodeState(
            yearMonth: currentKey,
            position: CGPoint(x: 1500, y: 2800)
        )
        await store.send(.galaxiesUpdated([currentKey: galaxy])) {
            $0.galaxies = [currentKey: galaxy]
            $0.camera.position = CGPoint(x: 1500, y: 2800)
            $0.needsInitialFocus = false
        }
    }

    func test_galaxiesUpdated_initialFocus_현재월없으면_포커스안함() async {
        let store = TestStore(
            initialState: UniverseSceneFeature.State(needsInitialFocus: true)
        ) {
            UniverseSceneFeature()
        }

        let galaxy = UniverseSceneFeature.GalaxyNodeState(
            yearMonth: "2025-01",
            position: CGPoint(x: 800, y: 800)
        )
        await store.send(.galaxiesUpdated(["2025-01": galaxy])) {
            $0.galaxies = ["2025-01": galaxy]
            // 현재월이 아니므로 카메라 이동 없음, needsInitialFocus 유지
        }
    }

    // MARK: - GalaxyNodeState

    func test_galaxyNodeState_id는_yearMonth() {
        let galaxy = UniverseSceneFeature.GalaxyNodeState(
            yearMonth: "2026-04",
            position: .zero
        )
        XCTAssertEqual(galaxy.id, "2026-04")
    }
}
