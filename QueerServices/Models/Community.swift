import Foundation

struct CommunityEvent: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let theme: String?
    let city: String
    let address: String?
    let eventDate: String
    let eventEndDate: String?
    let photoUrl: String?
    let websiteUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, theme, city, address
        case eventDate = "event_date"
        case eventEndDate = "event_end_date"
        case photoUrl = "photo_url"
        case websiteUrl = "website_url"
    }

    /// `event_date` est un type `date` Postgres : "2026-11-05".
    var startDate: Date? { DateFormats.day.date(from: eventDate) }

    var dateLabel: String {
        guard let start = startDate else { return eventDate }
        let startText = DateFormats.display.string(from: start)
        guard let endRaw = eventEndDate, let end = DateFormats.day.date(from: endRaw), end != start else {
            return startText
        }
        return "\(startText) → \(DateFormats.display.string(from: end))"
    }
}

/// Participant à un événement (jointure event_attendees + profiles).
struct EventAttendee: Decodable, Hashable {
    let eventId: String
    let profileId: String
    let profile: AttendeeProfile?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case profileId = "profile_id"
        case profile
    }
}

struct AttendeeProfile: Codable, Hashable {
    let displayName: String
    let photoUrl: String?
    let companyName: String?
    let accountType: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case photoUrl = "photo_url"
        case companyName = "company_name"
        case accountType = "account_type"
    }

    var title: String {
        if accountType == "pro", let companyName, !companyName.isEmpty { return companyName }
        return displayName
    }
}

struct EventAttendeeInsert: Encodable {
    let eventId: String
    let profileId: String

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case profileId = "profile_id"
    }
}

struct MissionRequest: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let budget: String?
    let createdAt: String
    let createdBy: String
    let author: MissionAuthor?

    enum CodingKeys: String, CodingKey {
        case id, title, description, budget
        case createdAt = "created_at"
        case createdBy = "created_by"
        case author = "profiles"
    }
}

struct MissionAuthor: Codable, Hashable {
    let displayName: String
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case photoUrl = "photo_url"
    }
}

/// Création de la conversation liée à une candidature (comme ApplyToMissionModal côté web).
struct ApplicationConnection: Encodable {
    let userA: String
    let userB: String
    let serviceLabel: String
    let status: String
    let missionRequestId: String?

    enum CodingKeys: String, CodingKey {
        case userA = "user_a"
        case userB = "user_b"
        case serviceLabel = "service_label"
        case status
        case missionRequestId = "mission_request_id"
    }
}

/// Mise à jour du profil depuis l'écran d'édition.
struct ProfilePatch: Encodable {
    let displayName: String
    let city: String?
    let pronouns: String?
    let bio: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case city, pronouns, bio
        case displayName = "display_name"
        case updatedAt = "updated_at"
    }
}

enum DateFormats {
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let display: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM yyyy"
        return f
    }()
}
