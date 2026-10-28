import Foundation

/// Une annulation de navigation n'est pas un échec à présenter à l'utilisateur.
enum AppError {
    static func isCancellation(_ error: Error) -> Bool {
        var current: Error = error
        // Certains clients réseau encapsulent l'erreur d'origine dans NSError.
        for _ in 0..<8 {
            if current is CancellationError { return true }
            let value = current as NSError
            if value.domain == NSURLErrorDomain, value.code == NSURLErrorCancelled { return true }
            if value.domain == "Swift.CancellationError", value.code == 1 { return true }
            guard let underlying = value.userInfo[NSUnderlyingErrorKey] as? Error else { return false }
            current = underlying
        }
        return false
    }
}

/// Colonnes sûres pour afficher le profil d'un autre membre (miroir de PUBLIC_PROFILE_COLUMNS côté web).
let publicProfileColumns = """
id, display_name, civilite, pronouns, account_type, bio, photo_url, city, skills, needs, \
intervention_zone, company_name, company_description, phone, website_url, opening_hours, pro_services, verification_status, is_community_member, \
is_ally, profile_status, created_at, updated_at
"""

struct Profile: Codable, Identifiable, Hashable {
    let id: String
    var displayName: String
    var civilite: String?
    var pronouns: String?
    var accountType: String?
    var bio: String?
    var photoUrl: String?
    var city: String?
    var skills: [String]?
    var needs: [String]?
    var companyName: String?
    var companyDescription: String?
    /// Champs visibles seulement sur son propre profil (select *).
    var phone: String?
    var linkedinUrl: String?
    var interventionZone: String?
    var websiteUrl: String?
    var openingHours: String?
    var proServices: [ProServiceItem]?
    var verificationStatus: String?
    var isCommunityMember: Bool?
    var isAlly: Bool?
    var profileStatus: String?
    var stripeChargesEnabled: Bool = false
    var stripePayoutsEnabled: Bool = false
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case civilite, pronouns, bio, city, skills, needs, phone
        case accountType = "account_type"
        case photoUrl = "photo_url"
        case linkedinUrl = "linkedin_url"
        case interventionZone = "intervention_zone"
        case websiteUrl = "website_url"
        case openingHours = "opening_hours"
        case proServices = "pro_services"
        case companyName = "company_name"
        case companyDescription = "company_description"
        case verificationStatus = "verification_status"
        case isCommunityMember = "is_community_member"
        case isAlly = "is_ally"
        case profileStatus = "profile_status"
        case stripeChargesEnabled = "stripe_charges_enabled"
        case stripePayoutsEnabled = "stripe_payouts_enabled"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); displayName = try c.decode(String.self, forKey: .displayName)
        civilite = try c.decodeIfPresent(String.self, forKey: .civilite); pronouns = try c.decodeIfPresent(String.self, forKey: .pronouns)
        accountType = try c.decodeIfPresent(String.self, forKey: .accountType); bio = try c.decodeIfPresent(String.self, forKey: .bio)
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl); city = try c.decodeIfPresent(String.self, forKey: .city)
        skills = try c.decodeIfPresent([String].self, forKey: .skills); needs = try c.decodeIfPresent([String].self, forKey: .needs)
        companyName = try c.decodeIfPresent(String.self, forKey: .companyName); companyDescription = try c.decodeIfPresent(String.self, forKey: .companyDescription)
        phone = try c.decodeIfPresent(String.self, forKey: .phone); linkedinUrl = try c.decodeIfPresent(String.self, forKey: .linkedinUrl)
        interventionZone = try c.decodeIfPresent(String.self, forKey: .interventionZone); websiteUrl = try c.decodeIfPresent(String.self, forKey: .websiteUrl)
        openingHours = try c.decodeIfPresent(String.self, forKey: .openingHours); proServices = try c.decodeIfPresent([ProServiceItem].self, forKey: .proServices)
        verificationStatus = try c.decodeIfPresent(String.self, forKey: .verificationStatus); isCommunityMember = try c.decodeIfPresent(Bool.self, forKey: .isCommunityMember)
        isAlly = try c.decodeIfPresent(Bool.self, forKey: .isAlly); profileStatus = try c.decodeIfPresent(String.self, forKey: .profileStatus)
        stripeChargesEnabled = try c.decodeIfPresent(Bool.self, forKey: .stripeChargesEnabled) ?? false
        stripePayoutsEnabled = try c.decodeIfPresent(Bool.self, forKey: .stripePayoutsEnabled) ?? false
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    /// Nom affiché : l'entreprise pour un compte pro, sinon le prénom.
    var title: String {
        if accountType == "pro", let companyName, !companyName.isEmpty { return companyName }
        return displayName
    }

    /// Affiche uniquement les indications déclarées par le membre.
    var identityBadges: [ProfileIdentityBadge] {
        var result: [ProfileIdentityBadge] = accountType == "pro" ? [.professional] : []
        if isCommunityMember == true {
            result.append(.community)
        } else if isAlly == true {
            result.append(.gayFriendly)
        }
        return result
    }

    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let value = parts.compactMap { $0.first }.map(String.init).joined()
        return value.isEmpty ? "?" : value.uppercased()
    }
}

enum ProfileIdentityBadge: String, Identifiable {
    case professional = "Pro"
    case community = "Communauté"
    case gayFriendly = "Gay friendly"

    var id: String { rawValue }
}

/// Insertion / mise à jour du profil lors de l'onboarding.
struct ProfileUpsert: Encodable {
    let id: String
    let displayName: String
    let email: String?
    let city: String?
    let accountType: String
    let charteAccepted: Bool
    let charteAcceptedAt: String

    enum CodingKeys: String, CodingKey {
        case id, email, city
        case displayName = "display_name"
        case accountType = "account_type"
        case charteAccepted = "charte_accepted"
        case charteAcceptedAt = "charte_accepted_at"
    }
}

struct BlockRow: Decodable {
    let blockerId: String
    let blockedId: String

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

struct Connection: Codable, Identifiable, Hashable {
    let id: String
    let userA: String
    let userB: String
    let status: String
    let serviceLabel: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case userA = "user_a"
        case userB = "user_b"
        case serviceLabel = "service_label"
        case updatedAt = "updated_at"
    }

    func otherUserId(for me: String) -> String {
        userA == me ? userB : userA
    }
}

struct Message: Codable, Identifiable, Hashable {
    let id: String
    let connectionId: String
    let senderId: String
    let body: String
    let createdAt: String
    let readAt: String?

    enum CodingKeys: String, CodingKey {
        case id, body
        case connectionId = "connection_id"
        case senderId = "sender_id"
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}

struct NewMessage: Encodable {
    let connectionId: String
    let senderId: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case body
        case connectionId = "connection_id"
        case senderId = "sender_id"
    }
}

struct Resource: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let title: String
    let description: String?
    let content: String?
    let phone: String?
    let url: String?
    let hours: String?
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, type, title, description, content, phone, url, hours
        case sortOrder = "sort_order"
    }
}
