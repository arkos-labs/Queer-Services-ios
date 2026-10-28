import SwiftUI

/// Numéros utiles et guides. Affiché en page poussée (depuis l'accueil ou le profil), sans NavigationStack propre.
struct ResourcesView: View {
    @State private var resources: [Resource] = []
    @State private var loading = true
    @State private var errorMessage: String?

    private var hotlines: [Resource] { resources.filter { $0.type == "numero_utile" } }
    private var guides: [Resource] { resources.filter { $0.type == "guide" } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                    Text("Tu n'es pas seul·e")
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                    Text("Des lignes d'écoute gratuites et confidentielles, et des guides pour avancer à ton rythme.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(
                    LinearGradient(colors: [Theme.pink, Theme.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Theme.pink.opacity(0.3), radius: 16, y: 8)

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                if loading {
                    SkeletonList(count: 3)
                } else {
                    if !hotlines.isEmpty {
                        Text("Numéros utiles")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.ink)
                        ForEach(hotlines) { HotlineCard(resource: $0) }
                    }
                    if !guides.isEmpty {
                        Text("Guides")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.top, 6)
                        ForEach(guides) { GuideCard(resource: $0) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .brandBackground()
        .navigationTitle("Ressources")
        .brandTopLogo()
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        defer { loading = false }
        do {
            resources = try await supabase
                .from("resources")
                .select()
                .order("type")
                .order("sort_order")
                .execute()
                .value
            errorMessage = nil
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}

private struct HotlineCard: View {
    let resource: Resource

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(resource.title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink)
            if let description = resource.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            if let hours = resource.hours {
                Label(hours, systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
            HStack(spacing: 10) {
                if let phone = resource.phone, let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
                    Link(destination: url) {
                        GradientCapsuleLabel(title: phone, systemImage: "phone.fill")
                    }
                    .buttonStyle(BrandPressStyle())
                }
                if let link = resource.url, let url = URL(string: link) {
                    Link(destination: url) {
                        Image(systemName: "safari.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.primary)
                            .frame(width: 50, height: 50)
                            .glassCapsule()
                    }
                    .accessibilityLabel("Site web")
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(cornerRadius: 24)
    }
}

private struct GuideCard: View {
    let resource: Resource
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(duration: 0.35)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resource.title)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        if let description = resource.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.primary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Replier le guide" : "Lire le guide")

            if expanded, let content = resource.content {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink.opacity(0.85))
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(cornerRadius: 24)
    }
}
