import SpriteKit
import DomainEntity

extension UniverseScene {

    // MARK: - Record Creation

    static let greekLetters = ["α","β","γ","δ","ε","ζ","η","θ","ι","κ","λ","μ","ν","ξ","ο","π","ρ","σ","τ","υ","φ","χ","ψ","ω"]

    func autoStarName(existingRecords: [Record]) -> String {
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
}
