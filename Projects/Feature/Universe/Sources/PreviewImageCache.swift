import UIKit
import ComposableArchitecture

/// SpriteKit 셰이더로 렌더링된 은하/별 프리뷰 이미지를 보관하는 2계층 캐시.
/// - 1계층: 메모리 (딕셔너리) — 즉시 접근
/// - 2계층: 디스크 (Caches/previews/) — 앱 재실행 시에도 셰이더 재렌더링 불필요
/// TCA State 외부에 두어 Equatable 비교 비용과 불필요한 View 리렌더링을 방지한다.
@MainActor
final class PreviewImageCache {

    private(set) var galaxyImages: [String: UIImage] = [:]
    private(set) var starImages: [String: UIImage] = [:]

    /// 프리뷰 이미지 업데이트 시점을 SwiftUI에 알리기 위한 리비전 카운터
    private(set) var revision: UInt = 0

    private let fileManager = FileManager.default
    private let galaxyDir: URL
    private let starDir: URL

    init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        galaxyDir = caches.appendingPathComponent("previews/galaxies", isDirectory: true)
        starDir = caches.appendingPathComponent("previews/stars", isDirectory: true)

        try? fileManager.createDirectory(at: galaxyDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: starDir, withIntermediateDirectories: true)
    }

    // MARK: - 메모리 캐시 업데이트 (기존 호환)

    func update(galaxies: [String: UIImage], stars: [String: UIImage]) {
        galaxyImages = galaxies
        starImages = stars
        revision &+= 1
    }

    // MARK: - 읽기 (메모리 → 디스크 순)

    func galaxyImage(for key: String) -> UIImage? {
        if let mem = galaxyImages[key] { return mem }
        if let disk = loadFromDisk(dir: galaxyDir, key: key) {
            galaxyImages[key] = disk
            return disk
        }
        return nil
    }

    func starImage(for recordId: String) -> UIImage? {
        if let mem = starImages[recordId] { return mem }
        if let disk = loadFromDisk(dir: starDir, key: recordId) {
            starImages[recordId] = disk
            return disk
        }
        return nil
    }

    // MARK: - 쓰기 (메모리 + 디스크)

    func setGalaxyImage(_ image: UIImage, for key: String) {
        galaxyImages[key] = image
        saveToDisk(image: image, dir: galaxyDir, key: key)
    }

    func setStarImage(_ image: UIImage, for recordId: String) {
        starImages[recordId] = image
        saveToDisk(image: image, dir: starDir, key: recordId)
    }

    // MARK: - 삭제

    func removeGalaxy(for key: String) {
        galaxyImages.removeValue(forKey: key)
        removeFromDisk(dir: galaxyDir, key: key)
    }

    func removeStar(for recordId: String) {
        starImages.removeValue(forKey: recordId)
        removeFromDisk(dir: starDir, key: recordId)
    }

    // MARK: - 디스크 캐시 존재 여부

    func hasGalaxyOnDisk(_ key: String) -> Bool {
        fileManager.fileExists(atPath: filePath(dir: galaxyDir, key: key).path)
    }

    func hasStarOnDisk(_ recordId: String) -> Bool {
        fileManager.fileExists(atPath: filePath(dir: starDir, key: recordId).path)
    }

    // MARK: - 전체 초기화

    func reset() {
        galaxyImages.removeAll()
        starImages.removeAll()
        revision = 0
        try? fileManager.removeItem(at: galaxyDir)
        try? fileManager.removeItem(at: starDir)
        try? fileManager.createDirectory(at: galaxyDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: starDir, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private func filePath(dir: URL, key: String) -> URL {
        dir.appendingPathComponent("\(key).png")
    }

    private func saveToDisk(image: UIImage, dir: URL, key: String) {
        guard let data = image.pngData() else { return }
        try? data.write(to: filePath(dir: dir, key: key), options: .atomic)
    }

    private func loadFromDisk(dir: URL, key: String) -> UIImage? {
        let path = filePath(dir: dir, key: key)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    private func removeFromDisk(dir: URL, key: String) {
        try? fileManager.removeItem(at: filePath(dir: dir, key: key))
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
