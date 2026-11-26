# Hinweise für KI-Agenten

Seminararbeit Elektrotechnik, DHBW Mannheim (Betreuer: Dipl.-Ing. M. Densborn):
**„Simulation des Drehstrom-Asynchronmotors in MATLAB“**.

| Ordner | Inhalt | Sprache |
|---|---|---|
| `S1/` | Ausarbeitung in Typst (Vorlage `@local/templat-projektarbeit:0.1.22`, supercharged-dhbw) | Deutsch |
| `MATLAB_ASM_Bausteine/` | MATLAB/Simulink/Simscape-Bausteinbibliothek, Beispielmodelle, Tests, Doku | Code Englisch, Ausgaben und Doku Deutsch |

## Grundregeln

- Mit dem Nutzer auf Deutsch kommunizieren.
- **Nichts erfinden:** keine Quellen, Zitate, Seitenangaben, Messwerte oder Simulationsergebnisse.
  Zahlen für die Arbeit nur aus tatsächlich ausgeführten Läufen übernehmen (`verify_asm`,
  `benchmark_motor`, `run_asm`) und den Lauf nennen. Was nicht ausgeführt wurde, als ungeprüft
  kennzeichnen.
- Alle Motordaten sind **Beispielwerte** eines fiktiven 4-kW-Motors (`parameter/asm_standard.m`),
  keine Datenblatt- oder Messwerte – so kennzeichnen.
- Fachlich unbegründete Parameteränderungen unterlassen. Bekannte Eigenheit: Der Bemessungspunkt
  (1440 1/min, 26,5 N·m) liegt bewusst nicht auf der Kloss-Kennlinie (27,52 N·m bei s_N); nicht
  „korrigieren“, ohne vorher zu fragen (`doku/VALIDIERUNG.md`, Abschnitt 2).
- Einordnung der Ergebnisse: Vergleiche mit ESB, Kloss und Simscape Electrical sind
  Konsistenzprüfungen bzw. Modellbenchmark, **keine experimentelle Validierung**.
- KI-Nutzung muss in der Arbeit offengelegt werden (`S1/Anmerkung KI.typ`, Erklärung in
  `S1/main.typ`). Diese Stellen nicht eigenmächtig ändern; bei einer neuen Art der Nutzung den
  Nutzer darauf hinweisen.

## Git

- Hauptbranch ist `S1`. Commit-Nachrichten auf Deutsch, kurz im Betreff, Details im Text.
- Nur committen oder pushen, wenn der Nutzer darum bittet.
- Keine Build-Artefakte einchecken (`.gitignore`: `*.asv`, `*.slxc`, `slprj/`, `codegen/`, …).
  Die generierten Dateien in `lib/` und `examples/*.slx` gehören dagegen ins Repository.

## Ausarbeitung (`S1/`)

- Einstieg `S1/main.typ`; Kapitel in `S1/Texte/`, Abkürzungen in `S1/Zusatz/acronyms.typ`
  (im Text `#acr("ASM")`), Glossar `S1/Zusatz/glossary.typ`, Literatur `S1/Zusatz/zotero.bib`
  (Export aus Zotero – neue Quellen in Zotero anlegen, zitieren mit `@schluessel[Folien 13--30]`).
- Text der Arbeit (`S1/Texte/*.typ`) nur auf ausdrückliche Bitte ändern; sonst Vorschläge im Chat.
- Formale Vorgaben: DHBW-Leitlinien Technik (Stand 10.11.2025).
- Notation wie in den Vorlesungsfolien (Densborn): Index 1 = Stator, 2 = Rotor, Strich = auf den
  Stator bezogen, Winkel am Umfang elektrisch, Polpaarzahl p. Formelzeichen wie im MATLAB-Projekt
  (MK, sK, M_N, n_N, R2′, L2σ′, …; siehe `MATLAB_ASM_Bausteine/doku/KONVENTIONEN.md`).
- Abbildungen in `S1/Bilder/<Kapitel>/`: Kopien aus `MATLAB_ASM_Bausteine/export/` (dort mit
  `export_slide_figures` bzw. `benchmark_motor` erzeugt) und Python-Skripte in
  `S1/Bilder/Grundlagen/erzeugung/` (schemdraw, matplotlib). Abbildungen nicht von Hand
  nachbearbeiten, sondern neu erzeugen und erneut kopieren.
