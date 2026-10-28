import SwiftUI

/// Hero de l'accueil : dégradé maillé animé, titre centré et défilé des services (le logo est dans l'en-tête).
struct ImmersiveHero: View {
    let firstName: String?
    let isSignedIn: Bool
    /// Libellés des sous-catégories, affichés en défilé continu.
    let services: [String]
    let explore: () -> Void
    let signIn: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            // Le nom de l'app est dans l'en-tête fixe (BrandHeaderLogo) : ici, seulement le salut.
            if isSignedIn, let firstName, !firstName.isEmpty {
                Label("Salut \(firstName)", systemImage: "hand.wave.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassCapsule()
            }

            VStack(spacing: 0) {
                Text("Fait pour nous,")
                    .foregroundStyle(.white)
                RainbowShiftText(text: "par nous.")
            }
            .font(.system(size: 46, weight: .heavy, design: .rounded))
            .tracking(-1.2)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Text("Trouvez ou proposez des services en toute confiance au sein de votre communauté queer — modéré, sécurisé, construit ensemble.")
                .font(.system(.callout, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)

            ServiceMarquee(items: services)
                .padding(.horizontal, -22)

            VStack(spacing: 10) {
                Button(action: explore) {
                    Label("Explorer l'annuaire", systemImage: "sparkle.magnifyingglass")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.primaryDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
                }
                .buttonStyle(BrandPressStyle())

                if !isSignedIn {
                    Button(action: signIn) {
                        Text("Se connecter ou créer un compte")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glassCapsule()
                    }
                    .buttonStyle(BrandPressStyle())
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 36)
        .padding(.bottom, 58)
        .frame(maxWidth: .infinity)
        .background(MeshHeroBackground())
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
        .shadow(color: Theme.brandDeep.opacity(0.4), radius: 28, y: 14)
        .padding(.horizontal, 10)
        .padding(.top, 4)
        // Effet d'étirement quand on tire la page vers le bas.
        .visualEffect { content, proxy in
            let pull = max(0, proxy.frame(in: .scrollView).minY)
            return content.scaleEffect(1 + pull / 900, anchor: .bottom)
        }
    }
}

/// Défilé continu des services (sous-catégories), estompé sur les bords.
private struct ServiceMarquee: View {
    let items: [String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rowWidth: CGFloat = 0

    var body: some View {
        if !items.isEmpty {
            // Le ruban (très large) est posé en surimpression d'un cadre de hauteur fixe :
            // il ne participe pas à la mise en page et ne peut donc pas élargir le hero.
            Color.clear
                .frame(height: 34)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                        let elapsed = context.date.timeIntervalSinceReferenceDate
                        let offset = rowWidth > 0 ? -CGFloat((elapsed * 26).truncatingRemainder(dividingBy: Double(rowWidth))) : 0
                        HStack(spacing: 8) {
                            row
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear.onAppear { rowWidth = geometry.size.width + 8 }
                                    }
                                )
                            row
                        }
                        .fixedSize()
                        .offset(x: offset)
                    }
                }
                .clipped()
            .mask(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.88),
                    .init(color: .clear, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            )
            .accessibilityHidden(true)
        }
    }

    private var row: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 0.5))
            }
        }
        .fixedSize()
    }
}

/// Dégradé maillé statique (iOS 18) : il ne se redessine plus à chaque image, ce qui libère le processeur pour la saisie.
private struct MeshHeroBackground: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    Theme.brandDeep, Theme.primaryDeep, Theme.pink,
                    Theme.primaryDeep, Theme.primary, Color(hex: 0xC026D3),
                    Theme.brandDeep, Theme.rainbowBlue, Theme.primaryDeep,
                ]
            )
        } else {
            LinearGradient(colors: [Theme.brandDeep, Theme.primaryDeep, Theme.primary, Theme.pink],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Raccourci vers les missions (elles n'ont plus d'onglet : iOS en affiche 5 au maximum).
struct MissionsShortcut: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: "megaphone.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        LinearGradient(colors: [Theme.rainbowOrange, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Un coup de main ?")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("Découvre les missions ouvertes par les membres, ou publie la tienne.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primary)
            }
            .brandCard(cornerRadius: 24)
        }
        .buttonStyle(BrandPressStyle())
    }
}

/// Logo de l'en-tête : l'emblème seul, en grand, dans un disque blanc.
struct BrandHeaderLogo: View {
    var size: CGFloat = 76

    var body: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFit()
            .padding(size * 0.1)
            .frame(width: size, height: size)
            .background(Circle().fill(.white))
            .shadow(color: Theme.brandDeep.opacity(0.22), radius: 10, y: 4)
            .accessibilityLabel("Queer Services")
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Logo de l'app au centre de la barre de navigation (remplace le titre texte).
    func brandTopLogo() -> some View {
        toolbar {
            // Logo à gauche : le centre de la barre reste libre pour le titre de la page quand il se réduit.
            ToolbarItem(placement: .topBarLeading) {
                BrandHeaderLogo(size: 36)
            }
        }
    }
}

/// Barre d'en-tête fixe : logo centré sur un fond flouté qui s'estompe vers le bas.
/// Remplace la barre de navigation, trop basse pour un grand logo.
struct BrandHeaderBar: View {
    var body: some View {
        BrandHeaderLogo()
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .padding(.bottom, 10)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.55),
                            .init(color: .clear, location: 1),
                        ], startPoint: .top, endPoint: .bottom)
                    )
                    .ignoresSafeArea(edges: .top)
            }
    }
}

extension View {
    /// En-tête de page : logo au centre de la barre, et le titre de la page apparaît dans la barre quand on défile.
    /// À appliquer directement sur le ScrollView de la page.
    func collapsingBrandHeader(_ title: String) -> some View {
        modifier(PageHeader(title: title))
    }

    /// Vrai quand la liste a défilé vers le bas (iOS 18 et plus).
    @ViewBuilder
    func trackScrolledDown(_ flag: Binding<Bool>) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > 40
            } action: { _, scrolled in
                flag.wrappedValue = scrolled
            }
        } else {
            self
        }
    }
}

private struct PageHeader: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Logo tout en haut, dans la barre, centré.
                ToolbarItem(placement: .principal) {
                    BrandHeaderLogo(size: 60)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // Titre de la page en grand, juste sous le logo, fixe pendant le défilement.
                Text(title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
                    .background(Theme.paper)
            }
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// Texte arc-en-ciel qui défile en boucle : une bande de couleurs se déplace derrière le texte.
struct RainbowShiftText: View {
    let text: String
    @State private var moved = false
    /// Largeur d'une répétition de l'arc-en-ciel : la boucle se referme sans saut.
    private let period: CGFloat = 320

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: Theme.rainbow + Theme.rainbow, startPoint: .leading, endPoint: .trailing))
            .frame(width: period * 2, height: 80)
            .offset(x: moved ? -period : 0)
            .frame(width: period, height: 80)
            .clipped()
            .mask(Text(text))
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    moved = true
                }
            }
    }
}
