import SwiftUI

/// Publication d'une demande de mission (même champs que CreateMissionRequestModal côté web).
struct CreateMissionView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    var onPublished: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var budget = ""
    @State private var saving = false
    @State private var errorMessage: String?

    private var canPublish: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
            && description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mission") {
                    TextField("Titre (ex. Aide au déménagement)", text: $title)
                    TextField("Budget indicatif (facultatif)", text: $budget)
                }
                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 160)
                } header: {
                    Text("Description")
                } footer: {
                    Text("Décris ce que tu recherches, le lieu et les dates si besoin.")
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Theme.rose) }
                }
            }
            .brandScreen()
            .navigationTitle("Nouvelle mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publier") { Task { await publish() } }
                        .bold()
                        .disabled(saving || !canPublish)
                }
            }
        }
    }

    private func publish() async {
        guard let me = session.userId else { return }
        saving = true
        defer { saving = false }
        let trimmedBudget = budget.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await supabase
                .from("mission_requests")
                .insert(MissionInsert(
                    createdBy: me,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    budget: trimmedBudget.isEmpty ? nil : trimmedBudget
                ))
                .execute()
            onPublished()
            dismiss()
        } catch {
            guard !Task.isCancelled, !AppError.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
