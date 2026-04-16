import Foundation
import FirebaseFirestore

/// Firestore 인스턴스의 단일 접근 지점.
///
/// `Firestore.firestore()` 호출 반복을 제거하고, 향후 테스트용 인스턴스 주입 또는 설정
/// 커스터마이징이 필요할 때 이 타입만 수정하면 된다.
public enum FirestoreDB {
    public static var shared: Firestore { Firestore.firestore() }
}
