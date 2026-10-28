import Foundation
import SwiftUI
import Supabase

/// État de session : utilisateur Supabase connecté + sa ligne `profiles`.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var userId: String?
    @Published private(set) var email: String?
    @Published private(set) var profile: Profile?
    @Published private(set) var isBootstrapping = true
    @Published var loadError: String?
    /// Nom fourni par Apple ou Google, pour préremplir l'onboarding.
    @Published private(set) var suggestedName: String?
    /// Vrai une fois la ligne `profiles` du compte connecté lue (présente ou non).
    @Published private(set) var profileChecked = false

    /// Compte connecté sans profil complet : il faut passer par l'onboarding.
    var needsOnboarding: Bool {
        guard userId != nil, profileChecked, loadError == nil else { return false }
        return (profile?.displayName ?? "").isEmpty
    }

    func bootstrap() async {
        defer { isBootstrapping = false }
        #if DEBUG
        if DemoMode.isOn {
            apply("demo-me", email: nil)
            profile = DemoMode.ownProfile
            profileChecked = true
            return
        }
        #endif
        do {
            let session = try await supabase.auth.session
            apply(session.user.id.uuidString, email: session.user.email)
            await refreshProfile()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            clear()
        }
    }

    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(email: email, password: password)
        apply(session.user.id.uuidString, email: session.user.email)
        await refreshProfile()
    }

    /// Renvoie `true` si une session est ouverte directement, `false` si un code de confirmation est attendu.
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await supabase.auth.signUp(email: email, password: password)
        // Comme sur le site : Supabase renvoie un utilisateur sans identité quand l'e-mail a déjà un compte.
        if response.session == nil, response.user.identities?.isEmpty == true {
            throw AuthMessage.alreadyRegistered
        }
        guard let session = response.session else { return false }
        apply(session.user.id.uuidString, email: session.user.email)
        await refreshProfile()
        return true
    }

    func verifySignup(email: String, code: String) async throws {
        let response = try await supabase.auth.verifyOTP(email: email, token: code, type: .signup)
        guard let session = response.session else { return }
        apply(session.user.id.uuidString, email: session.user.email)
        await refreshProfile()
    }

    /// Connexion native avec Apple : Apple reçoit le nonce haché, Supabase le nonce brut (comme appleSignIn.ts).
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
        // Apple ne donne le nom qu'à la toute première connexion : on le garde dans le compte.
        if let fullName {
            let name = PersonNameComponentsFormatter().string(from: fullName).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                suggestedName = name
                _ = try? await supabase.auth.update(user: UserAttributes(data: ["full_name": .string(name)]))
            }
        }
        apply(session.user.id.uuidString, email: session.user.email)
        if suggestedName == nil { suggestedName = Self.metadataName(session.user) }
        await refreshProfile()
    }

    /// Connexion Google : page Google dans une fenêtre sécurisée, retour par queerservices://auth-callback
    /// (l'adresse déjà autorisée dans Supabase pour l'ancienne app, cf. googleSignIn.ts).
    func signInWithGoogle() async throws {
        let session = try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "queerservices://auth-callback")
        )
        apply(session.user.id.uuidString, email: session.user.email)
        suggestedName = Self.metadataName(session.user)
        await refreshProfile()
    }

    private static func metadataName(_ user: User) -> String? {
        for key in ["full_name", "name"] {
            if case let .string(value)? = user.userMetadata[key], !value.isEmpty { return value }
        }
        return nil
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        clear()
    }

    func refreshProfile() async {
        guard let userId else {
            profile = nil
            return
        }
        do {
            let rows: [Profile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            profile = rows.first
            loadError = nil
            profileChecked = true
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            loadError = error.localizedDescription
        }
    }

    /// Profil enregistré par l'onboarding : publié seulement à la toute fin (après l'étape Stripe).
    func adopt(_ newProfile: Profile) {
        profile = newProfile
        profileChecked = true
    }

    func saveProfile(_ upsert: ProfileUpsert) async throws {
        let rows: [Profile] = try await supabase
            .from("profiles")
            .upsert(upsert)
            .select()
            .execute()
            .value
        profile = rows.first ?? profile
    }

    private func apply(_ rawId: String, email: String?) {
        let id = rawId.lowercased()
        if id != userId { profileChecked = false }
        userId = id
        self.email = email
    }

    private func clear() {
        userId = nil
        email = nil
        profile = nil
        suggestedName = nil
        profileChecked = false
    }
}

/// Messages d'authentification en français, repris du site (lib/auth.tsx).
enum AuthMessage: LocalizedError {
    case alreadyRegistered

    var errorDescription: String? {
        switch self {
        case .alreadyRegistered:
            "Cet e-mail a déjà un compte. Connecte-toi, ou utilise « Mot de passe oublié » si besoin."
        }
    }

    /// Traduit les erreurs Supabase les plus fréquentes.
    static func friendly(_ error: Error) -> String {
        if let known = error as? AuthMessage { return known.errorDescription ?? "" }
        let raw = error.localizedDescription
        let lower = raw.lowercased()
        if lower.contains("invalid login credentials") { return "E-mail ou mot de passe incorrect." }
        if lower.contains("email not confirmed") { return "Ton e-mail n'est pas encore confirmé. Saisis le code reçu par e-mail." }
        if lower.contains("already registered") || lower.contains("already been registered") || lower.contains("already exists") {
            return AuthMessage.alreadyRegistered.errorDescription ?? raw
        }
        if lower.contains("expired") || lower.contains("invalid") && lower.contains("token") { return "Code invalide ou expiré. Demande un nouveau code." }
        if lower.contains("rate limit") || lower.contains("only request this after") || lower.contains("too many") {
            return "Trop de tentatives. Réessaie dans quelques instants."
        }
        if lower.contains("password") && lower.contains("6") { return "Le mot de passe doit contenir au moins 6 caractères." }
        if lower.contains("network") || lower.contains("offline") || lower.contains("internet") {
            return "Connexion impossible. Vérifie ton réseau."
        }
        return raw
    }
}
