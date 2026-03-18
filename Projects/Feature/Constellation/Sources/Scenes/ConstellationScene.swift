import SpriteKit

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
        let src = (try? String(contentsOf: Bundle.main.url(forResource: "Star", withExtension: "fsh")!))
            ?? "void main() { gl_FragColor = vec4(0.0); }"
        let s = SKShader(source: src)
        s.attributes = [
            SKAttribute(name: "a_color", type: .vectorFloat4),
        ]
        return s
    }()

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        backgroundColor = UIColor(red: 0.012, green: 0.024, blue: 0.031, alpha: 1)

        setupCamera()
        setupDustField()
        setupNebulae()
    }

    // MARK: - Camera

    private func setupCamera() {
        cameraNode.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        cameraNode.setScale(1.5)
        addChild(cameraNode)
        camera = cameraNode
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = self.view, let all = event?.allTouches else { return }
        let active = all.filter { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }

        if active.count >= 2 {
            let arr = Array(active)
            let p1 = arr[0].location(in: view); let p2 = arr[1].location(in: view)
            pinchStartDist = hypot(p2.x - p1.x, p2.y - p1.y)
            pinchStartScale = cameraNode.xScale
            lastTouchPos = nil; velocity = .zero
        } else if let touch = touches.first {
            lastTouchPos = touch.location(in: view)
            velocity = .zero
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view = self.view, let all = event?.allTouches else { return }
        let active = all.filter { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }

        if active.count >= 2 {
            let arr = Array(active)
            let p1 = arr[0].location(in: view); let p2 = arr[1].location(in: view)
            let dist = hypot(p2.x - p1.x, p2.y - p1.y)
            if pinchStartDist > 10 {
                let newScale = pinchStartScale * (pinchStartDist / dist)
                cameraNode.setScale(max(0.5, min(3.0, newScale)))
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
        guard let all = event?.allTouches else { return }
        let active = all.filter { $0.phase != .ended && $0.phase != .cancelled }

        if active.isEmpty {
            lastTouchPos = nil; pinchStartDist = 0
        } else if active.count == 1 {
            lastTouchPos = active.first?.location(in: view); pinchStartDist = 0
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPos = nil; pinchStartDist = 0; velocity = .zero
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        // 관성 패닝
        if lastTouchPos == nil && pinchStartDist == 0 {
            if abs(velocity.dx) > 0.1 || abs(velocity.dy) > 0.1 {
                cameraNode.position.x += velocity.dx
                cameraNode.position.y += velocity.dy
                velocity.dx *= 0.92; velocity.dy *= 0.92
            }
        }

        // 카메라 경계 제한
        let s = cameraNode.xScale
        let halfW = size.width * s / 2
        let halfH = size.height * s / 2
        cameraNode.position.x = max(halfW, min(worldSize.width - halfW, cameraNode.position.x))
        cameraNode.position.y = max(halfH, min(worldSize.height - halfH, cameraNode.position.y))
    }
}
