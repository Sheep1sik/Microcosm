import XCTest
@testable import FeatureConstellation
import DomainEntity

final class ConstellationFeatureCompletionTests: XCTestCase {

    // MARK: - Helpers

    private func allStarIndices(for constellationId: String) -> [Int] {
        guard let def = ConstellationCatalog.all.first(where: { $0.id == constellationId }) else {
            XCTFail("카탈로그에 \(constellationId) 가 없음")
            return []
        }
        return def.stars.map(\.index)
    }

    private func makeGoals(
        constellationId: String,
        completed: Bool
    ) -> [Goal] {
        allStarIndices(for: constellationId).map { idx in
            Goal(
                constellationId: constellationId,
                starIndex: idx,
                title: "g-\(idx)",
                completedAt: completed ? .now : nil
            )
        }
    }

    // MARK: - 완성 신규 감지

    func test_모든별에_완료목표있음_newlyCompleted_감지() {
        guard let first = ConstellationCatalog.all.first else {
            XCTFail("카탈로그 비어있음")
            return
        }
        let goals = makeGoals(constellationId: first.id, completed: true)
        var prev: Set<String> = []

        let change = ConstellationFeature.checkConstellationCompletion(
            goals: goals,
            previouslyCompletedIds: &prev
        )

        XCTAssertEqual(change.newlyCompleted, first.id)
        XCTAssertNil(change.newlyLost)
        XCTAssertTrue(prev.contains(first.id))
    }

    // MARK: - 이미 완성 → 변화 없음

    func test_이미완성_동일상태_변화없음() {
        guard let first = ConstellationCatalog.all.first else {
            XCTFail("카탈로그 비어있음")
            return
        }
        let goals = makeGoals(constellationId: first.id, completed: true)
        var prev: Set<String> = [first.id]

        let change = ConstellationFeature.checkConstellationCompletion(
            goals: goals,
            previouslyCompletedIds: &prev
        )

        XCTAssertNil(change.newlyCompleted)
        XCTAssertNil(change.newlyLost)
    }

    // MARK: - 해제 감지 (목표 삭제)

    func test_이전완성_목표전부삭제_newlyLost_감지() {
        guard let first = ConstellationCatalog.all.first else {
            XCTFail("카탈로그 비어있음")
            return
        }
        var prev: Set<String> = [first.id]

        let change = ConstellationFeature.checkConstellationCompletion(
            goals: [], // 전부 삭제
            previouslyCompletedIds: &prev
        )

        XCTAssertEqual(change.newlyLost, first.id)
        XCTAssertNil(change.newlyCompleted)
        XCTAssertFalse(prev.contains(first.id))
    }

    // MARK: - 해제 감지 (일부 목표 미완료)

    func test_이전완성_일부목표_미완료전환_newlyLost_감지() {
        guard let first = ConstellationCatalog.all.first else {
            XCTFail("카탈로그 비어있음")
            return
        }
        var goals = makeGoals(constellationId: first.id, completed: true)
        // 첫 번째 목표만 미완료 처리
        goals[0].completedAt = nil
        var prev: Set<String> = [first.id]

        let change = ConstellationFeature.checkConstellationCompletion(
            goals: goals,
            previouslyCompletedIds: &prev
        )

        XCTAssertEqual(change.newlyLost, first.id)
        XCTAssertNil(change.newlyCompleted)
    }

    // MARK: - 미완성 (일부 별에 목표 없음)

    func test_일부별에_목표없음_완성안됨() {
        guard let first = ConstellationCatalog.all.first,
              let anyStar = first.stars.first else {
            XCTFail("카탈로그 비어있음")
            return
        }
        // 한 별에만 완료 목표
        let goal = Goal(
            constellationId: first.id,
            starIndex: anyStar.index,
            title: "single",
            completedAt: .now
        )
        var prev: Set<String> = []

        let change = ConstellationFeature.checkConstellationCompletion(
            goals: [goal],
            previouslyCompletedIds: &prev
        )

        // 별이 1개인 별자리 정의가 없다는 가정. 여러 별이면 일부만 있으므로 완성 아님.
        if first.stars.count > 1 {
            XCTAssertNil(change.newlyCompleted)
            XCTAssertFalse(prev.contains(first.id))
        }
    }
}
