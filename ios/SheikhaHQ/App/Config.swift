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

    // dashboard accents – a deeper shade on light backgrounds, a brighter one on dark
    static let amber = adaptive(light: (0.851, 0.522, 0.0), dark: (1.0, 0.741, 0.231))
    static let blue = adaptive(light: (0.118, 0.420, 0.851), dark: (0.400, 0.639, 1.0))
    static let teal = adaptive(light: (0.0, 0.502, 0.533), dark: (0.255, 0.800, 0.800))
    static let purple = adaptive(light: (0.478, 0.271, 0.800), dark: (0.710, 0.553, 1.0))
    static let pink = adaptive(light: (0.800, 0.176, 0.471), dark: (1.0, 0.451, 0.659))

    /// Headline card and chart bars.
    static let sunset = LinearGradient(colors: [Color(red: 0.95, green: 0.42, blue: 0.10), Color(red: 0.80, green: 0.20, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let barFill = LinearGradient(colors: [Color(red: 1.0, green: 0.62, blue: 0.20), orange], startPoint: .top, endPoint: .bottom)

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
