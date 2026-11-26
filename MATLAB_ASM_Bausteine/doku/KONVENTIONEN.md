# Konventionen der ASM-Bausteinbibliothek

Gilt für alle Bausteine, Skripte und Tests. Hintergrund und Herleitungen: [SPEC.md](SPEC.md).

## 1 Notation (wie Folien)

Index 1 = Stator, Index 2 = Rotor. Rotorgrößen im Motormodell sind auf den Stator bezogen (′).

| Formelzeichen | Code | Bedeutung | Einheit |
|---|---|---|---|
| f1, ω1 | `f1`, `w1` | Statorfrequenz, -kreisfrequenz | Hz, rad/s |
| p | `p` | Polpaarzahl | – |
| ns | `ns` | Synchrondrehzahl 60·f1/p | 1/min |
| n, Ω | `n`, `Om` | Drehzahl, mech. Winkelgeschwindigkeit | 1/min, rad/s |
| s | `s` | Schlupf (ns − n)/ns | – |
| ϑ | `th_mech` | mech. Rotorwinkel | rad |
| γ, γ_k | `gam`, `gam_k` | Luftspaltwinkel (el.), Lage von Stab k (el.) | rad |
| φ_el | `phi_el` | Feldwinkel (Lage des Flussdichtemaximums, el., statorfest) | rad |
| θ2 | `theta2` | Feldwinkel relativ zum Rotor, φ_el − p·ϑ | rad |
| φ2, φ_Z | `phi2`, `phiZ` | Versatzwinkel Flussdichte/Strombelag, Rotorimpedanzwinkel | rad |
| B̂ | `Bhat` | Amplitude der Luftspaltflussdichte | T |
| ψh, iμ | `psi_h`, `i_mu` | Hauptflussverkettung, Magnetisierungsstrom (Raumzeiger αβ) | Wb, A |
| R1, L1σ | `R1`, `L1s` | Statorwiderstand, Statorstreuinduktivität | Ω, H |
| Lh | `Lh` | Hauptinduktivität | H |
| R2′, L2σ′ | `R2b`, `L2sb` | Rotorwiderstand, Rotorstreuinduktivität (statorbezogen) | Ω, H |
| i2′ | `i2b` | Rotorstrom (statorbezogen, αβ) | A |
| N1ξ1 | `N1xi1` | wirksame Windungszahl je Strang | – |
| l, r, N2 | `l`, `r`, `N2` | Stablänge, Radius der Stabmitte, Stabzahl | m, m, – |

Schreibregeln für Code-Bezeichner: σ → `s`, Strich (′) → `b` (bezogen), Dach (^) → `hat`,
griechische Buchstaben ausgeschrieben (`psi`, `phi`, `theta`, `xi`), ϑ → `th`.
In Folien und Diagrammen: p (nicht Z_p), ω (nicht ϖ), φ_el nur für den Feldwinkel.

## 2 Koordinaten und Vorzeichen

- **Raumzeiger** amplitudeninvariant, statorfest: x = 2/3·(x_a + a·x_b + a²·x_c), a = e^(j2π/3).
- **γ** wird in Drehrichtung des Feldes gezählt. Rechnung intern mathematisch positiv (αβ-Ebene).
- **Darstellung wie Folien:** U1 oben, V1 unten rechts, W1 unten links, Feld dreht im
  Uhrzeigersinn; Stabstrom positiv **aus der Zeichenebene** (•), negativ hinein (×).
- **φ2-Konvention:** intern `conv_phi2 = +1` (i = î·sin(γ − φ_el + φ2), φ2 = 90° + φ_Z,
  F = +i·l·B, rechtshändig e_z = e_r × e_γ). Folienform (Folie 14) nur in der Anzeige:
  i_Folie = −i, φ2,Folie = 90° − φ_Z. Herleitung: SPEC 3.4 und 4.4.
- **Motor:** Verbraucherzählpfeilsystem, P_el > 0 und M > 0 im Motorbetrieb.
- **Mechanik:** Port R = Welle, Port C = Gehäuse bzw. Bezug. Ein positives Moment treibt R
  gegenüber C in positive Richtung. Lastmomente wirken stets gegen die Drehrichtung.

## 3 Einheiten

- Intern SI. Ausnahmen, immer gekennzeichnet: Drehzahl n in 1/min, Winkel in Masken teils in °.
- Jede Maskenangabe trägt die Einheit in eckigen Klammern im Prompt, z. B. `Statorwiderstand R1 [Ω]`.
- Simulink-Ausgänge physikalischer Bausteine kommen über PS-Simulink-Wandler mit fester Einheit
  (Katalogfeld `unit`).

## 4 Bausteine und Masken

- Jeder Baustein ist ein **maskiertes Subsystem** (Simulink.Mask). Darunter liegt die
  Simscape-Komponente (`+asmlib/*.ssc`), ein Foundation-Block oder ein Simulink-Subsystem.
- **Einzige Quelle** für Ports, Maskenparameter, Wertebereiche und Hilfetexte ist der Katalog
  `+asmtools/catalog.m`. Bibliothek und Tests werden daraus erzeugt bzw. dagegen geprüft.
