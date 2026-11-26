# ASM-Bausteine – Drehstrom-Asynchronmotor als Simulink/Simscape-Bausteinbibliothek

Seminararbeit Elektrotechnik, DHBW Mannheim (Betreuer: Dipl.-Ing. M. Densborn).
Netz, Motor, Welle, Last und Messgeräte als Bausteine, die wie im Labor zusammengesteckt werden;
dazu Didaktik-Bausteine für Drehfeld, Rotorstabströme und Kräfte (Skript „DS-Asynchron-Motor“,
Folien 16–30) und ein Export für Folienbilder.

```matlab
startup_asm; build_library; build_examples      % Pfade, Bibliothek, Beispielmodelle erzeugen
R = run_asm(asm_params('kloss'));               % Teil B: Hochlauf + Laststoß (Kloss), ohne GUI
R = run_asm(asm_params('loop'));                % Teil A: Leiterschleife bei festem Schlupf
T = verify_asm();                               % fachliche Testfälle mit Berichtstabelle
runtests('tests')                               % alle Tests
ASMApp                                          % Bedienoberfläche
```

| Dokument | Inhalt |
|---|---|
| [doku/ANLEITUNG.md](doku/ANLEITUNG.md) | Schnellstart, Simulation ohne GUI (`run_asm`), Bedienoberfläche, Modell aufbauen, Folienbilder, Kompatibilität |
| [doku/SPEC.md](doku/SPEC.md) | Gleichungen, Abdeckung der Folien, Bausteinkatalog, offene Punkte, Umbenennung (Abschnitt 15) |
| [doku/KONVENTIONEN.md](doku/KONVENTIONEN.md) | Notation, Vorzeichen, Einheiten, Sprache (Code englisch, Ausgaben deutsch) |
| [doku/VALIDIERUNG.md](doku/VALIDIERUNG.md) | Testfälle, Konsistenzprüfungen, Modellbenchmark, Befunde, Modellgrenzen |

Motormodell: dynamisches Raumzeigermodell. Es stimmt stationär mit dem T-Ersatzschaltbild und
dynamisch mit der Simscape-Electrical-Asynchronmaschine überein (Abweichung < 0,1 %). Das sind
**Modellvergleiche mit denselben Beispielparametern (Benchmark), keine experimentelle Validierung**.
Alle Zahlenwerte sind Beispielwerte. Getestet mit MATLAB R2026b (siehe ANLEITUNG, Abschnitt 9).

Code-Bezeichner und Kommentare sind englisch; alles, was der Nutzer sieht (Bausteinnamen, Masken,
Oberfläche, Diagramme, Fehlermeldungen, Testbericht), ist deutsch.
