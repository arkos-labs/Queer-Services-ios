import Supabase
import UIKit
import UserNotifications

/// Notifications push : demande l'autorisation, récupère le jeton APNs et le range dans `device_tokens`
/// pour le compte connecté. L'envoi est fait côté serveur (fonction send-push).
@MainActor
final class PushManager {
    static let shared = PushManager()

    private var token: String?
    private var userId: String?

    /// Demande l'autorisation une fois connecté, puis s'enregistre auprès d'Apple.
    func requestAuthorization() {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Lie les notifications au compte connecté (et les délie à la déconnexion).
    func setUser(_ id: String?) {
        userId = id
        Task { await upload() }
    }

    /// Jeton renvoyé par Apple (appelé par AppDelegate).
    func didReceive(deviceToken data: Data) {
        token = data.map { String(format: "%02x", $0) }.joined()
        Task { await upload() }
    }

    private func upload() async {
        guard let token, let userId else { return }
        do {
            try await supabase
                .from("device_tokens")
                .upsert(DeviceTokenUpsert(
                    token: token,
                    userId: userId,
                    platform: "ios",
                    bundleId: Bundle.main.bundleIdentifier ?? "com.queerservices.app"
                ), onConflict: "token")
                .execute()
        } catch {
            // Sans jeton enregistré, la notification ne part pas : on réessaiera à la prochaine connexion.
        }
    }
}

private struct DeviceTokenUpsert: Encodable {
    let token: String
    let userId: String
    let platform: String
    let bundleId: String

    enum CodingKeys: String, CodingKey {
        case token, platform
        case userId = "user_id"
        case bundleId = "bundle_id"
    }
}

/// Reçoit le jeton APNs, que SwiftUI ne sait pas recevoir seul, et affiche les notifications
/// même quand l'app est ouverte (sinon iOS les garde en silence).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    /// Tap sur la notification : on transmet le chemin (action_url) à l'app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let path = response.notification.request.content.userInfo["action_url"] as? String {
            Task { @MainActor in DeepLink.post(path) }
        }
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushManager.shared.didReceive(deviceToken: deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Pas d'autorisation ou pas de réseau : l'app fonctionne sans push.
    }
}
