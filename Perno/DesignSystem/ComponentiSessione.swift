import SwiftUI

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

    var body: some View {
        Group {
            switch stato {
            case let .adesso(etichetta, evidenza, nota):
                adesso(etichetta: etichetta, evidenza: evidenza, nota: nota)
            case let .fatta(nota):
                riga(fatta: true, nota: nota)
            case .daFare:
                riga(fatta: false, nota: "obiettivo")
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
                    .foregroundStyle(Color.piastraTenue)
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
                    Text(nota).foregroundStyle(Color.piastraTenue)
                }
            }
            .font(.footnote.weight(.medium))
            .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 88, maxHeight: 88)
        .background(Color.piastra, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nome), adesso. \(valore)")
    }

    private func riga(fatta: Bool, nota: String?) -> some View {
        HStack(spacing: 8) {
            Group {
                if fatta {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.piastraFatta)
                        .frame(width: 20, height: 20)
                        .background(Color.inchiostro, in: Circle())
                } else {
                    Circle()
                        .strokeBorder(Color.inchiostroTenue, lineWidth: 2)
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
            Text(valore)
                .font(.piastra(26, peso: fatta ? .semibold : .medium))
                .monospacedDigit()
                .foregroundStyle(fatta ? Color.inchiostro : Color.inchiostroTenue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if let nota {
                Text(nota)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.inchiostroTenue)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        .background {
            if fatta {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.piastraFatta)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.inchiostro.opacity(0.22), lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(fatta ? "\(nome) fatto, \(valore)" : "\(nome) da fare, obiettivo \(valore)")
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
        VStack(alignment: .leading, spacing: 24) {
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
                }
                Spacer(minLength: 0)
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
        .padding(.top, 20)
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
