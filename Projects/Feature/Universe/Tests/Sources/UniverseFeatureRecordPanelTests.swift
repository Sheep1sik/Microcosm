import XCTest
import ComposableArchitecture
@testable import FeatureUniverse
import DomainEntity

@MainActor
final class UniverseFeatureRecordPanelTests: XCTestCase {

    // MARK: - recordsUpdated

    func test_recordsUpdated_allRecords_반영() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        let records = [Record(content: "a"), Record(content: "b")]
        await store.send(.recordsUpdated(records)) {
            $0.allRecords = records
            $0.hasReceivedInitialRecords = true
        }
    }

    // MARK: - openRecordPanel

    func test_openRecordPanel_신규입력상태로_패널열림() async {
        // 온보딩 createStarPrompt 단계에서는 일일 제한 체크를 건너뛴다.
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .createStarPrompt,
                recordContent: "이전 잔여물",
                starName: "잔여별",
                isAnalyzingColor: true,
                analyzedProfile: .fallback
            )
        ) {
            UniverseFeature()
        }

        await store.send(.openRecordPanel) {
            $0.recordContent = ""
            $0.starName = ""
            $0.analyzedProfile = nil
            $0.isAnalyzingColor = false
            $0.showRecordPanel = true
        }
    }

    func test_openRecordPanel_일일제한도달_showLimitAlert_true() async {
        // 온보딩이 아닌 상태에서 canCreateRecord == false 면 제한 알림.
        // dailyRecordLimit 이상의 오늘 기록을 주입하여 막힘 조건을 만든다.
        let limit = UniverseFeature.State.dailyRecordLimit
        let todays = (0..<limit).map { Record(content: "today-\($0)") }
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: true,
                onboardingStep: nil,
                allRecords: todays
            )
        ) {
            UniverseFeature()
        }

        await store.send(.openRecordPanel) {
            $0.showLimitAlert = true
        }
    }

    // MARK: - dismissPanel

    func test_dismissPanel_패널입력전체초기화() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                showRecordPanel: true,
                recordContent: "작성중",
                starName: "별이름",
                isAnalyzingColor: true,
                analyzedProfile: StarVisualProfile.fallback
            )
        ) {
            UniverseFeature()
        }

        await store.send(.dismissPanel) {
            $0.recordContent = ""
            $0.starName = ""
            $0.analyzedProfile = nil
            $0.isAnalyzingColor = false
            $0.showRecordPanel = false
        }
    }

    // MARK: - saveRecord

    func test_saveRecord_빈내용_무시() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                recordContent: "   \n\t  "
            )
        ) {
            UniverseFeature()
        }

        // whitespace-only 는 guard 로 조기 종료, state 변화 없음.
        await store.send(.saveRecord)
    }

    func test_saveRecord_비어있지않음_isAnalyzingColor_true로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                recordContent: "  오늘은 좋은 날  "
            )
        ) {
            UniverseFeature()
        } withDependencies: {
            // AI 분석 effect 는 본 테스트 관심사가 아니므로 즉시 성공 응답으로 고정한다.
            $0.openAIClient.analyzeEmotion = { _ in StarVisualProfile.fallback }
        }
        // saveRecord 이후 방출되는 profileAnalyzed 는 별도 테스트에서 검증한다.
        store.exhaustivity = .off

        await store.send(.saveRecord) {
            $0.isAnalyzingColor = true
        }
    }

    // MARK: - profileAnalyzed

    func test_profileAnalyzed_분석완료_패널닫기_프로필반영() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                showRecordPanel: true,
                isAnalyzingColor: true
            )
        ) {
            UniverseFeature()
        }

        let profile = StarVisualProfile.fallback
        await store.send(.profileAnalyzed(profile)) {
            $0.analyzedProfile = profile
            $0.isAnalyzingColor = false
            $0.showRecordPanel = false
        }
    }

    func test_profileAnalyzed_온보딩createStarPrompt일때_closingMessage로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .createStarPrompt,
                showRecordPanel: true,
                isAnalyzingColor: true
            )
        ) {
            UniverseFeature()
        }

        await store.send(.profileAnalyzed(.fallback)) {
            $0.analyzedProfile = .fallback
            $0.isAnalyzingColor = false
            $0.showRecordPanel = false
            $0.onboardingStep = .closingMessage
        }
    }

    // MARK: - colorAnalyzed (fallback 경로)

    func test_colorAnalyzed_legacyColor로부터_프로필파생_패널닫기() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                showRecordPanel: true,
                isAnalyzingColor: true
            )
        ) {
            UniverseFeature()
        }

        let color = RecordColor(r: 0.2, g: 0.4, b: 0.8)
        let expected = StarVisualProfile.from(legacyColor: color)
        await store.send(.colorAnalyzed(color)) {
            $0.analyzedProfile = expected
            $0.isAnalyzingColor = false
            $0.showRecordPanel = false
        }
    }

    func test_colorAnalyzed_온보딩단계면_closingMessage로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .createStarPrompt,
                showRecordPanel: true,
                isAnalyzingColor: true
            )
        ) {
            UniverseFeature()
        }

        let color = RecordColor(r: 0.5, g: 0.6, b: 0.7)
        let expected = StarVisualProfile.from(legacyColor: color)
        await store.send(.colorAnalyzed(color)) {
            $0.analyzedProfile = expected
            $0.isAnalyzingColor = false
            $0.showRecordPanel = false
            $0.onboardingStep = .closingMessage
        }
    }

    // MARK: - profileAnalysisFailed (최종 fallback)

    func test_profileAnalysisFailed_fallback프로필_반영_패널닫기() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                showRecordPanel: true,
                isAnalyzingColor: true
            )
        ) {
            UniverseFeature()
        }

        await store.send(.profileAnalysisFailed) {
            $0.analyzedProfile = .fallback
            $0.isAnalyzingColor = false
            $0.showRecordPanel = false
        }
    }

    func test_profileAnalysisFailed_온보딩단계면_closingMessage로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .createStarPrompt,
                showRecordPanel: true,
                isAnalyzingColor: true
            )
        ) {
            UniverseFeature()
        }

        await store.send(.profileAnalysisFailed) {
            $0.analyzedProfile = .fallback
            $0.isAnalyzingColor = false
            $0.showRecordPanel = false
            $0.onboardingStep = .closingMessage
        }
    }
}
