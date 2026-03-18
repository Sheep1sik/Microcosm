import Foundation
import ComposableArchitecture
import DomainEntity

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
                return RecordColor.fallback
            }

            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15

            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    [
                        "role": "system",
                        "content": "사용자의 글 내용을 분석하여 감정/분위기에 맞는 색상을 RGB로 반환하세요. 반드시 JSON만 반환: {\"r\": 0.0~1.0, \"g\": 0.0~1.0, \"b\": 0.0~1.0}. 다른 텍스트 없이 JSON만 출력하세요."
                    ],
                    [
                        "role": "user",
                        "content": content
                    ]
                ],
                "temperature": 0.7,
                "max_tokens": 50
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return RecordColor.fallback
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let contentString = message["content"] as? String else {
                return RecordColor.fallback
            }

            let trimmed = contentString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let colorData = trimmed.data(using: .utf8) else {
                return RecordColor.fallback
            }

            let decoded = try JSONDecoder().decode(RecordColor.self, from: colorData)
            return decoded.clamped()
        },
        analyzeEmotion: { content in
            guard let apiKey = Self.loadAPIKey() else {
                throw OpenAIError.requestFailed
            }

            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15

            let systemPrompt = """
            당신은 "소우주" 앱의 감정 해석 엔진이다.
            사용자의 글에서 미묘한 감정의 결, 복합 감정, 온도, 여운을 해석하여
            별의 시각 프로필을 JSON으로 반환하라.

            규칙:
            - 감정을 고정 공식으로 매핑하지 말 것. 같은 단어도 문맥에 따라 다른 색
            - 흔한 원색보다 미묘한 중간색과 뉘앙스를 살리는 색을 우선
            - 감정의 온도, 밀도, 여운, 에너지 수준을 함께 고려

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
                "temperature": 0.7,
                "max_tokens": 150
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw OpenAIError.requestFailed
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let contentString = message["content"] as? String else {
                throw OpenAIError.parseFailed
            }

            let trimmed = contentString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let jsonData = trimmed.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw OpenAIError.parseFailed
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

    enum OpenAIError: Error {
        case requestFailed
        case parseFailed
    }

    private static func loadAPIKey() -> String? {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
              !key.isEmpty,
              key != "YOUR_API_KEY_HERE" else {
            return nil
        }
        return key
    }
}

extension DependencyValues {
    public var openAIClient: OpenAIClient {
        get { self[OpenAIClient.self] }
        set { self[OpenAIClient.self] = newValue }
    }
}
