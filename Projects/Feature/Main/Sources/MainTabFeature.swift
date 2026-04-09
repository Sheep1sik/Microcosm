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

            case .recordsUpdated(let records):
                state.universe.allRecords = records
                return .none

            case .goalsUpdated(let goals):
                state.constellation.allGoals = goals

                // 별자리 완성/해제 메시지 체크
                let change = ConstellationFeature.checkConstellationCompletion(
                    goals: goals,
                    previouslyCompletedIds: &state.constellation.previouslyCompletedIds
                )
                // 첫 로드 시에는 메시지 없이 previouslyCompletedIds만 초기화
                if !state.constellation.hasInitialGoalsLoaded {
                    state.constellation.hasInitialGoalsLoaded = true
                } else {
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

                // 완성된 별자리 ID 계산 → Universe 배경에 표시
                let completedIds = ConstellationCatalog.all.compactMap { def -> String? in
                    let cGoals = goals.filter { $0.constellationId == def.id }
                    guard !cGoals.isEmpty else { return nil }
                    // 모든 별에 목표가 있고 모두 완료
                    let allStarIndices = Set(def.stars.map(\.index))
                    let starIndicesWithGoals = Set(cGoals.map(\.starIndex))
                    guard allStarIndices.isSubset(of: starIndicesWithGoals) else { return nil }
                    let allDone = cGoals.allSatisfy(\.isCompleted)
                    return allDone ? def.id : nil
                }
                state.universe.completedConstellationIds = completedIds
                return .none

            case .universe:
                return .none

            case .constellation(.toggleGoalCompletion),
                 .constellation(.toggleSubGoal),
                 .constellation(.goalSaved),
                 .constellation(.goalDeleted):
                // 낙관적 업데이트 후 즉시 완성/해제 체크
                if state.constellation.hasInitialGoalsLoaded {
                    let change = ConstellationFeature.checkConstellationCompletion(
                        goals: state.constellation.allGoals,
                        previouslyCompletedIds: &state.constellation.previouslyCompletedIds
                    )
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

                // 완성된 별자리 ID 갱신
                let updatedCompletedIds = ConstellationCatalog.all.compactMap { def -> String? in
                    let cGoals = state.constellation.allGoals.filter { $0.constellationId == def.id }
                    guard !cGoals.isEmpty else { return nil }
                    let allStarIndices = Set(def.stars.map(\.index))
                    let starIndicesWithGoals = Set(cGoals.map(\.starIndex))
                    guard allStarIndices.isSubset(of: starIndicesWithGoals) else { return nil }
                    return cGoals.allSatisfy(\.isCompleted) ? def.id : nil
                }
                state.universe.completedConstellationIds = updatedCompletedIds
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
}
