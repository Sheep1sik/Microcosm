import SwiftUI
import UIKit
import DomainEntity

public extension RecordColor {
    var swiftUIColor: Color {
        Color(red: r, green: g, blue: b)
    }

    var uiColor: UIColor {
        UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
    }
}

public extension Array where Element == Record {
    func blendedColor() -> Color {
        guard !isEmpty else { return Color(red: 0.6, green: 0.7, blue: 0.9) }
        var r: Double = 0, g: Double = 0, b: Double = 0
        for record in self {
            let pc = record.resolvedProfile.primaryColor
            r += pc.r
            g += pc.g
            b += pc.b
        }
        let n = Double(count)
        return Color(red: r / n, green: g / n, blue: b / n)
    }

    func blendedUIColor() -> UIColor {
        guard !isEmpty else { return UIColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 1) }
        var r: Double = 0, g: Double = 0, b: Double = 0
        for record in self {
            let pc = record.resolvedProfile.primaryColor
            r += pc.r
            g += pc.g
            b += pc.b
        }
        let n = Double(count)
        return UIColor(red: CGFloat(r / n), green: CGFloat(g / n), blue: CGFloat(b / n), alpha: 1)
    }
}
