# Modellprüfung der ASM-Bausteinbibliothek: Testfälle, Konsistenzprüfungen, Modellbenchmark

Stand: 26.11.2026, MATLAB R2026b Update 1, Simscape 26.2, Simscape Electrical 26.2 (nur dieses
Release ist getestet, siehe ANLEITUNG Abschnitt 9).
Reproduzieren: `startup_asm; T = verify_asm()` (fachliche Testfälle), `V = benchmark_motor()`
(Modellvergleich mit Bildern), `runtests('tests')` (73 automatische Tests, alle bestanden).

> Alle Parameter sind Beispielwerte (`parameter/asm_standard.m`), keine Datenblattwerte.
>
> **Einordnung:** Alle Prüfungen in diesem Dokument vergleichen Modell mit Rechnung oder Modell mit
> Modell – mit denselben Beispielparametern und denselben Grundannahmen (Grundwelle, keine Sättigung,
> keine Stromverdrängung). Sie zeigen, dass die Umsetzung ihre Gleichungen richtig löst
> (Verifikation, Konsistenzprüfung, Modellbenchmark). **Eine experimentelle Validierung gegen
> Messungen an einem realen Motor liegt nicht vor.** Der Dateiname „VALIDIERUNG“ ist historisch.

Prüfstand für V1–V8 (`asmtools.test_bench`), nur aus Bibliotheksbausteinen: Netz 3~ 400 V / 50 Hz
(starr), Stern, Drehmomentmesswelle, Schwungmasse J_L = 0,01 kg·m², Last Lüfter
M_L = M_N·(n/n_N)·|n/n_N|, Laststoß 0,3·M_N bei t = 1 s, Drehzahlmesser; Solver ode23t,
RelTol 1e-5, MaxStep 0,1 ms. Damit sind Netz, Mechanik und Messgeräte in V1 bis V8 mitgeprüft.

## 1 Fachliche Testfälle Teil A und Teil B (`verify_asm`)

Alle Läufe über `run_asm` und die Beispielmodelle `ex_conductor_loop` (Teil A), `ex_kloss_startup`
(Teil B) und `ex_startup_load_step` (dynamisches Modell). Abweichung = Ist − Soll.

| Test | Größe | Soll | Ist | Abweichung | Toleranz | Status |
|---|---|---|---|---|---|---|
| A1 | s = 0: max. Rotorstrom \|i_k\| | 0 A | 0 A | 0 | 1e-9 A | bestanden |
| A1 | s = 0: max. Schleifenmoment \|M_S\| | 0 N·m | 0 N·m | 0 | 1e-9 N·m | bestanden |
| A2 | s = s_N = 0,04: mittleres Schleifenmoment (2 Rotorperioden) | 1,965 66 N·m | 1,965 66 N·m | 5e-13 | 1e-6 relativ | bestanden |
| A3 | s = s_K = 0,2: mittleres Schleifenmoment | 5,110 71 N·m | 5,110 71 N·m | −4e-14 | 1e-6 relativ | bestanden |
| A4 | s = 1: mittleres Schleifenmoment | 1,965 66 N·m | 1,965 66 N·m | −2e-14 | 1e-6 relativ | bestanden |
| A5 | Konsistenz N_S·M̄_S(s_K) = MK | 71,55 N·m | 71,55 N·m | −5e-13 | 1e-6 relativ | bestanden |
| B1 | stationäre Drehzahl nach dem Hochlauf (Kloss ∩ Lüfterlast) | 1442,21 1/min | 1442,21 1/min | −7e-12 | 0,15 1/min | bestanden |
| B1 | Hochlaufzeit bis 0,9·n_N = 1296 1/min | 77,006 ms | 77,006 ms | 1e-7 s | 0,5 ms | bestanden |
| B2 | vor dem Laststoß eingeschwungen (max. Abweichung im Fenster) | 0 | 1,7e-9 1/min | – | 1,5 1/min | bestanden |
| B2 | Drehzahl vor dem Laststoß | 1442,21 1/min | 1442,21 1/min | −2e-11 | 0,15 1/min | bestanden |
| B2 | minimale Drehzahl nach dem Laststoß | 1424,47 1/min | 1424,47 1/min | 7e-12 | 0,15 1/min | bestanden |
| B2 | Drehzahleinbruch n_vor − n_min | 17,739 1/min | 17,739 1/min | −2e-11 | 0,3 1/min | bestanden |
| B2 | neuer stationärer Arbeitspunkt | 1424,47 1/min | 1424,47 1/min | 3e-12 | 0,15 1/min | bestanden |
| B2 | Einschwingzeit (Band ±1,5 1/min) | 13,04 ms | 13,12 ms | 0,08 ms | 0,5 ms | bestanden |
| Z1 | dyn. Modell: Drehzahl vor dem Laststoß (ESB ∩ Last) | 1444,78 1/min | 1444,77 1/min | −0,007 | 0,75 1/min | bestanden |
| Z2 | dyn. Modell: neuer stationärer Arbeitspunkt | 1427,43 1/min | 1427,42 1/min | −0,011 | 0,75 1/min | bestanden |
| Z3 | dyn. Modell: Drehzahleinbruch | – | 31,04 1/min | – | – | Info |
| Z4 | dyn. Modell: Einschwingzeit | – | 56,0 ms | – | – | Info |
| R | Bemessungspunkt: Kloss-Moment bei s_N (Soll = M_N) | 26,50 N·m | 27,52 N·m | +1,02 N·m (+3,8 %) | – | Info |

