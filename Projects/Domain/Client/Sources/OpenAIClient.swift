import Foundation
import ComposableArchitecture
import DomainEntity

public enum OpenAIError: LocalizedError, Equatable {
    case apiKeyNotConfigured
    case httpError(statusCode: Int)
    case malformedResponse
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured: return "OpenAI API 키가 설정되지 않았어요"
        case .httpError(let code): return "OpenAI 요청이 실패했어요 (HTTP \(code))"
        case .malformedResponse: return "OpenAI 응답 형식이 올바르지 않아요"
        case .decodingFailed: return "OpenAI 응답을 해석하지 못했어요"
        }
    }
}

public struct OpenAIClient {
    public var analyzeColor: (String) async throws -> RecordColor
    public var analyzeEmotion: (String) async throws -> StarVisualProfile

    public init(
        analyzeColor: @escaping (String) async throws -> RecordColor,
        analyzeEmotion: @escaping (String) async throws -> StarVisualProfile
    ) {
        self.analyzeColor = analyzeColor
        self.analyzeEmotion = analyzeEmotion
    }
}

extension OpenAIClient: DependencyKey {
    public static let liveValue = OpenAIClient(
        analyzeColor: { content in
            guard let apiKey = Self.loadAPIKey() else {
                throw OpenAIError.apiKeyNotConfigured
            }

            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15

            let colorSystemPrompt = """
            사용자의 글에서 감정, 분위기, 감각, 연상 이미지를 종합 해석하여 색상을 반환하라.

            해석 원칙:
            - 직접적 감정 표현이 없어도 텍스트의 톤, 소재, 상황에서 감각적 색을 연상하라
            - "치킨 먹었다" → 따뜻한 만족감의 앰버/골드, "비가 온다" → 젖은 아스팔트의 청회색
            - 매번 다른 뉘앙스를 만들어라. 같은 감정이라도 문맥에 따라 채도, 명도, 색상이 달라야 한다
            - 원색(순빨강, 순파랑)보다 자연에서 볼 수 있는 미묘한 색을 우선하라

            반드시 JSON만 출력: {"r": 0.0~1.0, "g": 0.0~1.0, "b": 0.0~1.0}
            """

            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "system", "content": colorSystemPrompt],
                    ["role": "user", "content": content]
                ],
                "temperature": 0.85,
                "max_tokens": 50
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.malformedResponse
            }
            guard httpResponse.statusCode == 200 else {
                throw OpenAIError.httpError(statusCode: httpResponse.statusCode)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let contentString = message["content"] as? String else {
                throw OpenAIError.malformedResponse
            }

            let trimmed = contentString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let colorData = trimmed.data(using: .utf8) else {
                throw OpenAIError.decodingFailed
            }

            do {
                let decoded = try JSONDecoder().decode(RecordColor.self, from: colorData)
                return decoded.clamped()
            } catch {
                throw OpenAIError.decodingFailed
            }
        },
        analyzeEmotion: { content in
            guard let apiKey = Self.loadAPIKey() else {
                throw OpenAIError.apiKeyNotConfigured
            }

            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15

            let systemPrompt = """
            당신은 "소우주" 앱의 감정 해석 엔진이다.
            사용자의 글에 담긴 감정의 결, 온도, 여운, 감각적 이미지를 해석하여
            별의 시각 프로필을 JSON으로 반환하라.

            핵심 원칙:
            1. 모든 글에는 감정이 있다. 직접적 감정 표현이 없어도 소재, 상황, 톤에서 감각적 색을 연상하라.
               - "편의점 삼각김밥" → 심야의 소소한 위안, 따뜻한 형광등 빛의 연한 앰버
               - "오늘 아무것도 안 했다" → 고요한 무중력, 깊은 우주의 남색과 보랏빛
               - "ㅋㅋㅋㅋ" → 가볍게 터지는 웃음의 밝은 레몬-민트
            2. 색상 다양성이 핵심이다.
               - 슬픔이라도 '비 오는 날의 회청색', '이별 후 새벽의 짙은 자주', '잔잔한 그리움의 연보라'처럼 매번 달라야 한다
               - 순수한 원색(#FF0000, #0000FF)은 절대 쓰지 마라. 자연의 색, 빛의 색, 계절의 색을 써라
               - R,G,B 중 하나가 0이거나 1인 극단값을 피하라. 항상 미세한 혼합이 있어야 한다
            3. 세 색(주색, 보조색, 잔광색)은 서로 조화롭되 구별되어야 한다.
               - 보조색(sc)은 주색에서 색상환 30~90도 이동한 따뜻한 변주
               - 잔광색(gc)은 주색을 더 연하고 넓게 퍼뜨린 빛
            4. 별의 행동(크기, 밝기, 반짝임, 움직임)도 감정에 맞춰라.
               - 격한 감정 → 크고 밝고 빠르게 반짝, 잔잔한 감정 → 작고 은은하게 천천히
               - 에너지 높음 → 움직임 크고 빠름, 에너지 낮음 → 거의 정지

            반드시 아래 JSON만 출력:
            {"pc":[r,g,b],"sc":[r,g,b],"gc":[r,g,b],"sz":0~1,"br":0~1,"ts":0~1,"ti":0~1,"ma":0~1,"ms":0~1}

            pc=주색, sc=보조색(내부 글로우), gc=잔광색(외부 글로우)
            sz=크기, br=밝기, ts=반짝임속도, ti=반짝임강도, ma=움직임폭, ms=움직임속도
            모든 RGB 값은 0.0~1.0 범위. 다른 텍스트 없이 JSON만 출력하세요.
            """

            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": content]
                ],
                "temperature": 0.9,
                "max_tokens": 150
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.malformedResponse
            }
            guard httpResponse.statusCode == 200 else {
                throw OpenAIError.httpError(statusCode: httpResponse.statusCode)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let contentString = message["content"] as? String else {
                throw OpenAIError.malformedResponse
            }

            let trimmed = contentString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let jsonData = trimmed.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw OpenAIError.decodingFailed
            }

            func parseColor(_ key: String) -> RecordColor {
                guard let arr = parsed[key] as? [Any],
                      arr.count >= 3 else { return .fallback }
                let r = (arr[0] as? Double) ?? (arr[0] as? Int).map(Double.init) ?? 0.6
                let g = (arr[1] as? Double) ?? (arr[1] as? Int).map(Double.init) ?? 0.7
                let b = (arr[2] as? Double) ?? (arr[2] as? Int).map(Double.init) ?? 0.9
                return RecordColor(r: r, g: g, b: b).clamped()
            }

            func parseDouble(_ key: String, fallback: Double = 0.5) -> Double {
                if let v = parsed[key] as? Double { return max(0, min(1, v)) }
                if let v = parsed[key] as? Int { return max(0, min(1, Double(v))) }
                return fallback
            }

            return StarVisualProfile(
                primaryColor: parseColor("pc"),
                secondaryColor: parseColor("sc"),
                glowColor: parseColor("gc"),
                size: parseDouble("sz"),
                brightness: parseDouble("br"),
                twinkleSpeed: parseDouble("ts"),
                twinkleIntensity: parseDouble("ti"),
                motionAmplitude: parseDouble("ma"),
                motionSpeed: parseDouble("ms")
            )
        }
    )

    // ⚠️ 임시 구조 — OPENAI_API_KEY 는 빌드 타임에 Info.plist 로 embed 되어
    // 앱 번들(.ipa)에 그대로 포함됩니다. OpenAI 키는 사용량 과금 직결이므로
    // 배포 빌드에서는 이 경로 사용 금지.
    // 장기 해결: Firebase Functions 등 서버 프록시 경유 (이슈: security/openai-key-proxy)
    private static func loadAPIKey() -> String? {
        let stubValues: Set<String> = [
            "YOUR_API_KEY_HERE",
            "your_openai_api_key_here",
            "ci_stub_key_not_used"
        ]
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
              !key.isEmpty,
              !stubValues.contains(key) else {
            return nil
        }
        return key
    }
}

extension OpenAIClient: TestDependencyKey {
    public static let testValue = OpenAIClient(
        analyzeColor: unimplemented("\(Self.self).analyzeColor"),
        analyzeEmotion: unimplemented("\(Self.self).analyzeEmotion")
    )
}

extension DependencyValues {
    public var openAIClient: OpenAIClient {
        get { self[OpenAIClient.self] }
        set { self[OpenAIClient.self] = newValue }
    }
}
