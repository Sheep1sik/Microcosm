import SpriteKit
import DomainEntity
import SharedDesignSystem

// MARK: - Scene Delegate

protocol ConstellationSceneDelegate: AnyObject {
    func didTapStar(constellationId: String, starIndex: Int)
    func didEnterConstellationDetail(id: String)
    func didExitConstellationDetail()
    func didTapEmptyArea()
}

// MARK: - Rendered Constellation (노드 참조)

struct RenderedConstellation {
    let containerNode: SKNode
    var starNodes: [SKSpriteNode]       // index 순
    var lineNodes: [SKShapeNode]
    var labelNode: SKLabelNode?
}

final class ConstellationScene: SKScene {

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

    // MARK: - Scene State

    enum SceneState { case overview, zoomingIn, constellationDetail, zoomingOut }
    var sceneState: SceneState = .overview

    var touchStartPos: CGPoint?
    var touchStartTime: TimeInterval = 0

    var savedCameraPos: CGPoint = .zero
    var savedCameraScale: CGFloat = 1.5
    var currentConstellationId: String?
    var detailMaxScale: CGFloat = 1.0  // 디테일 모드 줌아웃 한계

    weak var sceneDelegate: ConstellationSceneDelegate?

    // MARK: - Dust Stars (for frustum culling)

    var dustStarNodes: [SKNode] = []

    // MARK: - Constellation Rendering

    var renderedConstellations: [String: RenderedConstellation] = [:]
    var detailNodes: [SKNode] = []
    var backButton: SKLabelNode?

    // 마지막 목표 스냅샷 (줌아웃 시 완성 상태 참조용)
    var lastGoalsSnapshot: [Goal] = []

    // MARK: - Shared Textures & Shaders

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

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        backgroundColor = AppColors.sceneBackground

        setupCamera()
        setupDustField()
        setupNebulae()
        setupConstellations()
    }

    // MARK: - Camera

    private func setupCamera() {
        cameraNode.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        cameraNode.setScale(1.5)
        addChild(cameraNode)
        camera = cameraNode
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        // 관성 패닝 (overview, constellationDetail에서만)
        guard sceneState == .overview || sceneState == .constellationDetail else { return }

        // 디테일 모드에서는 관성 이동 비활성화
        if sceneState == .overview, lastTouchPos == nil, pinchStartDist == 0 {
            if abs(velocity.dx) > 0.1 || abs(velocity.dy) > 0.1 {
                cameraNode.position.x += velocity.dx
                cameraNode.position.y += velocity.dy
                velocity.dx *= 0.92; velocity.dy *= 0.92
            }
        }

        // 카메라 경계 제한
        if sceneState == .constellationDetail,
           let id = currentConstellationId,
           let rendered = renderedConstellations[id] {
            // 디테일: 별자리 중심 기준으로 패닝 범위 제한
            let center = rendered.containerNode.position
            let s = cameraNode.xScale
            let panLimit: CGFloat = 200 * (detailMaxScale / s) // 줌인할수록 더 이동 가능
            cameraNode.position.x = max(center.x - panLimit, min(center.x + panLimit, cameraNode.position.x))
            cameraNode.position.y = max(center.y - panLimit - size.height * s * 0.15,
                                        min(center.y + panLimit, cameraNode.position.y))
        } else {
            let s = cameraNode.xScale
            let halfW = size.width * s / 2
            let halfH = size.height * s / 2
            cameraNode.position.x = max(halfW, min(worldSize.width - halfW, cameraNode.position.x))
            cameraNode.position.y = max(halfH, min(worldSize.height - halfH, cameraNode.position.y))
        }

        updateDustStarVisibility()
    }

    /// 카메라 뷰포트 밖의 dust star를 숨겨 GPU 부하를 줄인다
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