- **Wertebereich:** Katalogregeln `pos`, `int`, `vector`, `min=x`, `max=x` werden zu
  Masken-Constraints. Unzulässige Werte lehnt Simulink schon bei der Eingabe bzw. bei `set_param` ab.
  Zusätzlich gilt immer: reell, endlich, Skalar (außer `vector`).
- **Maskenbeschreibung:** Kurzbeschreibung, Gleichungen, Quelle. **Hilfe:** zusätzlich alle
  Parameter mit Wertebereich und Einheit.
- **Parametersatz:** Bausteine mit Auswahl „Standard | Benutzerdefiniert“ zeigen bei „Standard“ die
  Werte aus `parameter/asm_standard.m` gesperrt an; erst bei „Benutzerdefiniert“ sind sie editierbar
  (Rückruf `asmtools.param_set_callback`, Maskenparameter `param_set`). Die Schaltung
  (Stern/Dreieck, Maskenparameter `connection`) bleibt immer wählbar. `run_asm` setzt immer
  „Benutzerdefiniert“ mit expliziten Werten, damit kein Lauf verdeckt von `asm_standard.m` abhängt.
- **Ports:** elektrisch a, b, c (Netzseite) bzw. U1, V1, W1, U2, V2, W2 (Wicklung);
  mechanisch R, C; Luftspalt LS (Domäne `asmlib.airgap`, Across ψh in Wb, Through i in A, je αβ).
  Durch-Größe am LS-Port: Stator und Rotor speisen ihren Strom ein (`* -> LS.i`), der
  Luftspalt nimmt iμ ab (`LS.i -> *`), Sonden nehmen nichts auf.
- **Messbus:** „ASM Standard“ liefert alle Messgrößen als Simulink-Bus `Mess`
  (Elementnamen = Code-Bezeichner aus Abschnitt 1; Drehzahl `n` in 1/min).

## 4a Simulationsläufe und Auswertung

- Skripte und Oberfläche simulieren über `run_asm(P)`; `P` kommt aus `asm_params(szenario)` und
  enthält **alle** verwendeten Werte. Parameter erreichen das Modell nur über
  `Simulink.SimulationInput`; Ergebnisse kommen nur als Rückgabewert. Kein `assignin`, kein `evalin`
  (einzige Ausnahme: `asmtools.last_sim_output` für die Maskenknöpfe nach einer Simulation im
  Modellfenster).
- Beispielmodelle haben keine Modell-Callbacks (PreLoadFcn, InitFcn, …).
- Kennzahlen mit festen Definitionen (`asmtools.speed_metrics`): Hochlaufzeit bis zu einem festen Ziel
  (0,9·n_N), Laststoß separat (vorher, Minimum bzw. Maximum, neuer Arbeitspunkt), Einschwingzeit nur bei
  eingehaltenem Toleranzband bis zum Ende des Auswertefensters; ohne gültiges Fenster kein Wert (NaN mit
  Grund), nie ein scheinbar gültiger Mittelwert. Definitionen und Sonderfälle: ANLEITUNG 1a; unabhängige
  Unit-Tests: `tests/SpeedMetricsTest.m`.
- Abgeleitete Größen (ns, N1xi1, Schleifenwerte, n_B, Hochlaufziel, Band) berechnet `run_asm` immer aus
  den Eingaben; sie werden nicht als Eingabe übernommen.
- Prüfberichte unterscheiden „bestanden“, „nicht bestanden“, „Fehler“, „abgewählt“, „nicht verfügbar“
  und „Info“; nur „bestanden“ zählt. Batch-Prüfung: `check_asm` (Exit-Code ≠ 0 bei Nichtbestehen).

## 4b Numerik

- Solver für Modelle mit Motor: `ode23t`, RelTol 1e-5, MaxStep 0,1 ms (Prüfstand-Standard).
- Zustände, die mit Netzfrequenz schwingen, nur wo nötig; Rotorgrößen rotorfest
  (Begründung: VALIDIERUNG.md, Befund 1).
- **Simscape-Gleichungen ereignisfrei:** keine Sprünge in der Zeit, kein `abs`, `sign`, `atan2`,
  `max` oder `if` über Variablen (nur über Parameter). Vorzeichen als tanh(Ω/0,1 rad/s), Sprünge als
  ½·(1 + tanh((t − t0)/τ)). Grund: Jedes Solver-Ereignis erzwingt eine Neuinitialisierung, an der die
  ee_lib-Referenzmaschine scheitert (VALIDIERUNG.md, Befund 6).
- Winkel (atan2), Effektivwerte und Mittelwerte bildet der Baustein in Simulink aus Rohsignalen
  der Komponente (Katalogfelder `raw`, `derived`); keine `delay`/`integ`-Operatoren in Simscape.
- Rückführungen aus dem Netz (z. B. Lastkennlinie aus der Drehzahl) im Simscape-Netz rechnen, nicht
  über Simulink (algebraische Schleife).
