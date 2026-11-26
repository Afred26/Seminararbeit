# Anleitung: ASM-Bausteinbibliothek

Bausteinbibliothek zur Simulation des Drehstrom-Asynchronmotors (Käfigläufer) – Seminararbeit
Elektrotechnik, DHBW Mannheim. Der Motor wird wie im Labor zusammengesteckt:
Netz → Messgeräte → Motor → Welle → Last.

> Alle Standardwerte sind **Beispielwerte** eines fiktiven 4-kW-Motors (`parameter/asm_standard.m`),
> keine Datenblattwerte.

## 1 Schnellstart

Voraussetzungen: MATLAB, Simulink, Simscape und Simscape Electrical (Simscape Electrical braucht
`build_library` für den Baustein „ASM Referenz“ und `BenchmarkTest` V2). Getestet ist nur
**R2026b Update 1** (Abschnitt 9). Ein C-Compiler wird nicht gebraucht.

```matlab
cd <Projektordner>/MATLAB_ASM_Bausteine
startup_asm          % Pfade setzen
build_library        % Bibliothek erzeugen (lib/, etwa 5 s)
build_examples       % Beispielmodelle erzeugen (examples/)
asm_blocks_lib       % Bibliothek öffnen
check_asm            % vollständige Prüfung (Unit-Tests + fachliche Testfälle, etwa 4 min)
```

Im Library Browser erscheint der Eintrag **„ASM-Bausteine (Drehstrom-Asynchronmotor)“** (ggf. im
Library Browser mit F5 aktualisieren). `lib/` wird von `build_library` vollständig neu erzeugt –
dort nichts von Hand ändern.

## 1a Simulation ohne Oberfläche: `run_asm`

Zentraler Einstieg für reproduzierbare Läufe. Der Parametersatz wird **explizit** übergeben, das
Ergebnis explizit zurückgegeben; der Base Workspace wird weder gelesen noch beschrieben.

```matlab
P = asm_params('kloss');          % vollständiger Parametersatz: 'kloss' | 'loop' | 'lab' | 'slides'
P.dM_L = 0;  P.t_end = 1;         % Eingabefelder dürfen geändert werden
R = run_asm(P);                   % Simulation über Simulink.SimulationInput
plot(R.time.t, R.time.n)          % Zeitverläufe
R.metrics.startup                 % Hochlaufzeit bis 0,9·n_N (oder "nicht erreicht")
R.metrics.load_step               % Laststoß: n_vor, n_min/n_max, Einbruch, n_neu, Einschwingzeit
R.metrics.expected                % erwarteter Arbeitspunkt (Kloss bzw. ESB ∩ Last)
R.params, R.sim_input             % tatsächlich verwendete Werte und übergebene Blockparameter
C = compare_kloss_dynamic();      % Vergleich Kloss/Raumzeigermodell beim Laststoß (Abbildung + Tabelle)
```

| Szenario | Modell | Inhalt |
|---|---|---|
| `'kloss'` | `examples/ex_kloss_startup.slx` | **Teil B**: Hochlauf und Laststoß nach Kloss (quasistationär) |
| `'loop'` | `examples/ex_conductor_loop.slx` | **Teil A**: Leiterschleife aus zwei Rotorstäben bei festem Schlupf `P.s_loop` |
| `'lab'` | `examples/ex_startup_load_step.slx` | dynamisches Raumzeigermodell am Netz (Grundlage der Oberfläche) |
| `'slides'` | `examples/ex_slides16_30_rotor_bars.slx` | Folien 16–30: ideales Drehfeld, Rotor steht |

Parameterübergabe: nur über `Simulink.SimulationInput` (`setBlockParameter`, `setModelParameter`),
zusätzliche Signale über `LoggingSpecification`; die Modelle werden nicht verändert und haben keine
Callbacks. Der Motor wird immer mit „Benutzerdefiniert“ und expliziten Werten simuliert, damit die
Maskeninitialisierung nicht verdeckt `asm_standard.m` liest. Bei `P.param_set = 'standard'` werden
die Motorwerte vorher aus `asm_standard.m` in `P` übernommen (Warnung `asm:standard`, falls andere
Werte übergeben wurden). Auch Solver-Einstellungen sind Parameter (`P.max_step`, `P.rel_tol`).
`R.params` enthält die tatsächlich verwendeten Werte, `R.sim_input` das simulierte
`SimulationInput`-Objekt.

