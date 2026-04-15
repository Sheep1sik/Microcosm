import ComposableArchitecture
import DomainEntity
import DomainClient
import FeatureUniverse
import FeatureConstellation
import FeatureProfile

@Reducer
public struct MainTabFeature {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: Tab = .universe
        public var universe = UniverseFeature.State()
        public var constellation = ConstellationFeature.State()
        public var profile = ProfileFeature.State()
        public var userId: String?

        public enum Tab: Equatable {
            case universe
            case constellation
            case profile
        }

        public init(
            selectedTab: Tab = .universe,
            universe: UniverseFeature.State = UniverseFeature.State(),
            constellation: ConstellationFeature.State = ConstellationFeature.State(),
            profile: ProfileFeature.State = ProfileFeature.State(),
            userId: String? = nil
        ) {
            self.selectedTab = selectedTab
            self.universe = universe
            self.constellation = constellation
            self.profile = profile
            self.userId = userId
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case tabSelected(State.Tab)
        case sessionUpdated(userId: String?, displayName: String?, profile: UserProfile)
        case recordsUpdated([Record])
        case goalsUpdated([Goal])
        case universe(UniverseFeature.Action)
        case constellation(ConstellationFeature.Action)
        case profile(ProfileFeature.Action)
    }

    @Dependency(\.recordClient) var recordClient
    @Dependency(\.goalClient) var goalClient

    private enum CancelID { case recordObserver, goalObserver }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.universe, action: \.universe) { UniverseFeature() }
        Scope(state: \.constellation, action: \.constellation) { ConstellationFeature() }
        Scope(state: \.profile, action: \.profile) { ProfileFeature() }

        Reduce { state, action in
            switch action {
            case .onAppear:
                guard let userId = state.userId else { return .none }
                return .merge(
                    .run { send in
                        for await records in recordClient.observe(userId) {
                            await send(.recordsUpdated(records))
                        }
                    }.cancellable(id: CancelID.recordObserver, cancelInFlight: true),
                    .run { send in
                        for await goals in goalClient.observe(userId) {
                            await send(.goalsUpdated(goals))
                        }
                    }.cancellable(id: CancelID.goalObserver, cancelInFlight: true)
                )

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .sessionUpdated(let userId, let displayName, let profile):
                // Root 에서 분산 갱신되던 프로필 연관 상태를 한 곳에서 처리.
                let effectiveName = profile.nickname ?? displayName
                state.userId = userId
                state.universe.userDisplayName = effectiveName
                state.universe.hasCompletedOnboarding = profile.hasCompletedOnboarding
                state.constellation.userDisplayName = effectiveName
                state.constellation.hasSeenConstellationGuide = profile.hasSeenConstellationGuide
                state.profile.userProfile = profile
                state.profile.displayName = effectiveName
                // Universe reducer 에게 profile 최초 도착을 알려 pending checkOnboarding 을
                // drain 시킨다. State 직접 대입만 하면 reducer 내부의 flag/pending 경로가
                // 안 돌아가 records 만 먼저 도착한 유저가 welcome 으로 잘못 진입한다.
                return .send(.universe(.profileReceived))

            case .recordsUpdated(let records):
                // Universe 는 reducer 내부에서 hasReceivedInitialRecords 플래그를 토글하고
                // 보류 중인 checkOnboarding 을 재발송한다. state 직접 대입은 이 경로를 우회하므로
                // 반드시 action 포워딩으로 전달해야 한다.
                state.profile.allRecords = records
                state.constellation.userDisplayName = state.universe.userDisplayName
                return .send(.universe(.recordsUpdated(records)))

            case .goalsUpdated(let goals):
                state.constellation.allGoals = goals
                Self.recomputeCompletion(state: &state, goals: goals, isFromObserver: true)
                return .none

            case .universe:
                return .none

            case .constellation(.toggleGoalCompletion),
                 .constellation(.toggleAllSubGoals),
                 .constellation(.toggleSubGoal),
                 .constellation(.goalSaved),
                 .constellation(.goalDeleted):
                // 낙관적 업데이트 후 즉시 완성/해제 체크
                Self.recomputeCompletion(state: &state, goals: state.constellation.allGoals, isFromObserver: false)
                return .none

            case .constellation:
                return .none

            case .profile:
                return .none

            case .binding:
                return .none
            }
        }
    }

    // MARK: - Completion Recompute

    /// 별자리 완성/해제 메시지 갱신 + Universe 배경에 표시될 완성 ID 계산.
    /// - Parameter isFromObserver: `goalsUpdated`(true)는 첫 로드 시 메시지를 띄우지 않음.
    ///   낙관적 업데이트 경로(false)는 항상 메시지 평가.
    private static func recomputeCompletion(state: inout State, goals: [Goal], isFromObserver: Bool) {
        let shouldEmitMessage: Bool
        if isFromObserver {
            if !state.constellation.hasInitialGoalsLoaded {
                state.constellation.hasInitialGoalsLoaded = true
                shouldEmitMessage = false
            } else {
                shouldEmitMessage = true
            }
        } else {
            shouldEmitMessage = state.constellation.hasInitialGoalsLoaded
        }

        let change = ConstellationFeature.checkConstellationCompletion(
            goals: goals,
            previouslyCompletedIds: &state.constellation.previouslyCompletedIds
        )

        if shouldEmitMessage {
            if let completedId = change.newlyCompleted {
                let def = ConstellationCatalog.find(completedId)
                state.constellation.completedConstellationMessage = "\(def?.nameKO ?? completedId)의\n모든 별들이 빛을 찾았어요!"
                let name = state.universe.userDisplayName ?? "우주인"
                state.constellation.completedConstellationSubtitle = "완성된 별자리는 \(name)님의 소우주에서도 볼 수 있어요"
            } else if let lostId = change.newlyLost {
                let def = ConstellationCatalog.find(lostId)
                state.constellation.completedConstellationMessage = "\(def?.nameKO ?? lostId)의\n별자리가 빛을 잃었어요"
                state.constellation.completedConstellationSubtitle = "목표를 다시 달성하면 별자리가 빛을 되찾아요"
            }
        }

        state.universe.completedConstellationIds = ConstellationCatalog.all.compactMap { def in
            let cGoals = goals.filter { $0.constellationId == def.id }
            guard !cGoals.isEmpty else { return nil }
            let allStarIndices = Set(def.stars.map(\.index))
            let starIndicesWithGoals = Set(cGoals.map(\.starIndex))
            guard allStarIndices.isSubset(of: starIndicesWithGoals) else { return nil }
            return cGoals.allSatisfy(\.isCompleted) ? def.id : nil
        }
    }
}
