import SwiftUI

/// Couleurs de la marque : violet de l'app web (tailwind.config.js) + arc-en-ciel du logo.
enum Theme {
    // Violet de l'app web
    static let primary = Color(hex: 0x7C3AED)
    static let primaryLight = Color(hex: 0x8B5CF6)
    static let primaryDeep = Color(hex: 0x5B21B6)
    /// Fond du logo / de l'icône d'app (manifest.json : #580482 à #400987).
    static let brandDeep = Color(hex: 0x580482)
    static let primarySoft = Color(hex: 0xEDE9FE)
    static let paper = Color(hex: 0xEDE9FE)
    static let pink = Color(hex: 0xEC4899)
    static let amber = Color(hex: 0xF59E0B)

    // Arc-en-ciel du logo (échantillonné dans src/assets/logo.png)
    static let rainbowRed = Color(hex: 0xE43C3C)
    static let rainbowOrange = Color(hex: 0xE49C24)
    static let rainbowYellow = Color(hex: 0xFCCC3C)
    static let rainbowGreen = Color(hex: 0x3C843C)
    static let rainbowBlue = Color(hex: 0x3C6CB4)
    static let rainbowPurple = Color(hex: 0x7B3C9C)

    static let rainbow: [Color] = [rainbowRed, rainbowOrange, rainbowYellow, rainbowGreen, rainbowBlue, rainbowPurple]

    // Texte et erreurs (web : neutral-900, neutral-500, error-600)
    static let ink = Color(hex: 0x18181B)
    static let muted = Color(hex: 0x71717A)
    static let rose = Color(hex: 0xDC2626)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Bande arc-en-ciel du logo, utilisée comme filet décoratif.
struct RainbowBar: View {
    var height: CGFloat = 4

    var body: some View {
        LinearGradient(colors: Theme.rainbow, startPoint: .leading, endPoint: .trailing)
            .frame(height: height)
            .clipShape(Capsule())
    }
}

/// Logo officiel (asset « Logo » copié depuis src/assets/logo.png).
struct BrandLogo: View {
    var width: CGFloat = 180

    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityLabel("Queer Services")
    }
}

/// Dates renvoyées par PostgREST (ex. `2026-10-26T10:00:00.123456+00:00`).
enum DateText {
    private static let parser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let output: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .short
        return f
    }()

    static func relative(_ raw: String?) -> String {
        guard let raw else { return "" }
        let withoutFraction = raw.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        guard let date = parser.date(from: withoutFraction) else { return "" }
        return output.localizedString(for: date, relativeTo: Date())
    }
}

