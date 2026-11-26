import SwiftUI
import UIKit
import Observation
import PernoCore

/// Chiavi e valori predefiniti delle Impostazioni (salvate in UserDefaults, non nel database).
enum Impostazioni {
    static let riscaldamento = "impostazioni.riscaldamento"
    static let bip = "impostazioni.bip"
    static let vibrazione = "impostazioni.vibrazione"
    /// Stessa chiave usata in sessione quando si tocca il tempo del recupero.
    /// Recupero scelto fino alla UI v5 (nelle Impostazioni): dalla v6 è nell'esercizio della scheda; restano
    /// solo per la migrazione allo SchemaV3 e per i backup vecchi.
    static let modoRecupero = "recupero.modo"
    static let partiDaSolo = "impostazioni.partiDaSolo"
    /// «Chiedi com'è andato» (UI v6; stessa chiave della vecchia «Chiedi quante ne avevi ancora»).
    static let chiediFaccina = "impostazioni.chiediRiserva"
    static let unita = "impostazioni.unita"
    static let passo = "impostazioni.passo"

    /// Durata del 3-2-1 scelta fino alla UI v5 (3, 5 o 10 s): dalla v6 il 3-2-1 dura sempre 3 s
    /// e il valore salvato si cancella.
    private static let vecchiSecondiPrimaDelSet = "impostazioni.secondiPrimaDelSet"

    /// Valori predefiniti della tavola: riscaldamento, bip, vibrazione e riserva attivi,
    /// recupero a cronometro senza partenza automatica, chili con passo 2,5.
    static func registraPredefiniti() {
        UserDefaults.standard.removeObject(forKey: vecchiSecondiPrimaDelSet)
        UserDefaults.standard.register(defaults: [
            riscaldamento: true,
            bip: true,
            vibrazione: true,
            modoRecupero: RestMode.stopwatch.rawValue,
            partiDaSolo: false,
            chiediFaccina: true,
            unita: WeightUnit.kilograms.rawValue,
            passo: PlateStep.standard,
        ])
    }

    static var riscaldamentoAttivo: Bool { UserDefaults.standard.bool(forKey: riscaldamento) }

    /// Porta «Unità e dischi» in `PernoCore` (formati dei pesi e passo dei dischi).
    static func applicaUnita() {
        let difese = UserDefaults.standard
        Units.unit = difese.string(forKey: unita).flatMap(WeightUnit.init(rawValue:)) ?? .kilograms
        let passoSalvato = difese.double(forKey: passo)
        Units.step = Units.steps.contains(passoSalvato) ? passoSalvato : PlateStep.standard
    }
}

/// Aspetto chiaro o scuro. All'avvio l'app segue l'iPhone; la scelta manuale vale finché l'iPhone
/// non cambia aspetto da solo, poi l'app torna a seguirlo (controllo al ritorno in primo piano e
/// ogni minuto).
@Observable
final class Aspetto {
    /// Scelta manuale; `nil` = come l'iPhone.
    private(set) var scelto: ColorScheme?
    /// Aspetto dell'iPhone quando è stata fatta la scelta.
    private var sistemaAllaScelta: UIUserInterfaceStyle = .unspecified

    /// Aspetto dell'iPhone, senza la scelta dell'app.
    var sistema: ColorScheme {
        UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    /// Aspetto in uso (per il selettore delle Impostazioni).
    var attuale: ColorScheme { scelto ?? sistema }

    func scegli(_ aspetto: ColorScheme) {
        sistemaAllaScelta = UIScreen.main.traitCollection.userInterfaceStyle
        scelto = aspetto == sistema ? nil : aspetto
    }

    /// Se l'iPhone ha cambiato aspetto da solo, la scelta manuale si toglie.
    func controllaSistema() {
        guard scelto != nil, UIScreen.main.traitCollection.userInterfaceStyle != sistemaAllaScelta else { return }
        scelto = nil
    }
}

// MARK: - Impostazioni

/// Impostazioni (tavola «Impostazioni», sezione della barra dal 24/11): Aspetto, Riscaldamento, Segnali (3-2-1 sempre 3 s; il recupero è nell'esercizio della scheda, UI v6),
/// Dopo ogni set, Dati.
struct ImpostazioniView: View {
    @Environment(Aspetto.self) private var aspetto

    @AppStorage(Impostazioni.riscaldamento) private var riscaldamento = true
    @AppStorage(Impostazioni.bip) private var bip = true
    @AppStorage(Impostazioni.vibrazione) private var vibrazione = true
    @AppStorage(Impostazioni.chiediFaccina) private var chiediFaccina = true
    @AppStorage(Impostazioni.unita) private var unita: WeightUnit = .kilograms
    @AppStorage(Impostazioni.passo) private var passo = PlateStep.standard

    @State private var unitaAperta = false
    @State private var backupAperto = false
    @Environment(Backup.self) private var backup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                TestataSezione(titolo: Sezione.impostazioni.titolo)

                sezione("Aspetto", nota: "Se l'iPhone passa da solo da chiaro a scuro, l'app fa lo stesso.") {
                    SelettoreSegmenti(valori: [ColorScheme.light, .dark],
                                      selezione: Binding(get: { aspetto.attuale }, set: { aspetto.scegli($0) }),
                                      etichetta: { $0 == .dark ? "Scuro" : "Chiaro" })
                }

                sezione("Riscaldamento") {
                    Interruttore(titolo: "Inizia con il riscaldamento",
                                 sottotitolo: "In ogni sessione, anche libera. Puoi sempre saltarlo",
                                 acceso: $riscaldamento)
                }