- Jede Simulation in Skripten und Tests mit `TimeOut`.
- Simulink-Rechenkerne (Didaktik) als System-Objekte in `+asmtools` (Klassennamen in UpperCamelCase,
  z. B. `asmtools.RotorBarProbe`), im MATLAB-System-Block mit „Interpreted execution“ – damit braucht
  die Bibliothek keinen C-Compiler. Eigenschaften sind `Nontunable`, die Maskenparameter
  entsprechend nicht abstimmbar.
- Querschnittsbilder: `asmtools.draw_cross_section` ist die einzige Zeichenfunktion (Animation, Folienserie,
  Einzelbilder); Strom positiv aus der Zeichenebene (•), B⊥ mit dazu passender Schleifennormale.

## 5 Farben und Symbole

| Kategorie | Hintergrund | Symbol |
|---|---|---|
| Quellen | orange | Kreis |
| Maschine | hellblau | Doppelkreis |
| Mechanik | hellgrün | Wellenlinie |
| Messgeräte | hellgelb | Kreis mit Zeiger |
| Didaktik | violett | Rahmen |
| Referenz | grau | Doppellinie |

Werte in `+asmtools/category_style.m`. Diagrammfarben (feste Farben für L1/L2/L3, Stab 1/2,
Flussdichte rot, Strom blau, Feldzeiger grün) in `+asmexport/style.m`.

## 6 Sprache und Code

- **Code englisch:** Datei-, Paket-, Funktions-, Variablen- und Feldnamen, Maskenparameter-Namen,
  Simscape-Komponenten und Kommentare sind englisch (Zuordnung alt → neu: SPEC, Abschnitt 15).
- **Ausgaben deutsch:** alles, was der Nutzer sieht, bleibt deutsch – Bausteinnamen in der
  Bibliothek, Masken-Prompts, Auswahltexte, Hilfetexte, Oberfläche, Diagrammbeschriftungen und
  Legenden, Fehlermeldungen, Hinweise, Testmeldungen und die Berichtstabelle von `verify_asm`;
  ebenso die Blocknamen in den Beispielmodellen und die Dateinamen der exportierten Folienbilder.
- Auswahlfelder: im Code englische Werte (`'star'`, `'fan'`, `'custom'`, …), in Masken und Oberfläche
  deutsche Texte („Stern“, „Lüfter“, „Benutzerdefiniert“); die Zuordnung steht jeweils an einer Stelle
  (`run_asm`, `asmtools.test_bench`, `ASMApp`).
- Formelzeichen bleiben wie in Folien und Arbeit (MK, sK, M_N, n_N, J_M, M_B, c_W, …), auch wenn ihre
  Indizes von deutschen Wörtern kommen; wortartige Bezeichner sind übersetzt (`t_on` statt `t_ein`,
  `t_step` statt `t_stoss`).
- **Code-Bezeichner ohne Umlaute.** Blocknamen, Prompts und Hilfetexte dürfen Umlaute enthalten.
  Dateien in UTF-8.
- Zahlenwerte: Alle Standardwerte sind **Beispielwerte** und so gekennzeichnet; keine
  Datenblattwerte ohne Quelle.
- Quelle für Gleichungen: Hagl, R.: Elektrische Antriebstechnik. Hanser, München 2013;
  Densborn, Skripte „DS-Asynchron-Motor“ und „Drehstrom & Drehfeld“ (DHBW Mannheim).

## 7 Ordner und Ablauf

```
run_asm.m     Simulation ohne Oberfläche (Parameter explizit, Simulink.SimulationInput)
verify_asm.m  fachliche Testfälle Teil A/B mit Berichtstabelle
+asmlib/      Simscape-Quellen (.ssc): Domäne airgap, Unterpakete sources, machine,
              mechanics, sensors, reference
+asmtools/    Katalog, Stil, Icons, Maskenrückrufe, Prüfstand, Kennzahlen, Didaktik
+asmexport/   slide_figure, model_figure, cross_section_series, style, output_folder
+asmapp/      Wertebereiche der Eingaben (limits, check_value)
lib/          GENERIERT von build_library (asmlib_lib.slx, asm_blocks_lib.slx) - nicht bearbeiten
parameter/    Parametersätze (asm_standard.m, asm_params.m)
examples/     Beispielmodelle (build_examples)
tests/        matlab.unittest-Tests
doku/         SPEC.md, KONVENTIONEN.md, VALIDIERUNG.md, ANLEITUNG.md
export/       Ausgabe der Folien- und Modellbilder
```

Neuen Baustein anlegen: Eintrag in `+asmtools/catalog.m` → ggf. `.ssc` in `+asmlib/<gruppe>/`
(Knoten in Katalogreihenfolge, `annotations` mit `Side`) → `build_library` → Tests.

Prüfen: `matlab -batch "startup_asm; runtests('tests')"` im Projektordner.

Werkzeug: Ab R2024b baut `sscbuild` die Simscape-Bibliothek (`ssc_build` ist dort als
„wird entfernt“ markiert); `build_library` fällt in älteren Releases auf `ssc_build` zurück.
