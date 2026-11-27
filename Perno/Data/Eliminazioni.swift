import SwiftUI
import SwiftData
import Observation
import PernoCore

/// Eliminazione di una sessione con «Annulla» (D6): niente finestra di conferma. La sessione sparisce subito
/// dalle liste (Storico, Home) e compare il toast «Sessione eliminata · Annulla» per 5 s; allo scadere si
/// cancella davvero. Gli identificativi in attesa sono salvati: se l'app si chiude prima, la sessione si
/// cancella al prossimo avvio (`eseguiPendenti`). La logica pura è `PendingDeletions` in `PernoCore`.
@Observable
final class Eliminazioni {
    static let shared = Eliminazioni()

    private static let chiave = "eliminazioni.sessioniInAttesa"
    private static var avviato = false

    private(set) var inAttesa: PendingDeletions
    /// Sessione del toast visibile (la più recente); `nil` quando non c'è toast.
    private(set) var ultima: UUID?
    private var contesto: ModelContext?
    private var attesa: Task<Void, Never>?

    private init() {
        inAttesa = PendingDeletions(stored: UserDefaults.standard.stringArray(forKey: Self.chiave) ?? [])
    }

    /// Le sessioni da mostrare: tolte quelle appena eliminate.
    func visibili(_ sessioni: [WorkoutSession]) -> [WorkoutSession] {
        inAttesa.visible(sessioni, id: \.id)
    }

    /// Nasconde la sessione e fa partire i 5 s di «Annulla». Una seconda eliminazione conferma subito la prima.
    func elimina(_ sessione: WorkoutSession, in contesto: ModelContext) {
        if let precedente = ultima { cancella(precedente, in: contesto) }
        self.contesto = contesto
        let id = sessione.id
        inAttesa.hide(id)
        salva()
        withAnimation(.easeOut(duration: 0.25)) { ultima = id }
        attesa?.cancel()
        attesa = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(PendingDeletions.undoDuration * 1_000_000_000))
            guard !Task.isCancelled, let self, self.ultima == id, let contesto = self.contesto else { return }
            self.cancella(id, in: contesto)
        }
    }

    /// «Annulla»: la sessione torna dov'era.
    func annulla() {
        guard let id = ultima else { return }
        attesa?.cancel()
        inAttesa.undo(id)
        salva()
        withAnimation(.easeOut(duration: 0.25)) { ultima = nil }
    }

    /// Al primo avvio dell'app: cancella quello che era rimasto in attesa quando si è chiusa.
    func eseguiPendenti(in contesto: ModelContext) {
        guard !Self.avviato else { return }
        Self.avviato = true
        for id in inAttesa.ids where id != ultima {
            cancella(id, in: contesto)
        }
    }

    private func cancella(_ id: UUID, in contesto: ModelContext) {
        attesa?.cancel()
        if let registro = (try? contesto.fetch(FetchDescriptor<WorkoutSession>()))?.first(where: { $0.id == id }) {
            contesto.delete(registro)
            try? contesto.save()
        }
        inAttesa.finish(id)
        salva()
        if ultima == id { withAnimation(.easeOut(duration: 0.25)) { ultima = nil } }
    }

    private func salva() {
        UserDefaults.standard.set(inAttesa.stored, forKey: Self.chiave)
    }
}

/// Toast «Sessione eliminata · Annulla»: grafite, in basso sopra la barra delle sezioni, 5 s.
struct ToastEliminazione: View {
    @Environment(\.accessibilityReduceMotion) private var menoMovimento

    var body: some View {
        Group {
            if Eliminazioni.shared.ultima != nil {
                HStack(spacing: 12) {
                    Text(PendingDeletions.sessionDeletedTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.piastraTesto)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        Aptica.selezione.dai()
                        Eliminazioni.shared.annulla()
                    } label: {
                        Text(PendingDeletions.undoTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.perno)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 16)
                .padding(.trailing, 4)
                .background(Color.piastra, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 96)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .transition(menoMovimento ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .contain)
            }
        }
    }
}
