import SwiftUI
import ComposableArchitecture
import DomainEntity
import DomainClient

public typealias Record = DomainEntity.Record

public enum OnboardingStep: Int, Equatable {
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
        public static let monthlyRecordLimit = 10
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

        // Preview Images
        public var galaxyPreviewImages: [String: UIImage] = [:]

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

        public func currentMonthRecordCount() -> Int {
            let cal = Calendar.current
            let now = Date()
            let year = cal.component(.year, from: now)
            let month = cal.component(.month, from: now)
            return allRecords.filter {
                !$0.isOnboardingRecord &&
                cal.component(.year, from: $0.createdAt) == year &&
                cal.component(.month, from: $0.createdAt) == month
            }.count
        }

        public var remainingRecordCount: Int {
            max(0, Self.monthlyRecordLimit - currentMonthRecordCount())
        }

        public var canCreateRecord: Bool {
            currentMonthRecordCount() < Self.monthlyRecordLimit
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
            searchText: String = "",
            isSearching: Bool = false,
            debouncedQuery: String = "",
            galaxyPreviewImages: [String: UIImage] = [:],
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
            self.searchText = searchText
            self.isSearching = isSearching
            self.debouncedQuery = debouncedQuery
            self.galaxyPreviewImages = galaxyPreviewImages
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
        case scenePreviewImagesUpdated(galaxies: [String: UIImage])

        // Search
        case searchTextChanged(String)
        case debouncedQueryUpdated(String)
        case closeSearch

        // Record Panel
        case openRecordPanel
        case dismissPanel
        case saveRecord
        case colorAnalyzed(RecordColor)
        case profileAnalyzed(StarVisualProfile)
        case profileAnalysisFailed

        // Onboarding
        case checkOnboarding
        case onboardingAdvanceFromGuide
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

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
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

            case .scenePreviewImagesUpdated(let galaxies):
                state.galaxyPreviewImages = galaxies
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
