import SwiftUI

/// Onglet sélectionné, partagé pour que l'accueil puisse ouvrir l'annuaire (sur une catégorie) ou les événements.
@MainActor
final class TabRouter: ObservableObject {
    enum Tab: Hashable {
        case home, directory, events, missions, messages, profile
    }

    @Published var selected: Tab = .home
    /// Messages non lus, affichés sur l'onglet Messages.
    @Published var unreadMessages = 0
    /// Catégorie à présélectionner à la prochaine ouverture de l'annuaire.
    @Published var pendingCategoryId: String?
    /// iOS n'affiche que 5 onglets : les missions s'ouvrent en feuille, depuis l'accueil ou le profil.
    @Published var showMissions = false

    /// Conversation à ouvrir (depuis une notification de message).
    @Published var pendingConnectionId: String?

    func openConversation(_ connectionId: String) {
        pendingConnectionId = connectionId
        selected = .messages
    }

    func openMissions() {
        showMissions = true
    }

    func openDirectory(category: String? = nil) {
        pendingCategoryId = category
        selected = .directory
    }
}
