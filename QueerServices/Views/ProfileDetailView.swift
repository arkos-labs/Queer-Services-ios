import SwiftUI

private struct ServiceLabelPatch: Encodable {
    let serviceLabel: String

    enum CodingKeys: String, CodingKey {
        case serviceLabel = "service_label"
    }
}

struct ProfileDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var router: TabRouter

    let profile: Profile

    @State private var badges: [Badge] = []
    @State private var reviews: [ProfileReview] = []
    @State private var isBlocked = false
    @State private var busy = false
    @State private var message: String?
    @State private var showReport = false
    @State private var reportReason = ""
    @State private var showBlockConfirm = false
    @State private var contactBusy = false
    @State private var showServiceRequest = false
    @State private var serviceTitle = ""
    @State private var serviceDetails = ""

    private var averageRating: Double? {
        guard !reviews.isEmpty else { return nil }
        return Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if profile.accountType == "pro" {
                    professionalDetails
                } else {
                    personalDetails
                }
                servicesCard

                if let bio = profile.bio, !bio.isEmpty {
                    CardSection(title: "À propos", systemImage: "text.quote") {
                        Text(bio)
                            .font(.body)
                            .foregroundStyle(Theme.ink.opacity(0.85))
                    }
                }

                if let skills = profile.skills, !skills.isEmpty {
                    CardSection(title: "Compétences", systemImage: "wand.and.stars") {
                        FlowLayout {
                            ForEach(skills, id: \.self) { TagChip(text: $0) }
                        }
                    }
                }

                if let needs = profile.needs, !needs.isEmpty {
                    CardSection(title: "Recherche", systemImage: "magnifyingglass") {
                        FlowLayout {
                            ForEach(needs, id: \.self) { TagChip(text: $0, color: Theme.pink) }
                        }
                    }
                }

                if !reviews.isEmpty {
                    CardSection(title: "Avis (\(reviews.count))", systemImage: "star.bubble.fill") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(reviews) { review in
                                ReviewRow(review: review)
                                if review.id != reviews.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                if let message {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.primarySoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if session.userId != nil, session.userId != profile.id {
                    contactActions
                    safetyActions
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .brandBackground()
        .navigationTitle(profile.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Bloquer ce membre ?", isPresented: $showBlockConfirm) {
            Button("Bloquer", role: .destructive) { Task { await block() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Vous ne verrez plus vos profils respectifs ni vos messages.")
        }
        .sheet(isPresented: $showReport) { reportSheet }
    }

    // MARK: En-tête

    private var header: some View {
        VStack(spacing: 0) {
            BrandGradient()
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(alignment: .bottom) {
                    Avatar(profile: profile, size: 104)
                        .padding(4)
                        .background(Circle().fill(.white))
                        .shadow(color: Theme.brandDeep.opacity(0.25), radius: 14, y: 6)
                        .offset(y: 52)
                }
                .padding(.bottom, 58)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(profile.title)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    if profile.verificationStatus == "verified" {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color(hex: 0x059669))
                            .accessibilityLabel("Membre vérifié")
                    }
                }

                HStack(spacing: 10) {
                    if let pronouns = profile.pronouns, !pronouns.isEmpty {
                        Text(pronouns)
                    }
                    if let city = profile.city, !city.isEmpty {
                        Label(city, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

                if let averageRating {
                    HStack(spacing: 6) {
                        StarsLabel(rating: Int(averageRating.rounded()))
                        Text(String(format: "%.1f · %d avis", averageRating, reviews.count))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }

                if !profile.identityBadges.isEmpty || !badges.isEmpty {
                    FlowLayout(spacing: 6) {
                        ProfileIdentityBadgeChips(profile: profile)
                        ForEach(badges.filter { badge in
                            !profile.identityBadges.contains { $0.rawValue.localizedCaseInsensitiveCompare(badge.label) == .orderedSame }
                        }) { badge in
                            TagChip(text: badge.label, color: Theme.primaryDeep)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
        }
        .padding(.top, 8)
    }

    private var safetyActions: some View {
        HStack(spacing: 10) {
            Button {
                if isBlocked { Task { await unblock() } } else { showBlockConfirm = true }
            } label: {
                Label(isBlocked ? "Débloquer" : "Bloquer", systemImage: isBlocked ? "hand.raised.slash" : "hand.raised.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .glassCapsule()
            }
            .buttonStyle(BrandPressStyle())

            Button {
                showReport = true
            } label: {
                Label("Signaler", systemImage: "flag.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.rose)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .glassCapsule()
            }
            .buttonStyle(BrandPressStyle())
        }
        .disabled(busy)
        .padding(.top, 4)
    }

    private var contactActions: some View {
        VStack(spacing: 10) {
            Button {
                serviceTitle = ""
                serviceDetails = ""
                showServiceRequest = true
            } label: {
                Label(contactBusy ? "Ouverture…" : "Demander un service", systemImage: "hand.raised.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .leading, endPoint: .trailing), in: Capsule())
            }
            .buttonStyle(BrandPressStyle())

            Button {
                Task { await openConversation(serviceLabel: "Échange avec \(profile.title)") }
            } label: {
                Label("Envoyer un message", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(Theme.primaryDeep)
                    .background(Theme.primarySoft, in: Capsule())
            }
            .buttonStyle(BrandPressStyle())
        }
        .disabled(contactBusy)
        .sheet(isPresented: $showServiceRequest) {
            serviceRequestSheet
                .presentationDetents([.medium, .large])
        }
    }

    /// Fiche « Demander un service » : titre de la prestation et détails facultatifs.
    private var serviceRequestSheet: some View {
        NavigationStack {
            Form {
                Section("Titre de la prestation") {
                    TextField("Ex. Ménage, baby-sitting…", text: $serviceTitle)
                }
                Section("Détails (facultatif)") {
                    TextField("Décris ce que tu demandes", text: $serviceDetails, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Demander un service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showServiceRequest = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") {
                        let title = serviceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let details = serviceDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                        showServiceRequest = false
                        Task { await openConversation(serviceLabel: title, details: details) }
                    }
                    .disabled(serviceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func openConversation(serviceLabel: String, details: String? = nil) async {
        guard let me = session.userId, me != profile.id else { return }
        contactBusy = true
        defer { contactBusy = false }
        do {
            let existing: [Connection] = try await supabase
                .from("connections")
                .select()
                .or("user_a.eq.\(me),user_b.eq.\(me)")
                .execute()
                .value
            // Une prestation clôturée reste dans « Clôturées » : une nouvelle demande ouvre une nouvelle conversation.
            if let connection = existing.first(where: {
                $0.status != "completed" && (($0.userA == me && $0.userB == profile.id) || ($0.userA == profile.id && $0.userB == me))
            }) {
                // Une demande en cours : son titre remplace le nom de la prestation affiché.
                if !serviceLabel.isEmpty {
                    _ = try? await supabase
                        .from("connections")
                        .update(ServiceLabelPatch(serviceLabel: String(serviceLabel.prefix(200))))
                        .eq("id", value: connection.id)
                        .execute()
                }
                await sendDetails(details, connectionId: connection.id, senderId: me)
                router.openConversation(connection.id)
                return
            }
            let created: [Connection] = try await supabase
                .from("connections")
                .insert(ApplicationConnection(userA: me, userB: profile.id, serviceLabel: String(serviceLabel.prefix(200)), status: "pending", missionRequestId: nil))
                .select()
                .execute()
                .value
            if let connection = created.first {
                await sendDetails(details, connectionId: connection.id, senderId: me)
                router.openConversation(connection.id)
            }
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            message = "Impossible d’ouvrir la conversation pour le moment."
        }
    }

    /// Envoie les détails de la demande comme premier message, s'il y en a.
    private func sendDetails(_ details: String?, connectionId: String, senderId: String) async {
        guard let details, !details.isEmpty else { return }
        _ = try? await supabase
            .from("messages")
            .insert(NewMessage(connectionId: connectionId, senderId: senderId, body: details))
            .execute()
    }

    private var professionalDetails: some View {
        CardSection(title: "Informations professionnelles", systemImage: "building.2.fill") {
            VStack(alignment: .leading, spacing: 12) {
                if let company = profile.companyName, !company.isEmpty {
                    detailLine("building.2.fill", "Société", company)
                }
                if let description = profile.companyDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(0.85))
                }
                if let hours = profile.openingHours, !hours.isEmpty {
                    detailLine("clock.fill", "Horaires", hours)
                }
                if let phone = profile.phone, !phone.isEmpty {
                    if let url = URL(string: "tel:\(phone.filter(\.isNumber))") {
                        Link(destination: url) {
                            detailLine("phone.fill", "Téléphone", phone)
                        }
                    }
                }
                if let website = profile.websiteUrl, !website.isEmpty,
                   let url = URL(string: website.hasPrefix("http") ? website : "https://\(website)") {
                    Link(destination: url) {
                        detailLine("globe", "Site web", website)
                    }
                }
            }
        }
    }

    /// Services et tarifs proposés, pour les comptes pro comme pour les membres particuliers.
    @ViewBuilder
    private var servicesCard: some View {
        if let services = profile.proServices, !services.isEmpty {
            CardSection(title: "Services et tarifs", systemImage: "tag.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(services, id: \.label) { service in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                            Text(service.label).font(.subheadline.weight(.semibold))
                            Spacer()
                            if !service.price.isEmpty {
                                Text(ProServiceItem.formatPrice(service.price)).font(.caption.weight(.bold)).foregroundStyle(Theme.primary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var personalDetails: some View {
        CardSection(title: "Informations du profil", systemImage: "person.text.rectangle") {
            VStack(alignment: .leading, spacing: 12) {
                if let civilite = profile.civilite, !civilite.isEmpty { detailLine("person.fill", "Civilité", civilite) }
                if let pronouns = profile.pronouns, !pronouns.isEmpty { detailLine("person.crop.circle", "Pronoms", pronouns) }
                if let city = profile.city, !city.isEmpty { detailLine("mappin.and.ellipse", "Ville", city) }
                if let zone = profile.interventionZone, !zone.isEmpty { detailLine("location.fill", "Zone", zone) }
            }
        }
    }

    private func detailLine(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.primary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.muted)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    private var reportSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $reportReason)
                        .frame(minHeight: 140)
                } header: {
                    Text("Raison du signalement")
                } footer: {
                    Text("Notre équipe examinera ce signalement.")
                }
            }
            .brandScreen()
            .navigationTitle("Signaler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showReport = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") { Task { await report() } }
                        .disabled(reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Données

    private func load() async {
        if DemoMode.isOn { return }
        guard let me = session.userId else { return }
        do {
            async let badgeRows: [ProfileBadgeRow] = supabase
                .from("profile_badges")
                .select("badge:badges(*)")
                .eq("profile_id", value: profile.id)
                .execute()
                .value
            async let reviewRows: [ProfileReview] = supabase
                .from("reviews")
                .select("*, author:profiles!reviews_author_id_fkey(id, display_name, photo_url)")
                .eq("target_id", value: profile.id)
                .order("created_at", ascending: false)
                .execute()
                .value
            async let blockRows: [BlockRow] = supabase
                .from("blocked_users")
                .select("blocker_id, blocked_id")
                .eq("blocker_id", value: me)
                .eq("blocked_id", value: profile.id)
                .execute()
                .value

            badges = try await badgeRows.compactMap(\.badge)
            reviews = try await reviewRows
            isBlocked = !(try await blockRows).isEmpty
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            message = error.localizedDescription
        }
    }

    private func block() async {
        guard let me = session.userId else { return }
        busy = true
        defer { busy = false }
        do {
            try await supabase
                .from("blocked_users")
                .insert(BlockInsert(blockerId: me, blockedId: profile.id))
                .execute()
            isBlocked = true
            message = "Membre bloqué."
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            message = error.localizedDescription
        }
    }

    private func unblock() async {
        guard let me = session.userId else { return }
        busy = true
        defer { busy = false }
        do {
            try await supabase
                .from("blocked_users")
                .delete()
                .eq("blocker_id", value: me)
                .eq("blocked_id", value: profile.id)
                .execute()
            isBlocked = false
            message = "Membre débloqué."
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            message = error.localizedDescription
        }
    }

    private func report() async {
        guard let me = session.userId else { return }
        busy = true
        defer { busy = false }
        do {
            try await supabase
                .from("reports")
                .insert(ReportInsert(
                    reporterId: me,
                    targetType: "profile",
                    targetId: profile.id,
                    reason: reportReason.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
                .execute()
            reportReason = ""
            showReport = false
            message = "Signalement envoyé. Merci."
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            message = error.localizedDescription
        }
    }
}

private struct ReviewRow: View {
    let review: ProfileReview

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(name: review.author?.displayName ?? "", photoUrl: review.author?.photoUrl, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(review.author?.displayName ?? "Membre")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    StarsLabel(rating: review.rating)
                }
                if let comment = review.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(0.85))
                }
                Text(DateText.relative(review.createdAt))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}
