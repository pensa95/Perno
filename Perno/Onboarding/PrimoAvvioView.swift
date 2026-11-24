import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PernoCore

/// Primo avvio (tavole «Benvenuto», «Cartella dei backup», «Backup trovato», «Prima scheda»):
/// Benvenuto → «Dove salvo i backup?» → se nella cartella c'è un backup «Backup trovato»,
/// altrimenti «Da dove parti?».
struct PrimoAvvioView: View {
    /// Come finisce il primo avvio.
    enum Fine {
        case home
        case nuovaScheda
        case sessioneLibera
    }

    let fine: (Fine) -> Void

    @Environment(Backup.self) private var backup
    @Environment(\.modelContext) private var context

    private enum Passo {
        case benvenuto
        case cartella
        case trovato
        case primaScheda
    }

    private enum SceltaFile {
        case cartella
        case copia
    }

    private struct CopiaLetta {
        let file: BackupFile
        /// Copia presa dalla cartella dei backup (non da un file scelto a parte).
        let dallaCartella: Bool
    }

    @State private var passo: Passo = .benvenuto
    @State private var sceltaAperta = false
    @State private var scelta: SceltaFile = .cartella
    /// La cartella si sceglie da «Ripristina da backup» (senza backup resta sul Benvenuto).
    @State private var perRipristinare = false
    @State private var copie: [String] = []
    @State private var copia: CopiaLetta?
    @State private var altreCopieAperte = false
    @State private var errore: String?

