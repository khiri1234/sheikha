import SwiftUI
import FirebaseCore

@main
struct SheikhaHQApp: App {
    @State private var store: HQStore

    init() {
        // Firebase must be configured before the store touches Auth or Firestore.
        // Reads GoogleService-Info.plist (Firebase console → Project settings → Your apps → iOS app).
        FirebaseApp.configure()
        _store = State(initialValue: HQStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Brand.orange)
        }
    }
}
