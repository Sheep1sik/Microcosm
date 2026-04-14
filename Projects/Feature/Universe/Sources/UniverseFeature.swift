import SwiftUI
import ComposableArchitecture
import DomainEntity
import DomainClient

public typealias Record = DomainEntity.Record

public enum OnboardingStep: Int, Equatable {
    case welcome
    case nicknameInput
    case galaxyBirthIntro
    case monthlyGalaxyGuide
    case tapGalaxyPrompt
    case createStarPrompt
    case closingMessage
    case completed
}

@Reducer
public struct UniverseFeature {
    @ObservableState
    public struct State: Equatable {
        // Onboarding
        public var hasCompletedOnboarding = false
        public var onboardingStep: OnboardingStep? = nil
        public var onboardingGalaxyScreenCenter: CGPoint?
        /// records observer가 최소 1회 yield 했는지. checkOnboarding 결정은
        /// 이 플래그가 true가 되어 `allRecords`가 신뢰 가능해진 뒤에만 수행.
        /// (View 진입 직후 records 없는 상태에서 잘못 welcome으로 진입하는 레이스 방지)
        public var hasReceivedInitialRecords = false
        public var pendingOnboardingCheck = false

        // Onboarding Nickname
        public var onboardingNickname = ""
        public var onboardingNicknameChecking = false
        public var onboardingNicknameError: String?
        public var onboardingNicknameAvailable: Bool?
        public var onboardingNicknameSaving = false

        public var isOnboarding: Bool { onboardingStep != nil && onboardingStep != .completed }

        // Auth Info
        public var userDisplayName: String?

        // Records
        public var allRecords: [Record] = []

        // Scene State
        public var isInGalaxyDetail = false
        public var currentYearMonth: String?
        public var currentDetailRecords: [Record] = []

        // Free Tier
        public static let dailyRecordLimit = 1
        public var showLimitAlert = false

        // Record Input
        public var showRecordPanel = false
        public var recordContent = ""
        public var starName = ""
        public var isAnalyzingColor = false
        public var analyzedProfile: StarVisualProfile?

        // Search
        public var searchText = ""
        public var isSearching = false
        public var debouncedQuery = ""

        // Completed Constellations (배경 표시용)
        public var completedConstellationIds: [String] = []

        // Preview Images (실제 이미지는 @Dependency(\.previewImageCache)로 관리)
        public var previewRevision: UInt = 0

        // Navigation (View에서 scene 메서드 호출용)
        public var pendingNavigation: PendingNavigation?

        public enum PendingNavigation: Equatable {
            case galaxy(String)
            case star(Record)
            case galaxyThenStar(yearMonth: String, record: Record)
        }

        // Computed
        public var isCurrentMonthGalaxy: Bool {
            guard let ym = currentYearMonth else { return false }
            let (y, m) = FormatHelper.parseYearMonth(ym)
            let cal = Calendar.current
            let now = Date()
            return cal.component(.year, from: now) == y && cal.component(.month, from: now) == m
        }

        public func todayRecordCount() -> Int {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            return allRecords.filter {
                !$0.isOnboardingRecord &&
                cal.isDate($0.createdAt, inSameDayAs: today)
            }.count
        }

        public var remainingRecordCount: Int {
            max(0, Self.dailyRecordLimit - todayRecordCount())
        }

        public var canCreateRecord: Bool {
            todayRecordCount() < Self.dailyRecordLimit
        }

        public func galaxyResults() -> [(yearMonth: String, label: String, recordCount: Int, color: Color)] {
            guard !isInGalaxyDetail else { return [] }
            let query = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cal = Calendar.current
            var monthMap: [String: [Record]] = [:]
            for record in allRecords {
                let y = cal.component(.year, from: record.createdAt)
                let m = cal.component(.month, from: record.createdAt)
                let key = String(format: "%04d-%02d", y, m)
                monthMap[key, default: []].append(record)
            }
            let now = Date()
            let curKey = String(format: "%04d-%02d", cal.component(.year, from: now), cal.component(.month, from: now))
            if monthMap[curKey] == nil { monthMap[curKey] = [] }

            var results: [(yearMonth: String, label: String, recordCount: Int, color: Color)] = []
            for (key, records) in monthMap.sorted(by: { $0.key > $1.key }) {
                let label = FormatHelper.yearMonthLabel(key)
                if !query.isEmpty && !label.lowercased().contains(query) && !key.contains(query) { continue }
                results.append((key, label, records.count, records.blendedColor()))
            }
            return results
        }

        public func starResults() -> [Record] {
            let source = isInGalaxyDetail ? currentDetailRecords : allRecords
            var results = source
            let query = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !query.isEmpty {
                results = results.filter {
                    $0.content.lowercased().contains(query) || $0.starName.lowercased().contains(query)
                }
            }
            return results
        }

