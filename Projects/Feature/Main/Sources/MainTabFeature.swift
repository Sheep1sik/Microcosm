import ComposableArchitecture
import DomainEntity
import DomainClient
import FeatureUniverse
import FeatureProfile

@Reducer
public struct MainTabFeature {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: Tab = .universe
        public var universe = UniverseFeature.State()
        public var profile = ProfileFeature.State()
        public var userId: String?

        public enum Tab: Equatable {
            case universe
            case profile
        }

        public init(
            selectedTab: Tab = .universe,
            universe: UniverseFeature.State = UniverseFeature.State(),
            profile: ProfileFeature.State = ProfileFeature.State(),
            userId: String? = nil
        ) {
            self.selectedTab = selectedTab
            self.universe = universe
            self.profile = profile
            self.userId = userId
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case tabSelected(State.Tab)
        case recordsUpdated([Record])
        case universe(UniverseFeature.Action)
        case profile(ProfileFeature.Action)
    }

    @Dependency(\.recordClient) var recordClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.universe, action: \.universe) { UniverseFeature() }
        Scope(state: \.profile, action: \.profile) { ProfileFeature() }

        Reduce { state, action in
            switch action {
            case .onAppear:
                guard let userId = state.userId else { return .none }
                return .run { send in
                    for await records in recordClient.observe(userId) {
                        await send(.recordsUpdated(records))
                    }
                }

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .recordsUpdated(let records):
                state.universe.allRecords = records
                return .none

            case .universe:
                return .none

            case .profile:
                return .none

            case .binding:
                return .none
            }
        }
    }
}
