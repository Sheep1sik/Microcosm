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
        mainContent
            .toolbar(store.isInGalaxyDetail || store.isOnboarding ? .hidden : .visible, for: .tabBar)
            .animation(.easeOut(duration: 0.3), value: store.showRecordPanel)
            .modifier(SceneChangeHandlers(store: store, scene: scene, pendingSaveContent: $pendingSaveContent, pendingSaveName: $pendingSaveName, pendingSaveIsOnboarding: $pendingSaveIsOnboarding, isTextFocused: $isTextFocused))
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

    // MARK: - Scene Setup

    private func setupScene() {
        let bridge = SceneDelegateBridge(store: store)
        sceneBridge = bridge
        scene.sceneDelegate = bridge
        store.send(.checkOnboarding)
        scene.refreshGalaxies()
    }
}

// MARK: - Scene onChange Handlers (body 복잡도 분산)

private struct SceneChangeHandlers: ViewModifier {
    @Bindable var store: StoreOf<UniverseFeature>
    let scene: UniverseScene
    @Binding var pendingSaveContent: String
    @Binding var pendingSaveName: String
    @Binding var pendingSaveIsOnboarding: Bool
    var isTextFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .onChange(of: store.pendingNavigation) {
                handleNavigation()
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
                handleProfileAnalyzed()
            }
            .onChange(of: store.isAnalyzingColor) {
                handleAnalyzingColor()
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

    private func handleProfileAnalyzed() {
        guard let profile = store.analyzedProfile else { return }
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

    private func handleAnalyzingColor() {
        if store.isAnalyzingColor {
            pendingSaveContent = store.recordContent.trimmingCharacters(in: .whitespacesAndNewlines)
            pendingSaveName = store.starName
            pendingSaveIsOnboarding = store.onboardingStep == .createStarPrompt
            DispatchQueue.main.async {
                isTextFocused.wrappedValue = false
            }
        }
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

    func previewImagesUpdated(galaxies: [String: UIImage], stars: [String: UIImage]) {
        store.send(.scenePreviewImagesUpdated(galaxies: galaxies, stars: stars))
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
