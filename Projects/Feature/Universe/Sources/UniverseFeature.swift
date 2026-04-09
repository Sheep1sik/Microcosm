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

        // Preview Images (실제 이미지는 PreviewImageCache.shared에 보관)
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

    private enum CancelID { case debounce }

    @Dependency(\.openAIClient) var openAIClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.userClient) var userClient
    @Dependency(\.recordClient) var recordClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .addRecordRequested(let record):
                return .run { [authClient, recordClient] send in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try await recordClient.addRecord(userId, record)
                } catch: { _, _ in
                    // Firestore 오프라인 캐시로 즉각 실패가 드물며,
                    // recordClient.observe가 실시간 상태를 반영하므로 별도 에러 액션 불필요
                }

            case .recordsUpdated(let records):
                state.allRecords = records
                return .none

            // MARK: - Scene Callbacks
            case .sceneDidEnterGalaxyDetail(let key, let records):
                state.isInGalaxyDetail = true
                state.currentYearMonth = key
                state.currentDetailRecords = records
                if state.onboardingStep == .tapGalaxyPrompt {
                    state.onboardingStep = .createStarPrompt
                }
                return .none

            case .sceneDidExitGalaxyDetail:
                state.isInGalaxyDetail = false
                state.currentYearMonth = nil
                state.currentDetailRecords = []
                return .none

            case .sceneDidUpdateDetailRecords(let records):
                state.currentDetailRecords = records
                return .none

            case .sceneGalaxyBirthCompleted:
                if state.onboardingStep == .galaxyBirthIntro {
                    state.onboardingStep = .monthlyGalaxyGuide
                }
                return .none

            case .sceneGalaxyScreenCenterUpdated(let center):
                state.onboardingGalaxyScreenCenter = center
                return .none

            case .scenePreviewImagesUpdated:
                state.previewRevision &+= 1
                return .none

            // MARK: - Search
            case .searchTextChanged(let text):
                state.searchText = text
                return .run { send in
                    try await Task.sleep(for: .milliseconds(250))
                    await send(.debouncedQueryUpdated(text))
                }
                .cancellable(id: CancelID.debounce, cancelInFlight: true)

            case .debouncedQueryUpdated(let query):
                state.debouncedQuery = query
                return .none

            case .closeSearch:
                state.searchText = ""
                state.debouncedQuery = ""
                state.isSearching = false
                return .cancel(id: CancelID.debounce)

            // MARK: - Record Panel
            case .openRecordPanel:
                if state.onboardingStep != .createStarPrompt {
                    guard state.canCreateRecord else {
                        state.showLimitAlert = true
                        return .none
                    }
                }
                state.recordContent = ""
                state.starName = ""
                state.analyzedProfile = nil
                state.isAnalyzingColor = false
                state.showRecordPanel = true
                return .none

            case .dismissPanel:
                state.recordContent = ""
                state.starName = ""
                state.analyzedProfile = nil
                state.isAnalyzingColor = false
                state.showRecordPanel = false
                return .none

            case .saveRecord:
                let trimmed = state.recordContent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                state.isAnalyzingColor = true
                let content = trimmed
                return .run { send in
                    // Fallback chain: analyzeEmotion → analyzeColor → fallback
                    do {
                        let profile = try await openAIClient.analyzeEmotion(content)
                        await send(.profileAnalyzed(profile))
                    } catch {
                        do {
                            let color = try await openAIClient.analyzeColor(content)
                            await send(.colorAnalyzed(color))
                        } catch {
                            await send(.profileAnalysisFailed)
                        }
                    }
                }

            case .profileAnalyzed(let profile):
                state.analyzedProfile = profile
                state.isAnalyzingColor = false
                state.showRecordPanel = false
                if state.onboardingStep == .createStarPrompt {
                    state.onboardingStep = .closingMessage
                }
                return .none

            case .colorAnalyzed(let color):
                state.analyzedProfile = StarVisualProfile.from(legacyColor: color)
                state.isAnalyzingColor = false
                state.showRecordPanel = false
                if state.onboardingStep == .createStarPrompt {
                    state.onboardingStep = .closingMessage
                }
                return .none

            case .profileAnalysisFailed:
                state.analyzedProfile = .fallback
                state.isAnalyzingColor = false
                state.showRecordPanel = false
                if state.onboardingStep == .createStarPrompt {
                    state.onboardingStep = .closingMessage
                }
                return .none

            // MARK: - Onboarding
            case .checkOnboarding:
                guard !state.hasCompletedOnboarding else { return .none }
                if !state.allRecords.isEmpty {
                    state.hasCompletedOnboarding = true
                    return .none
                }
                state.onboardingStep = .welcome
                return .none

            case .onboardingAdvanceFromWelcome:
                guard state.onboardingStep == .welcome else { return .none }
                state.onboardingStep = .nicknameInput
                return .none

            case .onboardingNicknameChanged(let text):
                state.onboardingNickname = text
                state.onboardingNicknameError = nil
                state.onboardingNicknameAvailable = nil
                return .none

            case .onboardingCheckNickname:
                let trimmed = state.onboardingNickname.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 2, trimmed.count <= 10 else {
                    state.onboardingNicknameError = "2~10자로 입력해주세요"
                    return .none
                }
                state.onboardingNicknameChecking = true
                state.onboardingNicknameError = nil
                state.onboardingNicknameAvailable = nil
                let nickname = trimmed
                return .run { send in
                    do {
                        let available = try await userClient.checkNickname(nickname)
                        await send(.onboardingNicknameCheckResult(available))
                    } catch {
                        await send(.onboardingNicknameCheckFailed("확인 중 오류가 발생했어요"))
                    }
                }

            case .onboardingNicknameCheckResult(let available):
                state.onboardingNicknameChecking = false
                if available {
                    state.onboardingNicknameAvailable = true
                    state.onboardingNicknameError = nil
                } else {
                    state.onboardingNicknameAvailable = false
                    state.onboardingNicknameError = "이미 사용 중인 닉네임이에요"
                }
                return .none

            case .onboardingNicknameCheckFailed(let message):
                state.onboardingNicknameChecking = false
                state.onboardingNicknameError = message
                return .none

            case .onboardingNicknameConfirm:
                let trimmed = state.onboardingNickname.trimmingCharacters(in: .whitespacesAndNewlines)
                guard state.onboardingNicknameAvailable == true else { return .none }
                state.onboardingNicknameSaving = true
                let nickname = trimmed
                return .run { send in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try await userClient.setNickname(userId, nickname)
                    await send(.onboardingNicknameSaveCompleted)
                }

            case .onboardingNicknameSaveCompleted:
                state.onboardingNicknameSaving = false
                state.userDisplayName = state.onboardingNickname.trimmingCharacters(in: .whitespacesAndNewlines)
                state.onboardingStep = .galaxyBirthIntro
                return .none

            case .onboardingAdvanceFromGuide:
                guard state.onboardingStep == .monthlyGalaxyGuide else { return .none }
                state.onboardingStep = .tapGalaxyPrompt
                return .none

            case .onboardingComplete:
                guard state.onboardingStep != .completed else { return .none }
                state.onboardingStep = .completed
                state.hasCompletedOnboarding = true
                return .run { _ in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try? await userClient.markOnboardingCompleted(userId)
                }

            case .skipOnboarding:
                state.onboardingStep = .completed
                state.hasCompletedOnboarding = true
                return .run { _ in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try? await userClient.markOnboardingCompleted(userId)
                }

            // MARK: - Navigation (View에서 scene 메서드 호출)
            case .navigateToGalaxy(let yearMonth):
                state.pendingNavigation = .galaxy(yearMonth)
                return .none

            case .navigateToGalaxyThenStar(let yearMonth, let record):
                state.pendingNavigation = .galaxyThenStar(yearMonth: yearMonth, record: record)
                return .none

            case .navigateToStar(let record):
                state.pendingNavigation = .star(record)
                return .none

            case .binding:
                return .none
            }
        }
    }
}
