import Foundation

// MARK: - Constellation Definition (정적 데이터)

public struct ConstellationDefinition: Equatable, Hashable, Identifiable {
    public let id: String           // IAU 약어: "ORI", "UMA" 등
    public let nameEN: String       // "Orion"
    public let nameKO: String       // "오리온자리"
    public let stars: [ConstellationStar]
    public let lines: [ConstellationLine]

    public init(
        id: String,
        nameEN: String,
        nameKO: String,
        stars: [ConstellationStar],
        lines: [ConstellationLine]
    ) {
        self.id = id
        self.nameEN = nameEN
        self.nameKO = nameKO
        self.stars = stars
        self.lines = lines
    }
}

// MARK: - Star (별자리 내 개별 별)

public struct ConstellationStar: Equatable, Hashable {
    public let index: Int
    public let x: Double            // 별자리 내 상대좌표 (0...1)
    public let y: Double
    public let magnitude: Double    // 겉보기 등급 (밝을수록 작음)
    public let name: String?        // 유명한 별 이름 (예: "베텔기우스")

    public init(index: Int, x: Double, y: Double, magnitude: Double, name: String? = nil) {
        self.index = index
        self.x = x
        self.y = y
        self.magnitude = magnitude
        self.name = name
    }
}

// MARK: - Line (별 사이 연결선)

public struct ConstellationLine: Equatable, Hashable {
    public let from: Int            // star index
    public let to: Int

    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}
