import Foundation
import Supabase

/// Même projet Supabase que la version web (`VITE_SUPABASE_URL`).
/// La clé anon est publique par conception : elle est déjà embarquée dans le bundle web.
enum AppConfig {
    static let supabaseURL = URL(string: "https://ovufzlswycrvadckhysi.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im92dWZ6bHN3eWNydmFkY2toeXNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ5NzUzMDUsImV4cCI6MjEwMDU1MTMwNX0.6uU23Br-WIsOPdW-HD2LH_yUep2oLaxXa2sLY2tNUOA"
    static let contactEmail = "contact@queerservices.fr"
    /// Clé publique Stripe (pk_…), la même que le web (`VITE_STRIPE_PUBLISHABLE_KEY`).
    /// Vide tant qu'elle n'est pas renseignée : sans elle, la feuille de paiement ne s'affiche pas.
    static let stripePublishableKey = "pk_live_51UP6SQ8GSwbYhAxqa2f7Ne8L0REO8a7fOGmVqRkLu31gmEK1xcGVmbrLPo2bj5GkOCFeB53rfZACrdnESYHsShNQ00XYhMcPgG"
}

let supabase = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)


#if DEBUG
/// Mode démo pour les captures d'écran : données fictives, uniquement dans une version de développement.
/// S'active au lancement avec la variable d'environnement QS_DEMO=1. Jamais actif dans la version publiée.
enum DemoMode {
    static let isOn = ProcessInfo.processInfo.environment["QS_DEMO"] == "1" || UserDefaults.standard.bool(forKey: "QS_DEMO")

