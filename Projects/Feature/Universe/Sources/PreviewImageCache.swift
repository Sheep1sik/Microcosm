import UIKit
import ComposableArchitecture

/// SpriteKit 셰이더로 렌더링된 은하/별 프리뷰 이미지를 보관하는 캐시.
/// TCA State 외부에 두어 Equatable 비교 비용과 불필요한 View 리렌더링을 방지한다.
@MainActor
final class PreviewImageCache {
    private(set) var galaxyImages: [String: UIImage] = [:]
    private(set) var starImages: [String: UIImage] = [:]

    /// 프리뷰 이미지 업데이트 시점을 SwiftUI에 알리기 위한 리비전 카운터
    private(set) var revision: UInt = 0

    init() {}

    func update(galaxies: [String: UIImage], stars: [String: UIImage]) {
        galaxyImages = galaxies
        starImages = stars
        revision &+= 1
    }

    func galaxyImage(for key: String) -> UIImage? {
        galaxyImages[key]
    }

    func starImage(for recordId: String) -> UIImage? {
        starImages[recordId]
    }

    func reset() {
        galaxyImages.removeAll()
        starImages.removeAll()
        revision = 0
    }
}

// MARK: - TCA Dependency

extension PreviewImageCache: @unchecked Sendable {}

private enum PreviewImageCacheKey: DependencyKey {
    @MainActor static let liveValue = PreviewImageCache()
    @MainActor static let testValue = PreviewImageCache()
}

extension DependencyValues {
    var previewImageCache: PreviewImageCache {
        get { self[PreviewImageCacheKey.self] }
        set { self[PreviewImageCacheKey.self] = newValue }
    }
}
