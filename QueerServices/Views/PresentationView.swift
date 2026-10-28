import SwiftUI

/// Page d'accueil de la communauté : reprend le message du site (LandingPage) en version native.
struct PresentationView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var router: TabRouter

    @State private var categories: [Category] = []
    @State private var subcategories: [Subcategory] = []
    @State private var events: [CommunityEvent] = []
    @State private var memberCount = 0
    @State private var eventCount = 0
    @State private var showSignIn = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ImmersiveHero(
                        firstName: session.profile?.displayName.split(separator: " ").first.map(String.init),
                        isSignedIn: session.userId != nil,
                        services: subcategories.map(\.label),
                        explore: { router.openDirectory() },
                        signIn: { showSignIn = true }
                    )
                    .reveal(appeared, order: 0)

                    StatsStrip(members: memberCount, services: subcategories.count, events: eventCount)
                        .padding(.horizontal, 28)
                        .offset(y: -34)
                        .padding(.bottom, -34)
                        .reveal(appeared, order: 1)

                    VStack(spacing: 34) {
                        themesSection.reveal(appeared, order: 2)
                        MissionsShortcut { router.openMissions() }
                            .padding(.horizontal, 20)
                            .reveal(appeared, order: 3)
                        if !events.isEmpty {
                            eventsSection.reveal(appeared, order: 3)
                        }
                        ValuesSection().reveal(appeared, order: 4)
                        StepsSection().reveal(appeared, order: 5)
                        ListeningCard().reveal(appeared, order: 6)
                        JoinCard(
                            isSignedIn: session.userId != nil,
                            signIn: { showSignIn = true },
                            publish: { router.openMissions() }
                        )
                        .reveal(appeared, order: 7)
                        Footer()
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 24)
                }
            }
            .scrollIndicators(.hidden)
            .background(Theme.paper.opacity(0.55).ignoresSafeArea())
            // En-tête fixe : le logo reste centré en haut pendant le défilement.
            .toolbar(.hidden, for: .navigationBar)
            // Pas de barre d'onglets sur l'accueil de présentation.
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .top, spacing: 0) { BrandHeaderBar() }
            .sheet(isPresented: $showSignIn) { SignInSheet() }
            .task { await load() }
            .refreshable { await load() }
            .onAppear { appeared = true }
        }
    }

    // MARK: Thèmes

    private var themesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Explorer par thème", action: "Tout voir") { router.openDirectory() }
                .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        Button {
                            router.openDirectory(category: category.id)
                        } label: {
                            ThemeTile(
                                category: category,
                                serviceCount: subcategories.filter { $0.categoryId == category.id }.count,
                                color: Theme.rainbow[index % Theme.rainbow.count]
                            )
                        }
                        .buttonStyle(PressableStyle())
                        .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                            view
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                .opacity(phase.isIdentity ? 1 : 0.7)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    // MARK: Événements

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Prochains événements", action: "Agenda") { router.selected = .events }
                .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(events) { event in
                        Button { router.selected = .events } label: {
                            EventTeaser(event: event)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    // MARK: Données

    /// Référentiel local d'abord (toujours affiché), puis Supabase. Les chiffres n'apparaissent que s'ils sont lisibles.
    private func load() async {
        let bundled = ReferenceCatalog.load()
        if categories.isEmpty {
            categories = bundled.categories
            subcategories = bundled.subcategories
        }
        if let remote: [Category] = try? await supabase.from("categories").select().order("sort_order").execute().value,
           !remote.isEmpty {
            categories = remote
        }
        if let remote: [Subcategory] = try? await supabase.from("subcategories").select().order("sort_order").execute().value,
           !remote.isEmpty {
            subcategories = remote
        }

        let today = DateFormats.day.string(from: Date())
        if let upcoming: [CommunityEvent] = try? await supabase
            .from("events")
            .select()
            .eq("status", value: "published")
            .gte("event_date", value: today)
            .order("event_date", ascending: true)
            .limit(6)
            .execute()
            .value {
            events = upcoming
        }

        // Vue anonymisée lisible sans compte (comme l'aperçu public du site).
        let members = (try? await supabase
            .from("public_directory_listings")
            .select("id", head: true, count: .exact)
            .execute()
            .count) ?? 0
        let upcomingCount = (try? await supabase
            .from("events")
            .select("id", head: true, count: .exact)
            .eq("status", value: "published")
            .gte("event_date", value: today)
            .execute()
            .count) ?? events.count

        withAnimation(.easeOut(duration: 1.1)) {
            memberCount = DemoMode.isOn ? DemoMode.profiles.count : members
            eventCount = upcomingCount
        }
    }
}

// MARK: - Hero

/// Fond du hero : violet profond de l'icône avec des halos radiaux statiques (sans flou ni animation continue).
private struct HeroBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.brandDeep, Theme.primaryDeep, Theme.primary],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Theme.pink.opacity(0.55), .clear], center: .topTrailing, startRadius: 0, endRadius: 170)
            RadialGradient(colors: [Theme.rainbowOrange.opacity(0.35), .clear], center: .bottomLeading, startRadius: 0, endRadius: 150)
            RadialGradient(colors: [Theme.rainbowBlue.opacity(0.45), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 150)
        }
    }
}

