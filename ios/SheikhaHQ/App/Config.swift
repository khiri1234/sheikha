import SwiftUI
import UIKit

/// The head-office login. Must match HQ_EMAIL in index.html and isHQ() in firestore.rules.
enum Config {
    static let hqEmail = "sheikhatextiles@gmail.com"
}

enum Brand {
    static let orange = Color(red: 0.882, green: 0.333, blue: 0.047)   // #E1550C
    static let charcoal = Color(red: 0.118, green: 0.133, blue: 0.157) // #1E2228
    static let compare = Color(red: 0.431, green: 0.455, blue: 0.494)  // #6E747E – comparison period
    // status colours: darker on light backgrounds, brighter on dark ones so they stay readable
    static let good = adaptive(light: (0.043, 0.420, 0.310), dark: (0.290, 0.871, 0.502))
    static let bad = adaptive(light: (0.659, 0.196, 0.165), dark: (1.0, 0.478, 0.431))
    static let warn = adaptive(light: (0.541, 0.357, 0.0), dark: (0.984, 0.749, 0.141))

    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(UIColor { t in
            let c = t.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

/// Light / dark choice in More → Appearance. "system" follows the iPhone setting.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { self == .system ? "Automatic" : self == .light ? "Light" : "Dark" }
    var scheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
}
