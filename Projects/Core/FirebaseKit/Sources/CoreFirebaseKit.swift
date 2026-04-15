import Foundation
@_exported import FirebaseFirestore

/// CoreFirebaseKit — Firebase SDK 를 얇게 감싸는 Core 레이어.
///
/// Domain/Feature 는 `import CoreFirebaseKit` 하나로 Firestore 사용이 가능하다.
/// @_exported 경유로 FirebaseFirestore 의 공개 타입(Timestamp, FieldValue, Firestore 등)을
/// 그대로 드러낸다. SDK 교체·변경 시 이 모듈만 수정하면 되는 단일 접점 역할을 한다.
public enum CoreFirebaseKit {
    public static let moduleName = "CoreFirebaseKit"
}
