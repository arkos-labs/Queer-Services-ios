import Foundation

// MARK: - Référentiel (catégories, sous-catégories)

struct Category: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let slug: String
    let icon: String?
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, label, slug, icon
        case sortOrder = "sort_order"
    }
}

struct Subcategory: Codable, Identifiable, Hashable {
    let id: String
    let categoryId: String
    let label: String
    let slug: String
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, label, slug
        case categoryId = "category_id"
        case sortOrder = "sort_order"
    }
}

struct ProfileSubcategoryRow: Codable, Hashable {
    let profileId: String
    let subcategoryId: String

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case subcategoryId = "subcategory_id"
    }
}

struct ProfileSubcategoryInsert: Encodable {
    let profileId: String
    let subcategoryId: String

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case subcategoryId = "subcategory_id"
    }
}

// MARK: - Badges et avis

struct Badge: Codable, Identifiable, Hashable {
    let id: String
    let code: String
    let label: String
    let description: String?
    let icon: String?
}

struct ProfileBadgeRow: Decodable {
    let badge: Badge?
}

struct ProfileReview: Codable, Identifiable, Hashable {
    let id: String
    let authorId: String
    let targetId: String
    let rating: Int
    let comment: String?
    let createdAt: String?
    let author: MissionAuthor?

    enum CodingKeys: String, CodingKey {
        case id, rating, comment, author
        case authorId = "author_id"
        case targetId = "target_id"
        case createdAt = "created_at"
    }
}

// MARK: - Lieux

struct Place: Codable, Identifiable, Hashable {
    let id: String
    let submittedBy: String
    let subcategoryId: String?
    let name: String
    let description: String?
    let address: String?
    let city: String?
    let photoUrl: String?
    let status: String
    let createdAt: String?
    let submitter: MissionAuthor?

    enum CodingKeys: String, CodingKey {
        case id, name, description, address, city, status, submitter
        case submittedBy = "submitted_by"
        case subcategoryId = "subcategory_id"
        case photoUrl = "photo_url"
        case createdAt = "created_at"
    }
}

struct PlaceReview: Codable, Identifiable, Hashable {
    let id: String
    let placeId: String
    let authorId: String
    let rating: Int
    let comment: String?
    let createdAt: String?
    let author: MissionAuthor?

    enum CodingKeys: String, CodingKey {
        case id, rating, comment, author
        case placeId = "place_id"
        case authorId = "author_id"
        case createdAt = "created_at"
    }
}

struct PlaceInsert: Encodable {
    let submittedBy: String
    let name: String
    let description: String?
    let address: String?
    let city: String?
    let subcategoryId: String?

    enum CodingKeys: String, CodingKey {
        case name, description, address, city
        case submittedBy = "submitted_by"
        case subcategoryId = "subcategory_id"
    }
}

struct PlaceReviewInsert: Encodable {
    let placeId: String
    let authorId: String
    let rating: Int
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case rating, comment
        case placeId = "place_id"
        case authorId = "author_id"
    }
}

// MARK: - Missions, signalements, blocages

struct MissionInsert: Encodable {
    let createdBy: String
    let title: String
    let description: String
    let budget: String?

    enum CodingKeys: String, CodingKey {
        case title, description, budget
        case createdBy = "created_by"
    }
}

struct BlockInsert: Encodable {
    let blockerId: String
    let blockedId: String

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

struct ReportInsert: Encodable {
    let reporterId: String
    let targetType: String
    let targetId: String
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reason
        case reporterId = "reporter_id"
        case targetType = "target_type"
        case targetId = "target_id"
    }
}

// MARK: - Annuaire public

/// Ligne de la vue `public_directory_listings`, lisible sans compte (aperçu public du site).
/// Volontairement anonymisée : jamais de nom complet, photo, e-mail, téléphone ni bio.
struct PublicListing: Decodable, Identifiable, Hashable {
    let id: String
    let displayInitial: String
    let city: String?
    let accountType: String?
    let skills: [String]?
    let verificationStatus: String?
    let avgRating: Double?
    let reviewCount: Int?
    let subcategoryIds: [String]?
    let companyName: String?

    enum CodingKeys: String, CodingKey {
        case id, city, skills
        case displayInitial = "display_initial"
        case accountType = "account_type"
        case verificationStatus = "verification_status"
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
        case subcategoryIds = "subcategory_ids"
        case companyName = "company_name"
    }

    /// Les comptes pro affichent le nom de l'entreprise, comme sur le site ; les particuliers restent anonymes.
    var title: String {
        if accountType == "pro", let companyName, !companyName.isEmpty { return companyName }
        // La vue fournit déjà l'initiale suivie de son point (ex. « L. »).
        return displayInitial
    }
}
