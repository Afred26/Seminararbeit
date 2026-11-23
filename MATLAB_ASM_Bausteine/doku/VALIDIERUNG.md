# Validierung der ASM-Bausteinbibliothek (Phasen 2 und 3)

Stand: 13.11.2026, MATLAB R2026b, Simscape 26.2, Simscape Electrical 26.2.
Reproduzieren: `startup_asm; V = validierung_motor();` (Zahlen und Bilder) bzw.
`runtests('tests')` (automatische Prüfung).

> Alle Parameter sind Beispielwerte (`parameter/asm_standard.m`), keine Datenblattwerte.
> Prüfstand (`asmbib.pruefstand`), seit Phase 3 nur aus Bibliotheksbausteinen: Netz 3~ 400 V / 50 Hz
> (starr), Stern, Drehmomentmesswelle, Schwungmasse J_L = 0,01 kg·m², Last Lüfter
> M_L = M_N·(n/n_N)·|n/n_N|, Laststoß 0,3·M_N bei t = 1 s, Drehzahlmesser; Solver ode23t,
> RelTol 1e-5, MaxStep 0,1 ms. Damit sind Netz, Mechanik und Messgeräte in V1 bis V8 mitgeprüft.

## Ergebnisse Motor (ValidierungTest)

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

## Ergebnisse Netz, Messgeräte, Mechanik (Phase 3)

| Test | Prüfung (gegen Rechnung) | Ergebnis |
|---|---|---|
| QuellenMessgeraeteTest | RL-Last in Stern (10 Ω, 20 mH) an 400 V: I, U, P, Q, S, cos φ aller Messgeräte | alle < 0,1 % (z. B. P = 11 471,2 W statt 11 471,3 W, Q = +7 207,7 var induktiv) |
| | Phasenfolge, Nullphasenwinkel, Einschaltzeitpunkt, Innenimpedanz, Bezug n / künstlicher Sternpunkt | ✔ |
| MechanikTest | Auslauf einer Schwungmasse mit viskoser/Coulomb-Reibung, Last konstant, Lüfter, Kennlinie, Laststoß | < 0,2 % gegen analytische Lösung |
| | Welle elastisch: Torsionseigenfrequenz und Schwerpunktdrehzahl zweier Massen | < 1 % |
| | Drehmomentmesswelle (Vorzeichen R → C), Drehzahlmesser (n, Ω, ϑ, s) | ✔ |
| BeispieleTest | alle vier Beispielmodelle bauen und laufen; Enddrehzahlen Standard = Referenz, Kloss 1424,5 1/min | ✔ |

## Ergebnisse Didaktik (Phase 4, DidaktikTest)

| Prüfung | Ergebnis |
|---|---|
| Folienzustände mit Ideales Drehfeld + Rotorstab-Sonde (p = 1, s = 1, φ2 = 90°): Strom 0 bei θ2 = 0° (Folie 18), Stab 1 maximal aus der Ebene bei 90° (Folie 21), Umkehr bei 270° (Folie 27), Kraft stets ≥ 0 | ✔ (< 0,1 %) |
| mittleres Schleifenmoment = î·l·B̂·r·sin φ2 | ✔ (< 0,1 %) |
| Rotorstab-Sonde am Motor: Summe aller 28 Stabmomente = Luftspaltmoment des Messbusses | < 10⁻³·MK ✔ |
| Leiterschleife (Prototyp Teil A): N_S·M_S(sK) = MK, î2(sK) | < 0,2 % ✔ |
| Spulenfelder: B̂ = 1,5·B̂_Spule, Feldwinkel = Stromwinkel | exakt ✔ |
| Folienserie 18–30 (13 Bilder), Animation, Kennlinien- und Spulenfeldbild | ✔ |

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

### Bilder (`export/`)

| Datei | Inhalt |
|---|---|
| [validierung_hochlauf_n.png](../export/validierung_hochlauf_n.png) | n(t): ASM Standard, ee_lib-Referenz, Kloss (quasistationär) |
| [validierung_hochlauf_M.png](../export/validierung_hochlauf_M.png) | Wellenmoment beim direkten Einschalten (Drehmomentmesswelle) |
| [validierung_kennlinie.png](../export/validierung_kennlinie.png) | M(n): ESB, Kloss, Simulationspunkte, dynamischer Hochlauf |
| [validierung_rotorstab.png](../export/validierung_rotorstab.png) | Stabströme und Schleifenmoment im Bemessungsbetrieb |

## Befunde

