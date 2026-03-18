import SwiftUI
import SpriteKit
import ComposableArchitecture
import DomainEntity
import DomainClient

// MARK: - SpriteKit UIViewRepresentable (키보드/레이아웃 변경 시 렌더링 중단 방지)

private struct SpriteKitView: UIViewRepresentable {
    let scene: UniverseScene

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.allowsTransparency = true
        skView.backgroundColor = .clear
        skView.presentScene(scene)
        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {}
}

public struct UniverseView: View {
    @Bindable var store: StoreOf<UniverseFeature>

    @State private var scene: UniverseScene = {
        let scene = UniverseScene(size: CGSize(width: 2000, height: 2000))
        scene.scaleMode = .resizeFill
        return scene
    }()

    @State private var sceneBridge: SceneDelegateBridge?

    @FocusState private var isTextFocused: Bool
    @FocusState private var isSearchFocused: Bool

    // 저장 중인 기록 정보 (GPT 분석 완료 후 scene에 전달)
    @State private var pendingSaveContent: String = ""
    @State private var pendingSaveName: String = ""
    @State private var pendingSaveIsOnboarding: Bool = false

    public init(store: StoreOf<UniverseFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            SpriteKitView(scene: scene)
                .ignoresSafeArea(.all)
                .onAppear { setupScene() }

            if store.isSearching {
                SearchOverlayView(store: store, isSearchFocused: $isSearchFocused)
            }

            if !store.showRecordPanel && !store.isOnboarding {
                GeometryReader { geo in
                    VStack {
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, store.isInGalaxyDetail
                                ? geo.safeAreaInsets.top + 64
                                : geo.safeAreaInsets.top + 4)
                        Spacer()
                    }
                    .ignoresSafeArea()
                }
            }

            plusButton

            OnboardingOverlayView(store: store)

            if store.showRecordPanel {
                VStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isTextFocused {
                                isTextFocused = false
                            } else {
                                withAnimation(.easeIn(duration: 0.25)) {
                                    store.send(.dismissPanel)
                                    scene.dismissPreviewStar()
                                }
                            }
                        }
                    RecordPanelView(store: store, scene: scene, isTextFocused: $isTextFocused)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .toolbar(store.isInGalaxyDetail || store.isOnboarding ? .hidden : .visible, for: .tabBar)
        .animation(.easeOut(duration: 0.3), value: store.showRecordPanel)
        .onChange(of: store.pendingNavigation) {
            guard let nav = store.pendingNavigation else { return }
            store.send(.binding(.set(\.pendingNavigation, nil)))
            switch nav {
            case .galaxy(let yearMonth):
                scene.navigateToGalaxy(yearMonth: yearMonth)
            case .star(let record):
                scene.navigateToStar(record: record)
            case .galaxyThenStar(let yearMonth, let record):
                scene.navigateToGalaxyThenStar(yearMonth: yearMonth, record: record)
            }
        }
        .onChange(of: store.allRecords) {
            scene.refreshGalaxies()
        }
        .onChange(of: store.onboardingStep) {
            if store.onboardingStep == .galaxyBirthIntro {
                scene.refreshGalaxies()
            }
        }
        .onChange(of: store.analyzedProfile) {
            guard let profile = store.analyzedProfile else { return }
            // GPT 감정 분석 완료 → scene에 기록 생성 요청
            scene.confirmPreviewStar()
            let content = pendingSaveContent
            let name = pendingSaveName
            let isOnboarding = pendingSaveIsOnboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                scene.createRecordAndRefresh(
                    content: content,
                    profile: profile,
                    starName: name,
                    isOnboardingRecord: isOnboarding
                )
            }
            pendingSaveContent = ""
            pendingSaveName = ""
            pendingSaveIsOnboarding = false
        }
        .onChange(of: store.isAnalyzingColor) {
            if store.isAnalyzingColor {
                // 분석 시작 시 현재 입력값 캡처
                pendingSaveContent = store.recordContent.trimmingCharacters(in: .whitespacesAndNewlines)
                pendingSaveName = store.starName
                pendingSaveIsOnboarding = store.onboardingStep == .createStarPrompt
                // 키보드 해제를 별도 프레임으로 분리하여 버튼 애니메이션 충돌 방지
                DispatchQueue.main.async {
                    isTextFocused = false
                }
            }
        }
        .alert("오늘의 기록을 이미 작성했어요", isPresented: $store.showLimitAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("하루에 1개까지 무료로 기록할 수 있어요")
        }
    }

    // MARK: - Plus Button

    @ViewBuilder
    private var plusButton: some View {
        let showPlusButton = store.isInGalaxyDetail
            && !store.showRecordPanel && !store.isSearching
            && (store.onboardingStep == .createStarPrompt || !store.isOnboarding)
        if showPlusButton {
            let canCreate = store.onboardingStep == .createStarPrompt || store.canCreateRecord
            let remaining = store.remainingRecordCount
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        if store.onboardingStep != .createStarPrompt {
                            Text("\(remaining)/\(UniverseFeature.State.dailyRecordLimit)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Button {
                            store.send(.openRecordPanel)
                            scene.showPreviewStar(color: .fallback)
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.black)
                                .frame(width: 52, height: 52)
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.55, green: 0.83, blue: 0.97))
                                        .shadow(color: Color(red: 0.55, green: 0.83, blue: 0.97).opacity(0.5), radius: 8)
                                )
                        }
                        .opacity(canCreate ? 1.0 : 0.4)
                        .overlay {
                            if store.onboardingStep == .createStarPrompt {
                                PlusPulsingRing()
                            }
                        }
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            ZStack(alignment: .leading) {
                if store.searchText.isEmpty {
                    Text(store.isInGalaxyDetail ? "별 검색" : "은하·별 검색")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                TextField("", text: Binding(
                    get: { store.searchText },
                    set: { store.send(.searchTextChanged($0)) }
                ))
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .tint(.white)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .onSubmit { isSearchFocused = false }
                    .onChange(of: isSearchFocused) {
                        if isSearchFocused {
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.send(.binding(.set(\.isSearching, true)))
                            }
                        }
                    }
            }

            if store.isSearching {
                Button {
                    store.send(.closeSearch)
                    isSearchFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Text("취소")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(store.isSearching ? 0.14 : 0.08)))
    }

    // MARK: - Scene Setup

    private func setupScene() {
        let bridge = SceneDelegateBridge(store: store)
        sceneBridge = bridge
        scene.sceneDelegate = bridge
        store.send(.checkOnboarding)
        scene.refreshGalaxies()
    }
}