Begründung der Toleranzen (vollständig in der Spalte `Begruendung` der Rückgabetabelle):

- **A, s = 0:** ohne Relativbewegung keine induzierte Spannung, Strom und Moment exakt null;
  Toleranz nur Rundung.
- **A, s > 0:** Sollwert analytisch M̄_S = î2·l·B̂·r·sin φ2 (`asmtools.loop_mean_torque`, SPEC 3.1).
  θ2 = s·ω1·t wird bei konstantem s exakt integriert, die Pulsation mit 2·s·f1 mittelt sich über ganze
  Rotorperioden heraus; erwartet ist Gleichheit bis auf Rundung. 1e-6 relativ deckt die
  Interpolation zwischen Solverschritten ab. A5 ist eine **Konsistenzprüfung**, keine unabhängige
  Validierung: R2 und L2σ der Schleife sind aus MK und sK abgeleitet (`asmtools.loop_parameters`).
- **B, Drehzahlen:** Sollwert = stabiler, aus der Anfangsbedingung erreichbarer Schnittpunkt von
  Motor- und Lastmoment (`asmtools.operating_point`; nach dem Laststoß ausgehend vom alten
  Arbeitspunkt). 0,01 % von n_s: stationärer Endwert, Solver-RelTol 1e-5; die geglättete Lüfterlast
  weicht um weniger als 1e-6·M_B ab.
- **B, Zeiten:** Sollwert aus der direkten Integration derselben Bewegungsgleichung
  J·dΩ/dt = M_Kloss − M_L (ode45, RelTol 1e-10) mit derselben Auswertung – das prüft die
  Lösungsverfahren gegeneinander, keine unabhängige Physik. 0,5 ms = 5·MaxStep.
- **B2, Minimum:** Das Kloss-Modell ist ein System 1. Ordnung ohne elektrische Dynamik; der Übergang
  ist monoton, das Minimum nach dem Stoß ist der neue Arbeitspunkt.
- **Z:** Das dynamische Modell trifft stationär die ESB-Kennlinie auf 0,02 % (V1); Toleranz 0,05 %
  von n_s. Für Einbruch und Einschwingzeit des dynamischen Modells gibt es keinen analytischen
  Sollwert (elektromagnetische Ausgleichsvorgänge, Unterschwingen um 31 statt 17 1/min), daher „Info“.
- Nicht ausgewählte oder nicht ausführbare Tests erscheinen als „nicht ausgeführt“ mit Grund.

## 2 Befunde der Vorprüfung und Umsetzung (26.11.2026)

