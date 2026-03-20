import SpriteKit
import DomainEntity

extension UniverseScene {

    // MARK: - Completed Constellations Background

    /// 완성된 별자리를 소우주 배경에 은은하게 렌더링
    func updateCompletedConstellations(ids: [String]) {
        let newSet = Set(ids)
        let currentSet = Set(completedConstellationNodes.keys)

        // 제거: 더 이상 완성이 아닌 별자리
        for id in currentSet.subtracting(newSet) {
            if let node = completedConstellationNodes[id] {
                node.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.removeFromParent()
                ]))
                completedConstellationNodes.removeValue(forKey: id)
            }
        }

        // 추가: 새로 완성된 별자리
        // 별자리 좌표(4000x4000)를 마진 안쪽으로 리매핑 + 기존 배경 요소 회피
        let margin: CGFloat = 300
        let usableW = worldSize.width - margin * 2
        let usableH = worldSize.height - margin * 2

        // 회피해야 할 영역: 태양, 은하, 성운, 밝은 별
        let sunCenter = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2 + 200)
        let sunExclusion: CGFloat = 700
        let galaxyPositions = activeGalaxies.values.map { $0.position }
        let galaxyExclusion: CGFloat = 200

        for id in newSet.subtracting(currentSet) {
            guard let def = ConstellationCatalog.find(id),
                  let anchor = ConstellationCatalog.worldAnchors[id] else { continue }
            let uniformSpan: CGFloat = 150

            var pos = CGPoint(
                x: margin + (anchor.x / worldSize.width) * usableW,
                y: margin + (anchor.y / worldSize.height) * usableH
            )

            // 태양 회피: 겹치면 태양 반대 방향으로 밀어냄
            let dxSun = pos.x - sunCenter.x
            let dySun = pos.y - sunCenter.y
            let distSun = hypot(dxSun, dySun)
            if distSun < sunExclusion {
                let push = (sunExclusion - distSun) + 50
                let angle = atan2(dySun, dxSun)
                pos.x += cos(angle) * push
                pos.y += sin(angle) * push
            }

            // 은하 회피: 가장 가까운 은하와 겹치면 밀어냄
            for gPos in galaxyPositions {
                let dx = pos.x - gPos.x
                let dy = pos.y - gPos.y
                let dist = hypot(dx, dy)
                if dist < galaxyExclusion {
                    let push = (galaxyExclusion - dist) + 30
                    let angle = atan2(dy, dx)
                    pos.x += cos(angle) * push
                    pos.y += sin(angle) * push
                }
            }

            // 마진 내로 클램핑
            pos.x = max(margin, min(worldSize.width - margin, pos.x))
            pos.y = max(margin, min(worldSize.height - margin, pos.y))

            let node = renderBackgroundConstellation(def, at: pos, span: uniformSpan)
            completedConstellationNodes[id] = node
        }
    }

    /// 배경 별자리 렌더링 (은은한 장식용)
    private func renderBackgroundConstellation(
        _ def: ConstellationDefinition,
        at anchor: CGPoint,
        span: CGFloat
    ) -> SKNode {
        let container = SKNode()
        container.position = anchor
        container.name = "bg_constellation_\(def.id)"
        container.zPosition = 0.5  // 배경 위, 은하 아래
        container.alpha = 0

        var starPositions: [CGPoint] = []

        // 별 렌더링
        for star in def.stars {
            let x = CGFloat(star.x - 0.5) * span
            let y = CGFloat(star.y - 0.5) * span
            let pos = CGPoint(x: x, y: y)
            starPositions.append(pos)

            let baseSz = max(3, 8 - CGFloat(star.magnitude) * 1.0)
            let sprite = SKSpriteNode(color: .white, size: CGSize(width: baseSz, height: baseSz))
            sprite.position = pos
            sprite.zPosition = 1
            sprite.alpha = 0.6
            sprite.blendMode = .add
            sprite.shader = starShader
            let warmColor = vector_float4(1.0, 0.95, 0.85, 1.0)
            sprite.setValue(SKAttributeValue(vectorFloat4: warmColor), forAttribute: "a_color")

            container.addChild(sprite)
        }

        // 연결선 렌더링
        for line in def.lines {
            guard line.from < starPositions.count, line.to < starPositions.count else { continue }

            let path = CGMutablePath()
            path.move(to: starPositions[line.from])
            path.addLine(to: starPositions[line.to])

            let lineNode = SKShapeNode(path: path)
            lineNode.strokeColor = UIColor(white: 1, alpha: 0.4)
            lineNode.lineWidth = 0.4
            lineNode.zPosition = 0
            lineNode.lineCap = .round

            container.addChild(lineNode)
        }

        // 별자리 이름 라벨
        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Light")
        label.text = def.nameKO
        label.fontSize = 10
        label.fontColor = UIColor(white: 1, alpha: 0.7)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .top
        // 별자리 중심 아래에 배치
        let minY = starPositions.map(\.y).min() ?? 0
        label.position = CGPoint(x: 0, y: minY - 8)
        label.zPosition = 2
        container.addChild(label)

        addChild(container)

        // 페이드 인
        container.run(SKAction.fadeAlpha(to: 0.35, duration: 1.0))

        return container
    }
}
