# Perno — istruzioni per Claude

App iOS nativa (Swift/SwiftUI) per registrare gli allenamenti in palestra. Offline, dati sul telefono (SwiftData). Installata senza App Store: build non firmata su GitHub Actions, firma e installazione con SideStore (Apple ID gratuito). Niente Mac e niente simulatore: l'unica prova vera è la build in CI e l'app sul telefono.

## Regole di progetto (valgono sempre)

1. **Leggi solo `claude/lavori.md`** (documento del progetto claude.ai «App palestra»): backlog, decisioni, regole di lavoro e task. Gli altri documenti `claude/…` sono archivio, da aprire solo se serve; `claude/funzionalita-v1.md` descrive cosa fa l'app.
2. **Pacchetti, non task singoli**: più voci in un ramo e una PR, ramo nuovo da `origin/main` aggiornato.
3. **Prima di ogni commit controlla che il budget basti per chiudere** (piano Claude Pro con limiti di sessione e settimanali). Se non basta, non cominciare: pubblica ciò che è completo e lascia scritto cosa resta.
4. **Mai lavori a metà su `main`**: ogni commit è completo e coerente, il ramo principale resta in uno stato che builda.
5. **Specifiche e tavole sono già decise**: non ripianificare né cambiare la UI, implementa; se qualcosa è ambiguo chiedi. Niente stili fuori dal Design System «Pacco pesi».
6. **Niente «fatto» senza prova**: CI verde. Non c'è compilatore Swift nelle sessioni, quindi logica testabile in `PernoCore` e diff riletto prima del push.
7. Commit e messaggi in italiano, brevi, al presente («Aggiunge…», «Corregge…»). Resoconti di una riga.

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
| Si misura in: Ripetizioni / Tempo | `SetMeasure` (`.reps` / `.time`) | Scelta nell'esercizio della scheda (UI v5) |
| Durata (del set a tempo) | `targetSeconds` / `seconds` | Durata obiettivo e fatta di un set a tempo, in secondi; passi di 5 s |
| Con peso | `withWeight` | Spunta degli esercizi a tempo; a ripetizioni il peso c'è sempre |
| Com'è andato? Leggero / Giusto / Faticoso | `Feeling` (`feelingRaw` sul set) | Faccina dopo un set di lavoro (UI v6); sostituisce la riserva, che resta per i dati vecchi |
| Recupero dell'esercizio | `restModeRaw` / `autoStartAfterRest` | Cronometro o alla rovescia e «Parti da solo», scelti nell'esercizio della scheda (UI v6) |

## Ciclo della sessione (non cambiarlo)

Riscaldamento (dock arancio) → Cambio esercizio (grafite) → «Inizia» → 3-2-1 → Set in corso (chiaro) → «Set N fatto» → Recupero (blu) → «Inizia set N+1» … Non esiste lo stato «tocca a te». Il posto secondario del dock non fa mai avanzare («Salta», «Rimanda», «+15 s»).

## Struttura del repository

- `Packages/PernoCore/` — logica pura in Swift (solo Foundation, deve compilare anche su Linux), con test XCTest. Tutta la logica che si può testare va qui, non nelle view.
- `Perno/` — app SwiftUI (iOS 17+).
- `PernoWidget/` — estensione WidgetKit con la Live Activity della sessione (blocco schermo e Dynamic Island). `Shared/` è compilato nell'app e nell'estensione (attributi e pulsanti, `LiveActivityIntent`); i testi della card li prepara `LiveActivityText` in `PernoCore`.
- `Perno/Data/` — modello SwiftData versionato (`SchemaV1`, `SchemaV2`, `SchemaV3` attuale dalla UI v6, `PernoMigrationPlan`). Enum salvati come valore grezzo, pesi sempre in chili, ordine con `position`. Per cambiare il modello si aggiunge una nuova versione dello schema con la sua migrazione, mai modifiche dirette a `SchemaV1`.
- `project.yml` — progetto XcodeGen; il `.xcodeproj` non si committa, lo genera la CI.
- `.github/workflows/build.yml` — test su Linux e macOS, build `.ipa` non firmata, release scaricabile dal telefono.

## Design System «Pacco pesi» (riassunto)

Colori chiaro / scuro: lamiera `#ECEFF1` / `#14181B` (fondo), foglio `#FFFFFF` / `#20262A` (superfici), inchiostro `#1C2226` / `#EEF1F3`, inchiostro tenue `#566069` / `#9AA5AD`, piastra `#2A3136` / `#353E45`, piastra fatta `#DCE1E4` / `#252B30`, perno `#F5B700` (unico accento), recupero `#2457B8`, riscaldamento `#C2410C`, errore `#B3261E` / `#F2867C`. Numeri e titoli in Barlow Condensed con `Font.piastra(_:)` (OFL, file in `Perno/Resources/Fonts`, registrati in `project.yml` con `UIAppFonts`), testi in SF Pro con Dynamic Type. Un solo elemento giallo per schermata più il perno. Icone SF Symbols, mai emoji. Decimali con la virgola (62,5 kg), «×» tra peso e ripetizioni.
