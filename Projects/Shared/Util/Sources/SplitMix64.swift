/// 결정론적 랜덤 생성기 — 동일 시드에서 항상 같은 시퀀스를 생성한다.
/// 은하/별자리 배치 등에서 일관된 레이아웃을 보장하는 데 사용.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