**Eingaben und abgeleitete Größen.** Eingaben sind alle Felder von `asm_params` außer den
abgeleiteten. Abgeleitete Größen berechnet `run_asm` immer neu aus den verwendeten Eingaben – auch bei
„custom“: `ns = 60·f1/p`, `w1`, `N1xi1`, die Schleifenwerte `U20`, `R2_S`, `L2s_S` (aus MK, sK, B̂_N,
l, r, f_N, p, N2), die Bezugsdrehzahl der Lüfterlast `n_B`, das Hochlaufziel `n_target` und das
Toleranzband `band`. Ein abweichender Wert für ein abgeleitetes Feld wird mit Warnung
`asm:derived` ignoriert. Beispiel: `P.param_set = 'custom'; P.MK = 60` ändert auch R2 und L2σ der
Leiterschleife, sodass Teil A und Teil B konsistent bleiben.

**Kennzahlen (feste Definitionen, `asmtools.speed_metrics`).** Zwischen den Abtastwerten gilt der
Verlauf als stückweise linear; alle Zeitpunkte werden linear interpoliert.

- *Hochlaufzeit*: erstes Erreichen von `n_target_rel·n_N` (Standard 0,9·n_N = 1296 1/min) vor dem
  Laststoß; ein Abtastwert genau auf dem Ziel zählt als erreicht. Wird das Ziel nicht erreicht:
  „nicht erreicht“ (kein Bezug auf den letzten Simulationswert).
- *Stationäre Werte*: zeitliches Mittel über ein Fenster von 50 ms – vor dem Stoß bis 5 ms vor t_stoß
  (der Laststoß ist mit 0,5 ms geglättet und wirkt bei t_stoß bereits zu 50 %), am Ende die letzten
  50 ms. Das Fenster muss vollständig von Daten abgedeckt sein und nach dem Stoß beginnen (t_stoß +
  5 ms); sonst gibt es keinen Wert („Endfenster zu kurz“ bzw. „überlappt den Laststoß“). Ein einzelner
  letzter Abtastwert gilt nie als Nachweis eines stationären Zustands.
- *Laststoß*: n_vor, minimale Drehzahl n_min danach, Einbruch n_vor − n_min, Unterschwingen
  n_neu − n_min, neuer stationärer Arbeitspunkt n_neu und statischer Unterschied n_vor − n_neu.
  Bei Entlastung (ΔM_L < 0) steigt die Drehzahl; dann gelten n_max und das Überschwingen n_max − n_neu.
- *Einschwingzeit*: Zeit nach t_stoß bis zum letzten Eintritt in das Band |n − n_neu| ≤ ±0,1 % von n_s
  (±1,5 1/min, Rand zählt als innerhalb). Sie wird nur angegeben, wenn das Band ab dann bis zum Ende
  des Auswertefensters gehalten wird; sonst „nicht eingeschwungen“.
- *Erwartung*: stabiler, aus der Anfangsbedingung erreichbarer Schnittpunkt von Motor- und Lastmoment
  (`asmtools.operating_point`, gleiche geglättete Lastkennlinie wie im Lastbaustein), vor dem Stoß ab
  n = 0, danach ab dem alten Arbeitspunkt. Liegt der Schnittpunkt im Stillstand (unter 4,8 1/min, z. B.
  konstantes Lastmoment größer als das Anzugsmoment), meldet `run_asm` „kein erreichbarer stabiler
  Arbeitspunkt“ (Motor läuft nicht an bzw. kippt).

