import SwiftUI
import PhotosUI
import Storage
import UIKit

/// Tarifs des compétences, stockés dans `profiles.pro_services`.
struct ProServicesPatch: Encodable {
    let proServices: [ProServiceItem]

    enum CodingKeys: String, CodingKey {
        case proServices = "pro_services"
    }
}

/// Mise à jour complète du profil. Les champs vides sont envoyés en `null`, comme côté web.
struct ProfileFullPatch: Encodable {
    let displayName: String
    let civilite: String?
    let pronouns: String?
    let phone: String?
    let city: String?
    let bio: String?
    let photoUrl: String?
    let accountType: String
    let linkedinUrl: String?
    let interventionZone: String?
    let companyName: String?
    let companyDescription: String?
    let websiteUrl: String?
    let openingHours: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case civilite, pronouns, phone, city, bio
        case displayName = "display_name"
        case photoUrl = "photo_url"
        case accountType = "account_type"
        case linkedinUrl = "linkedin_url"
        case interventionZone = "intervention_zone"
        case companyName = "company_name"
        case companyDescription = "company_description"
        case websiteUrl = "website_url"
        case openingHours = "opening_hours"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(civilite, forKey: .civilite)
        try c.encode(pronouns, forKey: .pronouns)
        try c.encode(phone, forKey: .phone)
        try c.encode(city, forKey: .city)
        try c.encode(bio, forKey: .bio)
        try c.encode(photoUrl, forKey: .photoUrl)
        try c.encode(accountType, forKey: .accountType)
        try c.encode(linkedinUrl, forKey: .linkedinUrl)
        try c.encode(interventionZone, forKey: .interventionZone)
        try c.encode(companyName, forKey: .companyName)
        try c.encode(companyDescription, forKey: .companyDescription)
        try c.encode(websiteUrl, forKey: .websiteUrl)
        try c.encode(openingHours, forKey: .openingHours)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

struct ProfileEditView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var accountType = "particulier"
    @State private var civilite = ""
    @State private var pronouns = ""
    @State private var phone = ""
    @State private var city = ""
    @State private var bio = ""
    @State private var linkedin = ""
    @State private var interventionZone = ""
    @State private var companyName = ""
    @State private var companyDescription = ""
    @State private var websiteUrl = ""
    @State private var openingHours = ""
    @State private var photoUrl: String?

    @State private var categories: [Category] = []
    @State private var subcategories: [Subcategory] = []
    @State private var selectedSubs: Set<String> = []
    /// Tarif facultatif de chaque compétence, par identifiant de sous-catégorie.
    @State private var prices: [String: String] = [:]

    @State private var pickedItem: PhotosPickerItem?
    @State private var uploadingPhoto = false
    @State private var saving = false
    @State private var errorMessage: String?

