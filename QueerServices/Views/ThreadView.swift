import SwiftUI
import StripePaymentSheet
import UIKit

/// Mise à jour « lu » des messages reçus.
private struct ReadPatch: Encodable {
    let readAt: String

    enum CodingKeys: String, CodingKey {
        case readAt = "read_at"
    }
}

private struct ConnectionStatusPatch: Encodable {
    let status: String
}

private struct PaymentStatusPatch: Encodable {
    let status: String
}

private struct PaymentSecret: Identifiable {
    let id = UUID()
    let value: String
}

private struct PaymentSheetPresenter: UIViewControllerRepresentable {
    let clientSecret: String
    let completion: (PaymentSheetResult) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        DispatchQueue.main.async {
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Queer Services"
            configuration.allowsDelayedPaymentMethods = false
            // Apple Pay : identifiant marchand créé dans le compte développeur Apple.
            configuration.applePay = .init(merchantId: "merchant.com.queerservices.native", merchantCountryCode: "FR")
            let sheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
            context.coordinator.sheet = sheet
            sheet.present(from: controller) { result in
                completion(result)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var sheet: PaymentSheet?
    }
}

struct ThreadView: View {
    @EnvironmentObject private var session: SessionStore
    let conversation: Conversation

    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var errorMessage: String?
    @State private var payment: Payment?
    @State private var paymentLoading = false
    @State private var paymentSecret: PaymentSecret?
    @State private var showPaymentRequest = false
    @State private var paymentAmount = ""
    @State private var paymentService = ""
    @State private var paymentRequestLoading = false
    @State private var paymentResponding = false
    @State private var connectionStatus: String?
    @State private var confirmClose = false
    @State private var showRequestDetails = false
    @FocusState private var composerFocused: Bool

    /// Conversation clôturée par l'un des deux participants (statut « completed »).
    private var isClosed: Bool {
        (connectionStatus ?? conversation.connection.status) == "completed"
    }

    private static let acceptedText = "La demande a été acceptée."
    private static let refusedText = "La demande a été refusée."
    private static let requestPrefix = "Demande de paiement :"
    private static let closedText = "La conversation a été clôturée."
    private static let closeRequestText = "Demande de clôture : confirmez-vous que la prestation est terminée ?"
    private static let closeRefusedText = "La demande de clôture a été refusée."
    private static let cancelledText = "La demande de paiement a été annulée."

