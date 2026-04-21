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
    private(set) var dustStarNodes: [SKNode] = []
    private(set) var renderedGalaxies: [String: SKNode] = [:]
    private(set) var detailNodes: [SKNode] = []
    private(set) var backButtonNode: SKLabelNode?
    private var isAnimatingZoom = false
    private var zoomedGalaxyKey: String?
    private var lastRenderedStars: [UniverseSceneFeature.DetailStarState] = []

    // Minimap
    private(set) var minimapNode: SKNode?
    private(set) var minimapViewport: SKShapeNode?
    private(set) var minimapDots: [SKNode] = []

    // Solar System
    struct PlanetOrbitData {
        let node: SKNode
        let orbit: CGFloat
        let ellipseRatio: CGFloat
        let period: TimeInterval
        let startAngle: CGFloat
    }

    private(set) var sunNode: SKNode?
    private(set) var planetOrbits: [PlanetOrbitData] = []
    private(set) var planetElapsedTime: TimeInterval = 0

    // MARK: - Shared Shaders

    lazy var galaxyShader: SKShader = {
        let src: String
        if let url = Bundle.main.url(forResource: "Galaxy", withExtension: "fsh"),
           let content = try? String(contentsOf: url) {
            src = content
        } else {
            src = "void main() { gl_FragColor = vec4(0.0); }"
        }
        let s = SKShader(source: src)
        s.attributes = [
            SKAttribute(name: "a_color", type: .vectorFloat4),
            SKAttribute(name: "a_arm_count", type: .float),
            SKAttribute(name: "a_wind", type: .float),
            SKAttribute(name: "a_ellipticity", type: .float),
        ]
        return s
    }()

    lazy var starShader: SKShader = {
        let src: String
        if let url = Bundle.main.url(forResource: "Star", withExtension: "fsh"),
           let content = try? String(contentsOf: url) {
            src = content
        } else {
            src = "void main() { gl_FragColor = vec4(0.0); }"
        }
        let s = SKShader(source: src)
        s.attributes = [SKAttribute(name: "a_color", type: .vectorFloat4)]
        return s
    }()

    lazy var nebulaTexture: SKTexture = {
        let sz: CGFloat = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: sz, height: sz))
        let image = renderer.image { ctx in
            let center = CGPoint(x: sz / 2, y: sz / 2)
            let colors = [
                UIColor.white.withAlphaComponent(1.0).cgColor,
                UIColor.white.withAlphaComponent(0.7).cgColor,
                UIColor.white.withAlphaComponent(0.3).cgColor,
                UIColor.white.withAlphaComponent(0.08).cgColor,
                UIColor.white.withAlphaComponent(0).cgColor,
            ] as CFArray
            let locations: [CGFloat] = [0, 0.2, 0.45, 0.75, 1.0]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: colors, locations: locations)!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                             endCenter: center, endRadius: sz / 2, options: [])
        }
        return SKTexture(image: image)
    }()

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
        setupDustField()
        setupNebulae()
        setupBrightStars()
        setupDistantGalaxies()
        setupSolarSystem()
        setupMinimap()
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
        observe { [weak self] in
            guard let self else { return }
            self.reconcileGalaxies(self.store.galaxies)
        }
        observe { [weak self] in
            guard let self else { return }
            let _ = self.store.galaxies.mapValues { ($0.position, $0.diameter, $0.color) }
            self.refreshMinimapDots()
        }
        observe { [weak self] in
            guard let self else { return }
            self.reconcilePhase(self.store.phase)
        }
        observe { [weak self] in
            guard let self else { return }
            self.reconcileDetailStars(self.store.detailStars)
        }
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : min(currentTime - lastUpdateTime, 0.1)
        lastUpdateTime = currentTime
        guard dt > 0 else { return }
        store.send(.tick(deltaTime: dt))
        updateDustStarVisibility()
        updatePlanetOrbits(deltaTime: dt)
        updateMinimap()
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
        guard !isAnimatingZoom else { return }
        cameraNode.position = camera.position
        cameraNode.setScale(camera.scale)
    }

    private func updateDustStarVisibility() {
        let s = cameraNode.xScale
        let margin: CGFloat = 100
        let halfW = size.width * s / 2 + margin
        let halfH = size.height * s / 2 + margin
        let camX = cameraNode.position.x
        let camY = cameraNode.position.y
        for node in dustStarNodes {
            let dx = abs(node.position.x - camX)
            let dy = abs(node.position.y - camY)
            node.isHidden = dx > halfW || dy > halfH
        }
    }
}