| Nr. | Befund der Vorprüfung | Ergebnis der Prüfung | Änderung | Nachweis |
|---|---|---|---|---|
| 1 | Bemessungspunkt: Kloss liefert bei n_N 27,52 statt 26,50 N·m | **bestätigt**: s_N = 0,04, M_Kloss(s_N) = 27,519 N·m (+3,85 %). Zufall der Beispielwerte: s_N = sK², daher M(s_N) = M(s = 1). Kloss erreicht M_N bei 1442,4 1/min, das dynamische Modell (ESB) bei 1445,2 1/min | **kein Parameter geändert**: n_N und M_N sind laut Parametersatz nur Information, MK und sK sind die abgeglichenen Größen, aus denen ESB-Werte und Schleifenwerte abgeleitet sind. Abweichung als Eigenschaft des Beispieldatensatzes gekennzeichnet. MK und sK stehen jetzt zentral in `asm_standard.m` (vorher als Literale verstreut) | `asmtools.rated_point`, Zeile R in `verify_asm`, Test `ratedPointFinding` |
| 2 | Reproduzierbarer Lauf ohne GUI, Parameter über SimulationInput, Callbacks, `assignin`/`evalin` | **teilweise bestätigt**: Ein GUI-freier Kern mit SimulationInput gab es schon (`asmapp.simuliere`, Labor/Folien). Keine Modell-Callbacks, kein `assignin`. `evalin` nur in den zwei Maskenknöpfen. Implizite Abhängigkeit: Bei „Standard“ liest die Maskeninitialisierung `asm_standard.m` | `run_asm(P)` als zentrale Funktion für alle vier Szenarien (neu: Teil A `'loop'`, Teil B `'kloss'`), `asm_params` liefert den vollständigen Parametersatz; Motor immer „Benutzerdefiniert“ mit expliziten Werten; Ergebnis `R` explizit an Auswertung, GUI und Animation; Base-Workspace-Zugriff nur noch in `asmtools.last_sim_output` (Maskenknöpfe) | Test `runAsmIsExplicit` (Modell unverändert, Base Workspace unverändert, Parameter wirkt), `labLikeExampleModel` |
| 3 | Kennzahlen: „90 % des letzten Simulationswerts“ | **in dieser Bibliothek nicht vorhanden** (stammt aus `plot_asm.m` des Prototyps); es gab gar keine Hochlaufzeit, und die Endwerte (Mittel der letzten 5 %) trennten den Laststoß nicht | feste Definitionen in `asmtools.speed_metrics`: Hochlaufzeit bis 0,9·n_N mit „nicht erreicht“, Laststoß separat (vorher, Minimum, Einbruch, neuer Arbeitspunkt), Einschwingzeit nur bei Band bis Fensterende; Erwartungswerte über `asmtools.operating_point` | Tests `speedMetricsFirstOrder`, `speedMetricsLoadStep`, `operatingPointReachable`, B1/B2 |
| 4 | Drei fachliche Testfälle mit Bericht | Teil A war nur bei s = s_K geprüft | `verify_asm` mit A (s = 0, s_N, s_K, 1), B1, B2, Zusatz Z und Info R | Abschnitt 1, Test `allTechnicalCasesPass` |
| 5 | Aussagekraft, Referenz, Version | Kopplung A/B: siehe Abschnitt 3. „Validiert“ in README war zu stark formuliert. Widerspruch „R2023b oder neuer“ ↔ R2026b-Modelle **bestätigt** | Formulierungen auf Modellbenchmark/Konsistenz geändert; Kompatibilität: nur R2026b bestätigt, R2023b nicht getestet (ANLEITUNG 9) | – |
| – | (nebenbei) Test `libraryBrowser` schlug fehl, weil der Ordner inzwischen `MATLAB_ASM_Bausteine` heißt | bestätigt (63/64 vorher) | Test prüft jetzt den Pfad dieses Projekts statt eines Ordnernamens | 73/73 |

Außerdem: gesamter MATLAB-Code auf englische Bezeichner und Kommentare umgestellt; alle sichtbaren
Texte bleiben deutsch (KONVENTIONEN 6, SPEC 15). Die Physik ist unverändert: V1–V6 liefern nach der
Umstellung dieselben Zahlen wie vorher (Abschnitt 4).

## 3 Einordnung: Teil A, Teil B und Simscape-Referenz

**Teil A ↔ Teil B.** Die Leiterschleife (Teil A) erhält den Schlupf als **Vorgabe** (Konstante im
Modell `ex_conductor_loop`, `P.s_loop` in `run_asm`); sie übernimmt den Schlupf nicht automatisch aus
dem Hochlauf (Teil B). Eine einseitige Kopplung ist möglich, indem man z. B. `R.metrics.s_end` aus
Teil B als `s_loop` übergibt. Das Schleifenmoment wirkt **nicht** auf die Mechanik zurück: Teil B
rechnet das Motormoment allein mit der Kloss-Formel. Weil R2 und L2σ der Schleife aus MK und sK
abgeleitet sind, ist die Übereinstimmung N_S·M̄_S(s) = M_Kloss(s) eine **Konsistenzprüfung** der
Herleitung, keine unabhängige Validierung.

