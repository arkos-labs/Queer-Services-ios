import SwiftUI

/// Identifiants bloqués dans les deux sens (comme côté web).
enum BlockList {
    static func blockedIds(for me: String) async throws -> Set<String> {
        let rows: [BlockRow] = try await supabase
            .from("blocked_users")
            .select("blocker_id, blocked_id")
            .or("blocker_id.eq.\(me),blocked_id.eq.\(me)")
            .execute()
            .value
        return Set(rows.map { $0.blockerId == me ? $0.blockedId : $0.blockerId })
    }
}

struct DirectoryView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var router: TabRouter

    @State private var profiles: [Profile] = []
    @State private var subsByProfile: [String: Set<String>] = [:]
    @State private var categories: [Category] = []
    @State private var subcategories: [Subcategory] = []
    @State private var activeCategory: String?
    @State private var activeSub: String?
    @State private var search = ""
    @State private var loading = true
    @State private var errorMessage: String?
    /// Aperçu anonymisé de l'annuaire, affiché sans connexion.
    @State private var listings: [PublicListing] = []
    @State private var showSignIn = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var subsOfActiveCategory: [Subcategory] {
        subcategories.filter { $0.categoryId == activeCategory }
    }

    private var filtered: [Profile] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return profiles.filter { p in
            if let activeSub, !(subsByProfile[p.id] ?? []).contains(activeSub) { return false }
            if activeSub == nil, let activeCategory {
                let ids = Set(subsOfActiveCategory.map(\.id))
                if (subsByProfile[p.id] ?? []).isDisjoint(with: ids) { return false }
            }
            guard !q.isEmpty else { return true }
            return p.title.lowercased().contains(q)
                || (p.city?.lowercased().contains(q) ?? false)
                || (p.skills ?? []).contains { $0.lowercased().contains(q) }
        }
    }

    private var filteredListings: [PublicListing] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return listings.filter { listing in
            let subs = Set(listing.subcategoryIds ?? [])
            if let activeSub, !subs.contains(activeSub) { return false }
            if activeSub == nil, activeCategory != nil {
                if subs.isDisjoint(with: Set(subsOfActiveCategory.map(\.id))) { return false }
            }
            guard !q.isEmpty else { return true }
            return listing.title.lowercased().contains(q)
                || (listing.city?.lowercased().contains(q) ?? false)
                || (listing.skills ?? []).contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !categories.isEmpty {
                        filters
                    }

                    Group {
                        if let errorMessage {
                            ErrorBanner(message: errorMessage)
                        }

                        if session.userId == nil {
                            publicPreview
                        } else if loading {
                            SkeletonList()
                        } else if filtered.isEmpty {
                            BrandEmptyState(
                                systemImage: "person.2.slash",
                                title: "Personne pour l'instant",
                                message: search.isEmpty
                                    ? "Aucun membre dans ce thème pour le moment. Reviens bientôt !"
                                    : "Aucun résultat pour « \(search) »."
                            )
                        } else {
                            Text("\(filtered.count) membre\(filtered.count > 1 ? "s" : "")")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.muted)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filtered) { profile in
                                    NavigationLink(value: profile) {
                                        MemberCard(profile: profile)
                                    }
                                    .buttonStyle(BrandPressStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .animation(.snappy, value: activeCategory)
                .animation(.snappy, value: activeSub)
            }
            .scrollIndicators(.hidden)
            .collapsingBrandHeader("Annuaire")
            .brandBackground()
            .searchable(text: $search, prompt: "Nom, ville, compétence")
            .navigationDestination(for: Profile.self) { ProfileDetailView(profile: $0) }
            .sheet(isPresented: $showSignIn) { SignInSheet() }
            .refreshable { await load() }
            .task { await load() }
            .onAppear(perform: applyPendingCategory)
            .onChange(of: router.pendingCategoryId) { _, _ in applyPendingCategory() }
        }
    }

    /// Sans compte : l'aperçu anonymisé, comme PublicDirectoryPreview sur le site.
    @ViewBuilder
    private var publicPreview: some View {
        Button { showSignIn = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aperçu anonymisé")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("Connecte-toi pour voir les profils complets et contacter les membres.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.primary)
            }
            .brandCard(cornerRadius: 20, padding: 12)
        }
        .buttonStyle(BrandPressStyle())

        if loading {
            SkeletonList()
        } else if filteredListings.isEmpty {
            BrandEmptyState(
                systemImage: "person.2.slash",
                title: "Personne pour l'instant",
                message: search.isEmpty
                    ? "Aucun membre dans ce thème pour le moment. Reviens bientôt !"
                    : "Aucun résultat pour « \(search) »."
            )
        } else {
            Text("\(filteredListings.count) membre\(filteredListings.count > 1 ? "s" : "")")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.muted)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredListings) { listing in
                    Button { showSignIn = true } label: {
                        ListingCard(listing: listing)
                    }
                    .buttonStyle(BrandPressStyle())
                }
            }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    BrandChip(label: "Tous", selected: activeCategory == nil) {
                        activeCategory = nil
                        activeSub = nil
                    }
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        BrandChip(
                            label: category.label,
                            systemImage: category.sfSymbol,
                            selected: activeCategory == category.id,
                            tint: Theme.rainbow[index % Theme.rainbow.count]
                        ) {
                            activeCategory = category.id
                            activeSub = nil
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollIndicators(.hidden)

            if activeCategory != nil, !subsOfActiveCategory.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(subsOfActiveCategory) { sub in
                            BrandChip(label: sub.label, selected: activeSub == sub.id, tint: Theme.pink) {
                                activeSub = activeSub == sub.id ? nil : sub.id
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollIndicators(.hidden)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func loadPublicListings() async {
        defer { loading = false }
        do {
            listings = try await supabase
                .from("public_directory_listings")
                .select()
                .execute()
                .value
            errorMessage = nil
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Catégorie choisie depuis l'accueil : on la sélectionne puis on la consomme.
    private func applyPendingCategory() {
        guard let id = router.pendingCategoryId else { return }
        activeCategory = id
        activeSub = nil
        router.pendingCategoryId = nil
    }

    /// Catégories et sous-catégories : toujours affichées. Copie locale d'abord, puis Supabase si la lecture réussit.
    private func loadCatalog() async {
        if categories.isEmpty {
            let bundled = ReferenceCatalog.load()
            categories = bundled.categories
            subcategories = bundled.subcategories
        }
        if DemoMode.isOn { return }

        if let remoteCats: [Category] = try? await supabase.from("categories").select().order("sort_order").execute().value,
           !remoteCats.isEmpty {
            categories = remoteCats
        }
        if let remoteSubs: [Subcategory] = try? await supabase.from("subcategories").select().order("sort_order").execute().value,
           !remoteSubs.isEmpty {
            subcategories = remoteSubs
        }
    }

    private func load() async {
        if DemoMode.isOn {
            await loadCatalog()
            profiles = DemoMode.profiles
            subsByProfile = DemoMode.skills(for: DemoMode.profiles)
            loading = false
            return
        }
        await loadCatalog()
        guard let me = session.userId else {
            await loadPublicListings()
            return
        }
        defer { loading = false }
        do {
            async let blocked = BlockList.blockedIds(for: me)
            let rows: [Profile] = try await supabase
                .from("profiles")
                .select(publicProfileColumns)
                .eq("profile_status", value: "active")
                .eq("is_admin", value: false)
                .or("email.is.null,email.neq.\(AppConfig.contactEmail)")
                .order("created_at", ascending: false)
                .execute()
                .value

            let hidden = try await blocked
            profiles = rows.filter { $0.id != me && !hidden.contains($0.id) }

            let ids = profiles.map(\.id)
            if ids.isEmpty {
                subsByProfile = [:]
            } else {
                let links: [ProfileSubcategoryRow] = try await supabase
                    .from("profile_subcategories")
                    .select("profile_id, subcategory_id")
                    .in("profile_id", values: ids)
                    .execute()
                    .value
                subsByProfile = Dictionary(grouping: links, by: \.profileId)
                    .mapValues { Set($0.map(\.subcategoryId)) }
            }
            errorMessage = nil
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}

/// Carte membre de la grille (même contenu que les cartes de DirectoryPage côté web).
private struct MemberCard: View {
    let profile: Profile

    private var isVerified: Bool { profile.verificationStatus == "verified" }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(profile: profile, size: 68)
                    .padding(3)
                    .background(
                        Circle().stroke(
                            isVerified
                                ? AnyShapeStyle(AngularGradient(colors: Theme.rainbow + [Theme.rainbow[0]], center: .center))
                                : AnyShapeStyle(Theme.primary.opacity(0.15)),
                            lineWidth: 2.5
                        )
                    )
            }

            VStack(spacing: 3) {
                Text(profile.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if let city = profile.city, !city.isEmpty {
                    Label(city, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                ProfileIdentityBadgeChips(profile: profile)
                if let skill = profile.skills?.first {
                    TagChip(text: skill)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .brandCard(cornerRadius: 24, padding: 14)
    }
}

/// Carte de l'aperçu public : initiale à la place de la photo, aucune donnée de contact.
private struct ListingCard: View {
    let listing: PublicListing

    private var isVerified: Bool { listing.verificationStatus == "verified" }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Text(listing.displayInitial.prefix(1).uppercased())
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(
                        LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .padding(3)
                    .background(
                        Circle().stroke(
                            isVerified
                                ? AnyShapeStyle(AngularGradient(colors: Theme.rainbow + [Theme.rainbow[0]], center: .center))
                                : AnyShapeStyle(Theme.primary.opacity(0.15)),
                            lineWidth: 2.5
                        )
                    )
            }

            VStack(spacing: 3) {
                Text(listing.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if let city = listing.city, !city.isEmpty {
                    Label(city, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                if listing.accountType == "pro" {
                    TagChip(text: "Pro", color: Theme.rainbowBlue)
                        .fixedSize()
                }
                if let skill = listing.skills?.first {
                    TagChip(text: skill)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .brandCard(cornerRadius: 24, padding: 14)
    }
}
