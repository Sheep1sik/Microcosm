import UIKit
import ComposableArchitecture
import DomainEntity
import SharedDesignSystem
import SharedRecordVisuals
import SharedUtil

extension UniverseFeature {

    // MARK: - Scene Delegate → Parent

    func reduceSceneDelegate(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .scene(.delegate(let delegate)):
            return handleSceneDelegate(delegate, state: &state)

        case .syncGalaxiesToScene:
            let galaxies = buildGalaxyNodeStates(allRecords: state.allRecords)
            return .send(.scene(.galaxiesUpdated(galaxies)))

        default:
            return .none
        }
    }

    private func handleSceneDelegate(_ delegate: UniverseSceneFeature.Action.Delegate, state: inout State) -> Effect<Action> {
        switch delegate {
        case let .tappedGalaxy(key):
            return .send(.scene(.zoomIn(galaxyKey: key)))

        case .tappedEmptyArea(scenePoint: _):
            return .none

        case .swiped:
            return .none

        case let .didEnterGalaxyDetail(key):
            state.isInGalaxyDetail = true
            state.currentYearMonth = key
            let records = recordsForKey(key, allRecords: state.allRecords)
            state.currentDetailRecords = records
            let detailStars = buildDetailStars(records: records, galaxyKey: key, galaxies: state.scene.galaxies)
            return .merge(
                .send(.scene(.detailStarsUpdated(detailStars))),
                .send(.onboarding(.enteredGalaxyDetail))
            )

        case .didExitGalaxyDetail:
            state.isInGalaxyDetail = false
            state.currentYearMonth = nil
            state.currentDetailRecords = []
            return .none
        }
    }

    // MARK: - Galaxy Node States

    private func buildGalaxyNodeStates(allRecords: [Record]) -> [String: UniverseSceneFeature.GalaxyNodeState] {
        let cal = Calendar.current
        var grouped: [String: [Record]] = [:]
        for record in allRecords {
            let y = cal.component(.year, from: record.createdAt)
            let m = cal.component(.month, from: record.createdAt)
            let key = String(format: "%04d-%02d", y, m)
            grouped[key, default: []].append(record)
        }

        let now = Date()
        let currentKey = String(format: "%04d-%02d",
                                cal.component(.year, from: now),
                                cal.component(.month, from: now))
        if grouped[currentKey] == nil { grouped[currentKey] = [] }

        var result: [String: UniverseSceneFeature.GalaxyNodeState] = [:]
        for (yearMonth, records) in grouped {
            let (year, month) = FormatHelper.parseYearMonth(yearMonth)
            let pos = galaxyPosition(year: year, month: month)
            let props = galaxyProperties(year: year, month: month)
            let count = records.count
            let blended = records.blendedUIColor()
            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
            blended.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)

            result[yearMonth] = UniverseSceneFeature.GalaxyNodeState(
                yearMonth: yearMonth,
                position: pos,
                arms: props.arms,
                tilt: props.tilt,
                wind: props.wind,
                ellipticity: props.ellipticity,
                recordCount: count,
                diameter: diameterForCount(count),
                color: UniverseSceneFeature.RGBA(r: cr, g: cg, b: cb)
            )
        }
        return result
    }

    private func galaxyPosition(year: Int, month: Int) -> CGPoint {
        let key = "galaxyPosition_\(String(format: "%04d-%02d", year, month))"
        if let arr = UserDefaults.standard.array(forKey: key) as? [Double], arr.count == 2 {
            return CGPoint(x: arr[0], y: arr[1])
        }
        let ws = UniverseSceneFeature.CameraState.worldSize
        let margin: CGFloat = 350
        let sunCenter = CGPoint(x: ws.width / 2, y: ws.height / 2 + 200)
        let sunExclusion: CGFloat = 650

        for _ in 0..<50 {
            let x = CGFloat.random(in: margin...(ws.width - margin))
            let y = CGFloat.random(in: margin...(ws.height - margin))
            if hypot(x - sunCenter.x, y - sunCenter.y) < sunExclusion { continue }
            UserDefaults.standard.set([Double(x), Double(y)], forKey: key)
            return CGPoint(x: x, y: y)
        }
        let x = CGFloat.random(in: margin...(ws.width - margin))
        let y = CGFloat.random(in: margin...(ws.height - margin))
        UserDefaults.standard.set([Double(x), Double(y)], forKey: key)
        return CGPoint(x: x, y: y)
    }

    private func galaxyProperties(year: Int, month: Int) -> (arms: Int, tilt: CGFloat, wind: CGFloat, ellipticity: CGFloat) {
        let key = "galaxyProperties_\(String(format: "%04d-%02d", year, month))"
        if let arr = UserDefaults.standard.array(forKey: key) as? [Double], arr.count == 4 {
            return (Int(arr[0]), CGFloat(arr[1]), CGFloat(arr[2]), CGFloat(arr[3]))
        }
        let arms = Int.random(in: 2...5)
        let tilt = CGFloat.random(in: -1.57...1.57)
        let wind = CGFloat.random(in: 2.0...5.0)
        let ellipticity = CGFloat.random(in: 0.25...0.65)
        UserDefaults.standard.set([Double(arms), Double(tilt), Double(wind), Double(ellipticity)], forKey: key)
        return (arms, tilt, wind, ellipticity)
    }

    private func diameterForCount(_ count: Int) -> CGFloat {
        let c = CGFloat(max(count, 1))
        return min(60 + sqrt(c) * 18, 240)
    }

    // MARK: - Helpers

    private func recordsForKey(_ key: String, allRecords: [Record]) -> [Record] {
        let (year, month) = FormatHelper.parseYearMonth(key)
        let cal = Calendar.current
        return allRecords.filter { record in
            cal.component(.year, from: record.createdAt) == year &&
            cal.component(.month, from: record.createdAt) == month
        }.sorted { $0.createdAt < $1.createdAt }
    }

    private func buildDetailStars(
        records: [Record],
        galaxyKey: String,
        galaxies: [String: UniverseSceneFeature.GalaxyNodeState]
    ) -> [UniverseSceneFeature.DetailStarState] {
        guard let galaxy = galaxies[galaxyKey] else { return [] }

        let positions = generateDetailPositions(count: records.count)

        return records.enumerated().map { index, record in
            let profile = record.resolvedProfile
            let pos = index < positions.count ? positions[index] : .zero
            let worldPos = CGPoint(
                x: galaxy.position.x + pos.x,
                y: galaxy.position.y + pos.y
            )
            return UniverseSceneFeature.DetailStarState(
                index: index,
                starName: record.starName,
                position: worldPos,
                size: 10 + CGFloat(profile.sizeMultiplier) * 8,
                brightness: CGFloat(profile.brightness),
                color: UniverseSceneFeature.RGBA(
                    r: CGFloat(profile.primaryColor.r),
                    g: CGFloat(profile.primaryColor.g),
                    b: CGFloat(profile.primaryColor.b)
                ),
                twinkleIntensity: CGFloat(profile.twinkleIntensity),
                twinkleSpeed: CGFloat(profile.twinkleSpeed),
                motionAmplitude: 0.5,
                motionSpeed: 0.5,
                dateText: FormatHelper.shortDate(record.createdAt)
            )
        }
    }

    private func generateDetailPositions(count: Int) -> [CGPoint] {
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
}
