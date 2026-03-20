import SpriteKit
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

extension ConstellationScene {

    // MARK: - Setup All Constellations

    func setupConstellations() {
        let uniformSpan: CGFloat = 250
        let margin: CGFloat = 300
        let cols = 10
        let rows = 9
        let cellW = (worldSize.width - margin * 2) / CGFloat(cols)
        let cellH = (worldSize.height - margin * 2) / CGFloat(rows)
        // 홀수 행은 반 칸 오프셋 (벌집 배치) + 랜덤 흔들림
        var rng = SplitMix64(seed: 88)
        let jitter: CGFloat = 60  // 최대 흔들림

        for (i, constellation) in ConstellationCatalog.all.enumerated() {
            let col = i % cols
            let row = i / cols
            let honeycombOffset: CGFloat = (row % 2 == 1) ? cellW * 0.5 : 0
            let rx = CGFloat.random(in: -jitter...jitter, using: &rng)
            let ry = CGFloat.random(in: -jitter...jitter, using: &rng)
            let pos = CGPoint(
                x: margin + cellW * (CGFloat(col) + 0.5) + honeycombOffset + rx,
                y: margin + cellH * (CGFloat(row) + 0.5) + ry
            )
            let rendered = renderConstellation(constellation, at: pos, span: uniformSpan)
            renderedConstellations[constellation.id] = rendered
        }
    }

    // MARK: - Render Individual Constellation

    private func renderConstellation(
        _ def: ConstellationDefinition,
        at anchor: CGPoint,
        span: CGFloat
    ) -> RenderedConstellation {
        let container = SKNode()
        container.position = anchor
        container.name = "constellation_\(def.id)"
        container.zPosition = 1

        var starNodes: [SKSpriteNode] = []
        var lineNodes: [SKShapeNode] = []

        // 별 렌더링
        for star in def.stars {
            let x = CGFloat(star.x - 0.5) * span
            let y = CGFloat(star.y - 0.5) * span

            // magnitude 기반 크기 (밝을수록 큼): mag 0 → 12pt, mag 5 → 4pt
            let baseSz = max(4, 12 - CGFloat(star.magnitude) * 1.6)
            let sprite = SKSpriteNode(color: .white, size: CGSize(width: baseSz, height: baseSz))
            sprite.position = CGPoint(x: x, y: y)
            sprite.zPosition = 3
            sprite.shader = starShader
            sprite.blendMode = .add
            sprite.name = "star_\(def.id)_\(star.index)"

            // 초기 상태: dim (빛을 잃은 상태)
            sprite.alpha = 0.1
            let dimColor = vector_float4(0.4, 0.5, 0.7, 1.0) // 차가운 청회색
            sprite.setValue(SKAttributeValue(vectorFloat4: dimColor), forAttribute: "a_color")

            container.addChild(sprite)
            starNodes.append(sprite)
        }

        // 연결선 렌더링
        for line in def.lines {
            guard line.from < starNodes.count, line.to < starNodes.count else { continue }
            let fromPos = starNodes[line.from].position
            let toPos = starNodes[line.to].position

            let path = CGMutablePath()
            path.move(to: fromPos)
            path.addLine(to: toPos)

            let lineNode = SKShapeNode(path: path)
            lineNode.strokeColor = UIColor(white: 1, alpha: 0.06)
            lineNode.lineWidth = 0.5
            lineNode.zPosition = 2
            lineNode.lineCap = .round

            container.addChild(lineNode)
            lineNodes.append(lineNode)
        }

        // 별자리 이름 라벨
        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Light")
        label.text = def.nameKO
        label.fontSize = 12
        label.fontColor = UIColor(white: 1, alpha: 0.25)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .top
        let minY = starNodes.map(\.position.y).min() ?? 0
        label.position = CGPoint(x: 0, y: minY - 10)
        label.zPosition = 2
        container.addChild(label)

        addChild(container)

        return RenderedConstellation(
            containerNode: container,
            starNodes: starNodes,
            lineNodes: lineNodes,
            labelNode: label
        )
    }
}