**Simscape-Electrical-Referenz (V2).** Vergleichbarkeit der Prüfstände (`asmtools.test_bench`, Motor
`'asm'` bzw. `'ee'`):

| Merkmal | ASM Standard | ASM Referenz (ee_lib) | vergleichbar |
|---|---|---|---|
| Netz | Netz 3~ 400 V, 50 Hz, starr, Stern, Sternpunkt frei | identisch (Phase Splitter, Floating Neutral) | ja |
| Parameter | R1, L1σ, Lh, R2′, L2σ′, p aus `asm_standard.m` | dieselben Werte (SI), ohne Sättigung, Einfachkäfig | ja |
| Trägheit | J_M im Käfigläufer + Schwungmasse J_L | J_M als Inertia im Referenzbaustein + J_L | ja |
| Last | Lüfter M_N·(n/n_N)², Laststoß 0,3·M_N bei 1 s | identisch | ja |
| Anfangsbedingungen | stromlos, n = 0 | alle Flussverkettungen 0 (Priorität hoch), n = 0 | ja |
| Auswertefenster | 0 … 2 s, max. Abweichung über das ganze Fenster | identisch | ja |

Damit ist V2 ein **Modellbenchmark** (zwei unabhängige Implementierungen derselben Gleichungen),
**keine experimentelle Validierung**. Der Kloss-Motor im selben Prüfstand dient nur zur Einordnung.

## 4 Modellbenchmark Motor (BenchmarkTest)

| Nr. | Prüfung | Ergebnis | Kriterium |
|---|---|---|---|
| V1 | stationäre Punkte s = 0,02 … 1 gegen T-ESB | −0,017 % … −0,061 % | < 0,5 % ✔ |
| V2 | Hochlauf + Laststoß gegen ASM Referenz (ee_lib Induction Machine Squirrel Cage) | Δn ≤ 0,026 % von ns, Wellenmoment ΔM ≤ 0,043 % von MK | < 1 % ✔ |
| V3 | Bemessungsbetrieb M_L = M_N | n = 1445,2 1/min (Kloss 1442,4, n_N = 1440) | < 1 % von ns ✔ |
| V4 | Rotorstab-Formeln: Σ M_k gegen M | max. Abweichung 4·10⁻⁷ · MK | < 10⁻³ ✔ |
| V4 | Zwei-Stab-Schleife im Mittel gegen 2/N2·M | 1,9054 Nm = 1,9054 Nm | < 1 % ✔ |
| V5 | Leerlauf ohne Reibung | n = 1500,000 1/min | < 0,1 % ✔ |
| V5 | Kippmoment bei sK = 0,2 | 71,53 Nm (ESB 71,55 Nm) | < 1 % ✔ |
| V6 | Energiebilanz Hochlauf 0 … 2 s | E_el = 10 368 J, Verluste 1 446 J, mech. 8 917 J, ΔW_mag 5 J, Fehler −0,006 % | < 0,5 % ✔ |
| V7 | Baustein ASM Kloss gegen direkte Integration (ode45) | Δn ≤ 0,0005 % von ns | < 0,1 % ✔ |
| V8 | Klemmbrett: Dreieck an 231 V gegen Stern an 400 V | Δn < 0,01 % von ns | < 0,01 % ✔ |

### V1 – stationäre Kennlinie (feste Drehzahl, Mittel über die letzten 0,2 s)

| s | M_Sim [Nm] | M_ESB [Nm] | Abweichung | M_Kloss [Nm] |
|---|---|---|---|---|
| 0,02 | 15,006 | 15,010 | −0,022 % | 14,168 |
| 0,05 | 34,956 | 34,962 | −0,017 % | 33,671 |
| 0,10 | 58,032 | 58,045 | −0,021 % | 57,240 |
| 0,20 | 71,532 | 71,547 | −0,021 % | 71,550 |
| 0,40 | 58,051 | 58,061 | −0,019 % | 57,240 |
| 0,70 | 39,093 | 39,102 | −0,022 % | 37,800 |
| 1,00 | 28,750 | 28,768 | −0,061 % | 27,519 |

Die verbleibende Abweichung von −0,02 % ist Diskretisierungsfehler des Solvers (siehe unten). Bei
s = 1 klingt der Gleichfluss nach dem Einschalten langsam ab (τ ≈ (Lh + L2σ′)/R2′ ≈ 0,2 s), daher
3 s Simulationszeit.

## 5 Netz, Messgeräte, Mechanik, Beispiele