    private var canSend: Bool {
        !sending && !isClosed && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Demande de clôture en attente de confirmation dans la prestation en cours.
    private var pendingCloseRequest: Message? {
        guard let last = cycle.last(where: { $0.body == Self.closeRequestText || $0.body == Self.closeRefusedText || $0.body == Self.closedText }),
              last.body == Self.closeRequestText else { return nil }
        return last
    }

    /// Messages de la prestation en cours : tout ce qui suit la dernière clôture.
    private var cycle: [Message] {
        let start = (messages.lastIndex(where: { $0.body == Self.closedText }) ?? -1) + 1
        return Array(messages[start...])
    }

    /// Nom de la prestation écrit dans une demande : « Demande de paiement : Coiffure — 50,00 €. … ».
    private func requestTitle(of body: String) -> String? {
        guard body.hasPrefix(Self.requestPrefix) else { return nil }
        let rest = body.dropFirst(Self.requestPrefix.count).trimmingCharacters(in: .whitespaces)
        guard let range = rest.range(of: " — ") else { return nil }
        return String(rest[..<range.lowerBound])
    }

    /// Nom de la dernière demande de paiement envoyée dans la conversation.
    private var currentRequestTitle: String? {
        messages.last(where: { $0.body.hasPrefix(Self.requestPrefix) }).flatMap { requestTitle(of: $0.body) }
    }

    /// En-tête fixe : photo, nom du membre, prestation et bouton « Clôturer », toujours visibles.
    private var pinnedHeader: some View {
        ZStack(alignment: .topTrailing) {
            ConversationIntro(other: conversation.other, serviceLabel: currentRequestTitle ?? conversation.connection.serviceLabel, onServiceTap: { showRequestDetails = true })
                .frame(maxWidth: .infinity)
            if !isClosed && pendingCloseRequest == nil {
                Button {
                    confirmClose = true
                } label: {
                    Label("Clôturer", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .confirmationDialog("Demander la clôture ?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Demander la clôture") { Task { await requestClose() } }
        } message: {
            Text("L'autre personne devra confirmer. Ensuite, vous ne pourrez plus écrire ni payer dans cette conversation.")
        }
        .sheet(isPresented: $showRequestDetails) {
            requestDetailsSheet
                .presentationDetents([.medium])
        }
    }

    /// Fiche de la demande en cours : son nom, le texte envoyé et son statut.
    private var requestDetailsSheet: some View {
        NavigationStack {
            List {
                Section("Prestation") {
                    Text(currentRequestTitle ?? "Sans nom")
                }
                if let latest = messages.last(where: { $0.body.hasPrefix(Self.requestPrefix) }) {
                    Section("Demande") {
                        Text(latest.body)
                    }
                }
                Section("Statut") {
                    Text(requestStatusText)
                }
            }
            .navigationTitle("Détails de la demande")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { showRequestDetails = false }
                }
            }
        }
    }

    private var requestStatusText: String {
        if let payment, payment.status == "authorized" { return "Paiement réservé" }
        if let payment, payment.status == "pending" { return "Paiement en attente" }
        if let decision = paymentDecision { return decision.body }
        return "En attente de réponse"
    }

    private var cancelPaymentTitle: String {
        "Annuler la demande" + (currentRequestTitle.map { " « \($0) »" } ?? "")
    }

    private func payButtonTitle(_ amount: Int) -> String {
        let price = (Double(amount) / 100).formatted(.currency(code: "EUR"))
        return "Payer \(price)" + (currentRequestTitle.map { " · \($0)" } ?? "")
    }

    /// Une demande de paiement a été envoyée pour la prestation en cours.
    private var hasOpenRequest: Bool {
        cycle.contains { $0.body.hasPrefix(Self.requestPrefix) }
    }

    /// Décision (acceptée ou refusée) prise après la dernière demande de paiement, si elle existe.
    private var paymentDecision: Message? {
        let requestIndex = cycle.lastIndex(where: { $0.body.hasPrefix(Self.requestPrefix) }) ?? -1
        guard let index = cycle.lastIndex(where: { $0.body == Self.acceptedText || $0.body == Self.refusedText }),
              index > requestIndex else { return nil }
        return cycle[index]
    }

    /// Le prestataire voit que la demande a été acceptée : il peut envoyer la demande de paiement.
    private var awaitsProviderRequest: Bool {
        guard let decision = paymentDecision else { return false }
        return decision.body == Self.acceptedText && decision.senderId != session.userId
    }

    /// La demande en cours a été envoyée après une acceptation du client : il peut payer directement.
    private var requestFollowsAcceptance: Bool {
        guard let requestIndex = cycle.lastIndex(where: { $0.body.hasPrefix(Self.requestPrefix) }) else { return false }
        return cycle[..<requestIndex].contains { $0.body == Self.acceptedText }
    }

    /// Seul le prestataire envoie la demande de paiement : le client qui accepte ou refuse ne voit pas ce bouton.
    private var canSendPaymentRequest: Bool {
        guard let me = session.userId, !isClosed else { return false }
        if payment?.payerId == me { return false }
        if paymentDecision?.senderId == me { return false }
        return true
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let isMine = message.senderId == session.userId
                        let nextIsSameSender = index + 1 < messages.count && messages[index + 1].senderId == message.senderId
                        MessageBubble(message: message, isMine: isMine, showsTime: !nextIsSameSender)
                            .id(message.id)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .animation(.spring(duration: 0.35), value: messages.count)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .brandBackground()
        .safeAreaInset(edge: .top, spacing: 0) { pinnedHeader }
        .safeAreaInset(edge: .bottom) { composer }
        .navigationBarTitleDisplayMode(.inline)
        .brandTopLogo()
        // Pas de temps réel ici : on relit la conversation toutes les 4 secondes.
        .task {
            while !Task.isCancelled {
                await loadMessages()
                try? await Task.sleep(for: .seconds(4))
            }
        }
        .sheet(item: $paymentSecret) { secret in
            PaymentSheetPresenter(clientSecret: secret.value) { result in
                paymentSecret = nil
                if case .completed = result {
                    Task {
                        if let me = session.userId {
                            _ = try? await supabase.from("messages").insert(NewMessage(
                                connectionId: conversation.connection.id,
                                senderId: me,
                                body: "Paiement effectué. La prestation peut commencer."
                            )).execute()
                        }
                        await loadMessages()
                    }
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPaymentRequest) {
            NavigationStack {
                Form {
                    Section("Montant convenu") {
                        if let services = conversation.other.proServices, !services.isEmpty {
                            Picker("Prestation", selection: $paymentService) {
                                ForEach(services, id: \.label) { service in
                                    Text(service.label).tag(service.label)
                                }
                            }
                        }
                        TextField("Montant en euros", text: $paymentAmount)
                            .keyboardType(.decimalPad)
                        Text("Le client recevra cette demande dans cette conversation et pourra payer par carte ou Apple Pay.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .navigationTitle("Demander un paiement")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { showPaymentRequest = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(paymentRequestLoading ? "Envoi…" : "Envoyer") {
                            Task { await requestPayment() }
                        }
                        .disabled(paymentRequestLoading || parsedAmount == nil)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.rose)
            }
            if isClosed {
                Text("Prestation terminée. Pour reprendre, ouvrez une nouvelle demande.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            } else if let request = pendingCloseRequest {
                if request.senderId == session.userId {
                    Text("Clôture demandée. En attente de la confirmation de l'autre personne.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                } else {
                    Text("L'autre personne demande à clôturer la prestation.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    HStack(spacing: 8) {
                        Button("Confirmer la clôture") { Task { await closeConversation() } }
                            .buttonStyle(.borderedProminent)
                        Button("Refuser", role: .destructive) { Task { await refuseClose() } }
                            .buttonStyle(.bordered)
                    }
                }
            }
            if let decision = paymentDecision {
                Text(decision.body)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            if let payment, payment.status == "pending" || payment.status == "authorized" {
                // Toujours visible sur une demande non payée, même ancienne : c'est elle qui bloque les nouvelles demandes.
                // Seul le prestataire qui a envoyé la demande peut l'annuler : le client qui doit payer ne le voit pas.
                if payment.status == "pending", payment.payeeId == session.userId {
                    Button {
                        Task { await cancelPayment() }
                    } label: {
                        Label(cancelPaymentTitle, systemImage: "xmark.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.rose)
                    }
                    .disabled(paymentResponding)
                }
                if hasOpenRequest, payment.status == "pending", payment.payerId == session.userId, paymentDecision == nil, !requestFollowsAcceptance, !paymentResponding {
                    HStack(spacing: 8) {
                        Button("Accepter") { Task { await acceptPayment(payment) } }
                            .buttonStyle(.borderedProminent)
                        Button("Refuser", role: .destructive) { Task { await refusePayment(payment) } }
                            .buttonStyle(.bordered)
                    }
                }
                if hasOpenRequest, payment.payerId == session.userId, paymentDecision?.body != Self.refusedText,
                   paymentDecision?.body == Self.acceptedText || requestFollowsAcceptance || conversation.connection.status == "accepted" {
                    Button {
                        Task { await startPayment(payment) }
                    } label: {
                        Label(paymentLoading ? "Préparation du paiement…" : payButtonTitle(payment.amount), systemImage:"creditcard.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(.white)
                            .background(Theme.primary, in: Capsule())
                    }
                    .disabled(paymentLoading)
                } else if paymentDecision == nil {
                    Text(payment.payerId == session.userId
                         ? "Accepte ou refuse la prestation proposée."
                         : "En attente de la décision de la personne qui souhaite le service.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            if canSendPaymentRequest {
                Button {
                    showPaymentRequest = true
                } label: {
                    Label(awaitsProviderRequest ? "Envoyer la demande de paiement" : "Demander le paiement", systemImage: "eurosign.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(Theme.primaryDeep)
                        .background(Theme.primarySoft, in: Capsule())
                }
                .disabled(paymentLoading || paymentRequestLoading)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Écrire un message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .disabled(isClosed)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .glassRounded(22)

                Button(action: send) {
                    Image(systemName: sending ? "ellipsis" : "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background {
                            Circle().fill(
                                canSend
                                    ? AnyShapeStyle(LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : AnyShapeStyle(Theme.muted.opacity(0.35))
                            )
                        }
                        .symbolEffect(.pulse, isActive: sending)
                }
                .buttonStyle(BrandPressStyle())
                .disabled(!canSend)
                .accessibilityLabel("Envoyer")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func loadMessages() async {
        do {
            let rows: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("connection_id", value: conversation.connection.id)
                .order("created_at", ascending: true)
                .execute()
                .value
            if rows != messages { messages = rows }
            await markRead(rows)
            await loadPayment()
            await loadConnectionStatus()
            try Task.checkCancellation()
            errorMessage = nil
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadConnectionStatus() async {
        let rows: [Connection]? = try? await supabase
            .from("connections")
            .select()
            .eq("id", value: conversation.connection.id)
            .execute()
            .value
        if let status = rows?.first?.status { connectionStatus = status }
    }

    /// Envoie la demande de clôture : l'autre personne doit la confirmer.
    private func requestClose() async {
        guard let me = session.userId else { return }
        do {
            try await supabase.from("messages").insert(NewMessage(
                connectionId: conversation.connection.id,
                senderId: me,
                body: Self.closeRequestText
            )).execute()
            await loadMessages()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Refuse la demande de clôture : la conversation reste ouverte.
    private func refuseClose() async {
        guard let me = session.userId else { return }
        do {
            try await supabase.from("messages").insert(NewMessage(
                connectionId: conversation.connection.id,
                senderId: me,
                body: Self.closeRefusedText
            )).execute()
            await loadMessages()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func closeConversation() async {
        guard let me = session.userId else { return }
        do {
            // Une demande non payée bloquerait la prestation suivante : on l'annule.
            // Un paiement déjà réservé par le client est encaissé (prestation terminée).
            if let payment {
                if payment.status == "pending" {
                    _ = try await Edge.call("stripe-manage-payment", EdgeBody(connectionId: conversation.connection.id, action: "cancel"))
                } else if payment.status == "authorized", payment.payerId == me {
                    _ = try await Edge.call("stripe-manage-payment", EdgeBody(connectionId: conversation.connection.id, action: "capture"))
                }
            }
            try await supabase
                .from("connections")
                .update(ConnectionStatusPatch(status: "completed"))
                .eq("id", value: conversation.connection.id)
                .execute()
            try await supabase.from("messages").insert(NewMessage(
                connectionId: conversation.connection.id,
                senderId: me,
                body: Self.closedText
            )).execute()
            connectionStatus = "completed"
            await loadMessages()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadPayment() async {
        payment = try? await supabase
            .from("payments")
            .select()
            .eq("connection_id", value: conversation.connection.id)
            .in("status", values: ["pending", "authorized"])
            .order("created_at", ascending: false)
            .limit(1)
            .maybeSingle()
            .execute().value
    }

    private func startPayment(_ payment: Payment) async {
        guard let me = session.userId, payment.payerId == me else { return }
        guard !AppConfig.stripePublishableKey.isEmpty else {
            errorMessage = "Paiement non configuré : la clé Stripe manque dans l’application."
            return
        }
        paymentLoading = true
        defer { paymentLoading = false }
        do {
            let response = try await Edge.call("stripe-create-payment", EdgeBody(connectionId: conversation.connection.id))
            guard let secret = response.clientSecret else {
                errorMessage = "Le paiement n’est pas encore disponible."
                return
            }
            paymentSecret = PaymentSecret(value: secret)
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func acceptPayment(_ payment: Payment) async {
        guard let me = session.userId, payment.payerId == me, payment.status == "pending" else { return }
        paymentResponding = true
        defer { paymentResponding = false }
        do {
            // Comme le web : accepter le prix passe la connexion en « acceptée ». Le paiement reste celui en attente.
            try await supabase
                .from("connections")
                .update(ConnectionStatusPatch(status: "accepted"))
                .eq("id", value: conversation.connection.id)
                .execute()
            try await supabase.from("messages").insert(NewMessage(
                connectionId: conversation.connection.id,
                senderId: me,
                body: Self.acceptedText
            )).execute()
            await loadMessages()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Annule la demande en attente (les deux participants) pour pouvoir en envoyer une nouvelle.
    private func cancelPayment() async {
        guard let me = session.userId else { return }
        paymentResponding = true
        defer { paymentResponding = false }
        do {
            _ = try await Edge.call("stripe-manage-payment", EdgeBody(connectionId: conversation.connection.id, action: "cancel"))
            try await supabase.from("messages").insert(NewMessage(
                connectionId: conversation.connection.id,
                senderId: me,
                body: Self.cancelledText
            )).execute()
            await loadMessages()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func refusePayment(_ payment: Payment) async {
        guard let me = session.userId, payment.payerId == me, payment.status == "pending" else { return }
        paymentResponding = true
        defer { paymentResponding = false }
        do {
            _ = try await Edge.call("stripe-respond-payment", EdgeBody(connectionId: conversation.connection.id, action: "refuse"))
            try await supabase.from("messages").insert(NewMessage(
                connectionId: conversation.connection.id,
                senderId: me,
                body: Self.refusedText
            )).execute()
            await loadMessages()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private var parsedAmount: Int? {
        let normalized = paymentAmount.replacingOccurrences(of: ",", with: ".")
        guard let euros = Double(normalized), euros >= 1 else { return nil }
        return Int((euros * 100).rounded())
    }

    private func requestPayment() async {
        guard let amount = parsedAmount, let me = session.userId else { return }
        paymentRequestLoading = true
        defer { paymentRequestLoading = false }
        let service = paymentService.isEmpty ? (conversation.connection.serviceLabel ?? "") : paymentService
        do {
            _ = try await Edge.call(
                "stripe-request-payment",
                EdgeBody(connectionId: conversation.connection.id,
                         amount: amount,
                         description: service.isEmpty ? nil : service,
                         role: "payee")
            )
            let amountText = String(format: "%.2f €", Double(amount) / 100)
            try await supabase.from("messages").insert(NewMessage(
                connectionId: conversation.connection.id,
                senderId: me,
                body: "\(Self.requestPrefix) " + (service.isEmpty ? "" : "\(service) — ") + "\(amountText). Tu peux régler directement depuis cette conversation."
            )).execute()
            paymentAmount = ""
            paymentService = ""
            showPaymentRequest = false
            await loadMessages()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Comme MessageThreadPage : les messages reçus non lus passent en « lu ».
    private func markRead(_ rows: [Message]) async {
        guard let me = session.userId else { return }
        let unread = rows.filter { $0.senderId != me && $0.readAt == nil }.map(\.id)
        guard !unread.isEmpty else { return }
        _ = try? await supabase
            .from("messages")
            .update(ReadPatch(readAt: ISO8601DateFormatter().string(from: Date())))
            .in("id", values: unread)
            .execute()
        // Les notifications de ces messages sont vues aussi : elles ne comptent plus sur l'icône.
        await Inbox.markRead(messageIds: unread)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let me = session.userId else { return }
        Task {
            sending = true
            defer { sending = false }
            do {
                try await supabase
                    .from("messages")
                    .insert(NewMessage(connectionId: conversation.connection.id, senderId: me, body: text))
                    .execute()
                draft = ""
                errorMessage = nil
                await loadMessages()
            } catch {
                guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ConversationIntro: View {
    let other: Profile
    let serviceLabel: String?
    var onServiceTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            Avatar(profile: other, size: 64)
                .padding(3)
                .background(Circle().fill(.white))
                .shadow(color: Theme.primary.opacity(0.15), radius: 10, y: 4)
            Text(other.title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink)
            if let serviceLabel, !serviceLabel.isEmpty {
                if let onServiceTap {
                    Button(action: onServiceTap) {
                        TagChip(text: serviceLabel)
                    }
                    .buttonStyle(.plain)
                } else {
                    TagChip(text: serviceLabel)
                }
            }
            Text("Restez bienveillant·e·s : la charte de la communauté s'applique aussi ici.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }
}

private struct MessageBubble: View {
    let message: Message
    let isMine: Bool
    let showsTime: Bool

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
            HStack {
                if isMine { Spacer(minLength: 50) }
                Text(message.body)
                    .font(.body)
                    .foregroundStyle(isMine ? .white : Theme.ink)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background {
                        if isMine {
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20, bottomLeadingRadius: 20,
                                bottomTrailingRadius: showsTime ? 6 : 20, topTrailingRadius: 20,
                                style: .continuous
                            )
                            .fill(LinearGradient(colors: [Theme.primary, Theme.pink.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        } else {
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20, bottomLeadingRadius: showsTime ? 6 : 20,
                                bottomTrailingRadius: 20, topTrailingRadius: 20,
                                style: .continuous
                            )
                            .fill(.white)
                            .shadow(color: Theme.primary.opacity(0.08), radius: 6, y: 2)
                        }
                    }
                if !isMine { Spacer(minLength: 50) }
            }
            if showsTime {
                HStack(spacing: 4) {
                    Text(DateText.relative(message.createdAt))
                    if isMine, message.readAt != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .accessibilityLabel("Lu")
                    }
                }
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
        }
    }
}
