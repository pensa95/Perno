# Perno — istruzioni per Claude

App iOS nativa (Swift/SwiftUI) per registrare gli allenamenti in palestra. Offline, dati sul telefono (SwiftData). Installata senza App Store: build non firmata su GitHub Actions, firma e installazione con SideStore (Apple ID gratuito). Niente Mac e niente simulatore: l'unica prova vera è la build in CI e l'app sul telefono.

## Regole di progetto (valgono sempre)

1. **Prima di ogni commit su GitHub, controlla che il budget basti per chiudere il lavoro.** Il progetto gira su un piano Claude Pro con limiti di sessione e settimanali. Prima di iniziare un pezzo di lavoro stima se c'è margine per finirlo, fare il commit e il push. Se non c'è, non cominciarlo: chiudi e pubblica quello che è già completo, e lascia scritto cosa resta.
2. **Mai lavori a metà su `main`.** Ogni commit deve essere completo e coerente: compila, i test passano (per quanto verificabile), nessun file lasciato con TODO che rompe la build. Meglio commit piccoli e finiti che uno grande interrotto. Se una sessione si interrompe, il ramo principale deve restare in uno stato che builda.
3. **Specifiche e tavole sono già decise: non ripianificare né cambiare la UI, implementa.** Se qualcosa manca o è ambiguo, chiedi; non inventare stili fuori dal Design System «Pacco pesi».
4. **Niente «fatto» senza prova.** Prima di dire che un lavoro è finito, mostra l'esito dei test o della build (CI compresa).
5. **Un obiettivo per sessione**, poi prova sul telefono. Degli errori di build riporta solo le righe rilevanti.
6. Commit e messaggi in italiano, brevi, al presente («Aggiunge…», «Corregge…»).

## Dove sono le specifiche

Nel progetto claude.ai «App palestra» (documenti `claude/…`):
- `funzionalita-v1.md` — cosa fa l'app (fonte per il codice).
- `schermate-ui-v4.md` — tavole della UI v4, **fonte di verità**: canvas https://claude.ai/artifact/Rya7xFNT3KLuxohPYqGBUV e canvas della Live Activity https://claude.ai/artifact/WkBgjgJLNDqgeCn7muwaDd (regole in `live-activity-v1.md`). La UI v3 è superata.
- `piano-sviluppo.md` — calendario a settimane e regole per il piano Pro.
- `identity-v1.md` — nome Perno, marchio, icona.

## Glossario (stessi nomi nell'interfaccia e nel codice)

| Interfaccia | Codice | Significato |
|---|---|---|
| Riscaldamento | `warmUp` | Fase cronometrata a inizio sessione, non legata a un esercizio |
| Avvicinamento («Avv. N») | `approach` | Set leggeri in % del peso di lavoro di oggi: 1 → 60%; 2 → 50/75%; 3 → 40/60/80%, arrotondati al passo dei dischi |
| Set | `work` | Set di lavoro |
| Riserva | `reserve` | Ripetizioni che restavano: 0, 1, 2, 3, 4+ (sostituisce l'RPE) |
| Recupero | `rest` | Da «Set fatto» a «Inizia set» del set successivo dello stesso esercizio (3-2-1 escluso) |
| Cambio esercizio | `changeover` | Da «Set fatto» dell'ultimo set a «Inizia» del primo set dell'esercizio successivo; salvato a parte |
| Durata del set | `setDuration` | Dalla fine del 3-2-1 a «Set fatto» |
| Recupero abituale | `usualRest` | Media dei recuperi dei set di lavoro (esclusi avvicinamenti e cambi) |

## Ciclo della sessione (non cambiarlo)

Riscaldamento (dock arancio) → Cambio esercizio (grafite) → «Inizia» → 3-2-1 → Set in corso (chiaro) → «Set N fatto» → Recupero (blu) → «Inizia set N+1» … Non esiste lo stato «tocca a te». Il posto secondario del dock non fa mai avanzare («Salta», «Rimanda», «+15 s»).

## Struttura del repository

- `Packages/PernoCore/` — logica pura in Swift (solo Foundation, deve compilare anche su Linux), con test XCTest. Tutta la logica che si può testare va qui, non nelle view.
- `Perno/` — app SwiftUI (iOS 17+).
- `PernoWidget/` — estensione WidgetKit con la Live Activity della sessione (blocco schermo e Dynamic Island). `Shared/` è compilato nell'app e nell'estensione (attributi e pulsanti, `LiveActivityIntent`); i testi della card li prepara `LiveActivityText` in `PernoCore`.
- `Perno/Data/` — modello SwiftData versionato (`SchemaV1`, `PernoMigrationPlan`). Enum salvati come valore grezzo, pesi sempre in chili, ordine con `position`. Per cambiare il modello si aggiunge una nuova versione dello schema con la sua migrazione, mai modifiche dirette a `SchemaV1`.
- `project.yml` — progetto XcodeGen; il `.xcodeproj` non si committa, lo genera la CI.
- `.github/workflows/build.yml` — test su Linux e macOS, build `.ipa` non firmata, release scaricabile dal telefono.

## Design System «Pacco pesi» (riassunto)

Colori chiaro / scuro: lamiera `#ECEFF1` / `#14181B` (fondo), foglio `#FFFFFF` / `#20262A` (superfici), inchiostro `#1C2226` / `#EEF1F3`, inchiostro tenue `#566069` / `#9AA5AD`, piastra `#2A3136` / `#353E45`, piastra fatta `#DCE1E4` / `#252B30`, perno `#F5B700` (unico accento), recupero `#2457B8`, riscaldamento `#C2410C`, errore `#B3261E` / `#F2867C`. Numeri e titoli in Barlow Condensed con `Font.piastra(_:)` (OFL, file in `Perno/Resources/Fonts`, registrati in `project.yml` con `UIAppFonts`), testi in SF Pro con Dynamic Type. Un solo elemento giallo per schermata più il perno. Icone SF Symbols, mai emoji. Decimali con la virgola (62,5 kg), «×» tra peso e ripetizioni.