    private static func decode<T: Decodable>(_ json: String, as type: T.Type) -> T {
        try! JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    /// Profil affiché dans l'onglet Profil en mode démo (pas de connexion nécessaire).
    static var ownProfile: Profile? { profiles.first }

    /// Compétences fictives : chaque profil reçoit deux sous-catégories du catalogue, comme un vrai profil.
    static func skills(for profiles: [Profile]) -> [String: Set<String>] {
        let ids = ReferenceCatalog.load().subcategories.map(\.id)
        guard !ids.isEmpty else { return [:] }
        var result: [String: Set<String>] = [:]
        for (index, profile) in profiles.enumerated() {
            result[profile.id] = [ids[(index * 3) % ids.count], ids[(index * 3 + 1) % ids.count]]
        }
        return result
    }

    static let profiles: [Profile] = {
        let first = decode("""
        [
          {"id":"demo-1","is_community_member":true,"is_ally":false,"display_name":"Camille","skills":["Baby-sitting"],"photo_url":"asset:demo-portrait-1","account_type":"particulier","city":"Lyon","pronouns":"iel","bio":"Bénévole, toujours partante pour un coup de main."},
          {"id":"demo-2","is_community_member":false,"is_ally":true,"display_name":"Sasha","skills":["Garde de maison"],"photo_url":"asset:demo-portrait-2","account_type":"particulier","city":"Paris","bio":"Garde d'enfants et baby-sitting le week-end."},
          {"id":"demo-3","is_community_member":true,"is_ally":false,"display_name":"Atelier Arc-en-ciel","skills":["Couture"],"photo_url":"asset:demo-portrait-3","account_type":"pro","city":"Marseille","company_name":"Atelier Arc-en-ciel","company_description":"Couture et retouches sur mesure.","pro_services":[{"label":"Couture","price":"40 € / h","subcategory_id":null}]},
          {"id":"demo-4","is_community_member":false,"is_ally":true,"display_name":"Jordan","skills":["Bricolage"],"photo_url":"asset:demo-portrait-4","account_type":"particulier","city":"Toulouse","bio":"Bricolage et petits travaux."}
        ]
        """, as: [Profile].self)
        let names = ["Lou", "Maë", "Alex", "Nina", "Sam", "Juno", "Léo", "Eva", "Kai", "Noé",
                     "Rose", "Ari", "Tess", "Milo", "Iris", "Elio", "Lia", "Zoé", "Yann", "Mina",
                     "Oscar", "Lilou", "Ezra", "Chloé", "Rayan", "Inès", "Dani", "Mathis", "Ada", "Théo",
                     "Clém", "Soren", "Liv", "Nico", "Anaé", "Gaspard", "Elsa", "Robin", "Maya", "Quentin"]
        let skillLabels = ["Ménage", "Déménagement", "Plomberie", "Cuisine", "Jardinage", "Coiffeurs", "Pet-sitting", "Montage de meubles", "Cours particuliers", "Informatique à domicile"]
        let cities = ["Lyon", "Paris", "Marseille", "Toulouse", "Nantes", "Lille", "Bordeaux", "Rennes", "Strasbourg", "Montpellier"]
        let generated: [Profile] = names.enumerated().map { index, name in
            decode("""
            {"id":"demo-\(index + 5)","display_name":"\(name)","account_type":"particulier","city":"\(cities[index % cities.count])",\"skills\":[\"\(skillLabels[index % skillLabels.count])\"]\(index < 8 ? ",\"photo_url\":\"asset:demo-portrait-\(index + 1)\"" : "")}
            """, as: Profile.self)
        }
        return first + generated
    }()

    static let missions: [MissionRequest] = decode("""
    [
      {"id":"m-1","title":"Aide au déménagement","description":"Besoin d'un coup de main samedi matin pour porter des cartons.","budget":"50 €","created_at":"2026-10-20T10:00:00Z","created_by":"demo-1","profiles":{"display_name":"Camille","photo_url":null}},
      {"id":"m-2","title":"Baby-sitting ce soir","description":"Garde de deux enfants de 19h à 23h, quartier Bellecour.","budget":"15 € / h","created_at":"2026-10-21T18:00:00Z","created_by":"demo-2","profiles":{"display_name":"Sasha","photo_url":null}},
      {"id":"m-3","title":"Montage de meuble","description":"Une armoire à monter, outils fournis.","budget":null,"created_at":"2026-10-22T09:00:00Z","created_by":"demo-4","profiles":{"display_name":"Jordan","photo_url":null}}
    ]
    """, as: [MissionRequest].self)

    static let conversations: [Conversation] = {
        let me = "demo-me"
        let connection = decode("""
        {"id":"c-1","user_a":"demo-me","user_b":"demo-1","status":"accepted","service_label":"Aide au déménagement","updated_at":"2026-10-22T10:00:00Z"}
        """, as: Connection.self)
        let message = decode("""
        {"id":"msg-1","connection_id":"c-1","sender_id":"demo-1","body":"Coucou ! Je peux venir samedi matin, c'est bon pour toi ?","created_at":"2026-10-22T10:00:00Z","read_at":null}
        """, as: Message.self)
        let connection2 = decode("""
        {"id":"c-2","user_a":"demo-me","user_b":"demo-2","status":"pending","service_label":"Baby-sitting ce soir","updated_at":"2026-10-21T18:00:00Z"}
        """, as: Connection.self)
        let message2 = decode("""
        {"id":"msg-2","connection_id":"c-2","sender_id":"demo-me","body":"Bonjour, je suis disponible ce soir si tu veux.","created_at":"2026-10-21T18:00:00Z","read_at":"2026-10-21T18:05:00Z"}
        """, as: Message.self)
        _ = me
        return [
            Conversation(connection: connection, other: profiles[0], lastMessage: message),
            Conversation(connection: connection2, other: profiles[1], lastMessage: message2),
        ]
    }()
}
#else
/// Version publiée : le mode démo n'existe pas.
enum DemoMode {
    static let isOn = false
    static let profiles: [Profile] = []
    static func skills(for profiles: [Profile]) -> [String: Set<String>] { [:] }
    static let ownProfile: Profile? = nil
    static let missions: [MissionRequest] = []
    static let conversations: [Conversation] = []
}
#endif
