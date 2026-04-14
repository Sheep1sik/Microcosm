import XCTest
@testable import DomainClient

final class UserClientNormalizeNicknameTests: XCTestCase {

    // setNickname / checkNickname 양쪽이 동일 기준으로 비교/저장하기 위해
    // normalizeNickname은 단일 진입점이어야 한다. 입력 다양성 → 동일 키 보장이 핵심.

    func test_normalize_양끝공백_제거() {
        XCTAssertEqual(normalizeNickname("  bob  "), "bob")
        XCTAssertEqual(normalizeNickname("\t\nbob\n"), "bob")
    }

    func test_normalize_대문자_소문자로_변환() {
        XCTAssertEqual(normalizeNickname("Bob"), "bob")
        XCTAssertEqual(normalizeNickname("ALICE"), "alice")
    }

    func test_normalize_혼합공백과_대문자_정상처리() {
        XCTAssertEqual(normalizeNickname("  Bob "), "bob")
    }

    func test_normalize_빈문자열_빈문자열반환() {
        XCTAssertEqual(normalizeNickname(""), "")
        XCTAssertEqual(normalizeNickname("   "), "")
    }

    func test_normalize_한글_변경없음() {
        // 한글은 lowercased 영향을 받지 않으므로 그대로 유지된다.
        XCTAssertEqual(normalizeNickname("우주인"), "우주인")
    }

    func test_normalize_unicode_NFD_NFC로_정규화() {
        // NFD(분리형) "한"(ㅎ + ㅏ + ㄴ)과 NFC(완성형) "한"이 동일 키를 갖도록 보장.
        // Swift String == 은 canonical equivalence 로 비교하므로 바이트 수준(utf8)으로 선행 조건을 검증한다.
        let nfd = "한".decomposedStringWithCanonicalMapping
        let nfc = "한".precomposedStringWithCanonicalMapping
        XCTAssertNotEqual(
            Array(nfd.utf8),
            Array(nfc.utf8),
            "사전 조건: NFD/NFC 바이트 표현이 실제 다름을 확인"
        )
        // 정규화 후에는 utf8 바이트까지도 동일해야 한다.
        XCTAssertEqual(
            Array(normalizeNickname(nfd).utf8),
            Array(normalizeNickname(nfc).utf8)
        )
    }

    func test_normalize_같은의미_다른표기_충돌방지() {
        // "  Bob ", "BOB", "bob" 모두 같은 키로 정규화되어야 중복 닉네임이 막힌다.
        let variants = ["bob", "Bob", "BOB", "  bob  ", "\nBob\t"]
        let normalized = Set(variants.map(normalizeNickname))
        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized.first, "bob")
    }
}