        public init(
            hasCompletedOnboarding: Bool = false,
            onboardingStep: OnboardingStep? = nil,
            onboardingGalaxyScreenCenter: CGPoint? = nil,
            hasReceivedInitialRecords: Bool = false,
            pendingOnboardingCheck: Bool = false,
            onboardingNickname: String = "",
            onboardingNicknameChecking: Bool = false,
            onboardingNicknameError: String? = nil,
            onboardingNicknameAvailable: Bool? = nil,
            onboardingNicknameSaving: Bool = false,
            userDisplayName: String? = nil,
            allRecords: [Record] = [],
            isInGalaxyDetail: Bool = false,
            currentYearMonth: String? = nil,
            currentDetailRecords: [Record] = [],
            showLimitAlert: Bool = false,
            showRecordPanel: Bool = false,
            recordContent: String = "",
            starName: String = "",
            isAnalyzingColor: Bool = false,
            analyzedProfile: StarVisualProfile? = nil,
            completedConstellationIds: [String] = [],
            searchText: String = "",
            isSearching: Bool = false,
            debouncedQuery: String = "",
            previewRevision: UInt = 0,
            pendingNavigation: PendingNavigation? = nil
        ) {
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.onboardingStep = onboardingStep
            self.onboardingGalaxyScreenCenter = onboardingGalaxyScreenCenter
            self.hasReceivedInitialRecords = hasReceivedInitialRecords
            self.pendingOnboardingCheck = pendingOnboardingCheck
            self.onboardingNickname = onboardingNickname
            self.onboardingNicknameChecking = onboardingNicknameChecking
            self.onboardingNicknameError = onboardingNicknameError
            self.onboardingNicknameAvailable = onboardingNicknameAvailable
            self.onboardingNicknameSaving = onboardingNicknameSaving
            self.userDisplayName = userDisplayName
            self.allRecords = allRecords
            self.isInGalaxyDetail = isInGalaxyDetail
            self.currentYearMonth = currentYearMonth
            self.currentDetailRecords = currentDetailRecords
            self.showLimitAlert = showLimitAlert
            self.showRecordPanel = showRecordPanel
            self.recordContent = recordContent
            self.starName = starName
            self.isAnalyzingColor = isAnalyzingColor
            self.analyzedProfile = analyzedProfile
            self.completedConstellationIds = completedConstellationIds
            self.searchText = searchText
            self.isSearching = isSearching
            self.debouncedQuery = debouncedQuery
            self.previewRevision = previewRevision
            self.pendingNavigation = pendingNavigation
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // Records
        case recordsUpdated([Record])

        // Scene Callbacks
        case sceneDidEnterGalaxyDetail(key: String, records: [Record])
        case sceneDidExitGalaxyDetail
        case sceneDidUpdateDetailRecords([Record])
        case sceneGalaxyBirthCompleted
        case sceneGalaxyScreenCenterUpdated(CGPoint?)
        case scenePreviewImagesUpdated

        // Search
        case searchTextChanged(String)
        case debouncedQueryUpdated(String)
        case closeSearch

        // Record Persistence
        case addRecordRequested(Record)

        // Record Panel
        case openRecordPanel
        case dismissPanel
        case saveRecord
        case colorAnalyzed(RecordColor)
        case profileAnalyzed(StarVisualProfile)
        case profileAnalysisFailed

        // Onboarding
        case checkOnboarding
        case onboardingAdvanceFromWelcome
        case onboardingAdvanceFromGuide
        case onboardingNicknameChanged(String)
        case onboardingCheckNickname
        case onboardingNicknameCheckResult(Bool)
        case onboardingNicknameCheckFailed(String)
        case onboardingNicknameConfirm
        case onboardingNicknameSaveCompleted
        case onboardingComplete
        case skipOnboarding

        // Navigation
        case navigateToGalaxy(String)
        case navigateToGalaxyThenStar(yearMonth: String, record: Record)
        case navigateToStar(Record)
    }

    enum CancelID { case debounce }

    @Dependency(\.openAIClient) var openAIClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.userClient) var userClient
    @Dependency(\.recordClient) var recordClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        // 기능별로 분리된 Reduce 블록들. 각 블록은 자신이 처리하는 액션만 매칭하고
        // 나머지는 default → .none 으로 흘려보낸다. 분할 파일은:
        // - UniverseFeature+SceneCallbacks.swift
        // - UniverseFeature+Search.swift
        // - UniverseFeature+RecordPanel.swift
        // - UniverseFeature+Onboarding.swift
        // - UniverseFeature+Navigation.swift
        Reduce { state, action in
            reduceSceneCallbacks(into: &state, action: action)
        }
        Reduce { state, action in
            reduceSearch(into: &state, action: action)
        }
        Reduce { state, action in
            reduceRecordPanel(into: &state, action: action)
        }
        Reduce { state, action in
            reduceOnboarding(into: &state, action: action)
        }
        Reduce { state, action in
            reduceNavigation(into: &state, action: action)
        }
    }
}