    private let civilites = ["Il", "Elle", "Iel", "Ielle", "Ne se prononce pas"]
    private var isPro: Bool { accountType == "pro" }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Avatar(name: isPro ? companyName : displayName, photoUrl: photoUrl, size: 90)
                        PhotosPicker(selection: $pickedItem, matching: .images) {
                            Label(uploadingPhoto ? "Envoi…" : "Changer la photo", systemImage: "photo")
                        }
                        .disabled(uploadingPhoto)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Picker("Type de compte", selection: $accountType) {
                    Text("Particulier").tag("particulier")
                    Text("Professionnel").tag("pro")
                }
            }

            if isPro {
                Section("Entreprise") {
                    TextField("Nom de l'entreprise", text: $companyName)
                    TextField("Description", text: $companyDescription, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("Site web", text: $websiteUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Horaires", text: $openingHours)
                    TextField("Zone d'intervention", text: $interventionZone)
                }
            } else {
                Section("Identité") {
                    TextField("Prénom ou pseudo", text: $displayName)
                        .textContentType(.nickname)
                    Picker("Civilité", selection: $civilite) {
                        Text("Non renseigné").tag("")
                        ForEach(civilites, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Pronoms", text: $pronouns)
                }
            }

            Section("Contact") {
                TextField("Ville", text: $city)
                    .textContentType(.addressCity)
                TextField("Téléphone", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                TextField("Lien LinkedIn", text: $linkedin)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }

            Section("À propos") {
                TextEditor(text: $bio)
                    .frame(minHeight: 120)
            }

            if !categories.isEmpty {
                Section {
                    ForEach(categories) { category in
                        DisclosureGroup(category.label) {
                            ForEach(subcategories.filter { $0.categoryId == category.id }) { sub in
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle(sub.label, isOn: Binding(
                                        get: { selectedSubs.contains(sub.id) },
                                        set: { on in
                                            if on { selectedSubs.insert(sub.id) } else { selectedSubs.remove(sub.id) }
                                        }
                                    ))
                                    if selectedSubs.contains(sub.id) {
                                        HStack(spacing: 6) {
                                            TextField("Tarif (facultatif) : 20", text: Binding(
                                                get: { prices[sub.id] ?? "" },
                                                set: { prices[sub.id] = $0 }
                                            ))
                                            .keyboardType(.decimalPad)
                                            .font(.subheadline)
                                            Text("€ / h")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Theme.muted)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Mes compétences")
                } footer: {
                    Text("Choisis les catégories qui décrivent ce que tu proposes ou recherches.")
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Theme.rose) }
            }
        }
        .brandScreen()
        .navigationTitle("Modifier mon profil")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: pickedItem) { _, item in
            Task { await uploadPhoto(item) }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") { Task { await save() } }
                    .bold()
                    .disabled(saving || uploadingPhoto || !canSave)
            }
        }
    }

    private var canSave: Bool {
        isPro ? companyName.trimmingCharacters(in: .whitespaces).count >= 2
              : displayName.trimmingCharacters(in: .whitespaces).count >= 2
    }

    private func load() async {
        guard let me = session.userId else { return }
        if categories.isEmpty {
            do {
                async let cats: [Category] = supabase.from("categories").select().order("sort_order").execute().value
                async let subs: [Subcategory] = supabase.from("subcategories").select().order("sort_order").execute().value
                async let links: [ProfileSubcategoryRow] = supabase
                    .from("profile_subcategories")
                    .select("profile_id, subcategory_id")
                    .eq("profile_id", value: me)
                    .execute()
                    .value
                categories = try await cats
                subcategories = try await subs
                selectedSubs = Set(try await links.map(\.subcategoryId))
            } catch {
                guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
                errorMessage = error.localizedDescription
            }
        }
        guard displayName.isEmpty, let profile = session.profile else { return }
        accountType = profile.accountType ?? "particulier"
        displayName = profile.displayName
        civilite = profile.civilite ?? ""
        pronouns = profile.pronouns ?? ""
        city = profile.city ?? ""
        bio = profile.bio ?? ""
        // Tarifs déjà enregistrés, par compétence (pro_services, identifiée par subcategory_id).
        prices = Dictionary((profile.proServices ?? []).compactMap { service in
            service.subcategoryId.map { ($0, service.price) }
        }, uniquingKeysWith: { first, _ in first })
        photoUrl = profile.photoUrl
        companyName = profile.companyName ?? ""
        companyDescription = profile.companyDescription ?? ""
        phone = profile.phone ?? ""
        linkedin = profile.linkedinUrl ?? ""
        interventionZone = profile.interventionZone ?? ""
        websiteUrl = profile.websiteUrl ?? ""
        openingHours = profile.openingHours ?? ""
    }

    /// Même règle que le web : image uniquement, 5 Mo maximum.
    private func uploadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let me = session.userId else { return }
        uploadingPhoto = true
        defer { uploadingPhoto = false }
        do {
            guard let rawData = try await item.loadTransferable(type: Data.self),
                  let normalizedData = UIImage(data: rawData)?.jpegData(compressionQuality: 0.88) else {
                errorMessage = "Cette image ne peut pas être utilisée. Choisis une photo ou une image standard."
                return
            }
            guard normalizedData.count <= 5 * 1024 * 1024 else {
                errorMessage = "Image trop lourde (5 Mo maximum)."
                return
            }
            let path = "\(me)/\(Int(Date().timeIntervalSince1970)).jpg"
            try await supabase.storage
                .from("avatars")
                .upload(path, data: normalizedData, options: FileOptions(contentType: "image/jpeg", upsert: true))
            // Le paramètre évite qu'un ancien avatar reste dans le cache du téléphone.
            let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path).absoluteString
                + "?v=\(Int(Date().timeIntervalSince1970))"
            photoUrl = publicURL
            // Enregistre immédiatement la photo : elle est visible sur Mon profil
            // même si l'utilisateur quitte l'écran avant de toucher Enregistrer.
            try await supabase
                .from("profiles")
                .update(["photo_url": publicURL])
                .eq("id", value: me)
                .execute()
            await session.refreshProfile()
            errorMessage = nil
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let me = session.userId else { return }
        saving = true
        defer { saving = false }

        func trimmed(_ value: String) -> String? {
            let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        do {
            try await supabase
                .from("profiles")
                .update(ProfileFullPatch(
                    displayName: isPro ? companyName.trimmingCharacters(in: .whitespaces) : displayName.trimmingCharacters(in: .whitespaces),
                    civilite: isPro ? nil : trimmed(civilite),
                    pronouns: isPro ? nil : trimmed(pronouns),
                    phone: trimmed(phone),
                    city: trimmed(city),
                    bio: trimmed(bio),
                    photoUrl: photoUrl,
                    accountType: accountType,
                    linkedinUrl: trimmed(linkedin),
                    interventionZone: isPro ? trimmed(interventionZone) : nil,
                    companyName: isPro ? trimmed(companyName) : nil,
                    companyDescription: isPro ? trimmed(companyDescription) : nil,
                    websiteUrl: isPro ? trimmed(websiteUrl) : nil,
                    openingHours: isPro ? trimmed(openingHours) : nil,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                ))
                .eq("id", value: me)
                .execute()

            // Synchronise les compétences : on remplace la liste complète.
            try await supabase
                .from("profile_subcategories")
                .delete()
                .eq("profile_id", value: me)
                .execute()
            if !selectedSubs.isEmpty {
                try await supabase
                    .from("profile_subcategories")
                    .insert(selectedSubs.map { ProfileSubcategoryInsert(profileId: me, subcategoryId: $0) })
                    .execute()
            }

            // Tarifs : une ligne par compétence cochée, avec son tarif facultatif.
            // Les services saisis librement (sans sous-catégorie, côté pro) sont conservés.
            let freeServices = (session.profile?.proServices ?? []).filter { $0.subcategoryId == nil }
            let skillServices = subcategories
                .filter { selectedSubs.contains($0.id) }
                .map { ProServiceItem(subcategoryId: $0.id, label: $0.label, price: ProServiceItem.formatPrice(prices[$0.id] ?? "")) }
            try await supabase
                .from("profiles")
                .update(ProServicesPatch(proServices: freeServices + skillServices))
                .eq("id", value: me)
                .execute()

            await session.refreshProfile()
            dismiss()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
