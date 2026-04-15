import SwiftUI
import SpriteKit
import ComposableArchitecture
import DomainEntity
import DomainClient
import SharedDesignSystem

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

    public init(store: StoreOf<UniverseFeature>) {
        self.store = store
    }

    public var body: some View {
        mainContent
            .toolbar(store.isInGalaxyDetail || store.isOnboarding || store.isSearching ? .hidden : .visible, for: .tabBar)
            .animation(.easeOut(duration: 0.3), value: store.showRecordPanel)
            .modifier(SceneChangeHandlers(store: store, scene: scene, isTextFocused: $isTextFocused))
            .alert("오늘의 기록을 이미 작성했어요", isPresented: $store.showLimitAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("하루에 1개까지 무료로 기록할 수 있어요")
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            SpriteKitView(scene: scene)
                .ignoresSafeArea(.all)
                .onAppear { setupScene() }

            searchButton

            if store.isSearching {
                SearchOverlayView(store: store, isSearchFocused: $isSearchFocused)
                    .transition(.opacity)
            }

            plusButton

            OnboardingOverlayView(store: store)

            recordPanelOverlay
        }
        .animation(.easeOut(duration: 0.2), value: store.isSearching)
    }

    // MARK: - Search Button

    @ViewBuilder
    private var searchButton: some View {
        if !store.showRecordPanel && !store.isOnboarding && !store.isSearching {
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            _ = store.send(.binding(.set(\.isSearching, true)))
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
    }

    // MARK: - Record Panel Overlay

    @ViewBuilder
    private var recordPanelOverlay: some View {
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
                                        .fill(AppColors.accent)
                                        .shadow(color: AppColors.accent.opacity(0.5), radius: 8)
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

    // MARK: - Scene Setup

    private func setupScene() {
        let bridge = SceneDelegateBridge(store: store)
        sceneBridge = bridge
        scene.sceneDelegate = bridge
        scene.previewCache = bridge.previewImageCache
        store.send(.checkOnboarding)
        scene.refreshGalaxies()
    }
}

// MARK: - Scene onChange Handlers (body 복잡도 분산)

private struct SceneChangeHandlers: ViewModifier {
    @Bindable var store: StoreOf<UniverseFeature>
    let scene: UniverseScene
    var isTextFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .onChange(of: store.pendingNavigation) {
                handleNavigation()
            }
            .onChange(of: store.allRecords) {
                scene.refreshGalaxies()
            }
            .onChange(of: store.hasReceivedInitialRecords) {
                // records 가 빈 배열(`[]→[]`)로 도착해 allRecords onChange 가 트리거되지 않는
                // 엣지 케이스(온보딩 완료했지만 기록이 0개인 유저 등)를 위한 보완 경로.
                // setupScene 의 첫 refreshGalaxies 는 `isOnboardingUndecided`에서 early-return 되므로,
                // observer 응답이 도착한 시점에 한 번 호출해 현재월 빈 은하를 만들어준다.
                if store.hasReceivedInitialRecords {
                    scene.refreshGalaxies()
                }
            }
            .onChange(of: store.onboardingStep) {
                if store.onboardingStep == .galaxyBirthIntro {
                    scene.refreshGalaxies()
                }
            }
            .onChange(of: store.isAnalyzingColor) {
                if store.isAnalyzingColor {
                    DispatchQueue.main.async {
                        isTextFocused.wrappedValue = false
                    }
                }
            }
            .onChange(of: store.pendingStarCreation) {
                handlePendingStarCreation()
            }
            .onChange(of: store.completedConstellationIds) {
                scene.updateCompletedConstellations(ids: store.completedConstellationIds)
            }
    }

    private func handleNavigation() {
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

    private func handlePendingStarCreation() {
        guard let pending = store.pendingStarCreation else { return }
        scene.confirmPreviewStar()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            scene.createRecordAndRefresh(
                content: pending.content,
                profile: pending.profile,
                starName: pending.starName,
                isOnboardingRecord: pending.isOnboardingRecord
            )
        }
        store.send(.clearPendingStarCreation)
    }
}

// MARK: - Scene <-> TCA Bridge

protocol UniverseSceneDelegate: AnyObject {
    func didEnterGalaxyDetail(key: String, records: [DomainEntity.Record])
    func didExitGalaxyDetail()
    func didUpdateDetailRecords(_ records: [DomainEntity.Record])
    func galaxyBirthCompleted()
    func galaxyScreenCenterUpdated(_ center: CGPoint?)
    func previewImagesUpdated(galaxies: [String: UIImage], stars: [String: UIImage])
    @MainActor func getAllRecords() -> [DomainEntity.Record]
    func getIsOnboarding() -> Bool
    func getOnboardingStep() -> OnboardingStep?
    /// records observer가 최소 1회 응답하기 전까지는 true.
    /// 이 상태에서 은하를 그리면 온보딩 여부 결정 전에 현재월 은하가 애니메이션 없이 먼저 생성돼
    /// 이후 `.galaxyBirthIntro` 단계의 출생 모션이 사라지는 회귀를 유발한다.
    func isOnboardingUndecided() -> Bool
    func addRecord(_ record: DomainEntity.Record)
    func didTapEmptyArea()
}

@MainActor
final class SceneDelegateBridge: UniverseSceneDelegate {
    let store: StoreOf<UniverseFeature>
    @Dependency(\.previewImageCache) var previewImageCache

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

    func previewImagesUpdated(galaxies: [String: UIImage], stars: [String: UIImage]) {
        previewImageCache.update(galaxies: galaxies, stars: stars)
        store.send(.scenePreviewImagesUpdated)
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

    func isOnboardingUndecided() -> Bool {
        !store.hasReceivedInitialRecords
    }

    func addRecord(_ record: DomainEntity.Record) {
        store.send(.addRecordRequested(record))
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
                .stroke(AppColors.accent.opacity(0.6), lineWidth: 2)
                .frame(width: 52, height: 52)
                .scaleEffect(isPulsing ? 1.6 : 1.0)
                .opacity(isPulsing ? 0 : 0.8)
            Circle()
                .stroke(AppColors.accent.opacity(0.4), lineWidth: 1.5)
                .frame(width: 52, height: 52)
                .scaleEffect(isPulsing ? 1.3 : 0.9)
                .opacity(isPulsing ? 0.2 : 0.6)
        }
        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
        .onAppear { isPulsing = true }
        .allowsHitTesting(false)
    }
}