// MARK: - Scene <-> TCA Bridge

protocol UniverseSceneDelegate: AnyObject {
    func didEnterGalaxyDetail(key: String, records: [DomainEntity.Record])
    func didExitGalaxyDetail()
    func didUpdateDetailRecords(_ records: [DomainEntity.Record])
    func galaxyBirthCompleted()
    func galaxyScreenCenterUpdated(_ center: CGPoint?)
    func previewImagesUpdated(galaxies: [String: UIImage])
    func getAllRecords() -> [DomainEntity.Record]
    func getIsOnboarding() -> Bool
    func getOnboardingStep() -> OnboardingStep?
    func addRecord(_ record: DomainEntity.Record)
    func didTapEmptyArea()
}

@MainActor
final class SceneDelegateBridge: UniverseSceneDelegate {
    let store: StoreOf<UniverseFeature>

    init(store: StoreOf<UniverseFeature>) {
        self.store = store
    }

    func didEnterGalaxyDetail(key: String, records: [DomainEntity.Record]) {
        store.send(.sceneDidEnterGalaxyDetail(key: key, records: records))
    }

    func didExitGalaxyDetail() {
        store.send(.sceneDidExitGalaxyDetail)
    }

    func didUpdateDetailRecords(_ records: [DomainEntity.Record]) {
        store.send(.sceneDidUpdateDetailRecords(records))
    }

    func galaxyBirthCompleted() {
        store.send(.sceneGalaxyBirthCompleted)
    }

    func galaxyScreenCenterUpdated(_ center: CGPoint?) {
        store.send(.sceneGalaxyScreenCenterUpdated(center))
    }

    func previewImagesUpdated(galaxies: [String: UIImage]) {
        store.send(.scenePreviewImagesUpdated(galaxies: galaxies))
    }

    func getAllRecords() -> [DomainEntity.Record] {
        store.allRecords
    }

    func getIsOnboarding() -> Bool {
        store.isOnboarding
    }

    func getOnboardingStep() -> OnboardingStep? {
        store.onboardingStep
    }

    func addRecord(_ record: DomainEntity.Record) {
        @Dependency(\.authClient) var authClient
        @Dependency(\.recordClient) var recordClient
        guard let userId = authClient.currentUser()?.uid else { return }
        Task {
            try? await recordClient.addRecord(userId, record)
        }
    }

    func didTapEmptyArea() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Plus Button Pulsing Effect

private struct PlusPulsingRing: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.55, green: 0.83, blue: 0.97).opacity(0.6), lineWidth: 2)
                .frame(width: 52, height: 52)
                .scaleEffect(isPulsing ? 1.6 : 1.0)
                .opacity(isPulsing ? 0 : 0.8)
            Circle()
                .stroke(Color(red: 0.55, green: 0.83, blue: 0.97).opacity(0.4), lineWidth: 1.5)
                .frame(width: 52, height: 52)
                .scaleEffect(isPulsing ? 1.3 : 0.9)
                .opacity(isPulsing ? 0.2 : 0.6)
        }
        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
        .onAppear { isPulsing = true }
        .allowsHitTesting(false)
    }
}