- Übersetzen: `typst compile main.typ` im Ordner `S1`. Dafür muss die Vorlage
  `templat-projektarbeit` 0.1.22 im lokalen Typst-Paketordner installiert sein.

## MATLAB-Projekt (`MATLAB_ASM_Bausteine/`)

Voraussetzung: MATLAB **R2026b** mit Simulink, Simscape und Simscape Electrical. Nur dieses Release
ist getestet; ältere Releases nicht als unterstützt angeben.

```matlab
cd MATLAB_ASM_Bausteine
startup_asm; build_library; build_examples   % Pfade, Bibliothek, Beispielmodelle erzeugen
R = run_asm(asm_params('kloss'));            % Simulation ohne GUI ('kloss' | 'loop' | 'lab' | 'slides')
T = verify_asm();                            % fachliche Testfälle mit Berichtstabelle (~10 s)
runtests('tests')                            % alle Tests (~3 min), müssen vollständig bestehen
```

Kommandozeile: `matlab -batch "startup_asm; runtests('tests')"`.
Dokumentation: `README.md`, `doku/ANLEITUNG.md`, `doku/KONVENTIONEN.md`, `doku/VALIDIERUNG.md`,
`doku/SPEC.md`.

Regeln:

- **Sprache:** Datei-, Paket-, Funktions-, Variablen- und Feldnamen, Maskenparameter-Namen und
  Kommentare Englisch. Alles, was der Nutzer sieht, Deutsch: Bausteinnamen, Masken-Prompts und
  Auswahltexte, Hilfetexte, Oberfläche (`ASMApp`), Diagrammbeschriftungen, Fehlermeldungen,
  Testmeldungen, Berichtstabelle. Formelzeichen bleiben wie in der Arbeit.
- **Generierte Dateien:** `lib/*.slx` und `examples/*.slx` nie von Hand ändern, sondern
  `build_library` bzw. `build_examples` ausführen.
- **Einzige Quelle** für Bausteine, Ports, Masken, Wertebereiche und Hilfetexte:
  `+asmtools/catalog.m`. Neuer Baustein: Katalogeintrag → ggf. `.ssc` in `+asmlib/<gruppe>/` →
  `build_library` → Tests (KONVENTIONEN, Abschnitt 7). Maskenparameter dürfen nicht wie eingebaute
  Blockparameter heißen (z. B. `orientation`).
- **Parameter:** `parameter/asm_standard.m` (Motor, MK, sK, abgeleitete Schleifenwerte) und
  `parameter/asm_params.m` (vollständiger Laufparametersatz). Keine Zahlenwerte verstreut hart kodieren.
- **Datenfluss:** Simulationen über `run_asm(P)` bzw. `Simulink.SimulationInput`; Ergebnisse als
  Rückgabewert. Kein `assignin`/`evalin` (einzige Ausnahme `asmtools.last_sim_output` für die
  Maskenknöpfe), keine Modell-Callbacks, Beispielmodelle während eines Laufs nicht verändern.
- **Numerik:** Simscape-Gleichungen ereignisfrei halten (kein `abs`, `sign`, `atan2`, `if` über
  Variablen; Sprünge und Vorzeichen mit `tanh` glätten), sonst bleibt die ee_lib-Referenz hängen.
  Jede Simulation in Skripten und Tests mit `TimeOut`.
- **Kennzahlen** nur mit den festen Definitionen aus `asmtools.speed_metrics` (Hochlaufzeit bis
  0,9·n_N, Laststoß separat, Einschwingzeit nur bei gehaltenem Toleranzband).
- **Nach Änderungen:** `runtests('tests')` vollständig grün; bei Änderungen an Modell, Parametern
  oder Auswertung zusätzlich `verify_asm` ausführen und die Tabellen in `doku/VALIDIERUNG.md`
  nachziehen. Neue Prüfungen mit Sollwert, Toleranz und Begründung der Toleranz.
- `doku/SPEC.md`, Abschnitte 1–14, sind historisch (alte deutsche Bezeichner) – nicht umschreiben,
  Änderungen als neuen Abschnitt anhängen.
