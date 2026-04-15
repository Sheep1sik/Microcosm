import Foundation
import ComposableArchitecture
import DomainEntity
import FirebaseFirestore

extension UserClient: DependencyKey {
    public static let liveValue = UserClient(
        observe: { userId in
            AsyncStream { continuation in
                let db = Firestore.firestore()
                let listener = db.collection("users").document(userId)
                    .addSnapshotListener { snapshot, _ in
                        guard let data = snapshot?.data() else { return }
                        let profile = UserProfile(
                            displayName: data["displayName"] as? String ?? "",
                            email: data["email"] as? String ?? "",
                            nickname: data["nickname"] as? String,
                            hasCompletedOnboarding: data["hasCompletedOnboarding"] as? Bool ?? false,
                            hasSeenConstellationGuide: data["hasSeenConstellationGuide"] as? Bool ?? false
                        )
                        continuation.yield(profile)
                    }
                continuation.onTermination = { _ in
                    listener.remove()
                }
            }
        },
        createIfNeeded: { userId in
            let db = Firestore.firestore()
            let doc = db.collection("users").document(userId)
            let snapshot = try await doc.getDocument()
            if !snapshot.exists {
                try await doc.setData([
                    "createdAt": FieldValue.serverTimestamp(),
                    "displayName": "",
                    "email": "",
                ], merge: true)
            }
        },
        setNickname: { userId, rawNickname in
            // `nicknames/{nickname}` 인덱스 컬렉션을 이용한 원자적 예약/변경.
            // 트랜잭션으로 (1) 중복 검사 (2) 신규 예약 (3) 기존 예약 해제 (4) users 문서 갱신을 수행한다.
            // 이 구조는 보안 규칙에서 다른 사용자의 프로필 문서 접근을 허용하지 않아도 되도록 해준다.
            let nickname = normalizeNickname(rawNickname)
            guard !nickname.isEmpty else { throw UserClientError.nicknameInvalid }

            let db = Firestore.firestore()
            let userRef = db.collection("users").document(userId)
            let newNicknameRef = db.collection("nicknames").document(nickname)

            _ = try await db.runTransaction({ transaction, errorPointer in
                let nicknameSnap: DocumentSnapshot
                let userSnap: DocumentSnapshot
                do {
                    nicknameSnap = try transaction.getDocument(newNicknameRef)
                    userSnap = try transaction.getDocument(userRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                // 이미 다른 사용자가 선점한 닉네임이면 충돌 에러.
                if nicknameSnap.exists {
                    let existingOwner = nicknameSnap.data()?["userId"] as? String
                    if existingOwner != userId {
                        errorPointer?.pointee = UserClientError.nicknameTaken as NSError
                        return nil
                    }
                }

                // 신규 닉네임 예약. 원본 표시용과 정규화 키를 함께 저장한다.
                transaction.setData(
                    [
                        "userId": userId,
                        "createdAt": FieldValue.serverTimestamp(),
                    ],
                    forDocument: newNicknameRef
                )
                transaction.updateData(["nickname": nickname], forDocument: userRef)

                // 기존 닉네임이 있고 변경되는 경우 이전 예약 해제.
                if let oldNickname = userSnap.data()?["nickname"] as? String,
                   !oldNickname.isEmpty,
                   oldNickname != nickname {
                    let oldRef = db.collection("nicknames").document(oldNickname)
                    transaction.deleteDocument(oldRef)
                }
                return nil
            })
        },
        checkNickname: { rawNickname in
            // `nicknames/{nickname}` 단일 문서 존재 여부만 확인.
            // 과거 whereField 기반 구현은 다른 사용자 프로필 열람 권한을 필요로 했으므로 제거됨.
            let nickname = normalizeNickname(rawNickname)
            guard !nickname.isEmpty else { return false }
            let db = Firestore.firestore()
            let snapshot = try await db.collection("nicknames").document(nickname).getDocument()
            return !snapshot.exists
        },
        updateDisplayName: { userId, name in
            guard !name.isEmpty else { return }
            let db = Firestore.firestore()
            try await db.collection("users").document(userId)
                .updateData(["displayName": name])
        },
        updateEmail: { userId, email in
            guard !email.isEmpty else { return }
            let db = Firestore.firestore()
            try await db.collection("users").document(userId)
                .updateData(["email": email])
        },
        markOnboardingCompleted: { userId in
            let db = Firestore.firestore()
            try await db.collection("users").document(userId)
                .updateData(["hasCompletedOnboarding": true])
        },
        resetOnboarding: { userId in
            let db = Firestore.firestore()
            // 온보딩 플래그 리셋
            try await db.collection("users").document(userId)
                .updateData(["hasCompletedOnboarding": false])
            // 기존 기록 삭제
            let records = try await db.collection("users").document(userId)
                .collection("records").getDocuments()
            for doc in records.documents {
                try await doc.reference.delete()
            }
        },
        markConstellationGuideSeen: { userId in
            let db = Firestore.firestore()
            try await db.collection("users").document(userId)
                .updateData(["hasSeenConstellationGuide": true])
        }
    )
}
