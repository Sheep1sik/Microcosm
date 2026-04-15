import Testing
@testable import CoreFirebaseKit

struct CoreFirebaseKitTests {
    @Test
    func moduleNameMatchesConstant() {
        #expect(CoreFirebaseKit.moduleName == "CoreFirebaseKit")
    }
}
