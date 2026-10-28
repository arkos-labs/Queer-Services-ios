import SwiftUI
import UIKit

struct PaymentSettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var loading = false
    @State private var link: URL?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Label("Recevoir des paiements", systemImage: "creditcard.fill")
                    .font(.headline)
                Text("Active Stripe pour recevoir les paiements de tes prestations directement dans l’application.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Section {
                Button {
                    Task { await activate() }
                } label: {
                    Label(loading ? "Ouverture…" : "Activer les paiements", systemImage: "arrow.up.right.square")
                }
                .disabled(loading)
                if let link {
                    Link("Reprendre la vérification Stripe", destination: link)
                }
            }
            if let errorMessage { Section { Text(errorMessage).foregroundStyle(Theme.rose) } }
        }
        .navigationTitle("Paiements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func activate() async {
        loading = true
        defer { loading = false }
        do {
            let base = "https://queerservices.fr/parametres?stripe=return"
            let response = try await Edge.call("stripe-connect-onboarding", EdgeBody(returnUrl: base, refreshUrl: base))
            guard let urlString = response.url, let url = URL(string: urlString) else {
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
