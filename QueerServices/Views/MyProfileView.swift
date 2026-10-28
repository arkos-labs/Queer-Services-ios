import SwiftUI
import UIKit

struct MyProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var router: TabRouter

    @State private var confirmDelete = false
    @State private var showSignIn = false
    @State private var errorMessage: String?

    private let legalBase = "https://queerservices.fr"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    group("Communauté") {
                        Button { router.openMissions() } label: {
                            SettingsRow(systemImage: "megaphone.fill", color: Theme.rainbowOrange, title: "Missions")
                        }
                        .buttonStyle(.plain)
                        divider
                        NavigationLink { PlacesView() } label: {
                            SettingsRow(systemImage: "building.2.fill", color: Theme.rainbowBlue, title: "Lieux")
                        }
                        divider
                        NavigationLink { ResourcesView() } label: {
                            SettingsRow(systemImage: "cross.case.fill", color: Theme.pink, title: "Ressources utiles")
                        }
                    }

                    group("Informations légales") {
                        legalRow("Conditions générales", path: "cgu", icon: "doc.text.fill", color: Theme.primary)
                        divider
                        legalRow("Confidentialité", path: "confidentialite", icon: "lock.shield.fill", color: Color(hex: 0x059669))
                        divider
                        legalRow("Mentions légales", path: "mentions-legales", icon: "building.columns.fill", color: Theme.muted)
                        divider
                        legalRow("Cookies", path: "cookies", icon: "circle.grid.2x2.fill", color: Theme.rainbowOrange)
                    }

                    group("Compte") {
                        if session.userId == nil {
                            Button { showSignIn = true } label: {
                                SettingsRow(systemImage: "person.crop.circle.badge.plus", color: Theme.primary,
                                            title: "Se connecter ou créer un compte")
                            }
                        } else {
                            Button { Task { await session.signOut() } } label: {
                                SettingsRow(systemImage: "rectangle.portrait.and.arrow.right", color: Theme.rainbowOrange,
                                            title: "Se déconnecter", showsChevron: false)
                            }
                            divider
                            Button { confirmDelete = true } label: {
                                SettingsRow(systemImage: "trash.fill", color: Theme.rose,
                                            title: "Supprimer mon compte", showsChevron: false, titleColor: Theme.rose)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if session.userId != nil {
                        group("Prestations") {
                            NavigationLink { PaymentSettingsView() } label: {
                                SettingsRow(systemImage: "creditcard.fill", color: Theme.primary,
                                            title: "Paiements et prestations")
                            }
                        }
                    }

                    VStack(spacing: 6) {
                        RainbowBar(height: 3).frame(width: 60)
                        Text("Queer Services · version 1.0")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .collapsingBrandHeader("Profil")
            .brandBackground()
            .alert("Supprimer ton compte ?", isPresented: $confirmDelete) {
                Button("Supprimer", role: .destructive) { Task { await deleteAccount() } }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Ton profil sera supprimé définitivement. Cette action est irréversible.")
            }
            .sheet(isPresented: $showSignIn) { SignInSheet() }
            .task { await session.refreshProfile() }
            .refreshable { await session.refreshProfile() }
        }
    }

    // MARK: En-tête

    private var header: some View {
        VStack(spacing: 14) {
            if let profile = session.profile ?? DemoMode.ownProfile {
                Avatar(profile: profile, size: 88)
                    .padding(4)
                    .background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                VStack(spacing: 4) {
                    Text(profile.title)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                    if let city = profile.city, !city.isEmpty {
                        Label(city, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                if !profile.identityBadges.isEmpty {
                    HStack(spacing: 6) {
                        ProfileIdentityBadgeChips(profile: profile, onGradient: true)
                    }
                }
                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                NavigationLink {
                    ProfileEditView()
                } label: {
                    Label("Modifier mon profil", systemImage: "pencil")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryDeep)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(BrandPressStyle())
            } else {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .padding(14)
                    .frame(width: 88, height: 88)
                    .background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    .accessibilityHidden(true)
                Text("Bienvenue dans la communauté")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Connecte-toi pour créer ton profil, proposer tes services et échanger avec les membres.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                Button { showSignIn = true } label: {
                    Text("Se connecter")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryDeep)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(BrandPressStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(BrandGradient())
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Theme.brandDeep.opacity(0.3), radius: 18, y: 8)
    }

    // MARK: Groupes façon Réglages

    private var divider: some View {
        Divider().padding(.leading, 62)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.muted)
                .padding(.leading, 6)
            VStack(spacing: 0) {
                content()
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Theme.primary.opacity(0.06), radius: 12, y: 5)
        }
    }

    @ViewBuilder
    private func legalRow(_ title: String, path: String, icon: String, color: Color) -> some View {
        if let url = URL(string: "\(legalBase)/\(path)") {
            Link(destination: url) {
                SettingsRow(systemImage: icon, color: color, title: title)
            }
        }
    }

    /// Même effet que SettingsPage côté web : suppression de la ligne profil, puis déconnexion.
    private func deleteAccount() async {
        guard let me = session.userId else { return }
        do {
            try await supabase
                .from("profiles")
                .delete()
                .eq("id", value: me)
                .execute()
            await session.signOut()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}

struct PaymentSettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var loading = false
    @State private var link: URL?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Label("Recevoir des paiements", systemImage: "creditcard.fill").font(.headline)
                Text("Active Stripe pour recevoir les paiements de tes prestations directement dans l’application.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                if let profile = session.profile {
                    Label(profile.stripeChargesEnabled && profile.stripePayoutsEnabled ? "Paiements activés" : "Vérification à terminer",
                          systemImage: profile.stripeChargesEnabled && profile.stripePayoutsEnabled ? "checkmark.circle.fill" : "clock.fill")
                        .foregroundStyle(profile.stripeChargesEnabled && profile.stripePayoutsEnabled ? .green : Theme.rainbowOrange)
                }
            }
            Section {
                Button { Task { await activate() } } label: {
                    Label(loading ? "Ouverture…" : "Activer les paiements", systemImage: "arrow.up.right.square")
                }.disabled(loading)
                if let link { Link("Reprendre la vérification Stripe", destination: link) }
            }
            if let errorMessage { Section { Text(errorMessage).foregroundStyle(Theme.rose) } }
        }
        .navigationTitle("Paiements")
        .navigationBarTitleDisplayMode(.inline)
        .task { await syncStatus() }
        .refreshable { await syncStatus() }
    }

    private func syncStatus() async {
        _ = try? await Edge.call("stripe-sync-account", EdgeBody())
        await session.refreshProfile()
    }

    private func activate() async {
        loading = true
        defer { loading = false }
        do {
            let base = "https://queerservices.fr/parametres?stripe=return"
            let response = try await Edge.call("stripe-connect-onboarding", EdgeBody(returnUrl: base, refreshUrl: base))
            guard let value = response.url, let url = URL(string: value) else {
                errorMessage = "Stripe n’a pas renvoyé de lien de vérification."
                return
            }
            link = url
            await UIApplication.shared.open(url)
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
