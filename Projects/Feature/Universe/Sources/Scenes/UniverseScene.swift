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
    private var hasPerformedInitialLoad = false
    private var needsInitialFocus = true

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

    // MARK: - Solar System (Decorative)

    private func setupSun() {
        let center = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2 + 200)

        let container = SKNode()
        container.position = center
        container.zPosition = 8
        container.name = "sunNode"

        // Sun image
        if let sunImage = UIImage(named: "Sun") {
            let sprite = SKSpriteNode(texture: SKTexture(image: sunImage),
                                      size: CGSize(width: 64, height: 64))
            sprite.zPosition = 2
            sprite.run(SKAction.repeatForever(
                SKAction.rotate(byAngle: .pi * 2, duration: 120)))
            container.addChild(sprite)
        }

        addChild(container)
        sunNode = container

        // 궤도 시스템 — yScale 압축 없이 타원 궤도 직접 계산 (행성 찌그러짐 방지)
        let orbitSystem = SKNode()
        orbitSystem.position = center
        orbitSystem.zPosition = 7
        orbitSystem.zRotation = 0.25  // ~14° tilt (3D 느낌)
        addChild(orbitSystem)

        let ellipseRatio: CGFloat = 0.45  // y축 비율 (타원형)
        let tiltAngle: CGFloat = 0.25     // orbitSystem의 회전과 동일

        // Planet definitions (자전 없음, 공전만)
        let planets: [(name: String, image: String, size: CGFloat, orbit: CGFloat, period: TimeInterval)] = [
            ("mercury", "Mercury",   8,   80,  14),
            ("venus",   "Venus",    13,  120,  22),
            ("earth",   "Earth",    14,  165,  30),
            ("mars",    "Mars",     10,  210,  42),
            ("jupiter", "Jupiter",  28,  300,  65),
            ("saturn",  "Saturn",   24,  390,  85),
            ("uranus",  "Uranus",   18,  475, 110),
            ("neptune", "Neptune",  16,  550, 140),
        ]

        for planet in planets {
            // 타원 궤도 경로 (직접 그리기)
            let orbitPath = SKShapeNode(ellipseOf: CGSize(width: planet.orbit * 2,
                                                          height: planet.orbit * ellipseRatio * 2))
            orbitPath.strokeColor = UIColor(white: 1, alpha: 0.03)
            orbitPath.fillColor = .clear
            orbitPath.lineWidth = 0.5
            orbitSystem.addChild(orbitPath)

            let startAngle = CGFloat.random(in: 0...(2 * .pi))

            let planetNode = SKNode()
            planetNode.position = CGPoint(x: planet.orbit * cos(startAngle),
                                          y: planet.orbit * ellipseRatio * sin(startAngle))

            if let img = UIImage(named: planet.image) {
                let sprite = SKSpriteNode(texture: SKTexture(image: img),
                                          size: CGSize(width: planet.size, height: planet.size))
                sprite.name = "planetSprite_\(planet.name)"
                // 부모 회전 상쇄하여 행성이 항상 똑바로 보이게
                sprite.zRotation = -tiltAngle
                planetNode.addChild(sprite)
            }

            orbitSystem.addChild(planetNode)

            // update()에서 위치 갱신 (customAction 반복 경계 끊김 방지)
            planetOrbits.append(PlanetOrbitData(
                node: planetNode,
                orbit: planet.orbit,
                ellipseRatio: ellipseRatio,
                period: planet.period,
                startAngle: startAngle
            ))
        }
    }

    // MARK: - Dynamic Galaxies

    func refreshGalaxies() {
        let allRecords = sceneDelegate?.getAllRecords() ?? []

        let calendar = Calendar.current
        var grouped: [String: [Record]] = [:]
        for record in allRecords {
            let comps = calendar.dateComponents([.year, .month], from: record.createdAt)
            let key = String(format: "%04d-%02d", comps.year!, comps.month!)
            grouped[key, default: []].append(record)
        }

        let now = Date()
        let currentMonthKey = String(format: "%04d-%02d",
                                     calendar.component(.year, from: now),
                                     calendar.component(.month, from: now))

        // 온보딩 welcome/nicknameInput 단계에서는 빈 현재월 은하 생성 보류
        let step = sceneDelegate?.getOnboardingStep()
        let delayGalaxyCreation = step == .welcome || step == .nicknameInput
        if !delayGalaxyCreation, grouped[currentMonthKey] == nil {
            grouped[currentMonthKey] = []
        }

        let isFirstLoad = !hasPerformedInitialLoad
        hasPerformedInitialLoad = true

        var newGalaxyKeys: [String] = []

        for yearMonth in grouped.keys.sorted() {
            let records = grouped[yearMonth] ?? []
            if var existing = activeGalaxies[yearMonth] {
                let oldCount = existing.recordCount
                let newColor = records.blendedUIColor()

                if records.count == oldCount {
                    if newColor != existing.color {
                        existing.color = newColor
                        activeGalaxies[yearMonth] = existing
                        if let node = existing.node,
                           let sprite = node.childNode(withName: "galaxySprite") as? SKSpriteNode {
                            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
                            newColor.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
                            sprite.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(cr), Float(cg), Float(cb), 1)),
                                            forAttribute: "a_color")
                        }
                    }
                    continue
                }

                let newCount = records.count - oldCount
                existing.recordCount = records.count
                existing.diameter = diameterForCount(records.count)
                existing.color = newColor
                activeGalaxies[yearMonth] = existing
                rebuildGalaxyStars(yearMonth: yearMonth, records: records,
                                   animate: true, newCount: newCount)
            } else {
                let (year, month) = FormatHelper.parseYearMonth(yearMonth)
                let pos = galaxyPosition(year: year, month: month)
                let props = galaxyProperties(year: year, month: month)
                let galaxy = DynamicGalaxy(
                    yearMonth: yearMonth, position: pos,
                    arms: props.arms, tilt: props.tilt,
                    wind: props.wind, ellipticity: props.ellipticity,
                    recordCount: records.count,
                    diameter: diameterForCount(records.count),
                    color: records.blendedUIColor(),
                    node: nil)
                activeGalaxies[yearMonth] = galaxy
                newGalaxyKeys.append(yearMonth)
            }
        }

        let removedKeys = Set(activeGalaxies.keys).subtracting(grouped.keys)
        for key in removedKeys {
            activeGalaxies[key]?.node?.removeFromParent()
            activeGalaxies.removeValue(forKey: key)
        }

        let sortedNewKeys = newGalaxyKeys.sorted()
        let onboarding = sceneDelegate?.getIsOnboarding() == true
        for (qi, yearMonth) in sortedNewKeys.enumerated() {
            guard let galaxy = activeGalaxies[yearMonth] else { continue }
            let records = grouped[yearMonth] ?? []
            if isFirstLoad && !onboarding {
                let node = createGalaxyNode(galaxy: galaxy, records: records, animated: false)
                addChild(node)
                activeGalaxies[yearMonth]?.node = node
            } else {
                animateGalaxyBirth(yearMonth: yearMonth, galaxy: galaxy,
                                   records: records, queueIndex: qi)
            }
        }

        // 온보딩 중 은하가 이미 존재하고 새로운 birth 없는 경우 (재실행 대응)
        if onboarding && newGalaxyKeys.isEmpty && !activeGalaxies.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.sceneDelegate?.galaxyBirthCompleted()
            }
        }

        if sceneState != .galaxyDetail {
            refreshMinimapDots()
        }

        renderPreviews()
    }

    // MARK: - Galaxy Helpers

    private func galaxyPosition(year: Int, month: Int) -> CGPoint {
        let margin: CGFloat = 350
        let sunCenter = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2 + 200)
        let sunExclusion: CGFloat = 650
        let galaxyMinDist: CGFloat = 300

        var rng = SeededRNG(seed: UInt64(year * 100 + month))
        let existingPositions = activeGalaxies.values.map { $0.position }

        for _ in 0..<50 {
            let x = CGFloat.random(in: margin...(worldSize.width - margin), using: &rng)
            let y = CGFloat.random(in: margin...(worldSize.height - margin), using: &rng)

            if hypot(x - sunCenter.x, y - sunCenter.y) < sunExclusion { continue }

            let tooClose = existingPositions.contains { p in
                hypot(x - p.x, y - p.y) < galaxyMinDist
            }
            if tooClose { continue }

            return CGPoint(x: x, y: y)
        }
        // 폴백: 태양계만 피하기
        for _ in 0..<20 {
            let x = CGFloat.random(in: margin...(worldSize.width - margin), using: &rng)
            let y = CGFloat.random(in: margin...(worldSize.height - margin), using: &rng)
            if hypot(x - sunCenter.x, y - sunCenter.y) >= sunExclusion {
                return CGPoint(x: x, y: y)
            }
        }
        return CGPoint(x: CGFloat.random(in: margin...(worldSize.width - margin), using: &rng),
                       y: CGFloat.random(in: margin...(worldSize.height - margin), using: &rng))
    }

    private func galaxyProperties(year: Int, month: Int) -> (arms: Int, tilt: CGFloat, wind: CGFloat, ellipticity: CGFloat) {
        var rng = SeededRNG(seed: UInt64(year * 1000 + month * 7 + 31))
        let arms = Int.random(in: 2...5, using: &rng)
        let tilt = CGFloat.random(in: -1.57...1.57, using: &rng)
        let wind = CGFloat.random(in: 2.0...5.0, using: &rng)
        let ellipticity = CGFloat.random(in: 0.25...0.65, using: &rng)
        return (arms, tilt, wind, ellipticity)
    }

    private func diameterForCount(_ count: Int) -> CGFloat {
        let c = CGFloat(max(count, 1))
        return min(60 + sqrt(c) * 18, 240)
    }

    // MARK: - Galaxy Node Creation

    private func createGalaxyNode(galaxy: DynamicGalaxy, records: [Record], animated: Bool) -> SKNode {
        let c = SKNode()
        c.position = galaxy.position; c.zPosition = 5
        c.name = "galaxy_\(galaxy.yearMonth)"
        let r = galaxy.diameter / 2

        let galaxySize = CGSize(width: r * 4, height: r * 4)
        let sprite = SKSpriteNode(color: .white, size: galaxySize)
        sprite.name = "galaxySprite"
        sprite.shader = galaxyShader
        sprite.blendMode = .add
        sprite.zRotation = galaxy.tilt

        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
        galaxy.color.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
        sprite.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(cr), Float(cg), Float(cb), 1)),
                        forAttribute: "a_color")
        sprite.setValue(SKAttributeValue(float: Float(galaxy.arms)), forAttribute: "a_arm_count")
        sprite.setValue(SKAttributeValue(float: Float(galaxy.wind)), forAttribute: "a_wind")
        sprite.setValue(SKAttributeValue(float: Float(galaxy.ellipticity)), forAttribute: "a_ellipticity")
        c.addChild(sprite)

        let orbitNode = SKNode()
        orbitNode.name = "orbitNode"

        let goldenAngle: CGFloat = .pi * (3 - sqrt(5))
        for (i, record) in records.enumerated() {
            let profile = record.resolvedProfile
            let angle = CGFloat(i) * goldenAngle
            let dist = r * 0.5 + sqrt(CGFloat(i + 1)) * r * 0.22
            let sz = 6.0 + CGFloat(profile.size) * 12.0  // 6~18pt
            let dot = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
            dot.position = CGPoint(x: dist * cos(angle), y: dist * sin(angle))
            dot.zPosition = 1
            dot.alpha = animated ? 0 : (0.4 + CGFloat(profile.brightness) * 0.6)
            dot.shader = starShader
            dot.blendMode = .add
            dot.name = "recordStar"

            let starColor = profile.primaryColor.uiColor
            var scr: CGFloat = 0, scg: CGFloat = 0, scb: CGFloat = 0, sca: CGFloat = 0
            starColor.getRed(&scr, green: &scg, blue: &scb, alpha: &sca)
            dot.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(scr), Float(scg), Float(scb), 1)),
                         forAttribute: "a_color")
            orbitNode.addChild(dot)
        }

        let decoCount = max(5, 10 - records.count)
        var dr: CGFloat = 0, dg: CGFloat = 0, db: CGFloat = 0, da: CGFloat = 0
        galaxy.color.getRed(&dr, green: &dg, blue: &db, alpha: &da)
        for _ in 0..<decoCount {
            let a = CGFloat.random(in: 0...(2 * .pi))
            let d = CGFloat.random(in: r * 0.08...r * 0.85)
            let sz = CGFloat.random(in: 2...4)
            let dot = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
            dot.position = CGPoint(x: d * cos(a), y: d * sin(a))
            dot.alpha = CGFloat.random(in: 0.2...0.5)
            dot.shader = starShader
            dot.blendMode = .add
            let bright = Float.random(in: 0.8...1.0)
            dot.setValue(SKAttributeValue(vectorFloat4: vector_float4(
                min(Float(dr) + 0.2, 1) * bright,
                min(Float(dg) + 0.2, 1) * bright,
                min(Float(db) + 0.2, 1) * bright, 1)),
                         forAttribute: "a_color")
            orbitNode.addChild(dot)
        }

        let rotDuration = 30.0 + Double(galaxy.diameter) * 0.15
        orbitNode.run(SKAction.repeatForever(
            SKAction.rotate(byAngle: .pi * 2, duration: rotDuration)))

        let tiltContainer = SKNode()
        tiltContainer.name = "tiltContainer"
        tiltContainer.yScale = galaxy.ellipticity
        tiltContainer.zRotation = galaxy.tilt
        tiltContainer.addChild(orbitNode)
        c.addChild(tiltContainer)

        let l = SKLabelNode(text: FormatHelper.yearMonthLabel(galaxy.yearMonth))
        l.fontName = "AppleSDGothicNeo-Light"; l.fontSize = 44
        l.setScale(0.25)
        l.fontColor = galaxy.color.withAlphaComponent(0.5)
        l.position = CGPoint(x: 0, y: -r * galaxy.ellipticity - 16); l.zPosition = 6
        l.name = "galaxyLabel"
        c.addChild(l)
        return c
    }

    private func rebuildGalaxyStars(yearMonth: String, records: [Record],
                                     animate: Bool, newCount: Int) {
        guard let galaxy = activeGalaxies[yearMonth],
              let node = galaxy.node,
              let tilt = node.childNode(withName: "tiltContainer"),
              let orbit = tilt.childNode(withName: "orbitNode") else { return }

        if let sprite = node.childNode(withName: "galaxySprite") as? SKSpriteNode {
            let newColor = galaxy.color
            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
            newColor.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
            sprite.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(cr), Float(cg), Float(cb), 1)),
                            forAttribute: "a_color")
        }

        let oldStars = orbit.children.filter { $0.name == "recordStar" }
        for star in oldStars { star.removeFromParent() }

        let r = galaxy.diameter / 2
        let goldenAngle: CGFloat = .pi * (3 - sqrt(5))
        let existingCount = records.count - max(newCount, 0)

        for (i, record) in records.enumerated() {
            let profile = record.resolvedProfile
            let angle = CGFloat(i) * goldenAngle
            let dist = r * 0.5 + sqrt(CGFloat(i + 1)) * r * 0.22
            let sz = 6.0 + CGFloat(profile.size) * 12.0  // 6~18pt
            let dot = SKSpriteNode(color: .white, size: CGSize(width: sz, height: sz))
            dot.position = CGPoint(x: dist * cos(angle), y: dist * sin(angle))
            dot.zPosition = 1
            dot.shader = starShader
            dot.blendMode = .add
            dot.name = "recordStar"

            let starColor = profile.primaryColor.uiColor
            var scr: CGFloat = 0, scg: CGFloat = 0, scb: CGFloat = 0, sca: CGFloat = 0
            starColor.getRed(&scr, green: &scg, blue: &scb, alpha: &sca)
            dot.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(scr), Float(scg), Float(scb), 1)),
                         forAttribute: "a_color")

            let isNew = animate && i >= existingCount
            if isNew {
                dot.alpha = 0
                dot.setScale(0.3)
                animateStarBirth(sprite: dot, delay: Double(i - existingCount) * 0.1)
            } else {
                dot.alpha = 0.4 + CGFloat(profile.brightness) * 0.6
            }
            orbit.addChild(dot)
        }
    }

    // MARK: - Birth Animations

    private func animateGalaxyBirth(yearMonth: String, galaxy: DynamicGalaxy,
                                     records: [Record], queueIndex: Int) {
        let node = createGalaxyNode(galaxy: galaxy, records: records, animated: true)
        addChild(node)
        activeGalaxies[yearMonth]?.node = node

        let sprite = node.childNode(withName: "galaxySprite") as? SKSpriteNode
        let tiltC = node.childNode(withName: "tiltContainer")
        let label = node.childNode(withName: "galaxyLabel")
        sprite?.alpha = 0
        tiltC?.alpha = 0
        label?.alpha = 0

        let r = galaxy.diameter / 2
        let cloud = SKSpriteNode(texture: nebulaTexture,
                                  size: CGSize(width: r * 4, height: r * galaxy.ellipticity * 4))
        cloud.color = galaxy.color
        cloud.colorBlendFactor = 1.0
        cloud.zPosition = 4
        cloud.alpha = 0
        cloud.setScale(1.5)
        cloud.zRotation = galaxy.tilt
        cloud.blendMode = .add
        node.addChild(cloud)

        let totalDelay = Double(queueIndex) * 3.5

        cloud.run(SKAction.sequence([
            SKAction.wait(forDuration: totalDelay),
            SKAction.group([
                SKAction.fadeAlpha(to: 0.25, duration: 0.8),
            ]),
            SKAction.group([
                SKAction.scale(to: 0.8, duration: 1.0),
                SKAction.fadeAlpha(to: 0.5, duration: 1.0),
            ]),
            SKAction.fadeAlpha(to: 0.7, duration: 0.5),
            SKAction.fadeAlpha(to: 0, duration: 0.7),
            SKAction.removeFromParent(),
        ]))

        sprite?.run(SKAction.sequence([
            SKAction.wait(forDuration: totalDelay + 1.8),
            SKAction.fadeAlpha(to: 1.0, duration: 1.2),
        ]))

        tiltC?.run(SKAction.sequence([
            SKAction.wait(forDuration: totalDelay + 2.3),
            SKAction.fadeAlpha(to: 1.0, duration: 0.7),
        ]))

        if let orbit = tiltC?.childNode(withName: "orbitNode") {
            let recordStars = orbit.children.filter { $0.name == "recordStar" }
            for (i, star) in recordStars.enumerated() {
                if let s = star as? SKSpriteNode {
                    let starDelay = totalDelay + 2.5 + Double(i) * 0.1
                    animateStarBirth(sprite: s, delay: starDelay)
                }
            }
        }

        label?.run(SKAction.sequence([
            SKAction.wait(forDuration: totalDelay + 2.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
            SKAction.run { [weak self] in
                DispatchQueue.main.async {
                    self?.sceneDelegate?.galaxyBirthCompleted()
                }
            },
        ]))
    }

    private func animateStarBirth(sprite: SKSpriteNode, delay: TimeInterval) {
        sprite.alpha = 0
        sprite.setScale(0.3)
        sprite.run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.group([
                SKAction.fadeAlpha(to: 0.15, duration: 0.3),
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: 1.0, duration: 0.4),
                SKAction.scale(to: 1.3, duration: 0.4),
            ]),
            SKAction.group([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.5...0.8), duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5),
            ]),
        ]))
    }

    // MARK: - Star Positions

    func generateStarPositions(count: Int, yearMonth: String) -> [CGPoint] {
        guard count > 0 else { return [] }
        let (year, month) = FormatHelper.parseYearMonth(yearMonth)
        var rng = SplitMix64(seed: UInt64(year * 100 + month) &+ 7777)

        let spreadX: CGFloat = min(100 + CGFloat(count) * 0.4, 140)
        let spreadY: CGFloat = min(90 + CGFloat(count) * 0.35, 130)
        let minSep: CGFloat = max(4, 28 / sqrt(CGFloat(max(count, 1))))

        var positions: [CGPoint] = []
        for _ in 0..<count {
            var bestPos = CGPoint.zero
            var bestMinDist: CGFloat = -1

            for _ in 0..<50 {
                let rx = CGFloat(rng.next() % 20001) / 10000.0 - 1.0
                let ry = CGFloat(rng.next() % 20001) / 10000.0 - 1.0
                let candidate = CGPoint(x: rx * spreadX, y: ry * spreadY)

                if positions.isEmpty {
                    bestPos = candidate
                    break
                }

                var nearest: CGFloat = .greatestFiniteMagnitude
                for p in positions {
                    nearest = min(nearest, hypot(candidate.x - p.x, candidate.y - p.y))
                }

                if nearest >= minSep {
                    bestPos = candidate
                    break
                }
                if nearest > bestMinDist {
                    bestMinDist = nearest
                    bestPos = candidate
                }
            }
            positions.append(bestPos)
        }
        return positions
    }

    func generateSinglePosition(avoiding existingPositions: [CGPoint], yearMonth: String) -> StarPosition {
        let count = existingPositions.count + 1
        let spreadX: CGFloat = min(100 + CGFloat(count) * 0.4, 140)
        let spreadY: CGFloat = min(90 + CGFloat(count) * 0.35, 130)
        let minSep: CGFloat = max(4, 28 / sqrt(CGFloat(max(count, 1))))

        var bestPos = CGPoint.zero
        var bestMinDist: CGFloat = -1

        for _ in 0..<50 {
            let rx = CGFloat.random(in: -1...1)
            let ry = CGFloat.random(in: -1...1)
            let candidate = CGPoint(x: rx * spreadX, y: ry * spreadY)

            if existingPositions.isEmpty {
                return StarPosition(x: Double(candidate.x), y: Double(candidate.y))
            }

            var nearest: CGFloat = .greatestFiniteMagnitude
            for p in existingPositions {
                nearest = min(nearest, hypot(candidate.x - p.x, candidate.y - p.y))
            }
            if nearest >= minSep {
                return StarPosition(x: Double(candidate.x), y: Double(candidate.y))
            }
            if nearest > bestMinDist { bestMinDist = nearest; bestPos = candidate }
        }
        return StarPosition(x: Double(bestPos.x), y: Double(bestPos.y))
    }

    /// starPosition이 있는 레코드는 그대로, nil인 레코드는 레거시 방식으로 위치 계산
    func resolvePositions(records: [Record], yearMonth: String) -> [CGPoint] {
        let nilCount = records.filter { $0.starPosition == nil }.count
        let legacyPositions: [CGPoint]
        if nilCount > 0 {
            legacyPositions = generateStarPositions(count: records.count, yearMonth: yearMonth)
        } else {
            legacyPositions = []
        }

        return records.enumerated().map { (i, record) in
            record.starPosition?.cgPoint ?? legacyPositions[i]
        }
    }

    // MARK: - Data Access

    func fetchRecords(forKey key: String) -> [Record] {
        let allRecords = sceneDelegate?.getAllRecords() ?? []
        let (year, month) = FormatHelper.parseYearMonth(key)
        let cal = Calendar.current

        return allRecords.filter { record in
            cal.component(.year, from: record.createdAt) == year &&
            cal.component(.month, from: record.createdAt) == month
        }.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Record Creation

    private static let greekLetters = ["α","β","γ","δ","ε","ζ","η","θ","ι","κ","λ","μ","ν","ξ","ο","π","ρ","σ","τ","υ","φ","χ","ψ","ω"]

    private func autoStarName(existingRecords: [Record]) -> String {
        let idx = existingRecords.count
        let letter: String
        if idx < Self.greekLetters.count {
            letter = Self.greekLetters[idx]
        } else {
            letter = Self.greekLetters[idx % Self.greekLetters.count] + "\(idx / Self.greekLetters.count + 1)"
        }
        return "별 \(letter)"
    }

    func createRecordAndRefresh(content: String, profile: StarVisualProfile, starName: String = "", isOnboardingRecord: Bool = false) {
        previewStarNode?.removeFromParent()
        previewStarNode = nil
        previewStarConfirmed = false

        guard let sceneDelegate else { return }

        let cal = Calendar.current
        let now = Date()
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        let currentKey = String(format: "%04d-%02d", y, m)
        let existingRecords = fetchRecords(forKey: currentKey)

        let finalName: String
        if starName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalName = autoStarName(existingRecords: existingRecords)
        } else {
            finalName = starName
        }

        let existingPositions = resolvePositions(records: existingRecords, yearMonth: currentKey)
        let newPosition = pendingPreviewPosition
            ?? generateSinglePosition(avoiding: existingPositions, yearMonth: currentKey)
        pendingPreviewPosition = nil

        let record = Record(
            content: content,
            color: profile.primaryColor,
            visualProfile: profile,
            starName: finalName,
            isOnboardingRecord: isOnboardingRecord,
            starPosition: newPosition
        )

        sceneDelegate.addRecord(record)

        // galaxyDetail에서 생성한 경우 즉시 UI 반영
        guard sceneState == .galaxyDetail,
              let key = currentGalaxyKey,
              let galaxy = activeGalaxies[key] else {
            return
        }

        let prevCount = detailRecords.count
        // 로컬에 임시로 추가하여 즉시 반영 (Firestore 리스너가 곧 업데이트)
        var freshRecords = existingRecords
        freshRecords.append(record)

        for node in detailNodes {
            node.removeAllActions()
            node.removeFromParent()
        }
        detailNodes.removeAll()
        backButton = nil
        galaxyMinimapContainer?.removeFromParent()
        galaxyMinimapContainer = nil

        detailRecords = freshRecords
        sceneDelegate.didUpdateDetailRecords(freshRecords)
        createDetailRecordStars(for: freshRecords, around: galaxy, animateFrom: prevCount)
        showBackButton(yearMonth: key)

        let positions = resolvePositions(records: freshRecords, yearMonth: galaxy.yearMonth)
        if let newStarPos = positions.last {
            let worldPos = CGPoint(x: galaxy.position.x + newStarPos.x,
                                   y: galaxy.position.y + newStarPos.y)
            let move = SKAction.move(to: worldPos, duration: 0.5)
            move.timingMode = .easeInEaseOut
            cameraNode.run(move)
        }

        activeGalaxies[key]?.recordCount = freshRecords.count
        activeGalaxies[key]?.color = freshRecords.blendedUIColor()
        activeGalaxies[key]?.diameter = diameterForCount(freshRecords.count)
        if let g = activeGalaxies[key] {
            switchMinimapToGalaxy(galaxy: g, records: freshRecords)
        }
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
