import UIKit
import UserNotifications
import FirebaseMessaging

/// Registers the iPhone for push notifications and hands the Firebase
/// messaging token to HQStore, which saves it in config/devices so the
/// Cloud Functions (functions/index.js) know where to send.
final class PushManager: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let tokenChanged = Notification.Name("SheikhaHQPushToken")
    static var token: String?
    /// For the checklist in More → Notifications.
    static var apnsRegistered = false
    static var registrationError: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        return true
    }

    /// Ask permission (once) and register with Apple. Called after head office signs in.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    static func permissionStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushManager.apnsRegistered = true
        PushManager.registrationError = nil
        Messaging.messaging().apnsToken = deviceToken
        // make sure the Firebase token is (re)issued now that Apple's token is known
        Messaging.messaging().token { token, error in
            if let token { PushManager.received(token) }
            else if let error { PushManager.registrationError = error.localizedDescription }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Push registration failed:", error.localizedDescription)
        PushManager.registrationError = error.localizedDescription
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        PushManager.received(fcmToken)
    }

    private static func received(_ fcmToken: String) {
        DispatchQueue.main.async {
            token = fcmToken
            NotificationCenter.default.post(name: tokenChanged, object: fcmToken)
        }
    }

    // show notifications while the app is open, too
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