1. **Numerik bei kleinem Schlupf (behoben).** In der ersten Fassung wurde die Rotorgleichung
   statorfest gelöst. Die Trapezregel von ode23t verfälscht die Frequenz der 50-Hz-Schwingung
   um etwa (ω1·h)²/12 ≈ 8·10⁻⁵. Dieser Fehler wirkt direkt auf die Schlupffrequenz und wird mit 1/s
   verstärkt: +0,44 % Moment bei s = 0,02, Leerlaufdrehzahl 1500,1 statt 1500 1/min. Mit
   MaxStep 0,04 ms sank der Fehler auf 0,06 % (Nachweis, dass es Numerik ist). Lösung: Der
   Käfigläufer löst seine Spannungsgleichung jetzt intern rotorfest (Zustand ψ2r, mathematisch
   identisch). Danach −0,02 % über den ganzen Schlupfbereich, Leerlauf exakt 1500,000 1/min.
2. **Dynamik gegen Kloss.** Beim direkten Einschalten erreicht das Luftspaltmoment kurzzeitig
   etwa 106 Nm ≈ 1,5·MK und wird zeitweise negativ (Ausgleichsvorgänge des Statorflusses). Die
   Kloss-Formel (Teil B) kann das grundsätzlich nicht zeigen.
3. **Bemessungspunkt.** Mit den Beispielwerten liegt der stationäre Punkt bei M_N bei 1445 1/min
   statt n_N = 1440 1/min (0,35 % von ns). Ursache: Kloss-Abgleich auf MK/sK, nicht auf (n_N, M_N);
   siehe SPEC 3.6 Nr. 2.
4. **Prüfstand.** Zwei Solverfallen beim Aufbau, beide in `asmbib.pruefstand` behoben und
   kommentiert: (a) Lastmoment aus der Drehzahl in Simulink gerechnet → algebraische Schleife;
   jetzt im Simscape-Netz (PS-Blöcke, ohne Nulldurchgangserkennung). (b) Laststoß über PS Step
   oder gefilterten Eingang → der Solver der ee_lib-Maschine bleibt am Sprung hängen (bekannt aus
   Prototyp Teil C); jetzt Simulink-Step ohne Nulldurchgang, ungefiltert. Jede Simulation hat eine
   Rechenzeitgrenze (`TimeOut`, Standard 300 s).
5. **J_M > 0.** Mit J_M = 0 hat der Käfigläufer keine Drehzahl-Zustandsgröße mehr (Simscape bricht
   ab). Die Maske verlangt daher J_M > 0.
6. **Solver-Ereignisse und die ee_lib-Maschine (Phase 3, behoben).** Im Vergleichsbeispiel blieb der
   Solver bei t = 10,4 ms stehen, sobald ASM Standard und ASM Referenz im selben Modell liefen (einzeln
   liefen beide). Ursache: `atan2` in den Winkelausgängen φ_el und θ2 der Simscape-Komponenten
   erzeugt Nulldurchgangsereignisse; bei jedem Ereignis initialisiert der Solver neu, und daran
   scheitert die ee_lib-Maschine (wie schon beim Laststoß in Phase 2). Lösung: Die Komponenten geben
   nur ψh aus, die Winkel rechnet der Baustein in Simulink (Fcn-Block, ereignisfrei). Danach laufen
   beide Motoren auch am selben Netzknoten. Regel seitdem: Simscape-Gleichungen der Bibliothek sind
   ereignisfrei (keine Sprünge, kein abs/sign/atan2/if über Variablen; Glättung mit tanh).
7. **Effektivwerte und Leistungsmittel (Phase 3).** Gleitende Mittelwerte mit `delay` bzw. `integ`
   in Simscape brauchen sehr viel Verlaufsspeicher (Fehler „Insufficient memory budget for delay
   expressions“; mit 64 MB Budget lief die 0,2-s-Prüfschaltung über 2 min). Lösung: Die
   Komponenten liefern Augenblickswerte (i², p, q, …), gemittelt wird im Baustein in Simulink mit
   Integrator und Transport Delay (Fenster 1/f_mess). Prüfschaltung jetzt 2,8 s.
8. **Glättung |Ω| in „Last Kennlinie“ (Phase 3, behoben).** Die erste Fassung √(Ω² + ε²) − ε
   verschob den Arbeitspunkt um ε = 0,1 rad/s (0,4 % Fehler im Auslauftest). Jetzt Ω·tanh(Ω/ε),
   für |Ω| ≫ ε exakt.
