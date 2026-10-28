import Foundation
import Supabase

// MARK: - Paiements

struct Payment: Codable, Identifiable, Hashable {
    let id: String
    let connectionId: String
    let payerId: String
    let payeeId: String
    let description: String?
    let amount: Int
    let platformFeeAmount: Int
    let stripePaymentIntentId: String?
    let status: String
    let proposedBy: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, description, amount, status
        case connectionId = "connection_id"
        case payerId = "payer_id"
        case payeeId = "payee_id"
        case platformFeeAmount = "platform_fee_amount"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case proposedBy = "proposed_by"
        case createdAt = "created_at"
    }
}

/// Corps commun des fonctions Edge Stripe. Les champs absents ne sont pas envoyés.
struct EdgeBody: Encodable {
    var connectionId: String?
    var amount: Int?
    var description: String?
    var role: String?
    var action: String?
    var returnUrl: String?
    var refreshUrl: String?

    enum CodingKeys: String, CodingKey {
        case amount, description, role, action
        case connectionId = "connection_id"
        case returnUrl = "return_url"
        case refreshUrl = "refresh_url"
    }
}

/// Réponse commune : `url` (Connect), `client_secret` (carte), `synced` (synchro Stripe).
struct EdgeResponse: Decodable {
    let url: String?
    let clientSecret: String?
    let synced: Bool?

    enum CodingKeys: String, CodingKey {
        case url, synced
        case clientSecret = "client_secret"
    }
}

/// Erreur renvoyée par une Edge Function sous la forme `{ "error": "..." }`.
private struct EdgeErrorBody: Decodable {
    let error: String
}

enum Edge {
    static func call(_ name: String, _ body: EdgeBody) async throws -> EdgeResponse {
        do {
            return try await supabase.functions.invoke(name, options: FunctionInvokeOptions(body: body))
        } catch let error as FunctionsError {
            // Le message exact du serveur (ex. rôle refusé) remplace le « non-2xx » générique.
            if case .httpError(_, let data) = error,
               let message = try? JSONDecoder().decode(EdgeErrorBody.self, from: data).error {
                throw EdgeFailure(message: message)
            }
            throw error
        }
    }
}

struct EdgeFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Administration

struct Report: Codable, Identifiable, Hashable {
    let id: String
    let reporterId: String
    let targetType: String
    let targetId: String
    let reason: String
    let status: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, reason, status
        case reporterId = "reporter_id"
        case targetType = "target_type"
        case targetId = "target_id"
        case createdAt = "created_at"
    }
}

struct EventSubmission: Codable, Identifiable, Hashable {
    let id: String
    let submittedBy: String
    let kind: String
    let status: String
    let name: String
    let description: String?
    let city: String
    let address: String?
    let eventDate: String
    let websiteUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, status, name, description, city, address
        case submittedBy = "submitted_by"
        case eventDate = "event_date"
        case websiteUrl = "website_url"
    }
}

struct EventInsert: Encodable {
    let name: String
    let description: String?
    let city: String
    let address: String?
    let eventDate: String
    let websiteUrl: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case name, description, city, address, status
        case eventDate = "event_date"
        case websiteUrl = "website_url"
    }
}

struct StatusPatch: Encodable {
    let status: String
}

struct ProfileStatusPatch: Encodable {
    let profileStatus: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case profileStatus = "profile_status"
        case updatedAt = "updated_at"
    }
}

struct PlaceDecisionPatch: Encodable {
    let status: String
    let reviewedBy: String
    let reviewedAt: String
    let rejectionReason: String?

    enum CodingKeys: String, CodingKey {
        case status
        case reviewedBy = "reviewed_by"
        case reviewedAt = "reviewed_at"
        case rejectionReason = "rejection_reason"
    }
}

struct AdminPlaceReview: Codable, Identifiable, Hashable {
    let id: String
    let rating: Int
    let comment: String?
    let status: String
    let author: MissionAuthor?
    let place: PlaceName?

    struct PlaceName: Codable, Hashable {
        let name: String
    }
}

struct AdminPlace: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let city: String?
    let status: String
    let submitter: MissionAuthor?

    enum CodingKeys: String, CodingKey {
        case id, name, city, status, submitter
    }
}

struct AdminProfile: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let email: String?
    let profileStatus: String?
    let isAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case profileStatus = "profile_status"
        case isAdmin = "is_admin"
    }
}
