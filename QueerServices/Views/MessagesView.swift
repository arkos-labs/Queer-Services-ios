import SwiftUI

/// Une conversation avec son interlocuteur et le dernier message.
struct Conversation: Identifiable, Hashable {
    let connection: Connection
    let other: Profile
    let lastMessage: Message?

    var id: String { connection.id }
}

/// Toutes les demandes d'un même membre, rangées ensemble.
struct ConversationGroup: Identifiable {
    let other: Profile
    var items: [Conversation]

    var id: String { other.id }
}

/// Enveloppe : une personne, puis la liste de toutes ses demandes avec leur titre.
private struct ConversationEnvelope: View {
    let other: Profile
    let items: [Conversation]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Avatar(profile: other, size: 40)
                Text(other.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer()
                Text("\(items.count) demandes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            ForEach(items) { conversation in
                NavigationLink(value: conversation) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(Theme.primary)
                        Text(conversation.connection.serviceLabel ?? "Demande de service")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(DateText.relative(conversation.lastMessage?.createdAt))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 6)
    }
}

struct MessagesView: View {
    @EnvironmentObject private var session: SessionStore

    @EnvironmentObject private var router: TabRouter
    @State private var path: [Conversation] = []
    @State private var conversations: [Conversation] = []
    @State private var loading = true
    @State private var errorMessage: String?
    /// Enveloppe : affiche les prestations clôturées à la place des conversations en cours.
    @State private var showClosed = false

    private var visibleConversations: [Conversation] {
        conversations.filter { ($0.connection.status == "completed") == showClosed }
    }

    /// Conversations regroupées par membre : plusieurs demandes d'une même personne partagent une enveloppe.
    private var groupedConversations: [ConversationGroup] {
        var groups: [ConversationGroup] = []
        for conversation in visibleConversations {
            if let index = groups.firstIndex(where: { $0.other.id == conversation.other.id }) {
                groups[index].items.append(conversation)
            } else {
                groups.append(ConversationGroup(other: conversation.other, items: [conversation]))
            }
        }
        return groups
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 14) {
                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if session.userId == nil && !DemoMode.isOn {
                        SignInPrompt(message: "Connecte-toi pour retrouver tes échanges avec les membres.")
                    } else if loading {
                        SkeletonList()
                    } else if visibleConversations.isEmpty {
                        BrandEmptyState(
                            systemImage: showClosed ? "envelope.open.fill" : "bubble.left.and.bubble.right.fill",
                            title: showClosed ? "Aucune prestation clôturée" : "Aucune conversation",
                            message: showClosed
                                ? "Les prestations que tu clôtures apparaîtront ici."
                                : "Tes échanges avec les membres apparaîtront ici. Postule à une mission pour démarrer."
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(groupedConversations) { group in
                                if group.items.count == 1, let conversation = group.items.first {
                                    NavigationLink(value: conversation) {
                                        ConversationRow(conversation: conversation, me: session.userId)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    ConversationEnvelope(other: group.other, items: group.items)
                                }
                                if group.id != groupedConversations.last?.id {
                                    Divider().padding(.leading, 82)
                                }
                            }
                        }
                        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Theme.primary.opacity(0.08), radius: 14, y: 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .collapsingBrandHeader(showClosed ? "Prestations clôturées" : "Messages")
            .brandBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showClosed.toggle()
                    } label: {
                        Image(systemName: showClosed ? "bubble.left.and.bubble.right.fill" : "envelope.fill")
                    }
                    .accessibilityLabel(showClosed ? "Voir les conversations" : "Voir les prestations clôturées")
                }
            }
            .navigationDestination(for: Conversation.self) { ThreadView(conversation: $0) }
            .refreshable { await load() }
            .task { await load() }
            .onAppear {
                // Recalcule immédiatement les conversations au retour d'une discussion.
                Task { await load() }
            }
        }
    }

    /// Ouvre la conversation liée à une notification, si elle est dans la liste.
    private func openPendingConversation() {
        guard let id = router.pendingConnectionId,
              let conversation = conversations.first(where: { $0.connection.id == id })
        else { return }
        router.pendingConnectionId = nil
        path = [conversation]
    }

    private func load() async {
        if DemoMode.isOn { conversations = DemoMode.conversations; loading = false; return }
        guard let me = session.userId else {
            loading = false
            return
        }
        defer { loading = false }
        do {
            async let blocked = BlockList.blockedIds(for: me)
            let connections: [Connection] = try await supabase
                .from("connections")
                .select()
                .or("user_a.eq.\(me),user_b.eq.\(me)")
                .order("updated_at", ascending: false)
                .execute()
                .value
            let hidden = try await blocked
            let visible = connections.filter { !hidden.contains($0.otherUserId(for: me)) }

            let otherIds = Array(Set(visible.map { $0.otherUserId(for: me) }))
            let connectionIds = visible.map(\.id)

            async let profilesReq: [Profile] = otherIds.isEmpty ? [] : supabase
                .from("profiles")
                .select(publicProfileColumns)
                .in("id", values: otherIds)
                .execute()
                .value
            async let messagesReq: [Message] = connectionIds.isEmpty ? [] : supabase
                .from("messages")
                .select()
                .in("connection_id", values: connectionIds)
                .order("created_at", ascending: true)
                .execute()
                .value

            let profilesById = Dictionary(uniqueKeysWithValues: try await profilesReq.map { ($0.id, $0) })
            let lastByConnection = Dictionary(grouping: try await messagesReq, by: \.connectionId)
                .compactMapValues { $0.last }

            conversations = visible.compactMap { connection in
                guard let other = profilesById[connection.otherUserId(for: me)] else { return nil }
                return Conversation(connection: connection, other: other, lastMessage: lastByConnection[connection.id])
            }
            errorMessage = nil
            openPendingConversation()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let me: String?

    private var isUnread: Bool {
        guard let last = conversation.lastMessage else { return false }
        return last.senderId != me && last.readAt == nil
    }

    var body: some View {
        HStack(spacing: 14) {
            Avatar(profile: conversation.other, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.other.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(DateText.relative(conversation.lastMessage?.createdAt))
                        .font(.caption)
                        .foregroundStyle(isUnread ? Theme.primary : Theme.muted)
                }
                HStack(spacing: 6) {
                    if conversation.connection.status == "pending" {
                        TagChip(text: "En attente", color: Theme.amber)
                    }
                    Text(conversation.lastMessage?.body ?? conversation.connection.serviceLabel ?? "Nouvelle conversation")
                        .font(.subheadline.weight(isUnread ? .semibold : .regular))
                        .foregroundStyle(isUnread ? Theme.ink : Theme.muted)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if isUnread {
                        Circle()
                            .fill(LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .top, endPoint: .bottom))
                            .frame(width: 10, height: 10)
                            .accessibilityLabel("Non lu")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
