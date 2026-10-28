import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var router = TabRouter()
    #if DEBUG
    var screenshotTab: TabRouter.Tab? = nil
    #endif

    var body: some View {
        TabView(selection: $router.selected) {
            // L'accueil de présentation n'existe que pour les visiteurs : une fois connecté, on ne l'affiche plus.
            if session.userId == nil {
                PresentationView()
                    .tabItem { Label("Accueil", systemImage: "house.fill") }
                    .tag(TabRouter.Tab.home)
            }

            DirectoryView()
                .tabItem { Label("Annuaire", systemImage: "person.3.fill") }
                .tag(TabRouter.Tab.directory)

            EventsView()
                .tabItem { Label("Événements", systemImage: "calendar") }
                .tag(TabRouter.Tab.events)

            // Missions : onglet réservé aux membres connectés (iOS n'affiche que 5 onglets).
            if session.userId != nil {
                MissionsView()
                    .tabItem { Label("Missions", systemImage: "megaphone.fill") }
                    .tag(TabRouter.Tab.missions)
            }

            MessagesView()
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(router.unreadMessages)
                .tag(TabRouter.Tab.messages)

            MyProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }
                .tag(TabRouter.Tab.profile)
        }
        .tint(Theme.primary)
        .fullScreenCover(isPresented: .constant(session.needsOnboarding)) {
            OnboardingView()
                .environmentObject(session)
                .environmentObject(router)
        }
        .sheet(isPresented: $router.showMissions) {
            MissionsView(showsClose: true)
                .environmentObject(router)
        }
        .environmentObject(router)
        .sensoryFeedback(.selection, trigger: router.selected)
        .onAppear {
            #if DEBUG
            if let screenshotTab { router.selected = screenshotTab }
            #endif
            leaveHomeIfSignedIn()
            handleDeepLink()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLink)) { _ in handleDeepLink() }
        .onReceive(NotificationCenter.default.publisher(for: .inboxDidChange)) { _ in
            guard let me = session.userId else { return }
            Task { router.unreadMessages = await Inbox.refresh(for: me) }
        }
        // Notifications : autorisation et jeton lié au compte, à chaque connexion.
        .task(id: session.userId) {
            guard !DemoMode.isOn else { return }
            PushManager.shared.setUser(session.userId)
            if session.userId != nil { PushManager.shared.requestAuthorization() }
            // Compteur de messages non lus, rafraîchi toutes les 20 secondes tant qu'on est connecté.
            guard let me = session.userId else {
                router.unreadMessages = 0
                return
            }
            while !Task.isCancelled {
                router.unreadMessages = await Inbox.refresh(for: me)
                try? await Task.sleep(for: .seconds(20))
            }
        }
        .onChange(of: session.userId) { _, _ in leaveHomeIfSignedIn() }
    }

    /// Notification touchée : message → conversation, annonce → missions, événement → événements.
    private func handleDeepLink() {
        guard let path = DeepLink.pendingPath else { return }
        DeepLink.pendingPath = nil
        let parts = path.split(separator: "/").map(String.init)
        switch parts.first {
        case "messages" where parts.count > 1:
            router.openConversation(parts[1])
        case "missions":
            router.openMissions()
        case "evenements":
            router.selected = .events
        default:
            break
        }
    }

    /// Connecté : l'onglet Accueil disparaît, on ouvre l'annuaire à sa place.
    private func leaveHomeIfSignedIn() {
        if session.userId != nil, router.selected == .home {
            router.selected = .directory
        }
    }
}

struct Avatar: View {
    let name: String
    let photoUrl: String?
    var size: CGFloat = 44

    init(profile: Profile?, size: CGFloat = 44) {
        self.init(name: profile?.displayName ?? "", photoUrl: profile?.photoUrl, size: size)
    }

    init(name: String, photoUrl: String?, size: CGFloat = 44) {
        self.name = name
        self.photoUrl = photoUrl
        self.size = size
    }

    var body: some View {
        Group {
            if let photoUrl, photoUrl.hasPrefix("asset:") {
                // Photo fournie dans l'app (mode démo) : pas de téléchargement.
                Image(String(photoUrl.dropFirst(6)))
                    .resizable()
                    .scaledToFill()
            } else if let urlString = photoUrl, let url = URL(string: urlString) {
                RemoteImage(url: url, maxPixel: 240) { placeholder }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let value = parts.compactMap { $0.first }.map(String.init).joined().uppercased()
        return value.isEmpty ? "?" : value
    }

    /// Dégradé violet → rose du site pour les avatars sans photo (ou pendant le chargement).
    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
