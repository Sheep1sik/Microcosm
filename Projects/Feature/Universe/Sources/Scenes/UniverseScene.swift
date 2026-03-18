import SpriteKit
import CoreImage
import Combine
import DomainEntity

private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

final class UniverseScene: SKScene {

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

    // MARK: - Shared Shaders (재사용으로 컴파일 1회만)

    lazy var galaxyShader: SKShader = {
        let src = (try? String(contentsOf: Bundle.main.url(forResource: "Galaxy", withExtension: "fsh")!))
            ?? "void main() { gl_FragColor = vec4(0.0); }"
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
        let src = (try? String(contentsOf: Bundle.main.url(forResource: "Star", withExtension: "fsh")!))
            ?? "void main() { gl_FragColor = vec4(0.0); }"
        let s = SKShader(source: src)
        s.attributes = [
            SKAttribute(name: "a_color", type: .vectorFloat4),
        ]
        return s
    }()

    // MARK: - Minimap

    var minimapNode: SKNode!
    var minimapViewport: SKShapeNode!
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

    // MARK: - Preview Star

    var previewStarNode: SKSpriteNode?
    var previewStarConfirmed = false
    var pendingPreviewPosition: StarPosition?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        backgroundColor = UIColor(red: 0.012, green: 0.024, blue: 0.031, alpha: 1)

        setupCamera()
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
        if grouped[currentMonthKey] == nil {
            grouped[currentMonthKey] = []
        }

        let isFirstLoad = !hasPerformedInitialLoad
        hasPerformedInitialLoad = true

        var newGalaxyKeys: [String] = []

        for (yearMonth, records) in grouped {
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
        let seed = UInt64(year * 100 + month)
        var rng = SplitMix64(seed: seed)
        let margin: CGFloat = 350
        let x = margin + CGFloat(rng.next() % UInt64(worldSize.width - margin * 2))
        let y = margin + CGFloat(rng.next() % UInt64(worldSize.height - margin * 2))
        return CGPoint(x: x, y: y)
    }

    private func galaxyProperties(year: Int, month: Int) -> (arms: Int, tilt: CGFloat, wind: CGFloat, ellipticity: CGFloat) {
        let seed = UInt64(year * 100 + month + 7777)
        var rng = SplitMix64(seed: seed)
        let arms = 2 + Int(rng.next() % 4)
        let tilt = CGFloat(rng.next() % 315) / 100.0 - 1.57
        let wind = 2.0 + CGFloat(rng.next() % 300) / 100.0
        let ellipticity = 0.25 + CGFloat(rng.next() % 41) / 100.0
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