**Fachliche Testfälle:** `T = verify_asm()` simuliert Teil A bei s = 0, s_N, s_K, 1 und Teil B
(Hochlauf, Laststoß) und gibt je Prüfung Sollwert, Istwert, Abweichung, Toleranz, Status und Begründung
aus (Ergebnisse: [VALIDIERUNG.md](VALIDIERUNG.md), Abschnitt 1). Status: „bestanden“, „nicht
bestanden“, „Fehler“ (ausgewählter Test abgebrochen, z. B. Simulationsfehler oder Zeitgrenze, mit
Fehlerkennung), „abgewählt“ (Option `Tests`), „nicht verfügbar“ (Produkt oder erzeugte Datei fehlt),
„Info“ (Wert ohne unabhängigen Sollwert). Nur „bestanden“ zählt als bestanden.
`verify_asm('ErrorOnFailure', true)` bricht bei „nicht bestanden“, „Fehler“ oder „nicht verfügbar“
mit Fehler ab.

## 1b Bedienoberfläche

Wer nur simulieren und auswerten will, braucht keine Masken und keinen Bus Selector:

```matlab
startup_asm          % Pfade setzen (Bibliothek und Beispiele müssen erzeugt sein, siehe oben)
ASMApp               % Bedienoberfläche öffnen
```

![Bedienoberfläche ASMApp](../export/asmapp_bedienoberflaeche.png)

Das Fenster folgt dem Aufbau im Labor von links nach rechts: **Netz 3~ | Motor (ASM) | Welle/Last**,
darunter **Ausgaben** und **Simulationsparameter**. Jeder Bereich zeigt ein Schaltbild-Symbol, die
Eingabefelder (mit Einheit) stehen daneben. Wertebereiche kommen aus dem Bausteinkatalog
(`+asmtools/catalog.m`); ungültige Eingaben (z. B. R1 ≤ 0, p nicht ganzzahlig, J_L = 0) lehnt schon
das Feld ab, der Tooltip nennt den Bereich.

**Betriebsarten** (oben). Nicht benötigte Felder sind ausgegraut.

| Betriebsart | Grundlage | Eingaben |
|---|---|---|
| Laboraufbau Motor | `run_asm`, Szenario `'lab'` | Netz U, f1, Phasenfolge, t_ein; Motor: Parametersatz (bei „Standard“ gesperrt, Werte aus `asm_standard.m`), Stern/Dreieck, R1, L1σ, Lh, R2′, L2σ′, p, J_M; Last: Lasttyp (konstant oder Lüfter) mit M_L, Laststoß ΔM_L und t_stoß (ΔM_L = 0: kein Laststoß), Zusatzträgheit J_L |
| Folien 16–30 (Stillstand, s = 1) | `run_asm`, Szenario `'slides'` | f1, B̂, φ2 (fest oder aus der Rotorimpedanz 90° + φZ); zweipolig, zwei Stäbe |

Lüfterlast: M_L ist das Moment bei der Bezugsdrehzahl n_B = 0,96·n_s (Beispielmotor 1440 1/min).

**Ausgaben** (Tabs):

1. **Zeitverläufe** – Labor: M(t) (Luftspalt-, Wellen- und Lastmoment), n(t), Strangströme i_U, i_V,
   i_W (aus dem Raumzeiger i1) und I_eff. Folien: B⊥ (rot) und Stabstrom (blau) wie Folie 16,
   Kräfte auf Stab 1 und 2, Schleifenmoment M_S.
2. **Kennlinie M(n)** – dynamischer Verlauf, Lastkennlinie, stationäre ESB- und Kloss-Kennlinie mit
   den aktuellen Werten (`asmtools.torque_speed_plot`).
3. **Querschnitt** – Rotorquerschnitt im Folienstil (`asmtools.draw_cross_section`): Stromrichtung
   (• / ×), Feldzeiger, B⊥/B∥, Änderungsvektor, Kraftpfeile; Zeitschieberegler, ▶ (Abspielen/Anhalten),
   Zeitlupe, Ansicht rotor- oder statorfest.
4. **Kennzahlen** – Labor: n_s, n, s, M und I am Ende, Hochlaufzeit bis 0,9·n_N, erwarteter
   Arbeitspunkt, Laststoß (n_vor, n_min, Einbruch, n_neu, Einschwingzeit), Anzugs- und Kippmoment,
   Kippschlupf (stationär aus dem T-ESB), größtes dynamisches Moment. Folien: î_Stab, B̂, φ2, φZ,
   mittleres M_S.

