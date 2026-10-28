import AuthenticationServices
import SwiftUI

/// Connexion et inscription (même parcours que AuthPage côté web : e-mail + mot de passe, puis code reçu par e-mail).
struct AuthView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    enum Mode: Hashable {
        case signIn, signUp
    }

    private enum Field: Hashable {
        case email, password
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var code = ""
    @State private var awaitingCode = false
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var resetSent = false
    @State private var resendCooldown = 0
    @FocusState private var focus: Field?
    @FocusState private var codeFocused: Bool
    @State private var appleNonce: String?
    @State private var socialBusy = false
    @Namespace private var modePill

    private static let codeLength = 6

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var emailLooksValid: Bool {
        let parts = trimmedEmail.split(separator: "@")
        return parts.count == 2 && parts[1].contains(".")
    }

    private var canSubmit: Bool {
        if awaitingCode { return code.count == Self.codeLength }
        return emailLooksValid && password.count >= 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                VStack(spacing: 18) {
                    if awaitingCode {
                        codeStep
                    } else {
                        credentialsStep
                    }
                }
                .padding(22)
                .background(.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Theme.primary.opacity(0.12), radius: 24, y: 10)
                .padding(.horizontal, 16)
                .offset(y: -34)
                .padding(.bottom, -34)
                .animation(.spring(duration: 0.4, bounce: 0.2), value: awaitingCode)
                .animation(.spring(duration: 0.35), value: mode)

                VStack(spacing: 8) {
                    RainbowBar(height: 3).frame(width: 60)
                    Text("Fait pour nous, par nous.")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 28)
                .padding(.bottom, 30)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .brandBackground()
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .glassCapsule()
            }
            .padding(14)
            .accessibilityLabel("Fermer")
        }
        .onChange(of: mode) { _, _ in
            errorMessage = nil
            resetSent = false
        }
        .sensoryFeedback(.error, trigger: errorMessage) { _, new in new != nil }
    }

    // MARK: En-tête

    private var header: some View {
        VStack(spacing: 14) {
            BrandHeaderLogo(size: 84)
            Text(headerTitle)
                .font(.system(.title, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
            Text(headerSubtitle)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
        }
        .padding(.top, 44)
        .padding(.bottom, 64)
        .frame(maxWidth: .infinity)
        .background(BrandGradient())
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: mode)
        .animation(.easeInOut(duration: 0.25), value: awaitingCode)
    }

    private var headerTitle: String {
        if awaitingCode { return "Vérifie ton e-mail" }
        return mode == .signIn ? "Ravi·e de te revoir" : "Créer ton compte"
    }

    private var headerSubtitle: String {
        if awaitingCode { return "Dernière étape avant de rejoindre la communauté." }
        return mode == .signIn
            ? "Connecte-toi pour retrouver ton profil et tes échanges."
            : "Rejoins un espace d'entraide pensé par et pour la communauté."
    }

    // MARK: Étape 1 : e-mail + mot de passe

    @ViewBuilder
    private var credentialsStep: some View {
        modeSwitcher

        socialButtons

        HStack(spacing: 10) {
            Rectangle().fill(Theme.primary.opacity(0.15)).frame(height: 1)
            Text("ou avec ton e-mail")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.muted)
                .fixedSize()
            Rectangle().fill(Theme.primary.opacity(0.15)).frame(height: 1)
        }

        VStack(spacing: 12) {
            AuthField(icon: "envelope.fill", isFocused: focus == .email) {
                TextField("E-mail", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }

            AuthField(icon: "lock.fill", isFocused: focus == .password) {
                Group {
                    if showPassword {
                        TextField(mode == .signUp ? "6 caractères minimum" : "Mot de passe", text: $password)
                    } else {
                        SecureField(mode == .signUp ? "6 caractères minimum" : "Mot de passe", text: $password)
                    }
                }
                .textContentType(mode == .signUp ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)

                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe")
            }

            if mode == .signUp, !password.isEmpty {
                PasswordStrength(password: password)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }

        if mode == .signIn {
            HStack {
                Spacer()
                Button("Mot de passe oublié ?") { Task { await forgotPassword() } }
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primary)
                    .disabled(busy)
            }
            .padding(.top, -6)
        }

        messages

        Button(action: submit) {
            GradientCapsuleLabel(
                title: mode == .signIn ? "Se connecter" : "Créer mon compte",
                systemImage: mode == .signIn ? "arrow.right" : "person.badge.plus",
                busy: busy
            )
            .opacity(canSubmit ? 1 : 0.5)
        }
        .buttonStyle(BrandPressStyle())
        .disabled(busy || !canSubmit)

        if mode == .signUp {
            legalNote
        } else {
            Button {
                mode = .signUp
            } label: {
                Text("Pas encore de compte ? ") .foregroundStyle(Theme.muted)
                    + Text("Inscris-toi").foregroundStyle(Theme.primary).bold()
            }
            .font(.system(.footnote, design: .rounded))
            .buttonStyle(.plain)
        }
    }

    // MARK: Apple et Google

    private var socialButtons: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.continue) { request in
                let nonce = AppleNonce.random()
                appleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleNonce.sha256(nonce)
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(Capsule())
            .disabled(socialBusy || busy)

            Button {
                Task { await signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    if socialBusy {
                        ProgressView()
                    } else {
                        Image("GoogleG")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    Text("Continuer avec Google")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1F1F1F))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(Color(hex: 0x747775).opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(BrandPressStyle())
            .disabled(socialBusy || busy)
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = appleNonce
            else {
                withAnimation { errorMessage = "Apple n'a pas renvoyé de jeton de connexion." }
                return
            }
            Task {
                socialBusy = true
                errorMessage = nil
                defer { socialBusy = false }
                do {
                    try await session.signInWithApple(idToken: idToken, nonce: nonce, fullName: credential.fullName)
                } catch {
                    guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
                    withAnimation { errorMessage = Self.socialMessage(error, provider: "Apple") }
                }
            }
        case .failure(let error):
            // Fenêtre Apple fermée sans terminer : pas une erreur à afficher.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            withAnimation { errorMessage = Self.socialMessage(error, provider: "Apple") }
        }
    }

    private func signInWithGoogle() async {
        socialBusy = true
        errorMessage = nil
        defer { socialBusy = false }
        do {
            try await session.signInWithGoogle()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            // Fenêtre Google fermée sans terminer : pas une erreur à afficher.
            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return }
            withAnimation { errorMessage = Self.socialMessage(error, provider: "Google") }
        }
    }

    /// Erreurs de configuration fréquentes, expliquées en clair.
    private static func socialMessage(_ error: Error, provider: String) -> String {
        let lower = error.localizedDescription.lowercased()
        if lower.contains("audience") || lower.contains("client id") || lower.contains("unacceptable") {
            return "La connexion \(provider) n'est pas encore autorisée pour cette app dans Supabase."
        }
        if lower.contains("redirect") {
            return "L'adresse de retour de l'app n'est pas autorisée dans Supabase."
        }
        if lower.contains("provider is not enabled") || lower.contains("unsupported provider") {
            return "La connexion \(provider) n'est pas activée dans Supabase."
        }
        return AuthMessage.friendly(error)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 4) {
            modeButton("Connexion", .signIn)
            modeButton("Inscription", .signUp)
        }
        .padding(4)
        .background(Theme.primarySoft, in: Capsule())
    }

    private func modeButton(_ title: String, _ value: Mode) -> some View {
        Button {
            mode = value
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(mode == value ? Theme.primaryDeep : Theme.primary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if mode == value {
                        Capsule()
                            .fill(.white)
                            .shadow(color: Theme.primary.opacity(0.18), radius: 6, y: 2)
                            .matchedGeometryEffect(id: "pill", in: modePill)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }

    private var legalNote: some View {
        Text("En créant un compte, tu acceptes les [CGU](https://queerservices.fr/cgu) et la [politique de confidentialité](https://queerservices.fr/confidentialite).")
            .font(.caption)
            .foregroundStyle(Theme.muted)
            .tint(Theme.primary)
            .multilineTextAlignment(.center)
    }

    // MARK: Étape 2 : code reçu par e-mail

    @ViewBuilder
    private var codeStep: some View {
        Image(systemName: "envelope.open.fill")
            .font(.system(size: 30))
            .foregroundStyle(.white)
            .frame(width: 66, height: 66)
            .background(
                LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle()
            )
            .shadow(color: Theme.primary.opacity(0.3), radius: 12, y: 6)

        VStack(spacing: 4) {
            Text("Nous avons envoyé un code à")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Text(trimmedEmail)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
        }

        CodeBoxes(code: $code, length: Self.codeLength, focused: $codeFocused)
            .onChange(of: code) { _, value in
                let digits = String(value.filter(\.isNumber).prefix(Self.codeLength))
                if digits != value { code = digits }
                if digits.count == Self.codeLength { submit() }
            }
            .onAppear { codeFocused = true }

        messages

        Button(action: submit) {
            GradientCapsuleLabel(title: "Valider le code", systemImage: "checkmark", busy: busy)
                .opacity(canSubmit ? 1 : 0.5)
        }
        .buttonStyle(BrandPressStyle())
        .disabled(busy || !canSubmit)

        HStack(spacing: 18) {
            Button(resendCooldown > 0 ? "Renvoyer (\(resendCooldown) s)" : "Renvoyer le code") {
                Task { await resend() }
            }
            .disabled(resendCooldown > 0 || busy)

            Button("Modifier l'e-mail") {
                awaitingCode = false
                code = ""
                errorMessage = nil
            }
        }
        .font(.system(.footnote, design: .rounded).weight(.bold))
        .foregroundStyle(Theme.primary)
    }

    // MARK: Messages

    @ViewBuilder
    private var messages: some View {
        if let errorMessage {
            ErrorBanner(message: errorMessage)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
        if resetSent {
            Label("Si un compte existe pour cet e-mail, un lien de réinitialisation vient d'être envoyé.", systemImage: "envelope.badge.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.primaryDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.primarySoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: Actions

    private func submit() {
        guard canSubmit, !busy else { return }
        focus = nil
        codeFocused = false
        Task {
            busy = true
            errorMessage = nil
            defer { busy = false }
            do {
                if awaitingCode {
                    try await session.verifySignup(email: trimmedEmail, code: code)
                } else if mode == .signIn {
                    try await session.signIn(email: trimmedEmail, password: password)
                } else {
                    let signedIn = try await session.signUp(email: trimmedEmail, password: password)
                    if !signedIn {
                        awaitingCode = true
                        startCooldown()
                    }
                }
            } catch {
                guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
                let message = AuthMessage.friendly(error)
                // E-mail jamais confirmé : on passe directement à la saisie du code.
                if mode == .signIn, error.localizedDescription.lowercased().contains("email not confirmed") {
                    awaitingCode = true
                    await resend()
                }
                if awaitingCode { code = "" }
                withAnimation { errorMessage = message }
            }
        }
    }

    private func forgotPassword() async {
        guard emailLooksValid else {
            withAnimation { errorMessage = "Saisis d'abord ton e-mail ci-dessus." }
            focus = .email
            return
        }
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            // Même page de réinitialisation que le site.
            try await supabase.auth.resetPasswordForEmail(
                trimmedEmail,
                redirectTo: URL(string: "https://www.queerservices.fr/reset-password")
            )
            withAnimation { resetSent = true }
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            withAnimation { errorMessage = AuthMessage.friendly(error) }
        }
    }

    private func resend() async {
        do {
            try await supabase.auth.resend(email: trimmedEmail, type: .signup)
            startCooldown()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            withAnimation { errorMessage = AuthMessage.friendly(error) }
        }
    }

    /// Supabase limite les renvois : on bloque le bouton 30 secondes.
    private func startCooldown() {
        resendCooldown = 30
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                resendCooldown -= 1
            }
        }
    }
}

// MARK: - Composants

/// Champ de saisie avec icône, bord violet quand il est actif.
private struct AuthField<Content: View>: View {
    let icon: String
    let isFocused: Bool
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(isFocused ? Theme.primary : Theme.muted.opacity(0.7))
                .frame(width: 20)
            content
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(isFocused ? Color.white : Color(hex: 0xF8F7FC), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isFocused ? Theme.primary : Theme.primary.opacity(0.12), lineWidth: isFocused ? 2 : 1)
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

/// Jauge de robustesse du mot de passe à l'inscription.
private struct PasswordStrength: View {
    let password: String

    private var score: Int {
        var value = 0
        if password.count >= 6 { value += 1 }
        if password.count >= 10 { value += 1 }
        if password.contains(where: \.isNumber) { value += 1 }
        if password.contains(where: { $0.isUppercase }) || password.contains(where: { !$0.isLetter && !$0.isNumber }) { value += 1 }
        return value
    }

    private var label: (String, Color) {
        switch score {
        case 0, 1: ("Trop court", Theme.rose)
        case 2: ("Correct", Theme.amber)
        case 3: ("Bon", Color(hex: 0x059669))
        default: ("Excellent", Color(hex: 0x059669))
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < score ? label.1 : Theme.primary.opacity(0.12))
                        .frame(height: 5)
                }
            }
            Text(password.count < 6 ? "6 caractères minimum" : label.0)
                .font(.caption.weight(.bold))
                .foregroundStyle(password.count < 6 ? Theme.rose : label.1)
                .frame(width: 130, alignment: .trailing)
        }
        .animation(.easeOut(duration: 0.2), value: score)
        .accessibilityElement(children: .combine)
    }
}

/// Code à 6 chiffres : un champ invisible et six cases qui affichent les chiffres saisis.
private struct CodeBoxes: View {
    @Binding var code: String
    let length: Int
    var focused: FocusState<Bool>.Binding

    private var isFocused: Bool { focused.wrappedValue }

    var body: some View {
        ZStack {
            // Le champ couvre toute la rangée : toucher n'importe quelle case ouvre le clavier.
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused(focused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, minHeight: 56)
                .accessibilityLabel("Code de vérification")

            HStack(spacing: 8) {
                ForEach(0..<length, id: \.self) { index in
                    let characters = Array(code)
                    let digit = index < characters.count ? String(characters[index]) : ""
                    let isCurrent = isFocused && index == min(characters.count, length - 1)
                    Text(digit)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.primaryDeep)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: 0xF8F7FC), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isCurrent ? Theme.primary : Theme.primary.opacity(digit.isEmpty ? 0.12 : 0.4),
                                        lineWidth: isCurrent ? 2 : 1)
                        )
                        .scaleEffect(digit.isEmpty ? 1 : 1.03)
                        .animation(.spring(duration: 0.2), value: digit)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
