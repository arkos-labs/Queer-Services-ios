import SwiftUI
import UIKit

// MARK: - Titres de navigation arrondis

enum BrandAppearance {
    /// Titres de barre de navigation en police arrondie (proche de Quicksand, la police du site).
    /// On ne touche qu'aux attributs de texte pour garder les fonds natifs (Liquid Glass sur iOS 26).
    static func apply() {
        func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
            return UIFont(descriptor: descriptor, size: size)
        }
        let ink = UIColor(Theme.ink)
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: rounded(34, .heavy), .foregroundColor: ink]
        UINavigationBar.appearance().titleTextAttributes = [.font: rounded(17, .bold), .foregroundColor: ink]
    }
}

// MARK: - Fonds

/// Fond des écrans : violet très clair du site, avec deux halos en dégradé radial (sans flou, peu coûteux à dessiner).
struct BrandBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.paper, Color(hex: 0xF7F5FF), .white], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.pink.opacity(0.12), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
            RadialGradient(colors: [Theme.primary.opacity(0.12), .clear], center: .leading, startRadius: 0, endRadius: 240)
        }
        .ignoresSafeArea()
    }
}

/// Dégradé violet profond de l'icône, pour les en-têtes (halos radiaux, sans flou).
struct BrandGradient: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.brandDeep, Theme.primaryDeep, Theme.primary],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Theme.pink.opacity(0.5), .clear], center: .topTrailing, startRadius: 0, endRadius: 200)
            RadialGradient(colors: [Theme.rainbowBlue.opacity(0.4), .clear], center: .bottomLeading, startRadius: 0, endRadius: 180)
        }
    }
}

extension View {
    func brandBackground() -> some View {
        background(BrandBackdrop())
    }

    /// Carte blanche aux coins continus et à l'ombre violette (les « cards » du site).
    func brandCard(cornerRadius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.white, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Theme.primary.opacity(0.08), radius: 14, y: 6)
    }

    /// Effet verre : Liquid Glass sur iOS 26, matériau translucide avant.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func glassRounded(_ radius: CGFloat = 22) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    /// Barre d'onglets qui se replie au défilement (iOS 26).
    @ViewBuilder
    func minimizingTabBar() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

// MARK: - Boutons

/// Léger enfoncement au toucher (active:scale-[0.98] du site).
struct BrandPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Bouton principal : capsule en dégradé violet → rose.
struct GradientCapsuleLabel: View {
    let title: String
    var systemImage: String?
    var busy = false

    var body: some View {
        HStack(spacing: 8) {
            if busy {
                ProgressView().tint(.white)
            } else if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.system(.headline, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .leading, endPoint: .trailing),
            in: Capsule()
        )
        .shadow(color: Theme.primary.opacity(0.35), radius: 12, y: 6)
    }
}

// MARK: - Puces

struct BrandChip: View {
    let label: String
    var systemImage: String?
    let selected: Bool
    var tint: Color = Theme.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption.weight(.bold))
                }
                Text(label)
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(selected ? .white : tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if selected {
                    Capsule().fill(LinearGradient(colors: [tint, tint.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: tint.opacity(0.35), radius: 8, y: 4)
                } else {
                    Capsule().fill(.white)
                        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 1))
                }
            }
        }
        .buttonStyle(BrandPressStyle())
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// Étiquette non cliquable (compétence, thème…).
struct TagChip: View {
    let text: String
    var color: Color = Theme.primary

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

/// À placer dans le layout de badges de la carte ou du profil.
struct ProfileIdentityBadgeChips: View {
    let profile: Profile
    var onGradient = false

    var body: some View {
        ForEach(profile.identityBadges) { badge in
            TagChip(text: badge.rawValue, color: onGradient ? .white : color(for: badge))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func color(for badge: ProfileIdentityBadge) -> Color {
        switch badge {
        case .professional: Theme.rainbowBlue
        case .community: Theme.primary
        case .gayFriendly: Color(hex: 0x047857)
        }
    }
}

// MARK: - États

struct BrandEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 74, height: 74)
                .background(
                    LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: Theme.primary.opacity(0.3), radius: 14, y: 6)
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    GradientCapsuleLabel(title: actionTitle)
                }
                .buttonStyle(BrandPressStyle())
                .padding(.top, 4)
                .padding(.horizontal, 30)
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

/// Cartes fantômes animées pendant le chargement.
struct SkeletonList: View {
    var count = 4
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 14) {
                    Circle().fill(Theme.primary.opacity(0.10)).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(Theme.primary.opacity(0.10)).frame(width: 150, height: 12)
                        Capsule().fill(Theme.primary.opacity(0.07)).frame(width: 220, height: 10)
                    }
                    Spacer()
                }
                .brandCard()
            }
        }
        .opacity(pulse ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .accessibilityLabel("Chargement")
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(Theme.rose)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.rose.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Invitation à se connecter, pour les écrans réservés aux membres.
struct SignInPrompt: View {
    let message: String
    @State private var showSignIn = false

    var body: some View {
        BrandEmptyState(
            systemImage: "lock.heart.fill",
            title: "Réservé aux membres",
            message: message,
            actionTitle: "Se connecter",
            action: { showSignIn = true }
        )
        .brandCard(cornerRadius: 28, padding: 0)
        .sheet(isPresented: $showSignIn) { SignInSheet() }
    }
}

// MARK: - Mise en page

/// Disposition en lignes qui passent à la ligne (puces de compétences).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct CardSection<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.primary)
                }
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}

/// Ligne de réglage façon iOS : tuile d'icône colorée, titre, chevron.
struct SettingsRow: View {
    let systemImage: String
    let color: Color
    let title: String
    var showsChevron = true
    var titleColor: Color = Theme.ink

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(titleColor)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted.opacity(0.6))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

/// Note en étoiles à toucher.
struct StarRatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    rating = value
                } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(value <= rating ? Theme.amber : Theme.muted.opacity(0.4))
                        .scaleEffect(value == rating ? 1.15 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.5), value: rating)
        .sensoryFeedback(.selection, trigger: rating)
        .accessibilityElement()
        .accessibilityLabel("Note")
        .accessibilityValue("\(rating) sur 5")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(5, rating + 1)
            case .decrement: rating = max(1, rating - 1)
            @unknown default: break
            }
        }
    }
}

struct StarsLabel: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.amber)
        .accessibilityLabel("\(rating) étoiles sur 5")
    }
}

// MARK: - Catégories

extension Category {
    /// Icône SF Symbols équivalente aux icônes lucide du site (categoryIcons.ts).
    var sfSymbol: String {
        switch icon {
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
}