/// Emblème du logo dans un médaillon blanc entouré d'un anneau arc-en-ciel qui tourne.
private struct EmblemMedallion: View {
    var size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(colors: Theme.rainbow + [Theme.rainbow[0]], center: .center),
                    lineWidth: 4
                )
                .rotationEffect(.degrees(spin ? 360 : 0))
            Circle()
                .fill(.white)
                .padding(5)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .padding(size * 0.16)
                .accessibilityLabel("Logo Queer Services")
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}

// MARK: - Chiffres

private struct StatsStrip: View {
    let members: Int
    let services: Int
    let events: Int

    var body: some View {
        HStack(spacing: 0) {
            stat(value: members, label: "membres", color: Theme.primary)
            divider
            stat(value: services, label: "services", color: Theme.pink)
            divider
            stat(value: events, label: "événements", color: Theme.rainbowOrange)
        }
        .padding(.vertical, 16)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.primary.opacity(0.14), radius: 18, y: 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.primary.opacity(0.12))
            .frame(width: 1, height: 34)
    }

    private func stat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value > 0 ? "\(value)" : "—")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tuiles

private struct SectionHeader: View {
    let title: String
    let action: String
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button(action: onTap) {
                HStack(spacing: 3) {
                    Text(action)
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primary)
            }
        }
    }
}

private struct ThemeTile: View {
    let category: Category
    let serviceCount: Int
    let color: Color

    private var symbol: String {
        switch category.icon {
        case "Home": "house.fill"
        case "HeartPulse": "heart.text.square.fill"
        case "Briefcase": "briefcase.fill"
        case "ShoppingBag": "bag.fill"
        case "Handshake": "hands.and.sparkles.fill"
        case "Plane": "airplane"
        case "Users": "person.3.fill"
        default: "square.grid.2x2.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
                .shadow(color: color.opacity(0.4), radius: 8, y: 4)
            Spacer(minLength: 0)
            Text(category.label)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(serviceCount > 0 ? "\(serviceCount) services" : "Découvrir")
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(16)
        .frame(width: 158, height: 168, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(color.opacity(0.10))
                .frame(width: 90)
                .offset(x: 34, y: -34)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.primary.opacity(0.08), radius: 12, y: 6)
    }
}

private struct EventTeaser: View {
    let event: CommunityEvent

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "MMM"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text(event.startDate.map { Self.dayFormatter.string(from: $0) } ?? "–")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                Text(event.startDate.map { Self.monthFormatter.string(from: $0).uppercased() } ?? "")
                    .font(.caption2.weight(.heavy))
                    .tracking(1)
            }
            .foregroundStyle(.white)
            .frame(width: 56, height: 62)
            .background(
                LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(event.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Label(event.city, systemImage: "mappin.and.ellipse")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                if let theme = event.theme, !theme.isEmpty {
                    Text(theme)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.primaryDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.primarySoft, in: Capsule())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 280, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.primary.opacity(0.08), radius: 12, y: 6)
    }
}

// MARK: - Engagements, étapes, écoute

