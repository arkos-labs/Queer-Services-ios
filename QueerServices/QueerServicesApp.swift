import SwiftUI
import StripePaymentSheet

@main
struct QueerServicesApp: App {
    @StateObject private var session = SessionStore()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        BrandAppearance.apply()
        if !AppConfig.stripePublishableKey.isEmpty {
            StripeAPI.defaultPublishableKey = AppConfig.stripePublishableKey
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(Theme.primary)
                // Le site est toujours clair : évite le texte noir sur fond sombre.
                .preferredColorScheme(.light)
                .task { await session.bootstrap() }
        }
    }
}

/// Aiguille l'utilisateur : connexion → onboarding (prénom) → application.
struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launchIntroFinished = false

    private var showsLaunch: Bool { session.isBootstrapping || !launchIntroFinished }

    var body: some View {
        Group {
            // Connexion retirée à nouveau : AuthView et OnboardingView sont conservés
            // dans le projet mais ne sont plus affichés.
            if showsLaunch {
                SplashView { launchIntroFinished = true }
                    .transition(.opacity)
            } else {
                appContent
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: showsLaunch)
        // Pastille de l'icône : à l'ouverture et à la connexion, on affiche les notifications non vues.
        .onChange(of: scenePhase) { _, phase in
            if !DemoMode.isOn, phase == .active, let me = session.userId {
                Task { _ = await Inbox.refresh(for: me) }
            }
        }
        .onChange(of: session.userId) { _, id in
            if !DemoMode.isOn, let id { Task { _ = await Inbox.refresh(for: id) } }
        }
    }

    @ViewBuilder private var appContent: some View {
        #if DEBUG
        if DemoMode.isOn, ProcessInfo.processInfo.environment["QS_SCREENSHOT_TOUR"] == "1" {
            ScreenshotTourView()
        } else {
            MainTabView()
        }
        #else
        MainTabView()
        #endif
    }
}

#if DEBUG
/// Capture des vues réelles de l'app avec uniquement les profils fictifs locaux.
private struct ScreenshotTourView: View {
    @State private var page = 0
    @StateObject private var router = TabRouter()
    private let tabs: [TabRouter.Tab] = [.directory, .missions, .messages, .profile]

    var body: some View {
        Group {
            if page < tabs.count {
                MainTabView(screenshotTab: tabs[page]).id(page)
            } else {
                NavigationStack {
                    ProfileDetailView(profile: DemoMode.profiles[page == 4 ? 0 : 2])
                }
                .environmentObject(router)
                .id(page)
            }
        }
        .task {
            do {
                for index in 0..<6 {
                    try Task.checkCancellation()
                    page = index
                    try await Task.sleep(for: .seconds(4))
                }
            } catch { return }
        }
    }
}
#endif