**Abbildung exportieren** speichert die Abbildung des aktiven Tabs mit `asmexport.slide_figure`
(16:9, PNG 300 dpi und SVG) als `export/asmapp_<betriebsart>_<tab>.*`.

**Simulieren** sperrt die Oberfläche bis zum Ende der Rechnung (Laboraufbau 2 s Simulationszeit: einige
Sekunden). Status- und Fehlermeldungen stehen unter dem Knopf, darunter Hinweise zur Plausibilität
(z. B. Dreieckschaltung an 400 V, f1 ≠ f_N, Laststoß nach t_End, Hochlaufziel nicht erreicht).
Die Oberfläche ruft nur `run_asm` auf; das Ergebnis liegt in `app.Result` und wird explizit an
Diagramme und Animation weitergegeben.

## 2 Bausteine

| Gruppe | Bausteine |
|---|---|
| Quellen | Netz 3~ (Phasenfolge, Nullphasenwinkel, Einschaltzeitpunkt, Innenimpedanz), Sternpunkt (Erde) |
| Maschine | **ASM Standard** (kompakt), zerlegt: Klemmbrett (Stern/Dreieck), Stator, Luftspalt-Drehfeld, Käfigläufer |
| Mechanik | Schwungmasse, Welle elastisch, Last konstant, Last Lüfter, Last Kennlinie, Laststoß, Reibung, Mechanischer Bezug |
| Messgeräte | Amperemeter, Voltmeter, Strommessung 3~, Spannungsmessung 3~, Leistungsmesser 3~, Drehmomentmesswelle, Drehzahlmesser, Luftspalt-Sonde, Schreiber |
| Didaktik | Ideales Drehfeld, Rotorstab-Sonde, Drehfeld-Anzeige, Spulenfelder, Kennlinienschreiber |
| Referenz | ASM Referenz (Simscape Electrical), ASM Kloss (quasistationär, Teil B), Leiterschleife (Teil A) |

Jeder Baustein hat eine Maske mit Einheiten, Wertebereichsprüfung und Hilfe (Gleichungen, Quelle).
Doppelklick auf **ASM Standard**: Parametersatz „Standard“ (Felder gesperrt) oder
„Benutzerdefiniert“. Mit Ctrl+U sieht man den zerlegten Motor.

## 3 Ein Modell aufbauen

1. **Netz 3~** und **Sternpunkt (Erde)** an n, dazu eine **Solver Configuration**
   (Simscape › Utilities) an denselben Knoten.
2. Netzleiter a, b, c – optional über **Leistungsmesser 3~** und **Strommessung 3~** (in Reihe) – an
   a, b, c von **ASM Standard**. **Spannungsmessung 3~** und **Voltmeter** parallel anschließen.
3. Welle R des Motors → **Drehmomentmesswelle** → Wellenknoten. Am Wellenknoten: **Schwungmasse**
   (Trägheit der Last), Lasten (R an die Welle, C an den Bezug), **Drehzahlmesser** (R an die Welle,
   C an den Bezug).
4. Gehäuse C des Motors und alle C-Anschlüsse an **Mechanischer Bezug**.
5. Solver: `ode23t`, Relative Toleranz `1e-5`, maximale Schrittweite `1e-4` s.

Fertige Aufbauten: `examples/ex_startup_load_step.slx` (Laboraufbau mit allen Messgeräten),
`examples/ex_kloss_startup.slx` (Teil B), `examples/ex_conductor_loop.slx` (Teil A),
`examples/ex_model_comparison.slx` (ASM Standard, Referenz und Kloss nebeneinander).

**Messbus:** Der Ausgang „Mess“ von ASM Standard ist ein Simulink-Bus mit i1, u1, psi_h, phi_el,
Bhat, i_mu, i2b, M, n, Om, th_mech, theta2, s (Bus Selector verwenden).

## 4 Didaktik: Folien 16–30 im Modell

