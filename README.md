# Perno

Infila il perno, fai il set.

App iOS per registrare gli allenamenti in palestra: schede, set con tempi misurati, recuperi, avvicinamenti, storico e progressi. Funziona offline e i dati restano sul telefono.

## Installazione

Non passa dall'App Store. A ogni push su `main` GitHub Actions compila un `.ipa` non firmato e lo pubblica nelle [Releases](../../releases). Sul telefono si scarica l'ultimo `.ipa` e si apre con SideStore, che lo firma con l'Apple ID.

## Sviluppo

- `Packages/PernoCore` — logica dell'app con i test (`swift test --package-path Packages/PernoCore`).
- `Perno/` — app SwiftUI, progetto generato con [XcodeGen](https://github.com/yonaskolb/XcodeGen) da `project.yml`.

Le istruzioni per Claude sono in `CLAUDE.md`.
