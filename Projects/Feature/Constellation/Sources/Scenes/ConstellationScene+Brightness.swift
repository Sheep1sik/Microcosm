import SpriteKit
import DomainEntity

extension ConstellationScene {

    // MARK: - Star Brightness Update

    /// 목표 완료율에 따라 별 밝기를 업데이트
    /// - brightness = (해당 별의 모든 목표에서 완료된 subGoal 수) / (전체 subGoal 수)
    /// - alpha = 0.1 + brightness × 0.8
    /// - scale = 1.0 + brightness × 0.5
    /// - color: brightness 0 → (0.4, 0.5, 0.7) 차가운 청회색, brightness 1 → (1.0, 0.95, 0.85) 따뜻한 백색
    func updateStarBrightness(goals: [Goal]) {
        lastGoalsSnapshot = goals

        // 별자리별, 별 인덱스별로 목표 그룹핑
        var starGoals: [String: [Int: [Goal]]] = [:] // [constellationId: [starIndex: [Goal]]]
        for goal in goals {
            starGoals[goal.constellationId, default: [:]][goal.starIndex, default: []].append(goal)
        }

        for (constellationId, rendered) in renderedConstellations {
            let constellationGoals = starGoals[constellationId] ?? [:]

            var allStarsBright = !constellationGoals.isEmpty

            for (index, starNode) in rendered.starNodes.enumerated() {
                let goalsForStar = constellationGoals[index] ?? []
                let brightness = calculateBrightness(for: goalsForStar)
                let hasGoals = !goalsForStar.isEmpty

                applyBrightness(brightness, hasGoals: hasGoals, to: starNode)

                // 목표가 없거나 밝기가 1.0 미만이면 미완성
                if goalsForStar.isEmpty || brightness < 1.0 {
                    allStarsBright = false
                }
            }

            // 완성된 별자리: 연결선을 밝게 표시
            let targetLineAlpha: CGFloat = allStarsBright ? 0.5 : 0.15
            for lineNode in rendered.lineNodes {
                lineNode.run(SKAction.customAction(withDuration: 0.5) { node, elapsed in
                    guard let shape = node as? SKShapeNode else { return }
                    let progress = elapsed / 0.5
                    let currentAlpha = shape.strokeColor.cgColor.alpha
                    let newAlpha = currentAlpha + (targetLineAlpha - currentAlpha) * progress
                    shape.strokeColor = UIColor(white: 1, alpha: newAlpha)
                })
            }
        }
    }

    /// 특정 별의 밝기 계산
    func calculateBrightness(for goals: [Goal]) -> Double {
        guard !goals.isEmpty else { return 0 }

        var totalUnits = 0
        var completedUnits = 0

        for goal in goals {
            if goal.subGoals.isEmpty {
                // 서브골 없는 목표: completedAt 기준
                totalUnits += 1
                if goal.isCompleted { completedUnits += 1 }
            } else {
                totalUnits += goal.subGoals.count
                completedUnits += goal.subGoals.filter(\.isCompleted).count
            }
        }

        guard totalUnits > 0 else { return 0 }
        return Double(completedUnits) / Double(totalUnits)
    }

    /// 별자리의 완성 여부에 따른 연결선 alpha 반환
    func completedConstellationLineAlpha(for constellationId: String) -> CGFloat {
        guard let rendered = renderedConstellations[constellationId] else { return 0.06 }

        // lastGoals가 없으면 (아직 목표 데이터가 없으면) 기본값
        guard !lastGoalsSnapshot.isEmpty else { return 0.15 }

        let constellationGoals = lastGoalsSnapshot.filter { $0.constellationId == constellationId }
        guard !constellationGoals.isEmpty else { return 0.15 }

        // 모든 별에 목표가 있고 모두 밝기 1.0인지 체크
        for (index, _) in rendered.starNodes.enumerated() {
            let goalsForStar = constellationGoals.filter { $0.starIndex == index }
            if goalsForStar.isEmpty || calculateBrightness(for: goalsForStar) < 1.0 {
                return 0.15
            }
        }
        return 0.5
    }

    /// 별 노드에 밝기 적용 (애니메이션)
    /// - 목표 없음: 차가운 청회색, 매우 어둡게 (alpha 0.12)
    /// - 목표 등록됨(미완료): 따뜻한 보라빛, 확실히 밝게 (alpha 0.45~) + 느린 펄스
    /// - 목표 완료됨: 따뜻한 백색, 밝게 (alpha ~0.95) + 빠른 반짝임
    private func applyBrightness(_ brightness: Double, hasGoals: Bool, to starNode: SKSpriteNode) {
        let b = CGFloat(brightness)

        let targetAlpha: CGFloat
        let targetScale: CGFloat
        let targetColor: vector_float4

        if !hasGoals {
            // 목표 없음: 차가운 청회색, 매우 어둡게
            targetAlpha = 0.12
            targetScale = 1.0
            targetColor = vector_float4(0.35, 0.4, 0.6, 1.0)
        } else if brightness < 1.0 {
            // 목표 등록됨, 미완료: 따뜻한 보라빛 기본 + 진행률 반영
            targetAlpha = 0.45 + b * 0.4  // 0.45 ~ 0.85
            targetScale = 1.2 + b * 0.4   // 1.2 ~ 1.6
            let r = Float(0.55 + b * 0.45)  // 0.55 → 1.0
            let g = Float(0.45 + b * 0.5)   // 0.45 → 0.95
            let blue = Float(0.7 + b * 0.15) // 0.7 → 0.85
            targetColor = vector_float4(r, g, blue, 1.0)
        } else {
            // 완료: 따뜻한 백색, 밝게
            targetAlpha = 0.95
            targetScale = 1.7
            targetColor = vector_float4(1.0, 0.95, 0.85, 1.0)
        }

        // 부드러운 전환
        starNode.run(SKAction.group([
            SKAction.fadeAlpha(to: targetAlpha, duration: 0.5),
            SKAction.scale(to: targetScale, duration: 0.5),
        ]))
        starNode.setValue(SKAttributeValue(vectorFloat4: targetColor), forAttribute: "a_color")

        // 애니메이션 초기화
        starNode.removeAction(forKey: "brightTwinkle")
        starNode.removeAction(forKey: "goalPulse")

        if hasGoals && brightness < 1.0 {
            // 목표 등록됨: 느린 펄스 (숨쉬는 듯)
            let pulseMin = max(0.35, targetAlpha - 0.1)
            let pulseMax = min(1.0, targetAlpha + 0.1)
            starNode.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: pulseMin, duration: 2.0),
                SKAction.fadeAlpha(to: pulseMax, duration: 2.0),
            ])), withKey: "goalPulse")
        } else if brightness >= 1.0 {
            // 완료: 빠른 반짝임
            starNode.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.7, duration: 1.5),
                SKAction.fadeAlpha(to: 1.0, duration: 1.5),
            ])), withKey: "brightTwinkle")
        }
    }
}