- `examples/ex_slides16_30_rotor_bars.slx`: zweipoliges **Ideales Drehfeld**, Rotor steht (s = 1),
  φ2 = 90°, Leiterschleife aus zwei Stäben – genau die Situation der Folien 16–30. Die
  **Rotorstab-Sonde** liefert B⊥, Stabströme, Kräfte, Momente.
- Nach der Simulation: Doppelklick auf **Drehfeld-Anzeige** → Knopf **„Animation zeigen“**.
  Darstellung wie in den Folien: U1 oben, Feld im Uhrzeigersinn, rot • = Strom aus der
  Zeichenebene, blau × = hinein, grüner Feldzeiger, roter Anteil B⊥, grün gestrichelt B∥,
  dunkelroter Änderungsvektor, blaue Kraftpfeile.
- `examples/ex_rotor_bars_motor.slx`: dieselben Bausteine am echten Motor (4-polig, 28 Stäbe),
  dazu Spulenfelder und **Kennlinienschreiber** (Knopf „Kennlinie zeichnen“).
- Drehfeld-Anzeige und Kennlinienschreiber protokollieren nach `out.field_display_log` bzw.
  `out.torque_speed_log` – je Modell nur **ein** Baustein dieser Art. Die Knöpfe lesen das letzte
  Simulationsergebnis des Modells (`asmtools.last_sim_output`, die einzige Stelle mit Zugriff auf den
  Base Workspace). Ohne Modellfenster: `R = run_asm(asm_params('slides'));
  asmtools.field_animation(R.field_data, R.field_par)`.

## 5 Folienbilder exportieren

```matlab
export_slide_figures            % alle Folienbilder nach export/ (etwa 1 min)
benchmark_motor                 % Bilder und Kennzahlen des Modellbenchmarks nach export/
compare_kloss_dynamic           % n(t) Kloss gegen Raumzeigermodell beim Laststoß (vergleich_kloss_raumzeiger)
```

Alle drei Skripte schreiben mit `'Folder', ordner` in einen anderen Ordner, z. B. zum Vergleich mit
dem Stand in `export/`, ohne ihn zu überschreiben: `benchmark_motor('Folder', tempdir)`.

Eigene Abbildungen im einheitlichen Stil (16:9, Schrift ≥ 14 pt, PNG 300 dpi und SVG):

```matlab
asmexport.slide_figure(gcf, 'mein_bild')                       % Abbildung
asmexport.model_figure('ex_startup_load_step', 'aufbau')       % Modellansicht
R = run_asm(asm_params('slides'));                             % Querschnitt bei festen Feldwinkeln
asmexport.cross_section_series(R.field_data, R.field_par, 'Angles', 0:30:360)   % folie18 ... folie30
```

Linien mit „L1“, „L2“, „L3“, „Stab 1“, „Stab 2“ im DisplayName erhalten feste Farben
(`'Colours', false` schaltet das ab).

## 6 Prüfen

```matlab
T = verify_asm()      % fachliche Testfälle Teil A/B mit Berichtstabelle (etwa 10 s)
runtests('tests')     % alle Unit-Tests (etwa 3 min)
check_asm             % beides zusammen mit Versionsprotokoll; Fehler, wenn etwas nicht besteht
```

Kommandozeile (Exit-Code ≠ 0, sobald ein Unit-Test fehlschlägt oder eine Prüfzeile „nicht
bestanden“, „Fehler“ oder „nicht verfügbar“ ist):

```
matlab -batch "startup_asm; check_asm('Log', 'check_asm.log')"
```

Ergebnisse, Laufprotokoll und Befunde: [VALIDIERUNG.md](VALIDIERUNG.md).

## 7 Typische Fehler

