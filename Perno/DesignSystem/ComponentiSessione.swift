import SwiftUI
import PernoCore

// Componenti propri della schermata della sessione (UI v3): piastra del set e dock.

// MARK: - Piastra del set

/// Piastra di un set: adesso = grafite alta 88 pt con il perno; fatta = fondo chiaro pieno con la spunta;
/// da fare = solo bordo, numeri tenui e «obiettivo».
struct PiastraSet: View {
    enum Stato {
        /// `evidenza` è il dato in chiaro a destra («+2,5 kg»), `nota` quello tenue («prima 60 × 12»).
        case adesso(etichetta: String, evidenza: String?, nota: String?)
        case fatta(nota: String?)
        case daFare
    }

    let nome: String
    let valore: String
    let stato: Stato
    /// Avvicinamento: tinta calda (UI v6) al posto della grafite.
    var calda = false
    /// Piastra fatta oltre l'obiettivo: badge «+3» accanto al valore (UI v6).
    var badge: String? = nil
    /// Piastra fatta: faccina piccola a destra (UI v6).
    var faccina: Feeling? = nil
    /// Nota della piastra da fare: «obiettivo», o «prossimo» durante il recupero.
    var notaDaFare = "obiettivo"

    var body: some View {
        Group {
            switch stato {
            case let .adesso(etichetta, evidenza, nota):
                adesso(etichetta: etichetta, evidenza: evidenza, nota: nota)
            case let .fatta(nota):
                riga(fatta: true, nota: nota)
            case .daFare:
                riga(fatta: false, nota: notaDaFare)
            }
        }
        // Piastre ad altezza fissa (88 e 44 pt, come nelle tavole): il testo cresce fino a xxxLarge.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func adesso(etichetta: String, evidenza: String?, nota: String?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.perno).frame(width: 26, height: 26)
                Circle().fill(Color.suPerno).frame(width: 8, height: 8)
            }
            .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(etichetta)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(calda ? Color.avvicinamentoTenue : Color.piastraTenue)
                Text(valore)
                    .font(.piastra(48))
                    .monospacedDigit()
                    .foregroundStyle(Color.piastraTesto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                if let evidenza {
                    Text(evidenza).fontWeight(.semibold).foregroundStyle(Color.piastraTesto)
                }
                if let nota {
                    Text(nota).foregroundStyle(calda ? Color.avvicinamentoTenue : Color.piastraTenue)
                }
            }
            .font(.footnote.weight(.medium))
            .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 88, maxHeight: 88)
        .background(calda ? Color.avvicinamentoAdesso : Color.piastra,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nome), adesso. \(valore)")
    }

    private func riga(fatta: Bool, nota: String?) -> some View {
        HStack(spacing: 8) {
            Group {
                if fatta {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(calda ? Color.avvicinamentoFatto : Color.piastraFatta)
                        .frame(width: 20, height: 20)
                        .background(Color.inchiostro, in: Circle())
                } else {
                    Circle()
                        .strokeBorder(calda ? Color.riscaldamento : Color.inchiostroTenue, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 28, alignment: .leading)
            Text(nome)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(fatta ? Color.inchiostro : Color.inchiostroTenue)
                .frame(minWidth: 52, alignment: .leading)
                .lineLimit(1)
                .fixedSize()
            HStack(spacing: 8) {
                Text(valore)
                    .font(.piastra(26, peso: fatta ? .semibold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(fatta ? Color.inchiostro : Color.inchiostroTenue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if fatta, let badge {
                    Text(badge)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.suInchiostro)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(Color.inchiostro, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .fixedSize()
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if fatta, let faccina {
                    Faccina(tipo: faccina, dimensione: 20, colore: .inchiostroTenue)
                }
                if let nota {
                    Text(nota)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        .background {
            if fatta {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(calda ? Color.avvicinamentoFatto : Color.piastraFatta)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(calda ? Color.riscaldamento.opacity(0.38) : Color.inchiostro.opacity(0.22),
                                  lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(fatta
            ? ([("\(nome) fatto, \(valore)"), badge.map { "\($0) sull'obiettivo" }, faccina?.word]
                .compactMap { $0 }.joined(separator: ", "))
            : "\(nome) da fare, \(notaDaFare) \(valore)")
    }
}

/// Recupero in corso come piastrina tra il set fatto e il set dopo (UI v6, tavole 5, 5b, 5c): blu, alta 52,
/// perno, «Recupero» con il tempo del dock, a destra «di solito 2:10» o «fissato a 2:00».
struct PiastrinaRecupero: View {
    let tempo: String
    let nota: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.perno).frame(width: 26, height: 26)
                Circle().fill(Color.suPerno).frame(width: 8, height: 8)
            }
            .frame(width: 28)
            HStack(spacing: 10) {
                Text("Recupero")
                    .font(.subheadline.weight(.semibold))
                Text(tempo)
                    .font(.piastra(30))
                    .monospacedDigit()
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            if let nota {
                Text(nota)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.recuperoTenue)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
        .background(Color.recupero, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recupero in corso, \(tempo)")
    }
}

/// Recupero finito tra due set: riga sottile «recupero 2:12» con l'orologio (tempo misurato).
struct RigaRecupero: View {
    let testo: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 12, weight: .semibold))
            Text(testo)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(Color.inchiostroTenue)
        .padding(.leading, 20)
        .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

// MARK: - Dock

/// Dock fisso in basso, alto 224 pt: stato e timer a 64 pt a sinistra, posto secondario a destra
/// (non fa mai avanzare), 24 pt fissi e il pulsante principale da 64 pt.
struct DockSessione: View {
    struct Pulsante {
        var titolo: String
        var dettaglio: String? = nil
        var icona: String? = nil
        var sfondo: Color = .white
        var testo: Color = .suPerno
        let azione: () -> Void
    }

    struct Secondario {
        var titolo: String
        let azione: () -> Void
    }

    let sfondo: Color
    let coloreEtichetta: Color
    let coloreTesto: Color
    let etichetta: String
    let tempo: String
    var secondario: Secondario? = nil
    var principale: Pulsante? = nil
    var bordoSopra = false
    /// Tocco sul tempo (recupero: cronometro ↔ conto alla rovescia), con l'icona accanto.
    var azioneTempo: (() -> Void)? = nil
    /// Set a tempo (UI v5): «di 0:45» a destra del tempo e barra di avanzamento (0…1) sotto.
    var notaTempo: String? = nil
    var avanzamento: Double? = nil
    /// Riga sotto il tempo (UI v6, tavola 6): «Poi Lat machine, 3 set da 8 a 12».
    var sottotitolo: String? = nil

    /// Pulsante principale: 19 e 15 pt come nelle tavole, che crescono con «Testo più grande».
    @ScaledMetric(relativeTo: .title3) private var dimensioneTitolo: CGFloat = 19
    @ScaledMetric(relativeTo: .subheadline) private var dimensioneDettaglio: CGFloat = 15

    private var testoTempo: some View {
        Text(tempo)
            .font(.piastra(64))
            .monospacedDigit()
            .foregroundStyle(coloreTesto)
            .frame(height: 56)
            .lineLimit(1)
    }

    var body: some View {
        // Con la barra del set a tempo gli spazi si stringono, così il dock resta alto 224 pt.
        VStack(alignment: .leading, spacing: avanzamento == nil ? 24 : 12) {
            VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(etichetta)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(coloreEtichetta)
                        .lineLimit(1)
                    if let azioneTempo {
                        Button(action: azioneTempo) {
                            HStack(spacing: 8) {
                                testoTempo
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(coloreTesto.opacity(0.8))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Passa tra cronometro e conto alla rovescia")
                    } else {
                        testoTempo
                    }
                    if let sottotitolo {
                        Text(sottotitolo)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(coloreEtichetta)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.top, 6)
                    }
                }
                Spacer(minLength: 0)
                if let notaTempo {
                    Text(notaTempo)
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(coloreEtichetta)
                        .lineLimit(1)
                        .padding(.bottom, 4)
                }
                if let secondario {
                    Button(action: secondario.azione) {
                        Text(secondario.titolo)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(coloreTesto)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(coloreTesto.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                }
            }
            if let avanzamento {
                BarraAvanzamento(valore: avanzamento, colore: coloreTesto)
            }
            }
            if let principale {
                Button(action: principale.azione) {
                    HStack(spacing: 12) {
                        if let icona = principale.icona {
                            Image(systemName: icona)
                                .font(.system(size: dimensioneTitolo, weight: .semibold))
                                .padding(.trailing, -4)
                        }
                        Text(principale.titolo)
                            .font(.system(size: dimensioneTitolo, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let dettaglio = principale.dettaglio {
                            Text(dettaglio)
                                .font(.system(size: dimensioneDettaglio, weight: .medium))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(principale.testo)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(principale.sfondo, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, avanzamento == nil ? 20 : 18)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, minHeight: 224, maxHeight: 224, alignment: .top)
        // Dock alto 224 pt fissi (la schermata ci si appoggia sopra): il testo cresce fino a xxxLarge.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous)
                .fill(sfondo)
                .shadow(color: bordoSopra ? Color.inchiostro.opacity(0.08) : .clear, radius: 0, x: 0, y: -1)
        }
    }
}

/// Barra del set a tempo (UI v5): parte passata nel colore del testo, il resto in trasparenza.
struct BarraAvanzamento: View {
    let valore: Double
    let colore: Color

    var body: some View {
        GeometryReader { spazio in
            ZStack(alignment: .leading) {
                Capsule().fill(colore.opacity(0.14))
                Capsule().fill(colore)
                    .frame(width: spazio.size.width * min(1, max(0, valore)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
