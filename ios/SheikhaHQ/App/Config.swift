import SwiftUI

/// The head-office login. Must match HQ_EMAIL in index.html and isHQ() in firestore.rules.
enum Config {
    static let hqEmail = "sheikhatextiles@gmail.com"
}

enum Brand {
    static let orange = Color(red: 0.882, green: 0.333, blue: 0.047)   // #E1550C
    static let charcoal = Color(red: 0.118, green: 0.133, blue: 0.157) // #1E2228
    static let compare = Color(red: 0.431, green: 0.455, blue: 0.494)  // #6E747E – comparison period
    static let good = Color(red: 0.043, green: 0.420, blue: 0.310)
    static let bad = Color(red: 0.659, green: 0.196, blue: 0.165)
    static let warn = Color(red: 0.541, green: 0.357, blue: 0.0)
}
