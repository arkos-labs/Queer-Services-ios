import SwiftUI

struct EventsView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var events: [CommunityEvent] = []
    @State private var attendees: [String: [EventAttendee]] = [:]
    @State private var search = ""
    /// Ville choisie pour filtrer les événements ; nil = toutes les villes.
    @State private var city: String?
    @State private var loading = true
    @State private var busyEventId: String?
    @State private var errorMessage: String?
    @State private var showSignIn = false

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    /// Villes présentes dans les événements, dans l'ordre alphabétique.
    private var cities: [String] {
        Array(Set(events.map(\.city).filter { !$0.isEmpty })).sorted()
    }

    private var filtered: [CommunityEvent] {
        let inCity = city.map { selected in events.filter { $0.city == selected } } ?? events
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return inCity }
        return inCity.filter {
            $0.name.lowercased().contains(q)
                || ($0.description?.lowercased().contains(q) ?? false)
                || $0.city.lowercased().contains(q)
                || ($0.theme?.lowercased().contains(q) ?? false)
        }
    }

    /// Pastille de filtre par ville ; la ville active est en couleur pleine.
    private func cityChip(_ value: String?, label: String) -> some View {
        let active = city == value
        return Button {
            city = value
        } label: {
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(active ? Color.white : Theme.primaryDeep)
                .background(active ? Theme.primary : Theme.primarySoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Événements regroupés par mois, dans l'ordre chronologique.
    private var months: [(title: String, events: [CommunityEvent])] {
        var result: [(title: String, events: [CommunityEvent])] = []
        for event in filtered {
            let title = event.startDate.map { Self.monthFormatter.string(from: $0).capitalized } ?? "À venir"
            if let last = result.last, last.title == title {
                result[result.count - 1].events.append(event)
            } else {
                result.append((title, [event]))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                    if cities.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                cityChip(nil, label: "Toutes les villes")
                                ForEach(cities, id: \.self) { name in
                                    cityChip(name, label: name)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    if loading {
                        SkeletonList()
                    } else if filtered.isEmpty {
                        BrandEmptyState(
                            systemImage: "calendar.badge.clock",
                            title: "Aucun événement à venir",
                            message: "Les prochains événements de la communauté apparaîtront ici."
                        )
                    } else {
                        ForEach(months, id: \.title) { month in
                            Section {
                                ForEach(month.events) { event in
                                    EventCard(
                                        event: event,
                                        attendees: attendees[event.id] ?? [],
                                        isGoing: (attendees[event.id] ?? []).contains { $0.profileId == session.userId },
                                        busy: busyEventId == event.id,
                                        toggle: {
                                            if session.userId == nil {
                                                showSignIn = true
                                            } else {
                                                Task { await toggleGoing(event) }
                                            }
                                        }
                                    )
                                }
                            } header: {
                                MonthHeader(title: month.title, count: month.events.count)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .collapsingBrandHeader("Événements")
            .brandBackground()
            .searchable(text: $search, prompt: "Nom, ville, thème")
            .sheet(isPresented: $showSignIn) { SignInSheet() }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    /// Les événements publiés sont publics ; la liste des participants demande un compte.
    private func load() async {
        defer { loading = false }
        do {
            let today = DateFormats.day.string(from: Date())
            let rows: [CommunityEvent] = try await supabase
                .from("events")
                .select()
                .eq("status", value: "published")
                .gte("event_date", value: today)
                .order("event_date", ascending: true)
                .execute()
                .value
            events = rows
            errorMessage = nil

            guard let me = session.userId, !rows.isEmpty else {
                attendees = [:]
                return
            }
            async let attendeeRows: [EventAttendee] = supabase
                .from("event_attendees")
                .select("event_id, profile_id, profile:profiles(display_name, photo_url, company_name, account_type)")
                .in("event_id", values: rows.map(\.id))
                .execute()
                .value
            async let hidden = BlockList.blockedIds(for: me)

            let blocked = try await hidden
            let grouped = Dictionary(grouping: try await attendeeRows, by: \.eventId)
            attendees = grouped.mapValues { list in
                list.filter { $0.profile != nil && !blocked.contains($0.profileId) }
            }
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func toggleGoing(_ event: CommunityEvent) async {
        guard let me = session.userId, busyEventId == nil else { return }
        busyEventId = event.id
        defer { busyEventId = nil }
        do {
            let going = (attendees[event.id] ?? []).contains { $0.profileId == me }
            if going {
                try await supabase
                    .from("event_attendees")
                    .delete()
                    .eq("event_id", value: event.id)
                    .eq("profile_id", value: me)
                    .execute()
            } else {
                try await supabase
                    .from("event_attendees")
                    .insert(EventAttendeeInsert(eventId: event.id, profileId: me))
                    .execute()
            }
            await load()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}

private struct MonthHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .top, endPoint: .bottom))
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Theme.primarySoft, in: Capsule())
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        // Fond simple et léger : un dégradé animé à chaque image rendait le défilement saccadé.
        .background(.ultraThinMaterial)
        // Le fond va jusqu'aux bords de l'écran : rien ne passe à côté du titre quand il reste épinglé.
        .padding(.horizontal, -16)
    }
}

private struct EventCard: View {
    let event: CommunityEvent
    let attendees: [EventAttendee]
    let isGoing: Bool
    let busy: Bool
    let toggle: () -> Void

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d"
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let photo = event.photoUrl, let url = URL(string: photo) {
                RemoteImage(url: url, maxPixel: 900) {
                    EventPhotoPlaceholder()
                }
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("Photo de \(event.name)")
            }
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Text(event.startDate.map { Self.weekdayFormatter.string(from: $0).uppercased() } ?? "")
                        .font(.caption2.weight(.heavy))
                        .tracking(1)
                    Text(event.startDate.map { Self.dayFormatter.string(from: $0) } ?? "–")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(width: 58, height: 64)
                .background(
                    LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: Theme.primary.opacity(0.3), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(event.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Label(event.address ?? event.city, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    if let theme = event.theme, !theme.isEmpty {
                        TagChip(text: theme)
                    }
                }
                Spacer(minLength: 0)
            }

            if let description = event.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink.opacity(0.8))
                    .lineLimit(3)
            }

            HStack(spacing: 10) {
                AvatarStack(attendees: attendees)
                Text(attendees.isEmpty ? "Sois le·la premier·e" : "\(attendees.count) participant\(attendees.count > 1 ? "s" : "")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button(action: toggle) {
                    Group {
                        if busy {
                            ProgressView()
                        } else if isGoing {
                            Label("J'y vais", systemImage: "checkmark")
                                .foregroundStyle(Theme.primary)
                        } else {
                            Text("J'y vais")
                                .foregroundStyle(.white)
                        }
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background {
                        if isGoing {
                            Capsule().fill(Theme.primarySoft)
                        } else {
                            Capsule().fill(LinearGradient(colors: [Theme.primary, Theme.pink], startPoint: .leading, endPoint: .trailing))
                        }
                    }
                }
                .buttonStyle(BrandPressStyle())
                .disabled(busy)
                .sensoryFeedback(.success, trigger: isGoing)
            }

            if let url = event.websiteUrl, let link = URL(string: url) {
                Link(destination: link) {
                    Label("Site de l'événement", systemImage: "safari")
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .brandCard(cornerRadius: 24)
    }
}

/// Petite pile d'avatars des participants (les 4 premiers).
private struct AvatarStack: View {
    let attendees: [EventAttendee]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(attendees.prefix(4), id: \.profileId) { attendee in
                Avatar(name: attendee.profile?.displayName ?? "", photoUrl: attendee.profile?.photoUrl, size: 28)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
    }
}

/// Dégradé de remplacement quand l'événement n'a pas de photo, ou qu'elle ne charge pas.
private struct EventPhotoPlaceholder: View {
    var body: some View {
        LinearGradient(colors: [Theme.primary, Theme.pink, Theme.rainbowOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                Image(systemName: "calendar")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            )
    }
}
