import SwiftUI

struct MissionsView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    /// Bouton « Fermer » quand l'écran est ouvert en feuille.
    var showsClose = false

    @State private var missions: [MissionRequest] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var showSignIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Text("Les demandes ouvertes par les membres, de la plus récente à la plus ancienne.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if loading {
                        SkeletonList()
                    } else if missions.isEmpty {
                        BrandEmptyState(
                            systemImage: "megaphone.fill",
                            title: "Aucune mission ouverte",
                            message: "Les demandes publiées par les membres apparaîtront ici."
                        )
                    } else {
                        ForEach(missions) { mission in
                            NavigationLink(value: mission) {
                                MissionCard(mission: mission)
                            }
                            .buttonStyle(BrandPressStyle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
            }
            .scrollIndicators(.hidden)
            .collapsingBrandHeader("Missions")
            .brandBackground()
            .navigationDestination(for: MissionRequest.self) { mission in
                MissionDetailView(mission: mission) { Task { await load() } }
            }
            .toolbar {
                if showsClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if session.userId == nil { showSignIn = true } else { showCreate = true }
                } label: {
                    GradientCapsuleLabel(title: "Publier une mission", systemImage: "plus")
                }
                .buttonStyle(BrandPressStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
            }
            .sheet(isPresented: $showCreate) {
                CreateMissionView { Task { await load() } }
            }
            .sheet(isPresented: $showSignIn) { SignInSheet() }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        defer { loading = false }
        if DemoMode.isOn { missions = DemoMode.missions; return }
        do {
            missions = try await supabase
                .from("mission_requests")
                .select("id, title, description, budget, created_at, created_by, profiles(display_name, photo_url)")
                .eq("status", value: "open")
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

private struct MissionCard: View {
    let mission: MissionRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Avatar(name: mission.author?.displayName ?? "", photoUrl: mission.author?.photoUrl, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(mission.author?.displayName ?? "Membre")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(DateText.relative(mission.createdAt))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                if let budget = mission.budget, !budget.isEmpty {
                    Text(budget)
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.primaryDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.primarySoft, in: Capsule())
                }
            }

            Text(mission.title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)

            Text(mission.description)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack {
                Text("Voir la mission")
                Image(systemName: "arrow.right")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(cornerRadius: 24)
    }
}

struct MissionDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let mission: MissionRequest
    /// Appelé après suppression de l'annonce, pour rafraîchir la liste.
    var onDeleted: () -> Void = {}

    @State private var showApply = false
    @State private var showSignIn = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var pitch = ""
    @State private var sending = false
    @State private var errorMessage: String?
    @State private var sent = false

    private var isMine: Bool { mission.createdBy == session.userId }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    if let budget = mission.budget, !budget.isEmpty {
                        Label(budget, systemImage: "eurosign.circle.fill")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                    Text(mission.title)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                    HStack(spacing: 10) {
                        Avatar(name: mission.author?.displayName ?? "", photoUrl: mission.author?.photoUrl, size: 32)
                            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
                        Text("Publié par \(mission.author?.displayName ?? "un membre") · \(DateText.relative(mission.createdAt))")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(BrandGradient())
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Theme.brandDeep.opacity(0.3), radius: 18, y: 8)

                CardSection(title: "Description", systemImage: "text.alignleft") {
                    Text(mission.description)
                        .font(.body)
                        .foregroundStyle(Theme.ink.opacity(0.85))
                }

                if sent {
                    Label("Candidature envoyée. Retrouve l'échange dans Messages.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x059669))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(hex: 0x059669).opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
            .animation(.spring(duration: 0.4), value: sent)
        }
        .scrollIndicators(.hidden)
        .brandBackground()
        .navigationTitle("Mission")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if isMine {
                // Comme sur le site : seul l'auteur peut retirer son annonce.
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label(deleting ? "Suppression…" : "Supprimer mon annonce", systemImage: "trash")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassCapsule()
                }
                .buttonStyle(BrandPressStyle())
                .disabled(deleting)
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
            } else if !sent {
                Button {
                    if session.userId == nil { showSignIn = true } else { showApply = true }
                } label: {
                    GradientCapsuleLabel(title: "Postuler", systemImage: "paperplane.fill")
                }
                .buttonStyle(BrandPressStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
            }
        }
        .alert("Supprimer cette annonce ?", isPresented: $confirmDelete) {
            Button("Supprimer", role: .destructive) { Task { await deleteMission() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est irréversible.")
        }
        .sheet(isPresented: $showApply) { applySheet }
        .sheet(isPresented: $showSignIn) { SignInSheet() }
        .sensoryFeedback(.success, trigger: sent)
    }

    private var applySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $pitch)
                        .frame(minHeight: 160)
                } header: {
                    Text("Ta présentation")
                } footer: {
                    Text("Le message sera envoyé à la personne qui a publié la mission.")
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Theme.rose) }
                }
            }
            .brandScreen()
            .navigationTitle("Postuler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showApply = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") { Task { await apply() } }
                        .disabled(sending || pitch.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Même effet que MissionDetailModal côté web : suppression de l'annonce par son auteur.
    private func deleteMission() async {
        deleting = true
        errorMessage = nil
        defer { deleting = false }
        do {
            try await supabase
                .from("mission_requests")
                .delete()
                .eq("id", value: mission.id)
                .execute()
            onDeleted()
            dismiss()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Même flux que le web : une conversation « en attente » liée à la mission, puis le message de candidature.
    private func apply() async {
        guard let me = session.userId else { return }
        sending = true
        defer { sending = false }
        do {
            let connections: [Connection] = try await supabase
                .from("connections")
                .insert(ApplicationConnection(
                    userA: me,
                    userB: mission.createdBy,
                    serviceLabel: String(mission.title.prefix(200)),
                    status: "pending",
                    missionRequestId: mission.id
                ))
                .select()
                .execute()
                .value
            guard let connection = connections.first else { return }

            try await supabase
                .from("messages")
                .insert(NewMessage(
                    connectionId: connection.id,
                    senderId: me,
                    body: "Candidature pour « \(mission.title) » :\n\(pitch.trimmingCharacters(in: .whitespacesAndNewlines))"
                ))
                .execute()

            sent = true
            showApply = false
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
