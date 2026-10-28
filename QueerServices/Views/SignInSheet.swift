import SwiftUI

/// Connexion ouverte à la demande (depuis la présentation ou le profil), pas au démarrage.
struct SignInSheet: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if session.userId == nil {
                AuthView()
            } else {
                // Compte créé ou connecté sans prénom : on termine l'onboarding dans la même feuille.
                OnboardingView()
            }
        }
        .onChange(of: session.profile?.id) { _, id in
            if id != nil { dismiss() }
        }
    }
}