| Test | Prüfung (gegen Rechnung) | Ergebnis |
|---|---|---|
| SourcesSensorsTest | RL-Last in Stern (10 Ω, 20 mH) an 400 V: I, U, P, Q, S, cos φ aller Messgeräte | alle < 0,1 % (z. B. P = 11 471,2 W statt 11 471,3 W, Q = +7 207,7 var induktiv) |
| | Phasenfolge, Nullphasenwinkel, Einschaltzeitpunkt, Innenimpedanz, Bezug n / künstlicher Sternpunkt | ✔ |
| MechanicsTest | Auslauf einer Schwungmasse mit viskoser/Coulomb-Reibung, Last konstant, Lüfter, Kennlinie, Laststoß | < 0,2 % gegen analytische Lösung |
| | Welle elastisch: Torsionseigenfrequenz und Schwerpunktdrehzahl zweier Massen | < 1 % |
| | Drehmomentmesswelle (Vorzeichen R → C), Drehzahlmesser (n, Ω, ϑ, s) | ✔ |
| ExamplesTest | alle sechs Beispielmodelle bauen und laufen; Enddrehzahlen Standard = Referenz, Kloss 1424,5 1/min; keine Callbacks | ✔ |

## 6 Didaktik (DidacticsTest)

| Prüfung | Ergebnis |
|---|---|
| Folienzustände mit Ideales Drehfeld + Rotorstab-Sonde (p = 1, s = 1, φ2 = 90°): Strom 0 bei θ2 = 0° (Folie 18), Stab 1 maximal aus der Ebene bei 90° (Folie 21), Umkehr bei 270° (Folie 27), Kraft stets ≥ 0 | ✔ (< 0,1 %) |
| mittleres Schleifenmoment = î·l·B̂·r·sin φ2 | ✔ (< 0,1 %) |
| Rotorstab-Sonde am Motor: Summe aller 28 Stabmomente = Luftspaltmoment des Messbusses | < 10⁻³·MK ✔ |
| Leiterschleife (Teil A): N_S·M_S(sK) = MK, î2(sK) | < 0,2 % ✔ |
| Spulenfelder: B̂ = 1,5·B̂_Spule, Feldwinkel = Stromwinkel | exakt ✔ |
| Folienserie 18–30 (13 Bilder), Animation, Kennlinien- und Spulenfeldbild | ✔ |

### Bilder (`export/`)

| Datei | Inhalt |
|---|---|
| [validierung_hochlauf_n.png](../export/validierung_hochlauf_n.png) | n(t): ASM Standard, ee_lib-Referenz, Kloss (quasistationär) |
| [validierung_hochlauf_M.png](../export/validierung_hochlauf_M.png) | Wellenmoment beim direkten Einschalten (Drehmomentmesswelle) |
| [validierung_kennlinie.png](../export/validierung_kennlinie.png) | M(n): ESB, Kloss, Simulationspunkte, dynamischer Hochlauf |
| [validierung_rotorstab.png](../export/validierung_rotorstab.png) | Stabströme und Schleifenmoment im Bemessungsbetrieb |

## 7 Frühere Befunde (Phasen 2–4)

1. **Numerik bei kleinem Schlupf (behoben).** In der ersten Fassung wurde die Rotorgleichung
   statorfest gelöst. Die Trapezregel von ode23t verfälscht die Frequenz der 50-Hz-Schwingung
   um etwa (ω1·h)²/12 ≈ 8·10⁻⁵. Dieser Fehler wirkt direkt auf die Schlupffrequenz und wird mit 1/s
   verstärkt: +0,44 % Moment bei s = 0,02, Leerlaufdrehzahl 1500,1 statt 1500 1/min. Mit
   MaxStep 0,04 ms sank der Fehler auf 0,06 % (Nachweis, dass es Numerik ist). Lösung: Der
   Käfigläufer löst seine Spannungsgleichung jetzt intern rotorfest (Zustand ψ2r, mathematisch
   identisch). Danach −0,02 % über den ganzen Schlupfbereich, Leerlauf exakt 1500,000 1/min.
2. **Dynamik gegen Kloss.** Beim direkten Einschalten erreicht das Luftspaltmoment kurzzeitig
   etwa 106 Nm ≈ 1,5·MK und wird zeitweise negativ (Ausgleichsvorgänge des Statorflusses). Die
   Kloss-Formel (Teil B) kann das grundsätzlich nicht zeigen; ebenso nicht das Unterschwingen nach
   dem Laststoß (Z3: 31 statt 17,7 1/min Einbruch).
