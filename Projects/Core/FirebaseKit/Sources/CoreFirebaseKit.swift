import Foundation

/// CoreFirebaseKit — Firebase SDK 를 얇게 감싸는 Core 레이어.
///
/// Domain/Feature 에서 Firestore/Auth SDK 를 직접 호출하지 않도록 경계를 격리한다.
/// 이 파일은 모듈 네임플레이트 앵커로 유지한다. 실제 래퍼 타입은 별도 파일로 추가한다.
public enum CoreFirebaseKit {
    public static let moduleName = "CoreFirebaseKit"
}
