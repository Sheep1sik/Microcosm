import SpriteKit
import CoreImage
import Combine
import DomainEntity
import SharedDesignSystem

// MARK: - Seeded Random Number Generator

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

final class UniverseScene: SKScene {

    // SwiftUI가 scene을 pause하지 못하게 방지
    override var isPaused: Bool {
        get { super.isPaused }
        set { /* ignore */ }
    }

    // MARK: - World

    let worldSize = CGSize(width: 4000, height: 4000)
    let cameraNode = SKCameraNode()
    var lastTouchPos: CGPoint?
    var velocity: CGVector = .zero
    var pinchStartDist: CGFloat = 0
    var pinchStartScale: CGFloat = 1

    // MARK: - Zoom State

    enum SceneState { case universe, zoomingIn, galaxyDetail, recordDetail, zoomingOut }
    var sceneState: SceneState = .universe

    var touchStartPos: CGPoint?
    var touchStartTime: TimeInterval = 0

    var savedCameraPos: CGPoint = .zero
    var savedCameraScale: CGFloat = 1.0
    var currentGalaxyKey: String?
    var pendingStarRecord: Record?
    var detailNodes: [SKNode] = []
    var detailRecords: [Record] = []
    var recordDetailNodes: [SKNode] = []
    var backButton: SKLabelNode?

    weak var sceneDelegate: UniverseSceneDelegate?

    // MARK: - Preview Image Cache

    var previewCache: PreviewImageCache?

    // MARK: - Dust Stars (for frustum culling)

    var dustStarNodes: [SKNode] = []

    // MARK: - Sun & Planets

    var sunNode: SKNode?

    struct PlanetOrbitData {
        let node: SKNode
        let orbit: CGFloat
        let ellipseRatio: CGFloat
        let period: TimeInterval
        let startAngle: CGFloat
    }
    var planetOrbits: [PlanetOrbitData] = []
    var planetElapsedTime: TimeInterval = 0
    var lastUpdateTime: TimeInterval = 0

    // MARK: - Shared Shaders (재사용으로 컴파일 1회만)

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

    lazy var starShader: SKShader = {
        let src: String
        if let url = Bundle.main.url(forResource: "Star", withExtension: "fsh"),
           let content = try? String(contentsOf: url) {
            src = content
        } else {
            src = "void main() { gl_FragColor = vec4(0.0); }"
        }
        let s = SKShader(source: src)
        s.attributes = [
            SKAttribute(name: "a_color", type: .vectorFloat4),
        ]
        return s
    }()

    // MARK: - Minimap

    var minimapNode: SKNode?
    var minimapViewport: SKShapeNode?
    let mmSize: CGFloat = 60

    // MARK: - Galaxy Minimap

    var galaxyMinimapContainer: SKNode?
    var galaxyMinimapExtent: CGFloat = 40

    // MARK: - Dynamic Galaxy Data

    struct DynamicGalaxy {
        let yearMonth: String
        let position: CGPoint
        let arms: Int
        let tilt: CGFloat
        let wind: CGFloat
        let ellipticity: CGFloat
        var recordCount: Int
        var diameter: CGFloat
        var color: UIColor
        var node: SKNode?
    }

    var activeGalaxies: [String: DynamicGalaxy] = [:]
    var minimapDots: [SKNode] = []
    var hasPerformedInitialLoad = false
    var needsInitialFocus = true

    // MARK: - Completed Constellations (배경)

    var completedConstellationNodes: [String: SKNode] = [:]

    // MARK: - Preview Star

    var previewStarNode: SKSpriteNode?
    var previewStarConfirmed = false
    var pendingPreviewPosition: StarPosition?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        backgroundColor = AppColors.sceneBackground

        setupCamera()
        setupSun()
        setupDustField()
        setupNebulae()
        setupBrightStars()
        setupDistantGalaxies()
        setupMinimap()
        refreshGalaxies()
    }

    // MARK: - Camera

    private func setupCamera() {
        cameraNode.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        cameraNode.setScale(2.0)
        addChild(cameraNode)
        camera = cameraNode
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        // 행성 궤도 갱신 (delta 누적 — pause/resume 시 점프 방지)
        let dt = lastUpdateTime == 0 ? 0 : min(currentTime - lastUpdateTime, 0.1)
        lastUpdateTime = currentTime
        planetElapsedTime += dt
        for data in planetOrbits {
            let angle = data.startAngle + CGFloat(planetElapsedTime / data.period) * .pi * 2
            data.node.position = CGPoint(x: data.orbit * cos(angle),
                                         y: data.orbit * data.ellipseRatio * sin(angle))
        }

        if needsInitialFocus && !activeGalaxies.isEmpty && sceneState == .universe {
            needsInitialFocus = false
            let cal = Calendar.current
            let now = Date()
            let key = String(format: "%04d-%02d",
                             cal.component(.year, from: now),
                             cal.component(.month, from: now))
            if let galaxy = activeGalaxies[key] {
                cameraNode.position = galaxy.position
            }
        }

        if sceneState == .universe {
            if lastTouchPos == nil && pinchStartDist == 0 {
                if abs(velocity.dx) > 0.1 || abs(velocity.dy) > 0.1 {
                    cameraNode.position.x += velocity.dx
                    cameraNode.position.y += velocity.dy
                    velocity.dx *= 0.92; velocity.dy *= 0.92
                }
            }

            let s = cameraNode.xScale
            let halfW = size.width * s / 2
            let halfH = size.height * s / 2
            cameraNode.position.x = max(halfW, min(worldSize.width - halfW, cameraNode.position.x))
            cameraNode.position.y = max(halfH, min(worldSize.height - halfH, cameraNode.position.y))
        } else if sceneState == .galaxyDetail {
            if lastTouchPos == nil {
                if abs(velocity.dx) > 0.05 || abs(velocity.dy) > 0.05 {
                    cameraNode.position.x += velocity.dx
                    cameraNode.position.y += velocity.dy
                    velocity.dx *= 0.88; velocity.dy *= 0.88
                }
            }
            if let key = currentGalaxyKey, let galaxy = activeGalaxies[key] {
                let maxDrift: CGFloat = 150
                let dx = cameraNode.position.x - galaxy.position.x
                let dy = cameraNode.position.y - galaxy.position.y
                let dist = hypot(dx, dy)
                if dist > maxDrift {
                    let ratio = maxDrift / dist
                    cameraNode.position.x = galaxy.position.x + dx * ratio
                    cameraNode.position.y = galaxy.position.y + dy * ratio
                    velocity = .zero
                }
            }
        }

        updateMinimap()
        updateOnboardingGalaxyScreenPosition()
        updateDustStarVisibility()
    }

    /// 카메라 뷰포트 밖의 dust star를 숨겨 GPU 부하를 줄인다
    private func updateDustStarVisibility() {
        let s = cameraNode.xScale
        let margin: CGFloat = 100 // 약간의 여유를 두어 팝인 방지
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

    private func updateOnboardingGalaxyScreenPosition() {
        guard sceneDelegate?.getIsOnboarding() == true, let view = self.view else { return }
        let cal = Calendar.current
        let now = Date()
        let key = String(format: "%04d-%02d",
                         cal.component(.year, from: now),
                         cal.component(.month, from: now))
        guard let galaxy = activeGalaxies[key] else { return }
        let viewPoint = convertPoint(toView: galaxy.position)
        sceneDelegate?.galaxyScreenCenterUpdated(viewPoint)
    }
}
