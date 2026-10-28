import Foundation

extension Notification.Name {
    static let deepLink = Notification.Name("queerservices.deepLink")
}

/// Chemin reçu avec une notification (ex. « /messages/<id> »), gardé jusqu'à ce que l'accueil soit prêt.
@MainActor
enum DeepLink {
    static var pendingPath: String?

    static func post(_ path: String) {
        pendingPath = path
        NotificationCenter.default.post(name: .deepLink, object: nil)
    }
}
