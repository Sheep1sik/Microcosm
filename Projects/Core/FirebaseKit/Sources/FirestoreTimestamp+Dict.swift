import Foundation
import FirebaseFirestore

/// Firestore 문서 `[String: Any]` 에 대해 Timestamp ↔ Date 변환을 수행하는 유틸.
///
/// Firestore SDK 는 Date 를 Timestamp 로 저장하므로, Entity 디코딩/인코딩 시
/// 키별로 변환하는 상용구가 반복된다. 이를 단일 지점으로 모은다.
public enum FirestoreDictConverter {
    /// `data[key]` 가 Timestamp 이면 Date 로 교체한다. 키가 없거나 다른 타입이면 무시.
    public static func timestampsToDates(_ data: inout [String: Any], keys: [String]) {
        for key in keys {
            if let timestamp = data[key] as? Timestamp {
                data[key] = timestamp.dateValue()
            }
        }
    }

    /// `data[key]` 가 Date 이면 Timestamp 로 교체한다. 키가 없거나 다른 타입이면 무시.
    public static func datesToTimestamps(_ data: inout [String: Any], keys: [String]) {
        for key in keys {
            if let date = data[key] as? Date {
                data[key] = Timestamp(date: date)
            }
        }
    }
}
