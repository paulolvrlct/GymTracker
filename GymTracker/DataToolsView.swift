import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Mes données

/// Reprendre son historique d'une autre app, sauvegarder et restaurer ses
/// données. Gratuit : c'est ce qui donne confiance pour changer d'app.
struct DataToolsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("lastBackupDate") private var lastBackup: Double = 0

    private enum Picking { case history, backup }

    @State private var picking: Picking?
    @State private var showPicker = false
    @State private var importText: String?
    @State private var parsed: HistoryImport.Parsed?
    @State private var pounds = false
    @State private var message: String?
    @State private var backupURL: URL?
    @State private var pendingRestore: LiftRunBackup?

    var body: some View {
        List {
            Section {
                Button {
                    open(.history)
                } label: {
                    Label("Importer depuis Strong ou Hevy", systemImage: "square.and.arrow.down")
                }
                if let parsed { preview(parsed) }
            } header: {
                Text("Changer d'app sans repartir de zéro")
            } footer: {
                Text("Dans Strong ou Hevy, exporte tes données en CSV depuis les réglages, enregistre le fichier dans Fichiers, puis ouvre-le ici. Séances, séries et charges rejoignent ton historique ; les échauffements ne sont pas repris.")
            }

            Section {
                Button {
                    createBackup()
                } label: {
                    Label("Créer une sauvegarde", systemImage: "externaldrive.badge.icloud")
                }
                Button {
                    open(.backup)
                } label: {
                    Label("Restaurer une sauvegarde", systemImage: "clock.arrow.circlepath")
                }
                if lastBackup > 0 {
                    LabeledContent("Dernière sauvegarde",
                                   value: Date(timeIntervalSince1970: lastBackup)
                                    .formatted(.relative(presentation: .named)))
                }
            } header: {
                Text("Sauvegarde")
            } footer: {
                Text("Un seul fichier avec tout : séances, courses, nutrition et réglages. Enregistre-le dans Fichiers › iCloud Drive pour le retrouver sur un autre iPhone. La sauvegarde iCloud de ton iPhone inclut aussi les données de LiftRun.")
            }

            if let message {
                Section {
                    Text(message)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Mes données")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showPicker,
                      allowedContentTypes: picking == .backup
                        ? [.json]
                        : [.commaSeparatedText, .plainText, .text]) { result in
            handlePick(result)
        }
        .sheet(item: $backupURL) { url in ShareSheet(url: url) }
        .alert("Restaurer cette sauvegarde ?",
               isPresented: Binding(get: { pendingRestore != nil },
                                    set: { if !$0 { pendingRestore = nil } }),
               presenting: pendingRestore) { backup in
            Button("Restaurer", role: .destructive) { restore(backup) }
            Button("Annuler", role: .cancel) {}
        } message: { backup in
            Text("Toutes les données actuelles seront remplacées par celles du \(backup.createdAt.formatted(date: .long, time: .shortened)) : \(backup.sessions.count) séances et \(backup.runs.count) courses.")
        }
    }

    @ViewBuilder
    private func preview(_ parsed: HistoryImport.Parsed) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sourceName(parsed.source))
                .font(.headline)
            Text("\(parsed.workouts.count) séances · \(parsed.setCount) séries")
                .font(.subheadline)
            if let first = parsed.workouts.first?.date, let last = parsed.workouts.last?.date {
                Text("Du \(first.formatted(date: .abbreviated, time: .omitted)) au \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        if parsed.needsUnitChoice {
            Picker("Unité des charges", selection: $pounds) {
                Text("kg").tag(false)
                Text("lb").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: pounds) {
                if let importText { self.parsed = HistoryImport.parse(importText, pounds: pounds) }
            }
        }
        Button {
            runImport(parsed)
        } label: {
            Label("Importer ces séances", systemImage: "checkmark.circle.fill")
        }
        .disabled(parsed.workouts.isEmpty)
    }

    private func sourceName(_ source: HistoryImport.Source) -> String {
        switch source {
        case .strong: String(localized: "Export Strong")
        case .hevy: String(localized: "Export Hevy")
        case .liftRun: String(localized: "Export LiftRun")
        }
    }

    // MARK: Actions

    private func open(_ kind: Picking) {
        picking = kind
        message = nil
        showPicker = true
    }

    private func handlePick(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            message = String(localized: "Impossible de lire ce fichier.")
            return
        }
        switch picking {
        case .history:
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) ?? ""
            importText = text
            pounds = false
            parsed = HistoryImport.parse(text)
            if parsed == nil {
                message = String(localized: "Ce fichier n'est pas un export reconnu. LiftRun lit les exports CSV de Strong, de Hevy et de LiftRun.")
            }
        case .backup:
            do {
                pendingRestore = try BackupManager.decode(data)
            } catch let error as BackupManager.BackupError {
                message = error.localizedDescription
            } catch {
                message = String(localized: "Ce fichier n'est pas une sauvegarde LiftRun.")
            }
        case nil:
            break
        }
    }

    private func runImport(_ parsed: HistoryImport.Parsed) {
        let result = HistoryImport.insert(parsed.workouts, into: context)
        self.parsed = nil
        importText = nil
        var text = String(localized: "\(result.added) séances ajoutées à ton historique.")
        if result.duplicates > 0 {
            text += " " + String(localized: "\(result.duplicates) déjà présentes, laissées de côté.")
        }
        message = text
    }

    private func createBackup() {
        do {
            backupURL = try BackupManager.write(BackupManager.make(context: context))
            lastBackup = Date.now.timeIntervalSince1970
        } catch {
            message = String(localized: "La sauvegarde n'a pas pu être créée. Vérifie l'espace de stockage puis réessaie.")
        }
    }

    private func restore(_ backup: LiftRunBackup) {
        do {
            try BackupManager.restore(backup, into: context)
            message = String(localized: "Sauvegarde restaurée : \(backup.sessions.count) séances et \(backup.runs.count) courses.")
        } catch {
            message = String(localized: "La restauration a échoué. Tes données actuelles n'ont pas été modifiées.")
        }
        pendingRestore = nil
    }
}
