# ASM-Bausteine – Drehstrom-Asynchronmotor als Simulink/Simscape-Bausteinbibliothek

Seminararbeit Elektrotechnik, DHBW Mannheim (Betreuer: Dipl.-Ing. M. Densborn).
Netz, Motor, Welle, Last und Messgeräte als Bausteine, die wie im Labor zusammengesteckt werden;
dazu Didaktik-Bausteine für Drehfeld, Rotorstabströme und Kräfte (Skript „DS-Asynchron-Motor“,
Folien 16–30) und ein Export für Folienbilder.

**Voraussetzungen:** MATLAB mit Simulink, Simscape und Simscape Electrical. **Getestet nur mit
R2026b Update 1** (Windows 11); ältere Releases sind nicht geprüft (ANLEITUNG, Abschnitt 9).

```matlab
startup_asm; build_library; build_examples      % Pfade, Bibliothek, Beispielmodelle erzeugen
R = run_asm(asm_params('kloss'));               % Teil B: Hochlauf + Laststoß (Kloss), ohne GUI
R = run_asm(asm_params('loop'));                % Teil A: Leiterschleife bei festem Schlupf
T = verify_asm();                               % fachliche Testfälle mit Berichtstabelle
C = compare_kloss_dynamic();                    % Kloss gegen Raumzeigermodell beim Laststoß
check_asm                                       % Unit-Tests + Testfälle, Fehler bei Nichtbestehen
ASMApp                                          % Bedienoberfläche
```

Kommandozeile: `matlab -batch "startup_asm; check_asm('Log', 'check_asm.log')"`
(Exit-Code ≠ 0, wenn etwas nicht besteht).

| Dokument | Inhalt |
|---|---|
| [doku/ANLEITUNG.md](doku/ANLEITUNG.md) | Schnellstart, Simulation ohne GUI (`run_asm`), Kennzahlen, Bedienoberfläche, Modell aufbauen, Folienbilder, Kompatibilität |
| [doku/SPEC.md](doku/SPEC.md) | Gleichungen, Abdeckung der Folien, Bausteinkatalog, offene Punkte, Umbenennung (Abschnitt 15) |
| [doku/KONVENTIONEN.md](doku/KONVENTIONEN.md) | Notation, Vorzeichen, Einheiten, Sprache (Code englisch, Ausgaben deutsch) |
| [doku/VALIDIERUNG.md](doku/VALIDIERUNG.md) | Laufprotokoll, Testfälle, Konsistenzprüfungen, Modellbenchmark, Befunde, Modellgrenzen |

**Einordnung der Ergebnisse.** Das Motormodell „ASM Standard“ ist ein dynamisches Raumzeigermodell.
Es wird mit dem T-Ersatzschaltbild und mit der Asynchronmaschine aus Simscape Electrical verglichen –
mit denselben Beispielparametern; das ist ein **Modellbenchmark bzw. eine Konsistenzprüfung, keine
experimentelle Validierung**. Gemessene Größen (VALIDIERUNG, Abschnitt 4): stationäres Luftspaltmoment
bei fester Drehzahl, s = 0,02 … 1, weicht um −0,02 % bis −0,06 % vom ESB-Moment ab (BenchmarkTest V1);
beim Hochlauf mit Laststoß (0 … 2 s) beträgt die größte Abweichung zur Simscape-Electrical-Maschine
0,026 % von n_s in der Drehzahl und 0,043 % des Kippmoments im Wellenmoment (V2). Alle Zahlenwerte
sind Beispielwerte eines fiktiven 4-kW-Motors, keine Datenblatt- oder Messwerte; eine Prognosegüte
für einen realen Motor ist damit nicht belegt.

Code-Bezeichner und Kommentare sind englisch; alles, was der Nutzer sieht (Bausteinnamen, Masken,
Oberfläche, Diagramme, Fehlermeldungen, Testbericht), ist deutsch.
