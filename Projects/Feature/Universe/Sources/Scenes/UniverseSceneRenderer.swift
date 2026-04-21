import SpriteKit
import ComposableArchitecture
import SharedDesignSystem

// MARK: - UniverseSceneRenderer (SKScene 순수 렌더러)
//
// Store 를 관찰하여 SKNode 를 업데이트한다.
// 로직은 UniverseSceneFeature Reducer 에 위임하고,
// 이 클래스는 "그리기"만 한다.
//
// 설계 문서: _workspace/02_architect_design.md §4.4.4

@MainActor
final class UniverseSceneRenderer: SKScene {
    private let store: StoreOf<UniverseSceneFeature>
    private var lastUpdateTime: TimeInterval = 0

    override var isPaused: Bool {
        get { super.isPaused }
        set { /* SwiftUI 의 자동 pause 무시 */ }
    }

    // MARK: - Nodes

    private let cameraNode = SKCameraNode()

    // MARK: - Init

    init(store: StoreOf<UniverseSceneFeature>) {
        self.store = store
        super.init(size: .zero)
        scaleMode = .resizeFill
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        backgroundColor = AppColors.sceneBackground
        setupCamera()
        setupObservation()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        store.send(.viewportResized(size))
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        let initial = store.camera
        cameraNode.position = initial.position
        cameraNode.setScale(initial.scale)
        addChild(cameraNode)
        camera = cameraNode
    }

    // MARK: - Observation

    private func setupObservation() {
        observe { [weak self] in
            guard let self else { return }
            self.reconcileCamera(self.store.camera)
        }
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : min(currentTime - lastUpdateTime, 0.1)
        lastUpdateTime = currentTime
        guard dt > 0 else { return }
        store.send(.tick(deltaTime: dt))
    }

    // MARK: - Touch Forwarding

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let allTouches = event?.allTouches else { return }
        let active = allTouches.filter { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }

        if active.count >= 2 {
            let arr = Array(active)
            let p1 = arr[0].location(in: view)
            let p2 = arr[1].location(in: view)
            let dist = hypot(p2.x - p1.x, p2.y - p1.y)
            store.send(.touch(.beganPinch(distance: dist)))
        } else if let touch = touches.first {
            let viewPoint = touch.location(in: view)
            store.send(.touch(.beganSingle(viewPoint: viewPoint, timestamp: touch.timestamp)))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let allTouches = event?.allTouches else { return }
        let active = allTouches.filter { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }

        if active.count >= 2 {
            let arr = Array(active)
            let p1 = arr[0].location(in: view)
            let p2 = arr[1].location(in: view)
            let dist = hypot(p2.x - p1.x, p2.y - p1.y)
            store.send(.touch(.movedPinch(distance: dist)))
        } else if let touch = active.first {
            let viewPoint = touch.location(in: view)
            store.send(.touch(.movedSingle(viewPoint: viewPoint)))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let allTouches = event?.allTouches else { return }
        let active = allTouches.filter { $0.phase != .ended && $0.phase != .cancelled }

        if active.isEmpty, let touch = touches.first, touches.count == 1 {
            let viewPoint = touch.location(in: view)
            let scenePoint = convertPoint(fromView: viewPoint)
            store.send(.touch(.ended(viewPoint: viewPoint, scenePoint: scenePoint, timestamp: touch.timestamp)))
        } else if active.count == 1, let remaining = active.first {
            let viewPoint = remaining.location(in: view)
            store.send(.touch(.beganSingle(viewPoint: viewPoint, timestamp: remaining.timestamp)))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        store.send(.touch(.cancelled))
    }

    // MARK: - Reconcile (State → SKNode)

    private func reconcileCamera(_ camera: UniverseSceneFeature.CameraState) {
        cameraNode.position = camera.position
        cameraNode.setScale(camera.scale)
    }
}
