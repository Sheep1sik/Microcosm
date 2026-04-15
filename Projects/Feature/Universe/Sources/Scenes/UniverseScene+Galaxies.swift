import SpriteKit
import DomainEntity
import SharedDesignSystem

extension UniverseScene {

    // MARK: - Dynamic Galaxies

    func refreshGalaxies() {
        // records observer 응답 전까지는 온보딩 여부가 결정되지 않은 상태.
        // 이 시점에 은하를 그리면 isFirstLoad 경로로 현재월 빈 은하가 즉시(애니메이션 없이) 생성돼,
        // 이후 `.galaxyBirthIntro`에서 출생 모션이 existing-branch로 흡수돼 사라진다.
        // 완전 early return 으로 첫 호출 자체를 미뤄 isFirstLoad 플래그를 소비하지 않는다.
        if sceneDelegate?.isOnboardingUndecided() == true { return }

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

    func galaxyPosition(year: Int, month: Int) -> CGPoint {
        let margin: CGFloat = 350
        let sunCenter = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2 + 200)
        let sunExclusion: CGFloat = 650
        let galaxyMinDist: CGFloat = 300

        let existingPositions = activeGalaxies.values.map { $0.position }

        for _ in 0..<50 {
            let x = CGFloat.random(in: margin...(worldSize.width - margin))
            let y = CGFloat.random(in: margin...(worldSize.height - margin))

            if hypot(x - sunCenter.x, y - sunCenter.y) < sunExclusion { continue }

            let tooClose = existingPositions.contains { p in
                hypot(x - p.x, y - p.y) < galaxyMinDist
            }
            if tooClose { continue }

            return CGPoint(x: x, y: y)
        }
        // 폴백: 태양계만 피하기
        for _ in 0..<20 {
            let x = CGFloat.random(in: margin...(worldSize.width - margin))
            let y = CGFloat.random(in: margin...(worldSize.height - margin))
            if hypot(x - sunCenter.x, y - sunCenter.y) >= sunExclusion {
                return CGPoint(x: x, y: y)
            }
        }
        return CGPoint(x: CGFloat.random(in: margin...(worldSize.width - margin)),
                       y: CGFloat.random(in: margin...(worldSize.height - margin)))
    }

    func galaxyProperties(year: Int, month: Int) -> (arms: Int, tilt: CGFloat, wind: CGFloat, ellipticity: CGFloat) {
        let arms = Int.random(in: 2...5)
        let tilt = CGFloat.random(in: -1.57...1.57)
        let wind = CGFloat.random(in: 2.0...5.0)
        let ellipticity = CGFloat.random(in: 0.25...0.65)
        return (arms, tilt, wind, ellipticity)
    }

    func diameterForCount(_ count: Int) -> CGFloat {
        let c = CGFloat(max(count, 1))
        return min(60 + sqrt(c) * 18, 240)
    }

    // MARK: - Galaxy Node Creation

    func createGalaxyNode(galaxy: DynamicGalaxy, records: [Record], animated: Bool) -> SKNode {
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

    func rebuildGalaxyStars(yearMonth: String, records: [Record],
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
}
