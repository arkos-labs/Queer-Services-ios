import Foundation

/// Service d'un compte pro, stocké dans `profiles.pro_services` (même format que ProServicesEditor côté web).
struct ProServiceItem: Codable, Hashable {
    let subcategoryId: String?
    let label: String
    let price: String

    enum CodingKeys: String, CodingKey {
        case label, price
        case subcategoryId = "subcategory_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(subcategoryId, forKey: .subcategoryId)
        try c.encode(label, forKey: .label)
        try c.encode(price, forKey: .price)
    }

    /// Tarif lisible : un simple nombre devient « 20 € / h ». Un tarif déjà écrit (« 40 € / h ») est gardé tel quel.
    static func formatPrice(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }
        if Double(value.replacingOccurrences(of: ",", with: ".")) != nil {
            return "\(value) € / h"
        }
        return value
    }
}

/// Ligne `profiles` écrite à la fin de l'onboarding (miroir de finishOnboarding dans OnboardingPage.tsx).
/// Les champs vides partent en `null`, comme sur le site.
struct OnboardingUpsert: Encodable {
    let id: String
    let displayName: String
    let email: String?
    let civilite: String?
    let city: String?
    let accountType: String
    let companyName: String?
    let companyDescription: String?
    let siret: String?
    let websiteUrl: String?
    let openingHours: String?
    let interventionZone: String?
    let skills: [String]
    let needs: [String]
    let proServices: [ProServiceItem]
    let isCommunityMember: Bool?
    let isAlly: Bool
    let charteAcceptedAt: String

    enum CodingKeys: String, CodingKey {
        case id, email, civilite, city, pronouns, siret, skills, needs
        case displayName = "display_name"
        case accountType = "account_type"
        case companyName = "company_name"
        case companyDescription = "company_description"
        case websiteUrl = "website_url"
        case openingHours = "opening_hours"
        case interventionZone = "intervention_zone"
        case proServices = "pro_services"
        case indicativeRates = "indicative_rates"
        case budgetIndicatif = "budget_indicatif"
        case isCommunityMember = "is_community_member"
        case isAlly = "is_ally"
        case charteAccepted = "charte_accepted"
        case charteAcceptedAt = "charte_accepted_at"
        case profileStatus = "profile_status"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(email, forKey: .email)
        try c.encode(civilite, forKey: .civilite)
        try c.encode(city, forKey: .city)
        try c.encodeNil(forKey: .pronouns)
        try c.encode(accountType, forKey: .accountType)
        try c.encode(companyName, forKey: .companyName)
        try c.encode(companyDescription, forKey: .companyDescription)
        try c.encode(siret, forKey: .siret)
        try c.encode(websiteUrl, forKey: .websiteUrl)
        try c.encode(openingHours, forKey: .openingHours)
        try c.encode(interventionZone, forKey: .interventionZone)
        try c.encode(skills, forKey: .skills)
        try c.encode(needs, forKey: .needs)
        try c.encode(proServices, forKey: .proServices)
        try c.encodeNil(forKey: .indicativeRates)
        try c.encodeNil(forKey: .budgetIndicatif)
        try c.encode(isCommunityMember, forKey: .isCommunityMember)
        try c.encode(isAlly, forKey: .isAlly)
        try c.encode(true, forKey: .charteAccepted)
        try c.encode(charteAcceptedAt, forKey: .charteAcceptedAt)
        try c.encode("active", forKey: .profileStatus)
    }
}

/// Textes repris tels quels du site (OnboardingPage.tsx).
enum OnboardingTexts {
    static let chartePoints = [
        "Je m'engage à respecter chaque membre, quelle que soit son orientation sexuelle, son identité ou son expression de genre.",
        "Je n'utilise pas de langage discriminant, haineux, stigmatisant ou de propos transphobes, homophobes, biphobes ou racistes.",
        "Je respecte les pronoms et civilités choisies par chacun·e, y compris lorsqu'ils diffèrent de mes habitudes.",
        "Je ne harcèle pas, je ne démarche pas de façon abusive ou insistante, et je n'utilise pas la messagerie à des fins de drague non sollicitée.",
        "Je décris honnêtement les services que je propose ou que je recherche, et je ne dissimule pas d'information importante sur le prix ou la prestation.",
        "Une fois une mission acceptée, je m'engage à la réaliser sérieusement ou à prévenir au plus vite en cas d'empêchement.",
        "Je respecte la vie privée des autres membres : je ne partage pas leurs informations personnelles ou nos échanges en dehors de la plateforme sans leur accord.",
        "Je privilégie des lieux et horaires sûrs pour les rencontres liées à une prestation, et je respecte le droit de chacun·e à refuser ou interrompre un échange à tout moment.",
        "Je signale tout comportement contraire à cette charte plutôt que de laisser une situation dégénérer.",
        "Je comprends que tout manquement à cette charte peut entraîner un avertissement, une suspension ou une suppression définitive de mon compte.",
    ]

    static let allyPoints = [
        "Respecter l'espace sécuritaire (safe space) créé pour la communauté.",
        "Faire preuve d'écoute, de bienveillance et d'ouverture.",
        "Ne pas porter de jugement sur les identités de genre et orientations sexuelles.",
        "Vous informer par vous-même sur les enjeux LGBTQIA+ si besoin.",
    ]

    static let civilites = ["Il", "Elle", "Iel", "Ielle", "Ne se prononce pas"]
}