    var body: some View {
        Group {
            switch passo {
            case .benvenuto: benvenuto
            case .cartella: cartella
            case .trovato: trovato
            case .primaScheda: primaScheda
            }
        }
        .animation(.easeInOut(duration: 0.25), value: passo)
        .background(Color.lamiera.ignoresSafeArea())
        .fileImporter(isPresented: $sceltaAperta,
                      allowedContentTypes: scelta == .copia ? [.json] : [.folder]) { risultato in
            guard case let .success(url) = risultato else { return }
            switch scelta {
            case .cartella: cartellaScelta(url)
            case .copia: copiaScelta(url)
            }
        }
        .alert("Non riuscito", isPresented: Binding(get: { errore != nil }, set: { if !$0 { errore = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errore ?? "")
        }
    }

    // MARK: Benvenuto

    private var benvenuto: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                PernoMark()
                    .frame(width: 136, height: 136)
                    .background(Color.foglio, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                Text("Perno")
                    .font(.piastra(64))
                    .foregroundStyle(Color.inchiostro)
                Text("Infila il perno, fai il set.")
                    .font(.body)
                    .foregroundStyle(Color.inchiostroTenue)
            }
            Spacer()
            VStack(spacing: 8) {
                Text("Schede, set e tempi restano sul telefono. Funziona anche senza rete.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inchiostroTenue)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
                PulsanteGiallo(titolo: "Inizia") {
                    perRipristinare = false
                    passo = .cartella
                }
                pulsanteTesto("Ripristina da backup") {
                    perRipristinare = true
                    apriScelta(.cartella)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Dove salvo i backup?

    private var cartella: some View {
        pagina(indietro: { passo = .benvenuto }) {
            Image(systemName: "folder")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.piastraTesto)
                .frame(width: 56, height: 56)
                .background(Color.piastra, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 24)
                .accessibilityHidden(true)
            titolo("Dove salvo i backup?")
                .padding(.top, 20)
            testo("Dopo ogni sessione l'app scrive una copia dei tuoi dati in una cartella. Se reinstalli l'app o cambi telefono, la ritrovi lì.")
            Pila {
                vantaggio("Meglio su iCloud Drive", "Sopravvive anche se il telefono si rompe")
                vantaggio("Una cartella sola per l'app", "Per esempio «Palestra». Si cambia in Impostazioni")
            }
            .padding(.top, 24)
        } pulsanti: {
            PulsanteGiallo(titolo: "Scegli cartella") {
                perRipristinare = false
                apriScelta(.cartella)
            }
            pulsanteTesto("Più tardi") { passo = .primaScheda }
        }
    }

    // MARK: Backup trovato

    private var trovato: some View {
        pagina(indietro: { passo = .cartella }) {
            titolo("Backup trovato")
                .padding(.top, 24)
            if let copia {
                testo(copia.dallaCartella
                      ? BackupText.found(folder: backup.nomeCartella ?? "scelta")
                      : "Nel file che hai scelto c'è una copia dei tuoi dati.")
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copia.dallaCartella && copia.file.createdAt == dataCopia(copie.first)
                             ? "Copia più recente" : "Copia scelta")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.inchiostroTenue)
                        Text(BackupText.copyDate(copia.file.createdAt))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.inchiostro)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        numero(copia.file.finishedSessionCount, "sessioni")
                        numero(copia.file.routines.count, "schede")
                        numero(copia.file.exercises.count, "esercizi")
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.foglio, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 24)
                .accessibilityElement(children: .combine)
            }
            Button {
                altreCopieAperte = true
            } label: {
                VocePila(titolo: "Scegli un'altra copia",
                         sottotitolo: BackupText.otherCopies(max(0, copie.count - 1), oldest: dataCopia(copie.last))
                            ?? "Da un file in un'altra cartella")
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .confirmationDialog("Scegli una copia", isPresented: $altreCopieAperte, titleVisibility: .visible) {
                ForEach(copie, id: \.self) { nome in
                    if let data = dataCopia(nome) {
                        Button(BackupText.copyDate(data)) { leggiCopia(nome) }
                    }
                }
                Button("Da un altro file") { apriScelta(.copia) }
                Button("Annulla", role: .cancel) {}
            }
        } pulsanti: {
            PulsanteGiallo(titolo: "Ripristina backup", attivo: copia != nil, azione: ripristina)
            pulsanteTesto("Parti da zero") { passo = .primaScheda }
        }
    }

    // MARK: Da dove parti?

    private var primaScheda: some View {
        pagina(indietro: { passo = .cartella }) {
            titolo("Da dove parti?")
                .padding(.top, 24)
            testo("Una scheda è l'elenco degli esercizi di un allenamento, con set e ripetizioni. Poi le metti nei giorni della settimana.")
            Pila {
                Button { fine(.nuovaScheda) } label: {
                    VocePila(titolo: "Scrivi la tua scheda",
                             sottotitolo: "Copia quella che hai in Note: esercizi, regolazioni, promemoria")
                }
                .buttonStyle(.plain)
                Button { fine(.sessioneLibera) } label: {
                    VocePila(titolo: "Allenati senza scheda",
                             sottotitolo: "Sessione libera: scegli gli esercizi strada facendo")
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
        } pulsanti: {
            PulsanteGiallo(titolo: "Crea la prima scheda") { fine(.nuovaScheda) }
        }
    }

    // MARK: Azioni

    private func apriScelta(_ tipo: SceltaFile) {
        scelta = tipo
        sceltaAperta = true
    }

    private func cartellaScelta(_ url: URL) {
        guard backup.scegliCartella(url) else {
            errore = "Non è stato possibile usare questa cartella."
            return
        }
        copie = backup.copieInCartella()
        guard let piuRecente = copie.first else {
            if perRipristinare {
                errore = "Nella cartella non ci sono backup di Perno."
            } else {
                passo = .primaScheda
            }
            return
        }
        leggiCopia(piuRecente)
    }

    private func leggiCopia(_ nome: String) {
        do {
            copia = CopiaLetta(file: try backup.leggiCopia(nome), dallaCartella: true)
            passo = .trovato
        } catch BackupError.newerVersion {
            errore = "Il backup è di una versione più nuova dell'app."
        } catch {
            errore = "Questa copia non si riesce a leggere."
        }
    }

    private func copiaScelta(_ url: URL) {
        do {
            copia = CopiaLetta(file: try Backup.leggi(url), dallaCartella: false)
            passo = .trovato
        } catch BackupError.newerVersion {
            errore = "Il backup è di una versione più nuova dell'app."
        } catch {
            errore = "Il file non è un backup di Perno."
        }
    }

    private func ripristina() {
        guard let copia else { return }
        do {
            try copia.file.ripristina(in: context)
            fine(.home)
        } catch {
            errore = "Il ripristino non è riuscito."
        }
    }

    private func dataCopia(_ nome: String?) -> Date? {
        nome.flatMap { BackupFiles.date(fromName: $0) }
    }

    // MARK: Pezzi

    /// Pagina con la freccia indietro in alto e i pulsanti fissi in basso.
    private func pagina<Contenuto: View, Pulsanti: View>(indietro: @escaping () -> Void,
                                                         @ViewBuilder contenuto: () -> Contenuto,
                                                         @ViewBuilder pulsanti: () -> Pulsanti) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: indietro) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.inchiostro)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, -10)
                    .accessibilityLabel("Indietro")
                    contenuto()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 8) { pulsanti() }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
        }
    }

    private func titolo(_ testo: String) -> some View {
        Text(testo)
            .font(.piastra(40))
            .foregroundStyle(Color.inchiostro)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func testo(_ testo: String) -> some View {
        Text(testo)
            .font(.body)
            .foregroundStyle(Color.inchiostroTenue)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
    }

    private func vantaggio(_ titolo: String, _ sottotitolo: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.inchiostro)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                Text(sottotitolo)
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func numero(_ valore: Int, _ etichetta: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(valore)")
                .font(.piastra(40))
                .monospacedDigit()
                .foregroundStyle(Color.inchiostro)
            Text(etichetta)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.inchiostroTenue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pulsanteTesto(_ titolo: String, azione: @escaping () -> Void) -> some View {
        Button(action: azione) {
            Text(titolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.plain)
    }
}