                sezione("Segnali", nota: "Il 3-2-1 prima di ogni set dura sempre 3 s. Il recupero si sceglie in ogni esercizio della scheda.") {
                    Pila {
                        Interruttore(titolo: "Bip",
                                     sottotitolo: "Anche a schermo bloccato, sopra la musica che si abbassa un attimo",
                                     acceso: $bip)
                        Interruttore(titolo: "Vibrazione", sottotitolo: "Utile con il telefono in silenzioso",
                                     acceso: $vibrazione)
                    }
                }

                sezione("Dopo ogni set") {
                    Interruttore(titolo: "Chiedi com'è andato",
                                 sottotitolo: "Leggero, giusto o faticoso. Serve a capire quando aumentare il peso",
                                 acceso: $chiediFaccina)
                }

                sezione("Dati") {
                    Pila {
                        Button {
                            unitaAperta = true
                        } label: {
                            VocePila(titolo: "Unità e dischi", sottotitolo: Units.summary(unit: unita, step: passo))
                        }
                        .buttonStyle(.plain)
                        Button {
                            backupAperto = true
                        } label: {
                            VocePila(titolo: "Backup",
                                     sottotitolo: BackupText.settingsSummary(location: backup.posizione,
                                                                             folder: backup.nomeCartella,
                                                                             last: backup.ultimo,
                                                                             failed: backup.fallito, now: .now))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $unitaAperta) { UnitaDischiView() }
        .navigationDestination(isPresented: $backupAperto) { BackupView() }
        .onAppear { aspetto.controllaSistema() }
    }

    private func sezione<Content: View>(_ titolo: String, nota: String? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EtichettaSezione(titolo)
            content()
            if let nota {
                Text(nota)
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
                    .padding(.leading, 4)
                    .padding(.top, -4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Unità e dischi

/// Unità e dischi (tavola «Unità e dischi»): Chili / Libbre, passo 1 / 1,25 / 2,5 / 5 ed esempio.
struct UnitaDischiView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Impostazioni.unita) private var unita: WeightUnit = .kilograms
    @AppStorage(Impostazioni.passo) private var passo = PlateStep.standard

    var body: some View {
        let esempio = Units.example(step: passo)
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                TestataImpostazioni(titolo: "Unità e dischi") { dismiss() }

                VStack(alignment: .leading, spacing: 12) {
                    EtichettaSezione("Unità")
                    SelettoreSegmenti(valori: WeightUnit.allCases,
                                      selezione: Binding(get: { unita }, set: { unita = $0; Impostazioni.applicaUnita() }),
                                      etichetta: \.name)
                    nota("Cambia solo come si leggono i pesi: lo storico viene convertito.")
                }

                VStack(alignment: .leading, spacing: 12) {
                    EtichettaSezione("Passo dei dischi")
                    SelettoreSegmenti(valori: Units.steps,
                                      selezione: Binding(get: { passo }, set: { passo = $0; Impostazioni.applicaUnita() }),
                                      etichetta: Weights.format)
                    nota("Di quanto sale il peso suggerito e come si arrotondano gli avvicinamenti.")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Con passo \(Weights.format(passo))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inchiostroTenue)
                    riga("Prossimo aumento", esempio.increase)
                    riga("Avvicinamento al 75%", esempio.approach)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.foglio, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func nota(_ testo: String) -> some View {
        Text(testo)
            .font(.footnote)
            .foregroundStyle(Color.inchiostroTenue)
            .padding(.leading, 4)
            .padding(.top, -4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func riga(_ titolo: String, _ valore: String) -> some View {
        HStack {
            Text(titolo)
                .font(.subheadline)
                .foregroundStyle(Color.inchiostro)
            Spacer()
            Text(valore)
                .font(.piastra(26))
                .monospacedDigit()
                .foregroundStyle(Color.inchiostro)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Componenti delle Impostazioni

/// Testata con la freccia indietro a sinistra e il titolo al centro.
struct TestataImpostazioni: View {
    let titolo: String
    let indietro: () -> Void

    var body: some View {
        ZStack {
            Text(titolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
            HStack {
                Button(action: indietro) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.inchiostro)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Indietro")
                Spacer()
            }
        }
    }
}

/// Voce della pila con titolo, sottotitolo e interruttore.
struct Interruttore: View {
    let titolo: String
    let sottotitolo: String
    @Binding var acceso: Bool

    var body: some View {
        Toggle(isOn: $acceso) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                Text(sottotitolo)
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(StileInterruttore())
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Interruttore con le misure di quello di sistema (51 × 31). Acceso: binario inchiostro e pallino
/// `suInchiostro`, così resta leggibile anche nel tema scuro (dove l'inchiostro è quasi bianco e il
/// pallino bianco di sistema spariva). Spento: binario grigio e pallino bianco, come quello di sistema.
struct StileInterruttore: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let acceso = configuration.isOn
        HStack(spacing: 12) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
            ZStack(alignment: acceso ? .trailing : .leading) {
                Capsule()
                    .fill(acceso ? Color.inchiostro : Color.inchiostroTenue.opacity(0.32))
                Circle()
                    .fill(acceso ? Color.suInchiostro : Color.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                    .padding(2)
            }
            .frame(width: 51, height: 31)
            .animation(.snappy(duration: 0.22), value: acceso)
        }
        .contentShape(Rectangle())
        .onTapGesture { configuration.isOn.toggle() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(acceso ? "Attivo" : "Disattivo")
        .accessibilityAction { configuration.isOn.toggle() }
    }
}