3. **Bemessungspunkt.** Siehe Abschnitt 2, Nr. 1.
4. **Prüfstand.** Zwei Solverfallen beim Aufbau, beide in `asmtools.test_bench` behoben und
   kommentiert: (a) Lastmoment aus der Drehzahl in Simulink gerechnet → algebraische Schleife;
   jetzt im Simscape-Netz. (b) Laststoß über PS Step oder gefilterten Eingang → der Solver der
   ee_lib-Maschine bleibt am Sprung hängen (bekannt aus Prototyp Teil C); jetzt ereignisfrei geglättet.
   Jede Simulation hat eine Rechenzeitgrenze (`TimeOut`, Standard 300 s).
5. **J_M > 0.** Mit J_M = 0 hat der Käfigläufer keine Drehzahl-Zustandsgröße mehr (Simscape bricht
   ab). Die Maske verlangt daher J_M > 0.
6. **Solver-Ereignisse und die ee_lib-Maschine (behoben).** Im Vergleichsbeispiel blieb der Solver bei
   t = 10,4 ms stehen, sobald ASM Standard und ASM Referenz im selben Modell liefen. Ursache: `atan2`
   in den Winkelausgängen der Simscape-Komponenten erzeugt Nulldurchgangsereignisse. Lösung: Die
   Komponenten geben nur ψh aus, die Winkel rechnet der Baustein in Simulink (Fcn-Block, ereignisfrei).
   Regel seitdem: Simscape-Gleichungen der Bibliothek sind ereignisfrei.
7. **Effektivwerte und Leistungsmittel.** Gleitende Mittelwerte mit `delay` bzw. `integ` in Simscape
   brauchen sehr viel Verlaufsspeicher. Lösung: Die Komponenten liefern Augenblickswerte, gemittelt
   wird im Baustein in Simulink mit Integrator und Transport Delay (Fenster 1/f_mess).
8. **Glättung |Ω| in „Last Kennlinie“ (behoben).** Die erste Fassung √(Ω² + ε²) − ε verschob den
   Arbeitspunkt um ε = 0,1 rad/s (0,4 % Fehler im Auslauftest). Jetzt Ω·tanh(Ω/ε).

## 8 Modellannahmen und Grenzen (Textbaustein für die Seminararbeit)

Der Prototyp bildet zwei vereinfachte Sichten auf den Käfigläufer ab. Teil A betrachtet eine
einzelne Leiterschleife aus zwei Rotorstäben in einem sinusförmigen Drehfeld konstanter Amplitude
bei fest vorgegebenem Schlupf; Stromverdrängung, Nutung, Oberwellen und die Rückwirkung des
Rotorstroms auf das Luftspaltfeld sind vernachlässigt, und das Schleifenmoment wirkt nicht auf die
Mechanik zurück. Teil B beschreibt Hochlauf und Laststoß quasistationär mit der Kloss-Formel
(R1 = 0, konstanter Fluss, starre Welle, keine elektrische Dynamik); Einschaltpendelmomente und das
Unterschwingen nach einem Laststoß kann dieses Modell grundsätzlich nicht zeigen. Die Ersatzwerte der
Leiterschleife sind aus Kippmoment und Kippschlupf abgeleitet, sodass die Übereinstimmung zwischen
Teil A und Teil B eine Konsistenzprüfung der Herleitung und keine unabhängige Bestätigung ist.
Ebenso ist der Vergleich mit der Asynchronmaschine aus Simscape Electrical ein Modellbenchmark mit
denselben Annahmen und Parametern, keine experimentelle Validierung. Alle Parameter sind Beispielwerte
eines fiktiven 4-kW-Motors; der Bemessungspunkt (1440 1/min, 26,5 N·m) liegt nicht exakt auf der
Kloss-Kennlinie (27,5 N·m bei s_N), weil Kippmoment und Kippschlupf vorgegeben und nicht an den
Bemessungspunkt angepasst sind. Ein Einfachkäfig ohne Stromverdrängung liefert zudem ein zu kleines
Anzugsmoment (≈ 1,04·M_N statt 2–2,5·M_N realer Motoren). Die Ergebnisse eignen sich daher, um
Wirkprinzip und qualitatives Betriebsverhalten zu erklären, nicht um einen bestimmten Motor
quantitativ vorherzusagen. Alle Ergebnisse wurden mit MATLAB R2026b erzeugt.
