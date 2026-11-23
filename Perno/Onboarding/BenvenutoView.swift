import SwiftUI

/// H1 Benvenuto (tavola delle schermate aggiunte, pagina Primo avvio).
/// Per ora è la sola schermata: serve a verificare che la catena build → SideStore → telefono funzioni.
struct BenvenutoView: View {
    var body: some View {
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

                Button {
                    // Settimana 4: passa a «Dove salvo i backup?».
                } label: {
                    Text("Inizia")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.suPerno)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(Color.perno, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    // Settimana 4: ripristino da backup.
                } label: {
                    Text("Ripristina da backup")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.inchiostro)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lamiera)
    }
}

#Preview {
    BenvenutoView()
}
