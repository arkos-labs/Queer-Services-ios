import Supabase
import UserNotifications

extension Notification.Name {
    static let inboxDidChange = Notification.Name("QueerServices.inboxDidChange")
}

/// Compteur de messages non vus : le même nombre sur la pastille de l'onglet Messages et sur l'icône.
@MainActor
enum Inbox {
    /// Messages reçus pas encore vus (notifications de type « message » non marquées comme vues).
    static func unreadCount(for me: String) async -> Int {
        struct UnreadMessage: Decodable {
            let connectionId: String
            let senderId: String
            enum CodingKeys: String, CodingKey {
                case connectionId = "connection_id"
                case senderId = "sender_id"
            }
        }
        let rows: [UnreadMessage] = (try? await supabase
            .from("messages")
            .select("connection_id, sender_id")
            .neq("sender_id", value: me)
            .is("read_at", value: nil)
            .execute().value) ?? []
        // Une conversation ne compte qu'une fois, même si elle contient 24 messages.
        return Set(rows.map(\.connectionId)).count
    }

    /// Met à jour la pastille de l'icône et renvoie le nombre pour l'onglet.
    static func refresh(for me: String) async -> Int {
        let count = await unreadCount(for: me)
        try? await UNUserNotificationCenter.current().setBadgeCount(count)
        return count
    }

    /// Marque comme vues les notifications des messages que l'utilisateur vient de lire.
    static func markRead(messageIds: [String]) async {
        guard !messageIds.isEmpty else { return }
        _ = try? await supabase
            .from("notifications")
            .update(ReadAtPatch(readAt: ISO8601DateFormatter().string(from: Date())))
            .in("reference_id", values: messageIds)
            .is("read_at", value: nil)
            .execute()
        NotificationCenter.default.post(name: .inboxDidChange, object: nil)
    }
}

private struct ReadAtPatch: Encodable {
    let readAt: String

    enum CodingKeys: String, CodingKey {
        case readAt = "read_at"
    }
}
