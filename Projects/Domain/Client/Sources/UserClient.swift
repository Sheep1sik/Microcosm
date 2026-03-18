import Foundation
import ComposableArchitecture
import DomainEntity
import FirebaseFirestore

public struct UserProfile: Equatable {
    public var displayName: String
    public var email: String
    public var nickname: String?
    public var hasCompletedOnboarding: Bool

    public var hasSetNickname: Bool { nickname != nil && !(nickname?.isEmpty ?? true) }

    public init(
        displayName: String = "",
        email: String = "",
        nickname: String? = nil,
        hasCompletedOnboarding: Bool = false
    ) {
        self.displayName = displayName
        self.email = email
        self.nickname = nickname
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

public struct UserClient {
    public var observe: (String) -> AsyncStream<UserProfile>
    public var createIfNeeded: (String) async throws -> Void
    public var setNickname: (String, String) async throws -> Void
    public var checkNickname: (String) async throws -> Bool
    public var updateDisplayName: (String, String) async throws -> Void
    public var updateEmail: (String, String) async throws -> Void
    public var markOnboardingCompleted: (String) async throws -> Void
    public var resetOnboarding: (String) async throws -> Void

    public init(
        observe: @escaping (String) -> AsyncStream<UserProfile>,
        createIfNeeded: @escaping (String) async throws -> Void,
        setNickname: @escaping (String, String) async throws -> Void,
        checkNickname: @escaping (String) async throws -> Bool,
        updateDisplayName: @escaping (String, String) async throws -> Void,
        updateEmail: @escaping (String, String) async throws -> Void,
        markOnboardingCompleted: @escaping (String) async throws -> Void,
        resetOnboarding: @escaping (String) async throws -> Void
    ) {
        self.observe = observe
        self.createIfNeeded = createIfNeeded
        self.setNickname = setNickname
        self.checkNickname = checkNickname
        self.updateDisplayName = updateDisplayName
        self.updateEmail = updateEmail
        self.markOnboardingCompleted = markOnboardingCompleted
        self.resetOnboarding = resetOnboarding
    }
}

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
                            hasCompletedOnboarding: data["hasCompletedOnboarding"] as? Bool ?? false
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
        setNickname: { userId, nickname in
            let db = Firestore.firestore()
            try await db.collection("users").document(userId)
                .updateData(["nickname": nickname])
        },
        checkNickname: { nickname in
            let db = Firestore.firestore()
            let snapshot = try await db.collection("users")
                .whereField("nickname", isEqualTo: nickname)
                .limit(to: 1)
                .getDocuments()
            return snapshot.documents.isEmpty
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
        }
    )
}

extension DependencyValues {
    public var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