private struct ValuesSection: View {
    private let values: [(icon: String, color: Color, title: String, text: String)] = [
        ("shield.lefthalf.filled", Theme.primary, "Modération active",
         "Une charte stricte et une équipe dédiée pour un espace sécurisant et bienveillant."),
        ("checkmark.seal.fill", Color(hex: 0x059669), "Membres vérifiés",
         "Des badges de confiance attribués pour rassurer et guider vos échanges."),
        ("heart.fill", Theme.pink, "Fait avec amour",
         "Pensé pour et par la communauté queer, avec l'inclusivité au cœur de chaque décision."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nos engagements")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)

            VStack(spacing: 10) {
                ForEach(values, id: \.title) { value in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: value.icon)
                            .font(.title3)
                            .foregroundStyle(value.color)
                            .frame(width: 46, height: 46)
                            .background(value.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(value.title)
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(Theme.ink)
                            Text(value.text)
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Theme.primary.opacity(0.06), radius: 10, y: 4)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct StepsSection: View {
    private let steps: [(icon: String, title: String, text: String)] = [
        ("person.crop.circle.badge.plus", "Créez votre profil",
         "Inscrivez-vous gratuitement. Remplissez votre bio et précisez si vous offrez ou cherchez des services."),
        ("wand.and.stars", "Déclarez vos talents",
         "Ajoutez vos compétences ou vos besoins. Le moteur connecte les bons profils ensemble."),
        ("bubble.left.and.text.bubble.right.fill", "Échangez en sécurité",
         "Utilisez la messagerie intégrée. Après la prestation, laissez un avis pour faire grandir la confiance."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Comment ça marche ?")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 0) {
                            Image(systemName: step.icon)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(Theme.rainbow[[0, 2, 4][index]], in: Circle())
                                .overlay(alignment: .topTrailing) {
                                    Text("\(index + 1)")
                                        .font(.caption2.weight(.heavy))
                                        .foregroundStyle(Theme.primaryDeep)
                                        .frame(width: 18, height: 18)
                                        .background(.white, in: Circle())
                                        .offset(x: 4, y: -4)
                                }
                            if index < steps.count - 1 {
                                LinearGradient(colors: [Theme.rainbow[[0, 2, 4][index]], Theme.rainbow[[0, 2, 4][index + 1]]],
                                               startPoint: .top, endPoint: .bottom)
                                    .frame(width: 3)
                                    .frame(minHeight: 34)
                                    .clipShape(Capsule())
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(Theme.ink)
                            Text(step.text)
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 9)
                        .padding(.bottom, index < steps.count - 1 ? 18 : 0)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

/// Accès direct aux lignes d'écoute (numéros de la table resources).
private struct ListeningCard: View {
    private let lines: [(name: String, detail: String, phone: String)] = [
        ("3114 — Prévention du suicide", "24h/24, 7j/7 · gratuit", "3114"),
        ("SOS Homophobie", "Écoute anonyme des victimes et témoins", "0148064241"),
        ("LÉIA EST LÀ", "7j/7, 8h–23h · appel gratuit", "0800004134"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "heart.circle.fill")
                    .font(.title)
                    .foregroundStyle(Theme.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Besoin d'écoute ?")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("Tu n'es pas seul·e. Ces lignes sont confidentielles.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }

            ForEach(lines, id: \.phone) { line in
                if let url = URL(string: "tel:\(line.phone)") {
                    Link(destination: url) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.name).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                                Text(line.detail).font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Theme.pink, in: Circle())
                        }
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }

            NavigationLink {
                ResourcesView()
            } label: {
                HStack(spacing: 4) {
                    Text("Tous les numéros et guides")
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.pink)
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color(hex: 0xFDF2F8), Color(hex: 0xF5F3FF)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Theme.pink.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

private struct JoinCard: View {
    let isSignedIn: Bool
    let signIn: () -> Void
    let publish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            EmblemMedallion(size: 64)
            Text(isSignedIn ? "Un besoin ? Une compétence ?" : "Rejoins la communauté")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(isSignedIn
                 ? "Publie une mission et laisse la communauté te répondre."
                 : "Crée ton compte gratuitement pour proposer tes services et échanger avec les membres.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Button(action: isSignedIn ? publish : signIn) {
                Text(isSignedIn ? "Publier une mission" : "Créer mon compte")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.primaryDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .sensoryFeedback(.impact(weight: .light), trigger: isSignedIn)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(HeroBackground())
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Theme.brandDeep.opacity(0.3), radius: 20, y: 10)
        .padding(.horizontal, 20)
    }
}

private struct Footer: View {
    var body: some View {
        VStack(spacing: 10) {
            RainbowBar(height: 3)
                .frame(width: 70)
            Text("© \(String(Calendar.current.component(.year, from: Date()))) Queer Service")
                .font(.caption.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 18) {
                if let cgu = URL(string: "https://queerservices.fr/cgu") {
                    Link("CGU", destination: cgu)
                }
                if let privacy = URL(string: "https://queerservices.fr/confidentialite") {
                    Link("Confidentialité", destination: privacy)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Styles

/// Léger enfoncement au toucher, comme les cartes du site (active:scale-[0.98]).
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

private extension View {
    /// Apparition en cascade des sections à l'ouverture de la page.
    func reveal(_ appeared: Bool, order: Int) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 22)
            .animation(.spring(duration: 0.7, bounce: 0.25).delay(Double(order) * 0.07), value: appeared)
    }
}