| Meldung / Verhalten | Ursache und Abhilfe |
|---|---|
| „Each physical network must be connected to exactly one Solver Configuration block“ | Solver Configuration fehlt (oder zwei an einem Netz) |
| Simulation hängt an einem Zeitpunkt | Sprung oder unstetige Funktion im Modell (z. B. PS Step, Simulink-Sprung mit Filter am Netz). Die Bibliotheksbausteine sind ereignisfrei; Laststoß-Baustein verwenden |
| Wert wird in der Maske abgelehnt | Wertebereich (Hilfe des Bausteins zeigt alle Grenzen) |
| „J_M muss > 0 sein“ | Motorträgheit nicht null setzen; Lastträgheit über Schwungmasse |
| Drehfeld-Anzeige: „Keine Simulationsdaten“ | erst im Modellfenster simulieren (Ergebnis in `out`), oder `run_asm` + `asmtools.field_animation(R.field_data, R.field_par)` |
| Spannungsmessung 3~ mit Bezug „Anschluss n“ meldet singuläres System | Anschluss n ist nicht angeschlossen |

## 8 Ordner

| Ordner / Datei | Inhalt |
|---|---|
| `run_asm.m`, `verify_asm.m`, `check_asm.m` | Simulation ohne Oberfläche, fachliche Testfälle, Gesamtprüfung für Batch-Läufe |
| `ASMApp.m` | Bedienoberfläche (programmatische App-Klasse, Abschnitt 1b) |
| `+asmlib/` | Simscape-Quellen (.ssc): Domäne `airgap`, Unterpakete sources, machine, mechanics, sensors, reference |
| `+asmtools/` | Bausteinkatalog (`catalog.m`), Stil, Masken, Prüfstand, Kennzahlen, Rotorstab-Formeln, Didaktik |
| `+asmexport/` | slide_figure, model_figure, cross_section_series |
| `+asmapp/` | Wertebereiche der Eingaben (limits, check_value) |
| `lib/` | **generiert**: `asm_blocks_lib.slx`, `asmlib_lib.slx` |
| `parameter/` | Parametersätze (`asm_standard.m` Motor, `asm_params.m` vollständiger Laufparametersatz) |
| `examples/` | Beispielmodelle und Skripte (build_examples, export_slide_figures, benchmark_motor, compare_kloss_dynamic) |
| `tests/` | matlab.unittest-Tests |
| `doku/` | SPEC, KONVENTIONEN, VALIDIERUNG, diese Anleitung |
| `export/` | erzeugte Folienbilder |

Neuen Baustein anlegen: [KONVENTIONEN.md](KONVENTIONEN.md), Abschnitt 7.

## 9 Kompatibilität

- **Bestätigt (getestet): nur MATLAB R2026b Update 1** mit Simulink 26.2, Simscape 26.2 und Simscape
  Electrical 26.2 unter Windows 11, belegt durch das Laufprotokoll von `check_asm` in einer frischen
  MATLAB-Sitzung (VALIDIERUNG.md, Abschnitt 0). Alle Testergebnisse dort stammen aus diesem Release.
- **Nicht getestet: R2023b und alle anderen älteren Releases.** R2023b ist ein Wunschziel (Labor,
  MATLAB Online der Hochschule), aber nicht bestätigt; ältere Releases waren nicht installiert.
- Die erzeugten `.slx`-Dateien (Bibliothek, Beispiele) haben das R2026b-Format und lassen sich in
  älteren Releases nicht öffnen. Vorgesehener Weg: im älteren Release `startup_asm; build_library;
  build_examples` ausführen – beide erzeugen alles neu aus den Quellen (`.ssc`, `.m`). Falls zusätzlich
  eine mit `save_system(..., 'ExportToVersion', 'R2023b')` exportierte Kopie gebraucht wird, nur in einen
  **separaten Ordner** exportieren, die Originale nicht überschreiben, und die Kopie vor Gebrauch in
  R2023b testen.
- Release-abhängige Stellen haben Rückfallwege (statisch geprüft, nicht ausgeführt): `sscbuild`
  (ab R2024b) → `ssc_build`; `exportgraphics(..., 'Padding', 'figure')` (neuere Releases) → `print`;
  Farbschemata (`theme`, ab R2025a) werden in älteren Releases übersprungen.
- Statische Durchsicht der übrigen Funktionen: alle seit R2022a oder früher verfügbar (u. a.
  `Simulink.SimulationInput` mit `LoggingSpecification`, `arguments`-Blöcke, uifigure/uigridlayout).
  Eine statische Durchsicht ersetzt keinen Test im Ziel-Release.
