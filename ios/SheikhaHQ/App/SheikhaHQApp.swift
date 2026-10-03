import SwiftUI
import FirebaseCore

@main
struct SheikhaHQApp: App {
    @UIApplicationDelegateAdaptor(PushManager.self) private var push
    @State private var store: HQStore
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue

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
                .preferredColorScheme((Appearance(rawValue: appearance) ?? .system).scheme)
        }
    }
}
