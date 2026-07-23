import UIKit
import UserNotifications

// Handles remote (APNs) push for cloud email sync. Wired into the SwiftUI app
// via @UIApplicationDelegateAdaptor in FinTrackApp.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // APNs handed us a device token → send it to the backend.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            RemoteEmailSyncService.shared.deviceToken = token
            await RemoteEmailSyncService.shared.registerDevice()
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Non-fatal — the user can re-enable from Settings → Cloud Email Sync.
    }

    // Background delivery (aps content-available) → pull new pending txns.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        let n = await RemoteEmailSyncService.shared.syncPending()
        return n > 0 ? .newData : .noData
    }

    // Show the banner even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // Tapped the notification → pull latest and jump to the review queue.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        await RemoteEmailSyncService.shared.syncPending()
        NotificationCenter.default.post(name: .openEmailReview, object: nil)
    }
}

extension Notification.Name {
    /// Posted when the user taps a "new transaction" push; RootView jumps to the
    /// Transactions tab where the email-review queue lives.
    static let openEmailReview = Notification.Name("ft.openEmailReview")
}
