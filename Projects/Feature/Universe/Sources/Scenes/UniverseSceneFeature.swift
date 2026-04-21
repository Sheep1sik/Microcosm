import ComposableArchitecture
import CoreGraphics
import Foundation

// MARK: - UniverseSceneFeature (SpriteKit 상태 Reducer)
//
// 기존 UniverseScene 의 "로직 상태"를 TCA Reducer 로 끌어올린다.
// SKNode 레퍼런스는 여기에 두지 않는다 — 순수 값 기반.
// 시각 장식(파티클, 반짝임, 배경 별)은 Renderer 자치권.
//
// 설계 문서: _workspace/02_architect_design.md §4.4

@Reducer
public struct UniverseSceneFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
        public var phase: ScenePhase = .universe
        public var camera: CameraState = .initial
        public var touch: TouchState = .init()
        public var galaxies: [String: GalaxyNodeState] = [:]
        public var viewportSize: CGSize = CGSize(width: 390, height: 844)
        public var needsInitialFocus: Bool = true
        public var detailStars: [DetailStarState] = []

        public init(
            phase: ScenePhase = .universe,
            camera: CameraState = .initial,
            touch: TouchState = .init(),
            galaxies: [String: GalaxyNodeState] = [:],
            viewportSize: CGSize = CGSize(width: 390, height: 844),
            needsInitialFocus: Bool = true,
            detailStars: [DetailStarState] = []
        ) {
            self.phase = phase
            self.camera = camera
            self.touch = touch
            self.galaxies = galaxies
            self.viewportSize = viewportSize
            self.needsInitialFocus = needsInitialFocus
            self.detailStars = detailStars
        }
    }

    // MARK: - ScenePhase

    public enum ScenePhase: Equatable, Sendable {
        case universe
        case zoomingIn(galaxyKey: String)
        case galaxyDetail(galaxyKey: String)
        case recordDetail(galaxyKey: String, recordIndex: Int)
        case zoomingOut
    }

    // MARK: - GalaxyNodeState

    public struct GalaxyNodeState: Equatable, Sendable, Identifiable {
        public var id: String { yearMonth }

        public let yearMonth: String
        public let position: CGPoint
        public let arms: Int
        public let tilt: CGFloat
        public let wind: CGFloat
        public let ellipticity: CGFloat
        public var recordCount: Int
        public var diameter: CGFloat
        public var color: RGBA

        public init(
            yearMonth: String,
            position: CGPoint,
            arms: Int = 3,
            tilt: CGFloat = 0,
            wind: CGFloat = 0.5,
            ellipticity: CGFloat = 0.5,
            recordCount: Int = 0,
            diameter: CGFloat = 100,
            color: RGBA = .white
        ) {
            self.yearMonth = yearMonth
            self.position = position
            self.arms = arms
            self.tilt = tilt
            self.wind = wind
            self.ellipticity = ellipticity
            self.recordCount = recordCount
            self.diameter = diameter
            self.color = color
        }
    }

    // MARK: - RGBA (UIColor 대체 — Sendable/Equatable)

    public struct RGBA: Equatable, Sendable {
        public let r: CGFloat
        public let g: CGFloat
        public let b: CGFloat
        public let a: CGFloat

        public init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1.0) {
            self.r = r; self.g = g; self.b = b; self.a = a
        }

        public static let white = RGBA(r: 1, g: 1, b: 1)
    }

    // MARK: - DetailStarState

    public struct DetailStarState: Equatable, Sendable, Identifiable {
        public var id: Int { index }
        public let index: Int
        public let starName: String
        public let position: CGPoint
        public let size: CGFloat
        public let brightness: CGFloat
        public let color: RGBA
        public let twinkleIntensity: CGFloat
        public let twinkleSpeed: CGFloat
        public let motionAmplitude: CGFloat
        public let motionSpeed: CGFloat
        public let dateText: String

        public init(
            index: Int,
            starName: String,
            position: CGPoint,
            size: CGFloat,
            brightness: CGFloat,
            color: RGBA,
            twinkleIntensity: CGFloat = 0.3,
            twinkleSpeed: CGFloat = 0.5,
            motionAmplitude: CGFloat = 0.5,
            motionSpeed: CGFloat = 0.5,
            dateText: String = ""
        ) {
            self.index = index
            self.starName = starName
            self.position = position
            self.size = size
            self.brightness = brightness
            self.color = color
            self.twinkleIntensity = twinkleIntensity
            self.twinkleSpeed = twinkleSpeed
            self.motionAmplitude = motionAmplitude
            self.motionSpeed = motionSpeed
            self.dateText = dateText
        }
    }

    // MARK: - CameraState

    public struct CameraState: Equatable, Sendable {
        public var position: CGPoint
        public var scale: CGFloat
        public var velocity: CGVector
        public var savedPosition: CGPoint
        public var savedScale: CGFloat

        public init(
            position: CGPoint = CGPoint(x: 2000, y: 2000),
            scale: CGFloat = 2.0,
            velocity: CGVector = .zero,
            savedPosition: CGPoint = .zero,
            savedScale: CGFloat = 1.0
        ) {
            self.position = position
            self.scale = scale
            self.velocity = velocity
            self.savedPosition = savedPosition
            self.savedScale = savedScale
        }

        public static let initial = CameraState()
        public static let worldSize = CGSize(width: 4000, height: 4000)
    }

    // MARK: - TouchState

    public struct TouchState: Equatable, Sendable {
        public var startPoint: CGPoint?
        public var startTime: TimeInterval = 0
        public var lastPoint: CGPoint?
        public var pinchStartDist: CGFloat = 0
        public var pinchStartScale: CGFloat = 1.0

        public init(
            startPoint: CGPoint? = nil,
            startTime: TimeInterval = 0,
            lastPoint: CGPoint? = nil,
            pinchStartDist: CGFloat = 0,
            pinchStartScale: CGFloat = 1.0
        ) {
            self.startPoint = startPoint
            self.startTime = startTime
            self.lastPoint = lastPoint
            self.pinchStartDist = pinchStartDist
            self.pinchStartScale = pinchStartScale
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case tick(deltaTime: TimeInterval)
        case touch(TouchAction)
        case viewportResized(CGSize)
        case galaxiesUpdated([String: GalaxyNodeState])
        case zoomIn(galaxyKey: String)
        case zoomInCompleted
        case zoomOut
        case zoomOutCompleted
        case detailStarsUpdated([DetailStarState])
        case delegate(Delegate)

        public enum TouchAction: Sendable, Equatable {
            case beganSingle(viewPoint: CGPoint, timestamp: TimeInterval)
            case movedSingle(viewPoint: CGPoint)
            case beganPinch(distance: CGFloat)
            case movedPinch(distance: CGFloat)
            case ended(viewPoint: CGPoint, scenePoint: CGPoint, timestamp: TimeInterval)
            case cancelled
        }

        public enum Delegate: Sendable, Equatable {
            case tappedGalaxy(key: String)
            case tappedEmptyArea(scenePoint: CGPoint)
            case swiped
            case didEnterGalaxyDetail(key: String)
            case didExitGalaxyDetail
        }
    }

    // MARK: - Reducer

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .tick(dt):
                return reduceTick(into: &state, deltaTime: dt)
            case let .touch(touchAction):
                return reduceTouch(into: &state, action: touchAction)
            case let .viewportResized(size):
                state.viewportSize = size
                return .none
            case let .galaxiesUpdated(galaxies):
                state.galaxies = galaxies
                if state.needsInitialFocus, !galaxies.isEmpty, state.phase == .universe {
                    focusOnCurrentMonth(state: &state)
                }
                return .none
            case let .zoomIn(galaxyKey):
                return reduceZoomIn(into: &state, galaxyKey: galaxyKey)
            case .zoomInCompleted:
                return reduceZoomInCompleted(into: &state)
            case .zoomOut:
                return reduceZoomOut(into: &state)
            case .zoomOutCompleted:
                return reduceZoomOutCompleted(into: &state)
            case let .detailStarsUpdated(stars):
                state.detailStars = stars
                return .none
            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Tick

    private func reduceTick(into state: inout State, deltaTime: TimeInterval) -> Effect<Action> {
        let isTouching = state.touch.lastPoint != nil || state.touch.pinchStartDist > 0

        switch state.phase {
        case .universe:
            if !isTouching {
                applyInertia(camera: &state.camera, friction: 0.92, threshold: 0.1)
            }
            clampToWorldBounds(camera: &state.camera, viewportSize: state.viewportSize)

        case let .galaxyDetail(galaxyKey):
            if !isTouching {
                applyInertia(camera: &state.camera, friction: 0.88, threshold: 0.05)
            }
            clampToGalaxyBounds(camera: &state.camera, galaxyKey: galaxyKey, galaxies: state.galaxies)

        case .zoomingIn, .zoomingOut, .recordDetail:
            break
        }

        return .none
    }

    // MARK: - Touch

    private func reduceTouch(into state: inout State, action: Action.TouchAction) -> Effect<Action> {
        let allowPanZoom: Bool = {
            switch state.phase {
            case .universe, .galaxyDetail: return true
            default: return false
            }
        }()

        switch action {
        case let .beganSingle(viewPoint, timestamp):
            state.touch.startPoint = viewPoint
            state.touch.startTime = timestamp
            state.touch.lastPoint = viewPoint
            state.camera.velocity = .zero
            return .none

        case let .movedSingle(viewPoint):
            guard allowPanZoom, let last = state.touch.lastPoint else { return .none }
            let result = UniverseTouchMath.panDelta(
                current: viewPoint,
                last: last,
                cameraScale: state.camera.scale
            )
            state.camera.position.x += result.cameraDelta.dx
            state.camera.position.y += result.cameraDelta.dy
            state.camera.velocity = result.velocity
            state.touch.lastPoint = viewPoint
            return .none

        case let .beganPinch(distance):
            guard allowPanZoom else { return .none }
            state.touch.pinchStartDist = distance
            state.touch.pinchStartScale = state.camera.scale
            state.touch.lastPoint = nil
            state.camera.velocity = .zero
            state.touch.startPoint = nil
            return .none

        case let .movedPinch(distance):
            guard allowPanZoom else { return .none }
            let range: ClosedRange<CGFloat> = {
                switch state.phase {
                case .universe: return UniverseTouchMath.universeScaleRange
                case .galaxyDetail: return UniverseTouchMath.galaxyDetailScaleRange
                default: return 0.5...3.0
                }
            }()
            state.camera.scale = UniverseTouchMath.pinchScale(
                startScale: state.touch.pinchStartScale,
                startDist: state.touch.pinchStartDist,
                currentDist: distance,
                currentScale: state.camera.scale,
                range: range
            )
            return .none

        case let .ended(viewPoint, scenePoint, timestamp):
            var effects: [Effect<Action>] = []

            if let startPoint = state.touch.startPoint {
                let dist = hypot(viewPoint.x - startPoint.x, viewPoint.y - startPoint.y)
                let elapsed = timestamp - state.touch.startTime
                let gesture = UniverseTouchMath.classifyGesture(distance: dist, elapsed: elapsed)

                switch gesture {
                case .tap:
                    let tapEffect = handleTap(scenePoint: scenePoint, state: state)
                    effects.append(tapEffect)
                case .swipe:
                    effects.append(.send(.delegate(.swiped)))
                case .none:
                    break
                }
            }

            state.touch.startPoint = nil
            state.touch.lastPoint = nil
            state.touch.pinchStartDist = 0
            return .merge(effects)

        case .cancelled:
            state.touch = TouchState()
            state.camera.velocity = .zero
            return .none
        }
    }

    // MARK: - Tap Hit Testing

    private func handleTap(scenePoint: CGPoint, state: State) -> Effect<Action> {
        switch state.phase {
        case .universe:
            let candidates = state.galaxies.values.map {
                UniverseTouchMath.GalaxyHitCandidate(
                    key: $0.yearMonth,
                    position: $0.position,
                    diameter: $0.diameter
                )
            }
            if let key = UniverseTouchMath.hitTestGalaxy(at: scenePoint, candidates: candidates) {
                return .send(.delegate(.tappedGalaxy(key: key)))
            }
            return .send(.delegate(.tappedEmptyArea(scenePoint: scenePoint)))

        default:
            return .send(.delegate(.tappedEmptyArea(scenePoint: scenePoint)))
        }
    }

    // MARK: - Focus

    private func focusOnCurrentMonth(state: inout State) {
        let cal = Calendar.current
        let now = Date()
        let key = String(format: "%04d-%02d",
                         cal.component(.year, from: now),
                         cal.component(.month, from: now))
        if let galaxy = state.galaxies[key] {
            state.camera.position = galaxy.position
            state.needsInitialFocus = false
        }
    }

    // MARK: - Camera Helpers

    private func applyInertia(camera: inout CameraState, friction: CGFloat, threshold: CGFloat) {
        if abs(camera.velocity.dx) < threshold { camera.velocity.dx = 0 }
        if abs(camera.velocity.dy) < threshold { camera.velocity.dy = 0 }
        guard camera.velocity.dx != 0 || camera.velocity.dy != 0 else { return }
        camera.position.x += camera.velocity.dx
        camera.position.y += camera.velocity.dy
        camera.velocity.dx *= friction
        camera.velocity.dy *= friction
    }

    private func clampToWorldBounds(camera: inout CameraState, viewportSize: CGSize) {
        let ws = CameraState.worldSize
        let s = camera.scale
        let halfW = viewportSize.width * s / 2
        let halfH = viewportSize.height * s / 2
        let newX = max(halfW, min(ws.width - halfW, camera.position.x))
        let newY = max(halfH, min(ws.height - halfH, camera.position.y))
        guard newX != camera.position.x || newY != camera.position.y else { return }
        camera.position.x = newX
        camera.position.y = newY
    }

    private func clampToGalaxyBounds(camera: inout CameraState, galaxyKey: String, galaxies: [String: GalaxyNodeState]) {
        guard let galaxy = galaxies[galaxyKey] else { return }
        let maxDrift: CGFloat = 150
        let dx = camera.position.x - galaxy.position.x
        let dy = camera.position.y - galaxy.position.y
        let dist = hypot(dx, dy)
        guard dist > maxDrift else { return }
        let ratio = maxDrift / dist
        camera.position.x = galaxy.position.x + dx * ratio
        camera.position.y = galaxy.position.y + dy * ratio
        camera.velocity = .zero
    }

    // MARK: - Zoom

    static let galaxyDetailScale: CGFloat = 0.15

    private func reduceZoomIn(into state: inout State, galaxyKey: String) -> Effect<Action> {
        guard state.phase == .universe, state.galaxies[galaxyKey] != nil else { return .none }
        state.camera.savedPosition = state.camera.position
        state.camera.savedScale = state.camera.scale
        state.camera.velocity = .zero
        state.touch = TouchState()
        state.phase = .zoomingIn(galaxyKey: galaxyKey)
        return .none
    }

    private func reduceZoomInCompleted(into state: inout State) -> Effect<Action> {
        guard case let .zoomingIn(galaxyKey) = state.phase else { return .none }
        guard let galaxy = state.galaxies[galaxyKey] else { return .none }
        state.camera.position = galaxy.position
        state.camera.scale = Self.galaxyDetailScale
        state.phase = .galaxyDetail(galaxyKey: galaxyKey)
        return .send(.delegate(.didEnterGalaxyDetail(key: galaxyKey)))
    }

    private func reduceZoomOut(into state: inout State) -> Effect<Action> {
        guard case .galaxyDetail = state.phase else { return .none }
        state.phase = .zoomingOut
        state.detailStars = []
        state.camera.velocity = .zero
        state.touch = TouchState()
        return .send(.delegate(.didExitGalaxyDetail))
    }

    private func reduceZoomOutCompleted(into state: inout State) -> Effect<Action> {
        guard state.phase == .zoomingOut else { return .none }
        state.camera.position = state.camera.savedPosition
        state.camera.scale = state.camera.savedScale
        state.phase = .universe
        return .none
    }
}
