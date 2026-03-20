import SwiftUI
import SpriteKit
import ComposableArchitecture
import DomainEntity

// MARK: - SpriteKit UIViewRepresentable

private struct SpriteKitView: UIViewRepresentable {
    let scene: ConstellationScene

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

public struct ConstellationView: View {
    @Bindable var store: StoreOf<ConstellationFeature>

    @State private var scene: ConstellationScene = {
        let scene = ConstellationScene(size: CGSize(width: 2000, height: 2000))
        scene.scaleMode = .resizeFill
        return scene
    }()

    @State private var sceneBridge: ConstellationSceneDelegateBridge?

    public init(store: StoreOf<ConstellationFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            SpriteKitView(scene: scene)
                .ignoresSafeArea(.all)
                .onAppear { setupScene() }

            searchButton

            // 검색 오버레이
            if store.isSearching {
                constellationSearchOverlay
                    .transition(.opacity)
            }

            // 목표 패널 (편집 모드가 아닐 때)
            if store.showGoalPanel && !store.isEditingGoal {
                GoalPanelView(store: store)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 목표 편집 뷰
            if store.isEditingGoal {
                GoalEditView(store: store)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 별자리 완성 축하 메시지
            if let message = store.completedConstellationMessage {
                constellationCompletionOverlay(message: message)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .toolbar(store.isInConstellationDetail ? .hidden : .visible, for: .tabBar)
        .animation(.easeOut(duration: 0.3), value: store.showGoalPanel)
        .animation(.easeOut(duration: 0.3), value: store.isEditingGoal)
        .animation(.easeOut(duration: 0.2), value: store.isSearching)
        .animation(.spring(duration: 0.5), value: store.completedConstellationMessage != nil)
        .onChange(of: store.allGoals) {
            scene.updateStarBrightness(goals: store.allGoals)
        }
        .onChange(of: store.pendingNavigation) {
            guard let nav = store.pendingNavigation else { return }
            store.send(.binding(.set(\.pendingNavigation, nil)))
            switch nav {
            case .zoomToConstellation(let id):
                scene.zoomInToConstellation(id: id)
            }
        }
    }

    // MARK: - Search Button

    @ViewBuilder
    private var searchButton: some View {
        if !store.isInConstellationDetail && !store.isSearching {
            VStack {
                HStack {
                    Spacer()
                    Button {
                        store.send(.toggleSearch)
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

    // MARK: - Search Overlay

    private var constellationSearchOverlay: some View {
        VStack(spacing: 0) {
            // 검색 바
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.5))
                TextField("별자리 검색", text: Binding(
                    get: { store.searchText },
                    set: { store.send(.searchTextChanged($0)) }
                ))
                .foregroundStyle(.white)
                .autocorrectionDisabled()

                Button {
                    store.send(.toggleSearch)
                } label: {
                    Text("취소")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // 검색 결과
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.searchResults) { def in
                        Button {
                            store.send(.selectSearchResult(def.id))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(def.nameKO)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white)
                                    Text(def.nameEN)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer()
                                Text(def.id)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
            .padding(.top, 8)
        }
        .background(Color.black.opacity(0.85))
    }

    // MARK: - Completion Overlay (Tutorial Style)

    private func constellationCompletionOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                CompletionTypewriterText(text: message)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.4), radius: 12)
                    .multilineTextAlignment(.center)

                if let subtitle = store.completedConstellationSubtitle {
                    CompletionTypewriterText(text: subtitle, speed: 0.03, delay: 1.5)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Text("탭하여 계속")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 32)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.send(.dismissCompletionMessage)
        }
    }

    // MARK: - Scene Setup

    private func setupScene() {
        let bridge = ConstellationSceneDelegateBridge(store: store)
        sceneBridge = bridge
        scene.sceneDelegate = bridge
        store.send(.onAppear)
        // 초기 밝기 반영
        scene.updateStarBrightness(goals: store.allGoals)
    }
}

// MARK: - Typewriter Text (Completion Overlay)

private struct CompletionTypewriterText: View {
    let text: String
    var speed: TimeInterval = 0.04
    var delay: TimeInterval = 0

    @State private var displayedText = ""

    var body: some View {
        Text(displayedText)
            .task(id: text) {
                displayedText = ""
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                for char in text {
                    if Task.isCancelled { return }
                    displayedText.append(char)
                    try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                }
            }
    }
}

// MARK: - Scene <-> TCA Bridge

@MainActor
final class ConstellationSceneDelegateBridge: ConstellationSceneDelegate {
    let store: StoreOf<ConstellationFeature>

    init(store: StoreOf<ConstellationFeature>) {
        self.store = store
    }

    func didTapStar(constellationId: String, starIndex: Int) {
        store.send(.sceneDidTapStar(constellationId: constellationId, starIndex: starIndex))
    }

    func didEnterConstellationDetail(id: String) {
        store.send(.sceneDidEnterConstellationDetail(id: id))
    }

    func didExitConstellationDetail() {
        store.send(.sceneDidExitConstellationDetail)
    }

    func didTapEmptyArea() {
        store.send(.sceneDidTapEmptyArea)
    }
}
