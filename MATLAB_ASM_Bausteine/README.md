# ASM-Bausteine – Drehstrom-Asynchronmotor als Simulink/Simscape-Bausteinbibliothek

Seminararbeit Elektrotechnik, DHBW Mannheim (Betreuer: Dipl.-Ing. M. Densborn).
Netz, Motor, Welle, Last und Messgeräte als Bausteine, die wie im Labor zusammengesteckt werden;
dazu Didaktik-Bausteine für Drehfeld, Rotorstabströme und Kräfte (Skript „DS-Asynchron-Motor“,
Folien 16–30) und ein Export für Folienbilder.

```matlab
startup_asm; build_library; baue_beispiele
```

Bedienoberfläche ohne Masken und Bus Selector: `startup_asm; ASMApp`.

| Dokument | Inhalt |
|---|---|
| [doku/ANLEITUNG.md](doku/ANLEITUNG.md) | Schnellstart, Bedienoberfläche (ASMApp), Modell aufbauen, Folienbilder, typische Fehler |
| [doku/SPEC.md](doku/SPEC.md) | Gleichungen, Abdeckung der Folien, Bausteinkatalog, offene Punkte |
| [doku/KONVENTIONEN.md](doku/KONVENTIONEN.md) | Notation, Vorzeichen, Einheiten, Regeln für neue Bausteine |
| [doku/VALIDIERUNG.md](doku/VALIDIERUNG.md) | Prüfungen und Ergebnisse |

Motormodell: dynamisches Raumzeigermodell, validiert gegen das T-Ersatzschaltbild und die
Simscape-Electrical-Asynchronmaschine (Abweichung < 0,1 %). Alle Zahlenwerte sind Beispielwerte.
Tests: `runtests('tests')`.
