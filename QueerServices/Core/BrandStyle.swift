import SwiftUI

extension View {
    /// Fond violet clair du site (body bg-paper-base) à la place du gris système des listes.
    /// Les lignes restent blanches, comme les cartes du site.
    func brandScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
    }
}
