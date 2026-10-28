import SwiftUI

struct PlacesView: View {
    @State private var places: [Place] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var showAdd = false
    @State private var search = ""

    private var filtered: [Place] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return places }
        return places.filter {
            $0.name.lowercased().contains(q) || ($0.city?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        List {
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Theme.rose) }
            }
            ForEach(filtered) { place in
                NavigationLink(value: place) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name).font(.headline).foregroundStyle(Theme.ink)
                        if let address = place.address ?? place.city {
                            Label(address, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .overlay {
            if loading {
                ProgressView()
            } else if filtered.isEmpty {
                ContentUnavailableView(
                    "Aucun lieu pour l'instant",
                    systemImage: "building.2",
                    description: Text("Ajoute un lieu solidaire ou accueillant pour la communauté.")
                )
            }
        }
        .searchable(text: $search, prompt: "Nom, ville")
        .brandScreen()
        .navigationTitle("Lieux")
        .brandTopLogo()
        .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddPlaceView { Task { await load() } }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        defer { loading = false }
        do {
            places = try await supabase
                .from("places")
                .select("*, submitter:profiles!places_submitted_by_fkey(id, display_name, photo_url)")
                .eq("status", value: "approved")
                .order("created_at", ascending: false)
                .execute()
                .value
            errorMessage = nil
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct PlaceDetailView: View {
    @EnvironmentObject private var session: SessionStore

    let place: Place

    @State private var reviews: [PlaceReview] = []
    @State private var rating = 5
    @State private var comment = ""
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(place.name).font(.title2.bold()).foregroundStyle(Theme.ink)
                    if let address = place.address, !address.isEmpty {
                        Label(address, systemImage: "mappin.and.ellipse").foregroundStyle(Theme.muted)
                    }
                    if let city = place.city, !city.isEmpty {
                        Label(city, systemImage: "building.2").foregroundStyle(Theme.muted)
                    }
                    if let submitter = place.submitter?.displayName {
                        Text("Ajouté par \(submitter)").font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.vertical, 4)
            }

            if let description = place.description, !description.isEmpty {
                Section("Description") { Text(description) }
            }

            Section("Avis") {
                if reviews.isEmpty {
                    Text("Aucun avis pour le moment.").foregroundStyle(Theme.muted)
                }
                ForEach(reviews) { review in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(review.author?.displayName ?? "Membre").font(.subheadline.bold())
                            Spacer()
                            Text(String(repeating: "★", count: review.rating)).foregroundStyle(Theme.amber)
                        }
                        if let comment = review.comment, !comment.isEmpty {
                            Text(comment).font(.subheadline)
                        }
                    }
                }
            }

            if session.userId != nil {
                Section("Laisser un avis") {
                    Stepper("Note : \(rating) / 5", value: $rating, in: 1...5)
                    TextField("Commentaire (facultatif)", text: $comment, axis: .vertical)
                        .lineLimit(2...5)
                    Button("Publier mon avis") { Task { await submitReview() } }
                        .disabled(busy)
                }
            }

            if let message {
                Section { Text(message).foregroundStyle(Theme.primary) }
            }
        }
        .brandScreen()
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadReviews() }
    }

    private func loadReviews() async {
        do {
            reviews = try await supabase
                .from("place_reviews")
                .select("*, author:profiles!place_reviews_author_id_fkey(id, display_name, photo_url)")
                .eq("place_id", value: place.id)
                .eq("status", value: "approved")
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            message = error.localizedDescription
        }
    }

    private func submitReview() async {
        guard let me = session.userId else { return }
        busy = true
        defer { busy = false }
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await supabase
                .from("place_reviews")
                .insert(PlaceReviewInsert(
                    placeId: place.id,
                    authorId: me,
                    rating: rating,
                    comment: trimmed.isEmpty ? nil : trimmed
                ))
                .execute()
            comment = ""
            message = "Merci ! Ton avis sera visible après validation."
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            message = error.localizedDescription
        }
    }
}

struct AddPlaceView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    var onAdded: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var address = ""
    @State private var city = ""
    @State private var subcategoryId = ""
    @State private var subcategories: [Subcategory] = []
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Lieu") {
                    TextField("Nom du lieu", text: $name)
                    TextField("Adresse", text: $address)
                    TextField("Ville", text: $city)
                    Picker("Catégorie", selection: $subcategoryId) {
                        Text("Non renseignée").tag("")
                        ForEach(subcategories) { Text($0.label).tag($0.id) }
                    }
                }
                Section("Description") {
                    TextEditor(text: $description).frame(minHeight: 120)
                }
                Section {
                    Text("Ton lieu sera publié après validation par l'équipe.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Theme.rose) }
                }
            }
            .brandScreen()
            .navigationTitle("Ajouter un lieu")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                subcategories = (try? await supabase
                    .from("subcategories")
                    .select()
                    .order("sort_order")
                    .execute()
                    .value) ?? []
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") { Task { await submit() } }
                        .bold()
                        .disabled(saving || name.trimmingCharacters(in: .whitespaces).count < 2)
                }
            }
        }
    }

    private func submit() async {
        guard let me = session.userId else { return }
        saving = true
        defer { saving = false }
        func trimmed(_ value: String) -> String? {
            let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        do {
            try await supabase
                .from("places")
                .insert(PlaceInsert(
                    submittedBy: me,
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: trimmed(description),
                    address: trimmed(address),
                    city: trimmed(city),
                    subcategoryId: subcategoryId.isEmpty ? nil : subcategoryId
                ))
                .execute()
            onAdded()
            dismiss()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
