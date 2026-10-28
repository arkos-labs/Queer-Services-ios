import Supabase
import SwiftUI

/// Création du profil après l'inscription : même parcours que OnboardingPage.tsx côté web.
/// Particulier·e : rôle → communauté → identité → services → charte.
/// Professionnel·le : rôle → entreprise → communauté → charte.
struct OnboardingView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var router: TabRouter

    private enum AccountKind: String {
        case particulier, pro
    }

    private enum Intent: Hashable {
        case seeking, offering
    }

    private enum StepKey {
        case role, structure, community, identity, services, charte
    }

    struct ProServiceRow: Identifiable, Hashable {
        let id = UUID()
        var subcategoryId: String?
        var label = ""
        var price = ""
        var other = false
    }

    private struct StripeLink: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var step = 0
    @State private var accountType: AccountKind?
    @State private var displayName = ""
    @State private var city = ""
    @State private var civilite: String?
    @State private var isCommunityMember: Bool?
    @State private var isAlly = false
    @State private var showAllyCharter = false
    @State private var intents: Set<Intent> = []
    @State private var noneSelected = false
    @State private var categories: [Category] = []
    @State private var subcategories: [Subcategory] = []
    @State private var selectedSubIds: Set<String> = []
    @State private var offerItems: [ServiceChoice] = []
    @State private var seekItems: [ServiceChoice] = []
    @State private var proServices: [ProServiceRow] = [ProServiceRow()]
    @State private var companyName = ""
    @State private var companyDescription = ""
    @State private var siret = ""
    @State private var websiteUrl = ""
    @State private var openingHours = ""
    @State private var interventionZone = ""
    @State private var charteAccepted = false
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var stripeLink: StripeLink?
    @State private var savedProfile: Profile?

    private var isPro: Bool { accountType == .pro }

    /// Le choix Particulier / Professionnel passe en premier ; les pros ont une étape « entreprise » en plus.
    private var stepKeys: [StepKey] {
        isPro ? [.role, .structure, .community, .charte] : [.role, .community, .identity, .services, .charte]
    }

    private var stepKey: StepKey { stepKeys[min(step, stepKeys.count - 1)] }
    private var isLastStep: Bool { step >= stepKeys.count - 1 }

    /// Qui propose des services vérifie son identité avec Stripe à l'inscription.
    private var offersServices: Bool { isPro || intents.contains(.offering) }

    private var siretDigits: String { siret.filter { !$0.isWhitespace } }

    private var canProceed: Bool {
        switch stepKey {
        case .role:
            return accountType != nil
        case .community:
            return isCommunityMember == true || isAlly
        case .structure:
            return !companyName.trimmed.isEmpty
                && !city.trimmed.isEmpty
                && proServices.contains { !$0.label.trimmed.isEmpty }
                && (siretDigits.isEmpty || (siretDigits.count == 14 && siretDigits.allSatisfy(\.isNumber)))
        case .identity:
            return !displayName.trimmed.isEmpty && !city.trimmed.isEmpty && civilite != nil
        case .services:
            return noneSelected || (
                !intents.isEmpty
                    && (!intents.contains(.offering) || !offerItems.isEmpty)
                    && (!intents.contains(.seeking) || !seekItems.isEmpty)
            )
        case .charte:
            return charteAccepted
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        BrandHeaderLogo(size: 64)
                        Text("CRÉONS TON PROFIL")
                            .font(.caption.weight(.heavy))
                            .tracking(2)
                            .foregroundStyle(Theme.primary)
                        progress
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 18) {
                        stepContent
                            .id(stepKey)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .padding(.top, 6)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(alignment: .top) {
                        RainbowBar(height: 6)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Theme.primary.opacity(0.1), radius: 18, y: 8)

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.spring(duration: 0.4, bounce: 0.15), value: step)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .brandBackground()
            .safeAreaInset(edge: .bottom) { bottomBar }
            .toolbar {
                if step == 0 {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Se déconnecter") { Task { await session.signOut() } }
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showAllyCharter) { allyCharter }
        .sheet(item: $stripeLink, onDismiss: {
            if let savedProfile { complete(savedProfile) }
        }) { link in
            SafariView(url: link.url).ignoresSafeArea()
        }
        .task { await loadTaxonomy() }
        .onAppear {
            // Nom donné par Apple ou Google à la connexion : on le propose d'office.
            if displayName.isEmpty, let suggested = session.suggestedName { displayName = suggested }
        }
        .sensoryFeedback(.selection, trigger: step)
    }

    // MARK: Progression et navigation

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(stepKeys.indices, id: \.self) { index in
                Capsule()
                    .fill(index == step
                          ? AnyShapeStyle(LinearGradient(colors: Theme.rainbow, startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(index < step ? Theme.primary.opacity(0.8) : Theme.primary.opacity(0.15)))
                    .frame(width: index == step ? 40 : 28, height: 8)
            }
        }
        .animation(.spring(duration: 0.35), value: step)
        .accessibilityElement()
        .accessibilityLabel("Étape \(step + 1) sur \(stepKeys.count)")
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button {
                    errorMessage = nil
                    step -= 1
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryDeep)
                        .frame(width: 52, height: 52)
                        .glassCapsule()
                }
                .buttonStyle(BrandPressStyle())
                .accessibilityLabel("Retour")
            }

            Button {
                if isLastStep {
                    Task { await finish() }
                } else {
                    errorMessage = nil
                    step += 1
                }
            } label: {
                GradientCapsuleLabel(
                    title: isLastStep ? (loading ? "Enregistrement…" : "Finaliser mon inscription") : "Continuer",
                    systemImage: isLastStep ? "checkmark" : "arrow.right",
                    busy: loading
                )
                .opacity(canProceed ? 1 : 0.5)
            }
            .buttonStyle(BrandPressStyle())
            .disabled(!canProceed || loading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: Étapes

    @ViewBuilder
    private var stepContent: some View {
        switch stepKey {
        case .role: roleStep
        case .structure: structureStep
        case .community: communityStep
        case .identity: identityStep
        case .services: servicesStep
        case .charte: charteStep
        }
    }

    private var roleStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(systemImage: "heart.fill", title: "Vous êtes…", subtitle: "Tu pourras toujours modifier cela plus tard.")
            SelectCard(emoji: "🤝", title: "Particulier·e",
                       text: "Je propose et/ou je cherche des services entre membres.",
                       selected: accountType == .particulier) { selectAccount(.particulier) }
            SelectCard(emoji: "💼", title: "Professionnel·le",
                       text: "Entreprise, professionnel·le ou centre de santé.",
                       selected: accountType == .pro) { selectAccount(.pro) }
        }
    }

    private func selectAccount(_ kind: AccountKind) {
        accountType = kind
    }

    private var structureStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(systemImage: "building.2.fill", title: "Votre entreprise",
                       subtitle: "Le nom et la ville sont requis, le reste est facultatif et modifiable plus tard.")
            LabeledInput(label: "Nom de l'entreprise *") {
                TextField("", text: $companyName).textContentType(.organizationName)
            }
            LabeledInput(label: "Ville *") {
                TextField("", text: $city).textContentType(.addressCity)
            }
            LabeledInput(label: "Présentation de l'activité") {
                TextField("", text: $companyDescription, axis: .vertical).lineLimit(3...8)
            }
            LabeledInput(label: "SIRET (14 chiffres, facultatif)",
                         hint: !siretDigits.isEmpty && siretDigits.count != 14 ? "Le SIRET doit contenir 14 chiffres." : nil) {
                TextField("", text: $siret).keyboardType(.numberPad)
            }
            LabeledInput(label: "Site web") {
                TextField("https://", text: $websiteUrl)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            LabeledInput(label: "Horaires") {
                TextField("Ex. Lun–ven 9h–18h", text: $openingHours)
            }
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Services proposés *")
                proServicesEditor
            }
            LabeledInput(label: "Zone d'intervention") {
                TextField("Ex. Paris et petite couronne", text: $interventionZone)
            }
        }
    }

    /// Un service par ligne : choix dans l'annuaire (ou « Autre » en texte libre) + tarif facultatif.
    private var proServicesEditor: some View {
        VStack(spacing: 10) {
            ForEach($proServices) { $row in
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(categories) { category in
                                let subs = subcategories.filter { $0.categoryId == category.id }
                                if !subs.isEmpty {
                                    Section(category.label) {
                                        ForEach(subs) { sub in
                                            Button(sub.label) {
                                                row.subcategoryId = sub.id
                                                row.label = sub.label
                                                row.other = false
                                            }
                                        }
                                    }
                                }
                            }
                            Divider()
                            Button("Autre service…") {
                                row.subcategoryId = nil
                                row.label = ""
                                row.other = true
                            }
                        } label: {
                            HStack {
                                Text(row.other ? "Autre service" : (row.label.isEmpty ? "Choisir un service…" : row.label))
                                    .foregroundStyle(row.label.isEmpty && !row.other ? Theme.muted : Theme.ink)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.primary)
                            }
                            .inputStyle()
                        }

                        Button {
                            proServices.removeAll { $0.id == row.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Theme.muted)
                                .frame(width: 44, height: 44)
                                .background(Color(hex: 0xF8F7FC), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Supprimer ce service")
                    }
                    if row.other {
                        TextField("Nom du service", text: $row.label).inputStyle()
                    }
                    TextField("Tarif (facultatif) — ex. 40 € / heure", text: $row.price).inputStyle()
                }
                .padding(12)
                .background(Theme.primarySoft.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Button {
                proServices.append(ProServiceRow())
            } label: {
                Label("Ajouter un service", systemImage: "plus")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(Capsule().stroke(Theme.primary.opacity(0.35), lineWidth: 1.5))
            }
            .buttonStyle(BrandPressStyle())
        }
    }

    private var communityStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(systemImage: "heart.fill", title: "Appartenance à la communauté",
                       subtitle: "Cette plateforme est d'abord pensée pour la communauté LGBTQIA+.")
            FieldLabel("Es-tu membre de la communauté LGBTQIA+ ?")
            HStack(spacing: 10) {
                ChoiceButton(title: "Oui", selected: isCommunityMember == true) {
                    isCommunityMember = true
                    isAlly = false
                }
                ChoiceButton(title: "Non", selected: isCommunityMember == false) {
                    isCommunityMember = false
                }
            }
            if isCommunityMember == false {
                Button {
                    if isAlly { isAlly = false } else { showAllyCharter = true }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isAlly ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundStyle(isAlly ? Theme.primary : Theme.muted)
                        Text("Je suis un·e allié·e (Gay Friendly)")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                    }
                    .padding(16)
                    .background(isAlly ? Theme.primarySoft.opacity(0.6) : Color(hex: 0xF8F7FC),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.3), value: isCommunityMember)
    }

    private var allyCharter: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Charte des allié·es")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.ink)
            Text("En tant qu'allié·e sur cette plateforme communautaire, vous vous engagez à :")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(OnboardingTexts.allyPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.pink)
                            .padding(.top, 3)
                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button {
                    showAllyCharter = false
                    isAlly = false
                } label: {
                    Text("Annuler")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.primaryDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.primarySoft, in: Capsule())
                }
                Button {
                    showAllyCharter = false
                    isAlly = true
                } label: {
                    GradientCapsuleLabel(title: "J'accepte")
                }
            }
            .buttonStyle(BrandPressStyle())
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(systemImage: "person.fill", title: "Bienvenue, qui es-tu ?",
                       subtitle: "Choisis ton nom d'affichage et ta civilité.")
            LabeledInput(label: "Nom affiché publiquement") {
                TextField("Ex. Alex Martin", text: $displayName).textContentType(.name)
            }
            LabeledInput(label: "Dans quelle ville ou région êtes-vous ?") {
                TextField("Ex. Paris, Île-de-France, ou À distance", text: $city).textContentType(.addressCity)
            }
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel("Civilité")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(OnboardingTexts.civilites, id: \.self) { value in
                        ChoiceButton(title: value, selected: civilite == value) { civilite = value }
                    }
                }
            }
        }
    }

    private var servicesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepHeader(systemImage: "magnifyingglass", title: "Que viens-tu faire ici ?",
                       subtitle: "Ça nous aide à personnaliser ton profil. Modifiable à tout moment. Plusieurs choix possibles.")
            SelectCard(symbol: "magnifyingglass", title: "Je cherche un service",
                       text: "J'ai besoin d'aide pour quelque chose.", selected: intents.contains(.seeking)) {
                toggleIntent(.seeking)
            }
            SelectCard(symbol: "hand.raised.fill", title: "Je propose un service",
                       text: "J'ai des compétences à offrir à la communauté.", selected: intents.contains(.offering)) {
                toggleIntent(.offering)
            }
            SelectCard(symbol: "safari.fill", title: "Aucun des deux",
                       text: "Je préfère explorer avant de me décider.", selected: noneSelected) {
                intents = []
                noneSelected = true
            }

            if intents.contains(.offering) {
                ServicePicker(
                    title: "Services que tu proposes",
                    subtitle: "Choisis dans la liste, puis indique ton tarif si tu veux.",
                    categories: categories,
                    subcategories: subcategories,
                    items: $offerItems,
                    tint: Theme.primary
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if intents.contains(.seeking) {
                ServicePicker(
                    title: "Services que tu recherches",
                    subtitle: "Choisis dans la liste ce dont tu as besoin, avec un budget si tu veux.",
                    categories: categories,
                    subcategories: subcategories,
                    items: $seekItems,
                    tint: Theme.pink
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.3), value: intents)
    }

    private func toggleIntent(_ intent: Intent) {
        noneSelected = false
        if intents.contains(intent) { intents.remove(intent) } else { intents.insert(intent) }
    }

    private var charteStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(systemImage: "checkmark.shield.fill", title: "Charte de respect",
                       subtitle: "L'acceptation de la charte conditionne l'accès à la messagerie et aux échanges.")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(OnboardingTexts.chartePoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Theme.rainbow[index % Theme.rainbow.count], in: Circle())
                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            .background(Color(hex: 0xF8F7FC), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
                charteAccepted.toggle()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: charteAccepted ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(charteAccepted ? Theme.primary : Theme.muted)
                    Text("J'ai lu et j'accepte la charte de respect de Queer Service.")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(charteAccepted ? Theme.primarySoft.opacity(0.6) : .white,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(charteAccepted ? Theme.primary : Theme.primary.opacity(0.15), lineWidth: charteAccepted ? 2 : 1)
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: charteAccepted) { _, accepted in accepted }

            if offersServices {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Theme.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dernière étape : vérification pour recevoir vos paiements.")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.ink)
                        Text("Pour proposer des services, vous allez être redirigé·e vers Stripe (environ 5 minutes) pour vérifier votre identité et votre compte bancaire. C'est ce qui permet de vous verser vos gains directement et de protéger la communauté.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(16)
                .background(Theme.primarySoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: Données

    private func loadTaxonomy() async {
        if categories.isEmpty {
            let bundled = ReferenceCatalog.load()
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
    }

    /// Même enregistrement que finishOnboarding côté web, puis vérification Stripe pour qui propose des services.
    private func finish() async {
        guard let me = session.userId else { return }
        loading = true
        errorMessage = nil
        defer { loading = false }

        // Sans session valide, la base refuserait la requête avec une erreur de sécurité peu claire.
        guard (try? await supabase.auth.session) != nil else {
            withAnimation { errorMessage = "Ta session a expiré. Reconnecte-toi, puis finalise ton inscription." }
            return
        }

        var finalWebsite: String?
        if isPro, !websiteUrl.trimmed.isEmpty {
            let raw = websiteUrl.trimmed
            let candidate = raw.lowercased().hasPrefix("http") ? raw : "https://\(raw)"
            guard let url = URL(string: candidate), url.scheme == "https", url.host != nil else {
                withAnimation { errorMessage = "Le site web doit être un lien HTTPS valide." }
                return
            }
            finalWebsite = url.absoluteString
        }

        let cleanedServices = proServices
            .filter { !$0.label.trimmed.isEmpty }
            .map { ProServiceItem(subcategoryId: $0.subcategoryId, label: $0.label.trimmed, price: $0.price.trimmed) }
        // Particulier·e : services proposés ou recherchés, avec leur tarif (stockés dans pro_services).
        let memberItems = offerItems + seekItems.filter { item in !offerItems.contains { $0.id == item.id } }
        let memberServices = memberItems.map {
            ProServiceItem(subcategoryId: $0.id, label: $0.label, price: $0.price.trimmed)
        }

        let upsert = OnboardingUpsert(
            id: me,
            displayName: isPro ? companyName.trimmed : displayName.trimmed,
            email: session.email,
            civilite: isPro ? nil : civilite,
            city: city.trimmed.nilIfEmpty,
            accountType: (accountType ?? .particulier).rawValue,
            companyName: isPro ? companyName.trimmed.nilIfEmpty : nil,
            companyDescription: isPro ? companyDescription.trimmed.nilIfEmpty : nil,
            siret: isPro ? siretDigits.nilIfEmpty : nil,
            websiteUrl: finalWebsite,
            openingHours: isPro ? openingHours.trimmed.nilIfEmpty : nil,
            interventionZone: isPro ? interventionZone.trimmed.nilIfEmpty : nil,
            skills: isPro ? Array(NSOrderedSet(array: cleanedServices.map(\.label))) as? [String] ?? [] : offerItems.map(\.label),
            needs: isPro ? [] : seekItems.map(\.label),
            proServices: isPro ? cleanedServices : memberServices,
            isCommunityMember: isCommunityMember,
            isAlly: isAlly,
            charteAcceptedAt: ISO8601DateFormatter().string(from: Date())
        )

        do {
            let rows: [Profile] = try await supabase
                .from("profiles")
                .upsert(upsert)
                .select()
                .execute()
                .value
            guard let saved = rows.first else {
                withAnimation { errorMessage = "Le profil n'a pas pu être enregistré. Réessaie." }
                return
            }

            let subIds = isPro ? Set(cleanedServices.compactMap(\.subcategoryId)) : Set(offerItems.map(\.id))
            if !subIds.isEmpty {
                try await supabase
                    .from("profile_subcategories")
                    .insert(subIds.map { ProfileSubcategoryInsert(profileId: me, subcategoryId: $0) })
                    .execute()
            }
            // Garde la preuve que le code e-mail a été saisi (session d'inscription).
            _ = try? await supabase.rpc("mark_email_code_verified").execute()

            if offersServices, let url = await stripeOnboardingURL() {
                savedProfile = saved
                stripeLink = StripeLink(url: url)
                return
            }
            // Pas de lien Stripe : l'inscription est faite, la vérification pourra se faire plus tard.
            complete(saved)
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            withAnimation { errorMessage = error.localizedDescription }
        }
    }

    /// Lien de vérification Stripe (même fonction que le site). Retour sur la page Réglages du site.
    private func stripeOnboardingURL() async -> URL? {
        func returnURL(_ path: String) -> String {
            let encoded = path.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? path
            return "https://www.queerservices.fr/retour-app?to=\(encoded)"
        }
        guard let response = try? await Edge.call(
            "stripe-connect-onboarding",
            EdgeBody(returnUrl: returnURL("/parametres?stripe=return"), refreshUrl: returnURL("/parametres?stripe=refresh"))
        ), let link = response.url else { return nil }
        return URL(string: link)
    }

    /// Profil publié : l'onboarding se ferme et l'app s'ouvre sur l'annuaire.
    private func complete(_ profile: Profile) {
        router.selected = .home
        session.adopt(profile)
    }
}

// MARK: - Composants

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension View {
    func inputStyle() -> some View {
        self
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xF8F7FC), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.primary.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct StepHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(
                    LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: Theme.primary.opacity(0.3), radius: 10, y: 4)
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.ink)
    }
}

private struct LabeledInput<Content: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(label)
            content.inputStyle()
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Theme.rose)
            }
        }
    }
}

