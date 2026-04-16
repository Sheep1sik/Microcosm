import SpriteKit
import DomainEntity
import SharedDesignSystem
import SharedUtil

extension UniverseScene {

    // MARK: - Star Positions

    func generateStarPositions(count: Int, yearMonth: String) -> [CGPoint] {
        guard count > 0 else { return [] }

        let spreadX: CGFloat = min(100 + CGFloat(count) * 0.4, 140)
        let spreadY: CGFloat = min(90 + CGFloat(count) * 0.35, 130)
        let minSep: CGFloat = max(4, 28 / sqrt(CGFloat(max(count, 1))))

        var positions: [CGPoint] = []
        for _ in 0..<count {
            var bestPos = CGPoint.zero
            var bestMinDist: CGFloat = -1

            for _ in 0..<50 {
                let rx = CGFloat.random(in: -1...1)
                let ry = CGFloat.random(in: -1...1)
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
}
