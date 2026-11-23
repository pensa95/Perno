import SwiftUI

// Componenti propri della UI v3, da riusare ovunque (niente stili fuori da qui e da Theme).

// MARK: - Testi

/// Titolo di sezione: 13 pt semibold, inchiostro tenue, rientro di 4 pt.
struct EtichettaSezione: View {
    let testo: String

    init(_ testo: String) { self.testo = testo }

    var body: some View {
        Text(testo)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.inchiostroTenue)
            .padding(.leading, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pila

/// Pila: ogni voce è una piastrina bianca a sé, raggio 8, 4 pt tra una e l'altra, nessun separatore.
struct Pila<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 4) { content }
    }
}

/// Voce della pila con titolo, sottotitolo opzionale e freccia.
struct VocePila: View {
    let titolo: String
    var sottotitolo: String? = nil
    var freccia = true

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                if let sottotitolo {
                    Text(sottotitolo)
                        .font(.footnote)
                        .foregroundStyle(Color.inchiostroTenue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if freccia {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inchiostroTenue)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .frame(minHeight: 60)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Pulsanti

/// Pulsante principale giallo (uno solo per schermata), alto 64 pt.
struct PulsanteGiallo: View {
    let titolo: String
    var attivo = true
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            Text(titolo)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.suPerno)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Color.perno, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!attivo)
        .opacity(attivo ? 1 : 0.4)
    }
}

/// Pulsante tondo da 44 pt con un'icona (X, +): fondo foglio.
struct PulsanteTondo: View {
    let icona: String
    let etichetta: String
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            Image(systemName: icona)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.inchiostro)
                .frame(width: 44, height: 44)
                .background(Color.foglio, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etichetta)
    }
}

/// Indietro in testata: freccia e nome della sezione.
struct PulsanteIndietro: View {
    let titolo: String
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                Text(titolo)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Color.inchiostro)
            .frame(minHeight: 44)
            .padding(.leading, -6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selettori

/// Capsula di scelta (filtri e selettori): scelta = inchiostro pieno, altrimenti foglio.
struct Scelta: View {
    let titolo: String
    let scelta: Bool
    var altezza: CGFloat = 36
    var riempi = false
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            Text(titolo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(scelta ? Color.foglio : Color.inchiostro)
                .lineLimit(1)
                .padding(.horizontal, riempi ? 4 : 14)
                .frame(maxWidth: riempi ? .infinity : nil, minHeight: altezza)
                .background(scelta ? Color.inchiostro : Color.foglio,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(scelta ? .isSelected : [])
    }
}

/// Selettore a griglia su tre colonne (gruppo muscolare, attrezzo), voci alte 44 pt.
struct SelettoreGriglia<Valore: Hashable>: View {
    let valori: [Valore]
    @Binding var selezione: Valore
    let etichetta: (Valore) -> String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(valori, id: \.self) { valore in
                Scelta(titolo: etichetta(valore), scelta: valore == selezione, altezza: 44, riempi: true) {
                    selezione = valore
                }
            }
        }
    }
}

// MARK: - Foglio

/// Foglio standard: maniglia, titolo, X (chiude senza salvare), contenuto, pulsante giallo in fondo.
struct Foglio<Content: View>: View {
    let titolo: String
    let pulsante: String
    var pulsanteAttivo = true
    let chiudi: () -> Void
    let conferma: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text(titolo)
                    .font(.piastra(32))
                    .foregroundStyle(Color.inchiostro)
                Spacer()
                PulsanteTondo(icona: "xmark", etichetta: "Chiudi", azione: chiudi)
            }
            ScrollView {
                VStack(spacing: 24) { content }
            }
            .scrollBounceBehavior(.basedOnSize)
            PulsanteGiallo(titolo: pulsante, attivo: pulsanteAttivo, azione: conferma)
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Color.lamiera)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Color.lamiera)
    }
}
