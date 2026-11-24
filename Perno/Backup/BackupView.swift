import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers
import PernoCore

/// Backup (tavola «Backup»): stato dell'ultimo backup, cartella con «Cambia», copie da tenere,
/// «Esporta adesso» e «Ripristina da file» (con conferma).
struct BackupView: View {
    @Environment(Backup.self) private var backup
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var sessioni: [WorkoutSession]

    @State private var sceltaAperta = false
    @State private var scelta: SceltaFile = .cartella
    @State private var daRipristinare: BackupFile?
    @State private var esportato: FileEsportato?
    @State private var errore: String?

    enum SceltaFile {
        case cartella
        case ripristino
    }

    struct FileEsportato: Identifiable {
        let url: URL
        var id: URL { url }
    }

    /// Con una sessione aperta o interrotta il ripristino non si può fare.
    private var sessioneAperta: Bool { sessioni.contains { $0.endedAt == nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                TestataImpostazioni(titolo: "Backup") { dismiss() }
                stato

                VStack(alignment: .leading, spacing: 12) {
                    EtichettaSezione("Cartella")
                    Button {
                        scelta = .cartella
                        sceltaAperta = true
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(backup.nomeCartella ?? "Nessuna cartella")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.inchiostro)
                                Text(backup.posizione ?? "Consigliata una cartella su iCloud Drive")
                                    .font(.footnote)
                                    .foregroundStyle(Color.inchiostroTenue)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(backup.cartellaScelta ? "Cambia" : "Scegli")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inchiostro)
                        }
                        .vocePila()
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 12) {
                    EtichettaSezione("Copie da tenere")
                    SelettoreSegmenti(valori: BackupFiles.keepChoices,
                                      selezione: Binding(get: { backup.copie }, set: { backup.copie = $0 }),
                                      etichetta: { "\($0)" })
                    Text("A fine sessione scrive una copia nuova, poi cancella la più vecchia.")
                        .font(.footnote)
                        .foregroundStyle(Color.inchiostroTenue)
                        .padding(.leading, 4)
                        .padding(.top, -4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    EtichettaSezione("A mano")
                    Pila {
                        Button(action: esporta) {
                            voce("Esporta adesso", "Un file da salvare o mandare dove vuoi", icona: "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)
                        Button {
                            scelta = .ripristino
                            sceltaAperta = true
                        } label: {
                            voce("Ripristina da file",
                                 sessioneAperta ? "Prima chiudi la sessione in corso"
                                                : "Sostituisce tutti i dati sul telefono, dopo una conferma",
                                 icona: "chevron.right")
                        }
                        .buttonStyle(.plain)
                        .disabled(sessioneAperta)
                        .opacity(sessioneAperta ? 0.5 : 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(isPresented: $sceltaAperta,
                      allowedContentTypes: scelta == .ripristino ? [.json] : [.folder]) { risultato in
            guard case let .success(url) = risultato else { return }
            switch scelta {
            case .cartella:
                if backup.scegliCartella(url) { backup.esegui(context) }
            case .ripristino:
                apri(url)
            }
        }
        .confirmationDialog("Ripristinare questo backup?",
                            isPresented: Binding(get: { daRipristinare != nil }, set: { if !$0 { daRipristinare = nil } }),
                            titleVisibility: .visible, presenting: daRipristinare) { file in
            Button("Ripristina backup", role: .destructive) { ripristina(file) }
            Button("Annulla", role: .cancel) {}
        } message: { file in
            Text("Backup del \(BackupText.dayMonth(file.createdAt)) alle \(ResumeText.time(file.createdAt)): "
                 + "\(BackupText.contents(file)). Tutti i dati sul telefono vengono sostituiti.")
        }
        .alert("Non riuscito", isPresented: Binding(get: { errore != nil }, set: { if !$0 { errore = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errore ?? "")
        }
        .sheet(item: $esportato) { file in
            CondividiFile(url: file.url)
                .ignoresSafeArea()
        }
    }

    // MARK: Stato

    @ViewBuilder
    private var stato: some View {
        let ora = Date.now
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: backup.fallito ? "exclamationmark.triangle" : (backup.ultimo == nil ? "clock" : "checkmark"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.piastraTesto)
                .frame(width: 40, height: 40)
                .background(Color.piastra, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titoloStato(ora))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(backup.fallito ? Color.errore : Color.inchiostro)
                Text(dettaglioStato)
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func titoloStato(_ ora: Date) -> String {
        if backup.fallito { return "Backup non riuscito" }
        if let ultimo = backup.ultimo { return BackupText.lastBackup(ultimo, now: ora) }
        return "Ancora nessun backup"
    }

    private var dettaglioStato: String {
        if backup.fallito {
            return BackupText.failure(folder: backup.nomeCartella ?? "scelta", lastSuccess: backup.ultimo)
        }
        if backup.ultimo != nil {
            return BackupText.detail(afterSession: backup.ultimaSessione, copies: backup.copieNellaCartella,
                                     oldest: backup.piuVecchia)
        }
        return backup.cartellaScelta
            ? "Il primo si scrive a fine sessione."
            : "Scegli una cartella: a fine sessione l'app ci scrive una copia di tutti i dati."
    }

    private func voce(_ titolo: String, _ sottotitolo: String, icona: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                Text(sottotitolo)
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: icona)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.inchiostroTenue)
        }
        .vocePila()
    }

    // MARK: Azioni

    private func esporta() {
        do {
            esportato = FileEsportato(url: try backup.fileDaEsportare(context))
        } catch {
            errore = "Non è stato possibile preparare il file."
        }
    }

    private func apri(_ url: URL) {
        do {
            daRipristinare = try Backup.leggi(url)
        } catch BackupError.newerVersion {
            errore = "Il backup è di una versione più nuova dell'app."
        } catch {
            errore = "Il file non è un backup di Perno."
        }
    }

    private func ripristina(_ file: BackupFile) {
        do {
            try file.ripristina(in: context)
        } catch {
            errore = "Il ripristino non è riuscito."
        }
    }
}

/// Foglio di condivisione di sistema per un file.
struct CondividiFile: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Avviso in Home

/// «Backup non riuscito» in cima alla Home: «Riseleziona cartella» e «Più tardi» (che lo riduce a
/// una riga da toccare per riaprirlo). Resta finché un backup non riesce.
struct AvvisoBackup: View {
    @Environment(Backup.self) private var backup
    @Environment(\.modelContext) private var context
    @State private var ridotto = false
    @State private var scegli = false

    var body: some View {
        Group {
            if ridotto {
                Button {
                    ridotto = false
                } label: {
                    HStack(spacing: 12) {
                        icona
                        Text("Backup non riuscito")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.errore)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        FrecciaVoce()
                    }
                    .vocePila()
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        icona.padding(.top, 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Backup non riuscito")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.errore)
                            Text(BackupText.failure(folder: backup.nomeCartella ?? "scelta", lastSuccess: backup.ultimo))
                                .font(.subheadline)
                                .foregroundStyle(Color.inchiostroTenue)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    HStack(spacing: 8) {
                        Button {
                            scegli = true
                        } label: {
                            Text("Riseleziona cartella")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.suInchiostro)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.inchiostro, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        PulsanteSecondario(titolo: "Più tardi", riempi: false) { ridotto = true }
                    }
                }
                .padding(16)
                .background(Color.foglio, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityElement(children: .contain)
            }
        }
        .fileImporter(isPresented: $scegli, allowedContentTypes: [.folder]) { risultato in
            guard case let .success(url) = risultato, backup.scegliCartella(url) else { return }
            backup.esegui(context)
        }
    }

    private var icona: some View {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.errore)
            .accessibilityHidden(true)
    }
}