/// Carte de choix (rôle, intention), cochée quand elle est sélectionnée.
private struct SelectCard: View {
    var emoji: String?
    var symbol: String?
    let title: String
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Group {
                    if let emoji {
                        Text(emoji).font(.title2)
                    } else if let symbol {
                        Image(systemName: symbol)
                            .font(.title3)
                            .foregroundStyle(Theme.primary)
                    }
                }
                .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.primary : Theme.muted.opacity(0.4))
            }
            .padding(16)
            .background(selected ? Theme.primarySoft.opacity(0.6) : Color(hex: 0xF8F7FC),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Theme.primary : Theme.primary.opacity(0.1), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(BrandPressStyle())
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ChoiceButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(selected ? Theme.primaryDeep : Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? Theme.primarySoft.opacity(0.7) : Color(hex: 0xF8F7FC),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(selected ? Theme.primary : Theme.primary.opacity(0.12), lineWidth: selected ? 2 : 1)
                )
        }
        .buttonStyle(BrandPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Un service choisi dans l'annuaire, avec son tarif facultatif.
struct ServiceChoice: Identifiable, Hashable {
    let id: String
    let label: String
    var price: String
}

/// Choix des prestations uniquement dans la liste de l'annuaire (catégorie → sous-catégorie), tarif par service.
private struct ServicePicker: View {
    let title: String
    let subtitle: String
    let categories: [Category]
    let subcategories: [Subcategory]
    @Binding var items: [ServiceChoice]
    let tint: Color

    /// Une seule catégorie ouverte à la fois : la liste reste courte.
    @State private var openCategory: String?

    private var openServices: [Subcategory] {
        guard let openCategory else { return [] }
        return subcategories.filter { $0.categoryId == openCategory }
    }

    private func count(in category: Category) -> Int {
        let ids = Set(subcategories.filter { $0.categoryId == category.id }.map(\.id))
        return items.filter { ids.contains($0.id) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                FieldLabel(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            // 1. Les catégories, en une seule rangée défilante.
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        CategoryTile(
                            category: category,
                            color: Theme.rainbow[index % Theme.rainbow.count],
                            selectedCount: count(in: category),
                            open: openCategory == category.id
                        ) {
                            withAnimation(.spring(duration: 0.3)) {
                                openCategory = openCategory == category.id ? nil : category.id
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .contentMargins(.horizontal, 2, for: .scrollContent)
            .scrollIndicators(.hidden)

            // 2. Les services de la catégorie ouverte uniquement.
            if openCategory != nil {
                FlowLayout(spacing: 6) {
                    ForEach(openServices) { service in
                        let active = items.contains { $0.id == service.id }
                        Button {
                            toggle(service, active: active)
                        } label: {
                            HStack(spacing: 4) {
                                if active {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                }
                                Text(service.label)
                            }
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(active ? .white : Theme.ink.opacity(0.75))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(active ? tint : .white, in: Capsule())
                            .overlay(Capsule().stroke(active ? tint : Theme.primary.opacity(0.15), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(active ? .isSelected : [])
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if items.isEmpty {
                Text("Touche une catégorie pour voir ses services.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            // 3. Ton choix, avec le tarif facultatif de chaque service.
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("Ton choix (\(items.count))")
                    ForEach($items) { $item in
                        HStack(spacing: 10) {
                            Text(item.label)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            TextField("Tarif ex. 40 € / h", text: $item.price)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.subheadline, design: .rounded))
                                .frame(maxWidth: 140)
                                .accessibilityLabel("Tarif de \(item.label)")
                            Button {
                                items.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.muted.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Retirer \(item.label)")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(tint.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(tint.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.spring(duration: 0.3), value: items.count)
    }

    private func toggle(_ service: Subcategory, active: Bool) {
        if active {
            items.removeAll { $0.id == service.id }
        } else {
            items.append(ServiceChoice(id: service.id, label: service.label, price: ""))
        }
    }
}

/// Carte de catégorie compacte : icône, nom, et nombre de services choisis dedans.
private struct CategoryTile: View {
    let category: Category
    let color: Color
    let selectedCount: Int
    let open: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: category.sfSymbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer(minLength: 0)
                    if selectedCount > 0 {
                        Text("\(selectedCount)")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Theme.ink, in: Capsule())
                    }
                }
                Text(category.label)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 120, alignment: .leading)
            }
            .padding(12)
            .frame(width: 144, alignment: .leading)
            .background(open ? color.opacity(0.15) : .white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(open ? color : Theme.primary.opacity(0.12), lineWidth: open ? 2 : 1)
            )
        }
        .buttonStyle(BrandPressStyle())
        .accessibilityAddTraits(open ? .isSelected : [])
    }
}
