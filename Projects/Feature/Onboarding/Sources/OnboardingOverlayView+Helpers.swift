import SwiftUI

// MARK: - TypewriterText

struct TypewriterText: View {
    let text: String
    var speed: TimeInterval = 0.04
    var delay: TimeInterval = 0
    var onCompleted: (() -> Void)? = nil

    @State private var displayedText = ""

    var body: some View {
        Text(displayedText)
            .task(id: text) {
                displayedText = ""
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                for char in text {
                    if Task.isCancelled { return }
                    displayedText.append(char)
                    try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                }
                onCompleted?()
            }
    }
}

// MARK: - View+Placeholder

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - PulsingRing

struct PulsingRing: View {
    @State private var isPulsing = false
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.3), lineWidth: 2)
                .scaleEffect(isPulsing ? 1.3 : 0.8)
                .opacity(isPulsing ? 0 : 0.8)
            Circle().stroke(.white.opacity(0.5), lineWidth: 1.5)
                .scaleEffect(isPulsing ? 1.0 : 0.6)
                .opacity(isPulsing ? 0.3 : 0.6)
        }
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
        .onAppear { isPulsing = true }
    }
}
