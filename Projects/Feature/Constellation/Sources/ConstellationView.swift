import SwiftUI
import SpriteKit
import ComposableArchitecture

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
    let store: StoreOf<ConstellationFeature>

    @State private var scene: ConstellationScene = {
        let scene = ConstellationScene(size: CGSize(width: 2000, height: 2000))
        scene.scaleMode = .resizeFill
        return scene
    }()

    public init(store: StoreOf<ConstellationFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            SpriteKitView(scene: scene)
                .ignoresSafeArea(.all)
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}
