# ASM-Bausteinbibliothek – Spezifikation (Phase 0)

Seminararbeit Elektrotechnik, DHBW Mannheim, 5. Semester – Betreuer: Dipl.-Ing. M. Densborn
Thema: Simulation des Drehstrom-Asynchronmotors (Käfigläufer)
Stand: 13.11.2026 – Status: **Entwurf zur Freigabe**

> **Alle Zahlenwerte in diesem Dokument sind Beispielwerte (fiktiver 4-kW-Normmotor, 4-polig)
> oder aus diesen Beispielwerten abgeleitet. Es sind keine Datenblatt- oder Messwerte.**

> **Hinweis (26.11.2026):** Der Code verwendet seit der Überarbeitung englische Bezeichner
> (Abschnitt 15 mit Zuordnung alt → neu). Die Abschnitte 1–14 dokumentieren den Stand der jeweiligen
> Phase und nennen Dateien und Funktionen mit den damaligen (deutschen) Namen.

Quellen
- [D-ASM] Densborn, Skript „DS-Asynchron-Motor“, Stand 14.04.2025 (Folien 13–30 gelesen, Schwerpunkt 16–30)
- [D-DF] Densborn, Skript „Drehstrom & Drehfeld“, Stand 04.11.2025 (Folien 23–26, 37–66 gelesen)
- [Hagl] Hagl, R.: Elektrische Antriebstechnik. Hanser, München 2013 (S. 114 ff., 138 f.)
- Prototyp, Version 3 (Drive-Ordner „Prototyp“ = lokal `ASM/V3`, dateigleich) sowie Teil C aus `ASM/V2`

---

## 1 Bestandsaufnahme Prototyp

| Datei | Ort | Inhalt |
|---|---|---|
| `init_asm.m` | V1 = V2 = V3 | alle Parameter Teil A/B (Beispielwerte) |
| `build_asm_prototyp.m` | V2 (in V3 nur das erzeugte `.slx`) | baut `asm_prototyp.slx`: Teil A (Leiterschleife) und Teil B (Kloss-Hochlauf), reine Simulink-Basisblöcke |
| `layout_asm_prototyp.m` | V2 | Anordnung, Farben, Bedienfeld im Modell |
| `plot_asm.m` | V1 = V2 = V3 | Diagramme 1–7 und 8 Plausibilitätsprüfungen (≈ 30 Simulationsläufe) |
| `animate_asm.m` | V2, V3 (erweitert) | Animation des Rotorquerschnitts (Feld, Stabströme, Kräfte), rotor- oder statorfest, MP4-Export |
| `START_ASM.m`, `asm_bedienung.m` | V3 | Bedienoberfläche (uifigure) |
| `init_asm_referenz.m`, `build_asm_referenz.m`, `plot_asm_referenz.m` | nur V2 | Teil C: Referenz mit `ee_lib` „Induction Machine Squirrel Cage“ |
| `backup/*_sps.m` | V2 | ältere Referenz mit Specialized Power Systems (nicht mehr verwendet) |

Prüfung der Umgebung (13.11.2026): MATLAB R2026b Update 1 mit Simulink, Simscape 26.2 und
Simscape Electrical 26.2 ist installiert. **Specialized Power Systems (`sps_lib`) ist nicht
installiert.** Der in der Aufgabenstellung genannte Block „Asynchronous Machine SI Units“ gehört zu
Specialized Power Systems; der Prototyp (Teil C) verwendet stattdessen `ee_lib/Electromechanical/
Asynchronous/Induction Machine Squirrel Cage`. Diese Lösung wird beibehalten (siehe offene Punkte).

---

## 2 Notation, Koordinaten, Drehrichtung

### 2.1 Formelzeichen (Notation wie Folien, Index 1 = Stator, 2 = Rotor)

| Zeichen | Code-Bezeichner | Bedeutung | Einheit |
|---|---|---|---|
| f1, ω1 | `f1`, `w1` | Statorfrequenz, Statorkreisfrequenz | Hz, rad/s |
| p | `p` | Polpaarzahl ([D-DF] Folie 66 schreibt Z_p) | – |
| ns | `ns` | Synchrondrehzahl ns = 60·f1/p | 1/min |
| n, Ω | `n`, `Om` | Rotordrehzahl, mech. Winkelgeschwindigkeit Ω = 2π·n/60 | 1/min, rad/s |
| s | `s` | Schlupf s = (ns − n)/ns | – |
| ϑ | `th_mech` | mech. Drehwinkel des Rotors | rad |
| γ | `gam` | Luftspaltwinkel, elektrisch, statorfest, gezählt in Drehrichtung des Feldes | rad |
| φ_el(t) | `phi_el` | Lage des Flussdichtemaximums (Feldwinkel), elektrisch, statorfest | rad |
| θ2 | `theta2` | Feldwinkel relativ zum Rotor, θ2 = φ_el − p·ϑ | rad |
| γ_k | `gam_k` | elektrische Lage von Rotorstab k | rad |
| φ2 | `phi2` | Versatzwinkel zwischen Flussdichte- und Strombelagswelle ([D-ASM] Folie 14–16) | rad |
| φ_Z | `phiZ` | Impedanzwinkel des Rotorkreises, tan φ_Z = s·ω1·L2σ/R2 | rad |
| B̂ | `Bhat` | Amplitude der Luftspaltflussdichte (Folien: B_ges,max) | T |
| l, r | `l`, `r` | wirksame Stablänge, Radius der Stabmitte | m |
| N2 | `N2` | Anzahl Rotorstäbe | – |

**Unstimmigkeit Notation:** Der Prototyp nennt die Stablage `phiel_1`, `phiel_2` („φ_el,k“), die
Folien verwenden φ_el(t) für den *Feldwinkel*. In der Bibliothek heißt die Stablage deshalb γ_k
(passend zu γ als Ortskoordinate auf Folie 14), φ_el bleibt der Feldwinkel.

### 2.2 Drehrichtung in den Folien (Befund)

- [D-ASM] Folien 18–30 zeigen eine volle Feldumdrehung in 30°-Schritten: Feldzeiger rechts (18) →
  unten rechts (19, 20) → unten (21) → links (24) → oben (27) → rechts (30). **Das Feld dreht im
  Uhrzeigersinn**, der Rotor steht (Stäbe in Ruhe → s = 1 bzw. rotorfeste Ansicht).
- Die Wicklungslage U1 oben, V1 unten rechts, W1 unten links ([D-ASM] Folie 13, [D-DF] Folie 62)
  ergibt mit der Phasenfolge U → V → W ebenfalls eine Drehung im Uhrzeigersinn; Hagl Bild 6.14
  ([D-DF] Folie 62) zeigt von φ_el = 0 nach π/6 dieselbe Richtung.
- Folie 14 schreibt B(γ,t) = B_ges,max·cos(γ − ωt): Das Feld läuft in +γ-Richtung. Beides passt
  zusammen, **wenn γ in den Bildern im Uhrzeigersinn gezählt wird.**

Konsequenz für die Bibliothek: Rechnung intern mathematisch (αβ-Ebene, γ gegen den Uhrzeigersinn
bei positiver Phasenfolge); alle Querschnittsbilder werden **gespiegelt wie die Folien** dargestellt
(U1 oben, Feld im Uhrzeigersinn). Damit zeigt die Ansichtsnormale e_z = e_r × e_γ in den Bildern
**in** die Zeichenebene (wichtig für die Stromrichtung, Abschnitt 3.4).

---

## 3 Gleichungen des Prototyps

### 3.1 Teil A – Leiterschleife aus zwei Rotorstäben (rotorfest, quasistationär)

Annahmen: sinusförmige Luftspaltflussdichte mit konstanter Amplitude B̂ (unabhängig von der Last),
zwei Stäbe im Abstand einer Polteilung (180° el. = π/p mech.), Stromamplitude und Phase folgen dem
Schlupf ohne eigene Zeitkonstante, nur Grundwellen, nur Tangentialkraft (radiales Luftspaltfeld).

```
θ2(t)    = ∫ s·ω1 dt                              Feldwinkel relativ zum Rotor (el.)
x_k      = γ_k − θ2                               (γ_1 = 0, γ_2 = π)
B_k      = B̂·cos(x_k)                             Flussdichte am Stab k
v1       = ω1·r/p                                 Umfangsgeschwindigkeit des Feldes
U20      = 2·B̂·l·v1                               Amplitude der Stillstandsspannung der Schleife
î2(s)    = s·U20 / √(R2² + (s·ω1·L2σ)²)
φ_Z(s)   = arctan(s·ω1·L2σ / R2)
φ2       = π/2 + konv·φ_Z                          (Schalter modus_phi2: alternativ φ2 = φ2,fix)
i_k      = î2·sin(x_k + konv·φ2)
F_k      = konv·i_k·l·B_k                          Tangentialkraft, positiv in Feldrichtung
M_k      = F_k·r ,   M_S = M_1 + M_2
B⊥       = B̂·sin(γ_1 − θ2) ,  Ψ_S = (2·l·r/p)·B⊥ ,  u_i = −dΨ_S/dt
```

Mittelwert je Stab: ½·î2·l·B̂·cos φ_Z > 0 (Motorbetrieb), mittleres Schleifenmoment
M̄_S = î2·l·B̂·r·sin φ2 = î2·l·B̂·r·cos φ_Z.

Kopplung an Teil B: Der Käfig hat N_S = N2/2 gleichartige Schleifen. R2 wird so gewählt, dass
N_S Schleifen bei s = sK im Mittel MK liefern, L2σ aus sK = R2/(ω1·L2σ):

```
R2  = N_S·l·B̂·r·sK·U20 / (2·MK)        L2σ = R2 / (sK·ω1)
⇒  N_S·M̄_S(s) = 2·MK·s·sK / (s² + sK²)   (exakt Kloss, geprüft: Plot 6, Prüfung 8)
```

Gültig nur unter R1 = 0 und konstantem Luftspaltfluss. R2, L2σ sind Ersatzwerte *einer Schleife*,
keine Stabwerte und keine ESB-Werte.

### 3.2 Teil B – Hochlauf nach Kloss

Annahmen: Kloss-Formel (R1 = 0, konstanter Fluss), keine Statordynamik, keine Stromverdrängung,
kein Sattelmoment, starre Welle, keine Reibung.

```
J·dΩ/dt = M − M_L ,  J = J_M + J_L ,  Ω(0) = 0
n = 60·Ω/(2π) ,  s = (ns − n)/ns
M = 2·MK·s·sK / (s² + sK²)                          (singularitätsfreie Form)
M_L = M_L0  (modus_last = 1)   oder   M_L = kL·n·|n|  (modus_last = 2)
      + ΔM_L·σ(t − t_stoß)                         Laststoß
```

### 3.3 Teil C – Referenz mit Simscape Electrical

`Induction Machine Squirrel Cage` (einfacher Käfig, SI-Parameter, ohne Sättigung, mit Nullsystem,
Start mit allen Flussverkettungen 0) am starren Netz 400 V/50 Hz, Sternschaltung mit freiem
Sternpunkt; J = J_M + J_L in einem separaten Inertia-Block, Last wie Teil B (über Ideal Torque
Source mit −M_L). Solver ode23t.

ESB je Strang (statorbezogen) aus den Beispielwerten: Lm, Rs angenommen; Xs = X1σ = X2σ′ so
bestimmt (fzero), dass das stationäre ESB-Kippmoment = MK ist; Rr′ aus sK = Rr′/|Z_th + jXs|
(Thevenin-Ersatz der Statorseite):

```
M_ESB(s) = 3·p/ω1 · |U_th / (Z_th + Rr′/s + jXs)|² · Rr′/s
τ1′ = σ·L_s/R_s   (Abklingzeit des Statorgleichflusses nach dem Einschalten)
```

### 3.4 Vorzeichenkonvention φ2 / Schalter `konv_phi2` – Befund

Prototyp (Koordinaten e_r, e_γ in Feldrichtung, e_z = e_r × e_γ):

| `konv_phi2` | Stabstrom | φ2 | Zählrichtung i | Kraft |
|---|---|---|---|---|
| +1 (Standard) | î2·sin(x + φ2) | 90° + φ_Z | positiv in +e_z | F = +i·l·B |
| −1 | î2·sin(x − φ2) (Form von Folie 14) | 90° − φ_Z | positiv in −e_z | F = −i·l·B |

Beide liefern dieselbe Kraft, dasselbe Moment und dieselbe physikalische Stromrichtung; in beiden
Fällen gilt sin φ2 = cos φ_Z und M̄ ∝ sin φ2.

**Neuer Befund aus den Folienbildern (geklärt durch Abschnitt 2.2):** In den Folienbildern läuft
das Feld im Uhrzeigersinn, e_z zeigt dort *in* die Zeichenebene. „Positiv in −e_z“ heißt in den
Folienbildern also **„aus der Zeichenebene“**. Damit ist die Form von Folie 14,

```
i2(γ,t) = i2,max·sin(γ − φ_el(t) − φ2),  i2 positiv aus der Zeichenebene, φ2 = 90° − φ_Z,
```

**mit den Bildern 18–30 konsistent** (Nachrechnung Folie 21: Feld zeigt nach unten, oberer Stab
liegt bei γ = φ_el + 180° → i = î·sin(90°) = +î, „Strom aus der Zeichenebene“, wie im Bild).
Der Widerspruch, den der Prototyp als offenen Punkt notiert hat, liegt nur in **Folie 15**:

- Mit dieser Zählrichtung lautet das Kraftgesetz F_γ = −i·l·B (bzw. vektoriell F = l·(i × B)).
  Folie 15 schreibt M(γ) = +i2·l·B·r; das Umlaufintegral ergibt dann −π·l·r·î2·B̂·sin φ2 < 0.
- Folie 15 setzt außerdem B(γ) = B̂·cos(γ) *ohne* Zeitabhängigkeit, i2 aber *mit* φ_El(t). Das
  Integral wird dann zeitabhängig: −π·l·r·î2·B̂·sin(φ_el(t) + φ2) (numerisch geprüft:
  φ2 = 60°, φ_el = 0 → −2,7207 = −π·sin 60°; φ_el = 1 rad → −2,7918).
- Konsistent wäre z. B.: B(γ,t) = B̂·cos(γ − φ_el), i2 wie Folie 14, M(γ) = −i2·l·B·r ⇒
  M = +k_Mo·I2·Φ·sin φ2. → offener Punkt für den Betreuer.

Festlegung für die Bibliothek (Vorschlag): intern `konv_phi2 = +1` (rechtshändig, F = +i·l·B,
φ2 = ∠ψ_h − ∠i2′ = 90° + φ_Z, siehe 4.3); Anzeige und Folienplots verwenden die Folienform
(Strom positiv aus der Zeichenebene, φ2,Folie = 90° − φ_Z). Die Umrechnung steckt nur in der
Darstellungsschicht.

### 3.5 Parameter des Prototyps

| Größe | Wert | Einheit | Herkunft |
|---|---|---|---|
| f1 | 50 | Hz | Beispielwert (Netz) |
| p | 2 | – | Beispielwert |
| U1 | 400 (Leiter, Stern) | V | Beispielwert |
| P_N | 4 | kW | Beispielwert |
| n_N | 1440 | 1/min | Beispielwert |
| M_N | 26,5 | Nm | Beispielwert (P_N/(2π·n_N/60) = 26,53 Nm) |
| MK | 2,7·M_N = 71,55 | Nm | Annahme |
| sK | 0,2 | – | Annahme |
| ns, s_N | 1500, 0,04 | 1/min, – | abgeleitet |
| J_M, J_L | 0,012, 0,01 | kg·m² | Beispielwerte |
| M_L0 | 0,5·M_N | Nm | Annahme |
| kL | M_N/n_N² | Nm·min² | Annahme (M_L(n_N) = M_N) |
| t_stoß, ΔM_L | 1, 0,3·M_N | s, Nm | Annahme |
| B̂ | 0,8 | T | Beispielwert |
| l, r | 0,15, 0,06 | m | Beispielwerte |
| N2 | 28 | – | Annahme |
| U20 | 2,262 | V | abgeleitet (Teil A) |
| R2, L2σ (Schleife) | 0,3187 mΩ, 5,072 µH | Ω, H | abgeleitet (Teil A) |
| î2(s=1), î2(s_N) | 1392, 278 | A | abgeleitet (Teil A) |
| φ_Z(s=1), φ_Z(s_N) | 78,7, 11,3 | ° | abgeleitet (Teil A) |
| Lm (= L_h) | 0,25 | H | Annahme (Teil C) |
| Rs (= R1) | 0,5 | Ω | Annahme (Teil C; realer 4-kW-Motor eher ≈ 1,5 Ω) |
| Lls = Llr′ (= L1σ = L2σ′) | 9,902 | mH | abgeleitet (Teil C, MK-Abgleich) |
| Rr′ (= R2′) | 1,225 | Ω | abgeleitet (Teil C, sK-Abgleich) |
| τ1′ | 38,9 | ms | abgeleitet |
| S_N (Bezugsgröße) | 5395 | VA | abgeleitet |
| t_end, max_step | 2, 1e-4 | s | Solver |

### 3.6 Plausibilitätsprüfung und Unstimmigkeiten

Plausibel: Bemessungsstrom des ESB I1(s_N) = 7,8 A (4-kW-Motor real ≈ 8 A); Anlaufstrom
I1(s=1) = 36,5 A = 4,7·I_N (real eher 6–7·I_N); Polfluss Φ = 2·B̂·l·r/p = 7,2 mWb; daraus
wirksame Windungszahl N1·ξ1 ≈ p·|ψ_h|/(2·B̂·l·r) ≈ 144 bei |ψ_h| ≈ U1,Str·√2/ω1 = 1,04 Vs;
Stabstrom ≈ 1,4 kA Scheitelwert im Stillstand – Größenordnung passt zur ESB-Rechnung.

Auffällig, offen anzusprechen:
1. **Anlaufmoment zu klein:** Kloss liefert M_A = M(s=1) = 27,5 Nm ≈ 1,04·M_N, das ESB 28,8 Nm.
   Reale 4-kW-Käfigläufer haben M_A ≈ 2–2,5·M_N wegen Stromverdrängung ([D-ASM] Folie 44). Ein
   Einfachkäfig kann MK/sK und M_A nicht gleichzeitig treffen.
2. Zufall der Beispielwerte: s_N = sK² ⇒ Kloss liefert M(s_N) = M(1) = 27,5 Nm. Der Bemessungspunkt
   (n_N, M_N) liegt deshalb 3,8 % neben der Kloss-Kurve (Prüfung 6 des Prototyps toleriert das).
3. Teil A setzt B̂ konstant; im dynamischen Modell sinkt der Luftspaltfluss beim Anlauf (R1, Streuung).
4. Folien 18–30 zeigen den idealisierten Fall φ_Z = 0 (Strommaximum genau bei B⊥ = 0, Folie 21).
   Mit den Beispielwerten ist φ_Z im Stillstand 78,7°; das Strommaximum kommt dann deutlich später.
5. Folien 19–29 zeichnen die Kraft mit Radialanteil (homogenes Feld im Bohrungsquerschnitt). Im
   Motor ist das Luftspaltfeld radial; Drehmoment bildet nur die Tangentialkraft F_γ = i·l·B_r.
   Der Prototyp rechnet nur F_γ.
6. Folien 23, 25, 26 tragen die Legende „Flussdichte / Strom“, die Kurven fehlen im PDF; Folie 16
   kündigt den cos-Verlauf (rot) und sin-Verlauf (blau) an. Vermutlich Animation in der Originaldatei.
7. [D-DF] Folien 58/59 (B_U = B_max·sin ωt·sin γ …, Summe B = 1,5·B_max·cos(γ − ωt)) und Hagl Bild
   6.13 (Folie 60/61) unterscheiden sich im Vorzeichen: Das Bild zeigt bei φ_el = 0 das Maximum bei
   γ = 180°, die Formel bei γ = 0 (ebenso B_V: Bild +0,87, Formel −0,87 bei γ = 210°). Bild und
   Bild 6.14 sind untereinander konsistent; die Bezugsachse ist um 180° verschoben.
8. Folie 15: Integral über dγ mit dem Stabstrom i2 ist dimensionell nur mit Strombelag A(γ) in A/m
   und Bogenelement r·dγ korrekt: M = l·r²·∫ A(γ)·B(γ) dγ. Folie 14 schreibt ϖt statt ωt.

---

## 4 Raumzeigermodell für den Motorbaustein

### 4.1 Definitionen

Raumzeiger, amplitudeninvariant, statorfest (α, β), a = e^(j2π/3):

```
x = 2/3·(x_a + a·x_b + a²·x_c) = x_α + j·x_β ,    x_0 = 1/3·(x_a + x_b + x_c)
x_a = Re{x} + x_0 ,  x_b = Re{a²·x} + x_0 ,  x_c = Re{a·x} + x_0
```

Strangwerte, Rotorgrößen auf den Stator bezogen (′). Parameter: R1, L1σ, Lh, R2′, L2σ′, p, J_M,
k_R (Reibung). L1 = L1σ + Lh, L2′ = L2σ′ + Lh.

### 4.2 Gleichungssatz (statorfestes Koordinatensystem)

```
u1  = R1·i1 + dψ1/dt                                  Statorspannungsgleichung
0   = R2′·i2′ + dψ2′/dt − j·p·Ω·ψ2′                    Rotorspannungsgleichung (Käfig kurzgeschlossen)
ψ1  = L1σ·i1 + ψh ,  ψ2′ = L2σ′·i2′ + ψh
ψh  = Lh·(i1 + i2′) = Lh·iμ                            Hauptfluss (Luftspalt)
M   = 3/2·p·Im{ψh*·i1} = −3/2·p·Im{ψ2′*·i2′}           Luftspaltmoment
J·dΩ/dt = M − M_L − k_R·Ω ,   dϑ/dt = Ω
n = 60·Ω/(2π) ,  s = (ns − n)/ns
Nullsystem: u_0 = R1·i_0 + L1σ·di_0/dt  (bei Stern ohne N-Leiter i_0 = 0)
```

Allgemeines Koordinatensystem K (für spätere Varianten, z. B. feldorientiert): Index K,
Zusatzterme +j·ω_K·ψ1 bzw. +j·(ω_K − p·Ω)·ψ2′. Für die Bibliothek reicht statorfest (ω_K = 0),
weil die Klemmengrößen ohnehin statorfest sind und keine Regelung vorgesehen ist.

Zustandsgrößen: ψ1, ψ2′ (je α, β), Ω, ϑ. Anfangswerte: alle Flüsse 0 (Einschalten aus dem
stromlosen Zustand), Ω(0) = 2π·n0/60.

Stationärer Sonderfall (Kontrolle): Mit u1 = Û1·e^(jω1t) folgt das bekannte T-ESB; mit R1 = 0
und konstantem ψh das Kloss-Moment. Damit sind Teil B und Teil C Grenzfälle dieses Modells.

### 4.3 Verbindung zu den Folien

```
Feldwinkel           φ_el(t) = ∠ψh                         (statorfest, el.)
Flussdichte          B(γ,t)  = B̂(t)·cos(γ − φ_el(t))       ([D-ASM] F.14, [D-DF] F.59)
Amplitude            B̂(t)    = p·|ψh| / (2·N1ξ1·l·r)        (Polfluss Φ = 2·B̂·l·r/p, |ψh| = N1ξ1·Φ)
Rotorfester Winkel   θ2      = φ_el − p·ϑ                   (stationär dθ2/dt = s·ω1, wie Teil A)
Versatzwinkel        φ2      = ∠ψh − ∠i2′ = 90° + φ_Z       (konv +1)
Drehmoment           M       = 3/2·p·|ψh|·|i2′|·sin φ2      (Form von Folie 15: k_Mo·I2·Φ·sin φ2)
```

Herleitung φ2: stationär im Rotorsystem gilt i2′ = −j·s·ω1·ψ2′/R2′, i2′ eilt ψ2′ also um 90° nach;
ψh = ψ2′ − L2σ′·i2′ dreht um φ_Z mit tan φ_Z = s·ω1·L2σ′/R2′ zurück ⇒ ∠ψh − ∠i2′ = 90° + φ_Z.
Mit M = −3/2·p·Im{ψh*·i2′} = 3/2·p·|ψh|·|i2′|·sin(∠ψh − ∠i2′) folgt die Folienform mit
**positivem** Vorzeichen; k_Mo·Φ = 3/2·p·N1ξ1·Φ.

### 4.4 Rotorstab-Sonde: Stabstrom und Stabkraft aus den Modellgrößen

Benötigte Modellgrößen: ψh (αβ), i2′ (αβ), ϑ. Zusätzliche Geometrieparameter: l, r, N2 und die
wirksame Windungszahl N1ξ1 (alternativ aus B̂_N vorgegeben: N1ξ1 = p·|ψh,N|/(2·B̂_N·l·r)).

1. **Stromübersetzung Käfig:** Jeder Stab ist ein Strang mit ½ Windung, m2 = N2, ξ2 = 1:
   ```
   ü_i = (m1·N1ξ1) / (m2·N2,w·ξ2) = 3·N1ξ1 / (N2·½) = 6·N1ξ1 / N2      (Beispiel: ≈ 30,9)
   î_Stab = ü_i·|i2′| ,   ε2 = ∠i2′
   ```
2. **Stablage** (elektrisch, statorfest), k = 1 … N2:
   ```
   γ_k(t) = p·ϑ(t) + γ_k0 ,   γ_k0 = γ_10 + (k − 1)·2π·p/N2
   ```
   Leiterschleife wie Folie 16: Stab 1 und Stab 1 + N2/(2p) (eine Polteilung = 180° el.).
3. **Stabstrom** (Durchflutungsgesetz: Strom in +e_z ∝ −∂B_r/∂γ der Rotordurchflutung):
   ```
   i_k  = î_Stab·sin(γ_k − ε2) = î_Stab·sin(γ_k − φ_el + φ2)        positiv in +e_z (konv +1)
   i_k,Folie = −i_k = î_Stab·sin(γ_k − φ_el − φ2,Folie), φ2,Folie = 90° − φ_Z   positiv aus der Zeichenebene
   ```
4. **Flussdichte, Kraft, Moment am Stab:**
   ```
   B_k = B̂·cos(γ_k − φ_el) ,  F_k = i_k·l·B_k  (tangential, positiv in Feldrichtung) ,  M_k = F_k·r
   ```
5. **Schleifengrößen wie Teil A:** B⊥ = B̂·sin(γ_1 − φ_el), Ψ_S = (2·l·r/p)·B⊥,
   Stromrichtung sgn(i_k,Folie), Änderungsvektor dB⊥/dt (Folie 17).
6. **Konsistenz (Testkriterium):** Für N2/p > 2 gilt ohne Mittelung
   ```
   Σ_k M_k = N2/2·î_Stab·B̂·l·r·sin φ2 = 3/2·p·|ψh|·|i2′|·sin φ2 = M
   ```
   (Einsetzen von ü_i und B̂). Die Summe der Stabmomente muss das Luftspaltmoment des Motors
   exakt (bis auf Rundung) wiedergeben; eine Zwei-Stab-Schleife liefert im Mittel 2/N2·M
   und pulsiert mit 2·f2 = 2·s·f1.

Hinweis: Die Sonde rechnet nur Grundwellen und vernachlässigt Nutung und Stromverdrängung. Sie
ist eine Darstellung der Modellgrößen, kein eigenes Feldmodell.

### 4.5 Standardparametersatz „ASM Standard“ (Vorschlag, Beispielwerte)

ESB-Werte aus Teil C (`init_asm_referenz.m`), damit Kloss, ESB und Raumzeigermodell dieselbe
Kennlinie haben: R1 = 0,5 Ω, L1σ = L2σ′ = 9,902 mH, Lh = 0,25 H, R2′ = 1,225 Ω, p = 2,
U1 = 400 V (Stern), f1 = 50 Hz, J_M = 0,012 kg·m², k_R = 0; Geometrie für die Sonde: l = 0,15 m,
r = 0,06 m, N2 = 28, B̂_N = 0,8 T (→ N1ξ1 ≈ 144). Datei `parameter/asm_standard.m`, jede Zeile
mit Einheit und Herkunft „Beispielwert“ bzw. „abgeleitet“.

### 4.6 Validierung

| Nr. | Prüfung | Kriterium |
|---|---|---|
| V1 | stationäre Arbeitspunkte (s = 0,02 … 1) gegen M_ESB(s) | Abweichung < 0,5 % |
| V2 | Hochlauf + Laststoß gegen `ee_lib` Induction Machine Squirrel Cage, gleiche Parameter | n(t), M(t) < 1 % (bezogen auf ns bzw. MK) |
| V3 | gegen Kloss (Teil B) | qualitativ; Abweichung durch R1 > 0 wenige % (dokumentieren) |
| V4 | Sonde: Σ M_k gegen M; Zwei-Stab-Mittelwert gegen 2/N2·M | < 0,1 % |
| V5 | Leerlauf (n → ns), s → 0 ⇒ i2′ → 0, M → 0; Kippmoment bei sK | wie Prototyp-Prüfungen 1, 4, 5 |
| V6 | Energiebilanz: P_el = P_Cu1 + P_Cu2 + M·Ω + dW_mag/dt | < 0,5 % |

---

## 5 Abdeckungsmatrix [D-ASM] Folien 16–30

Gemeinsame Grundlage: Folien 18–30 zeigen *eine* Feldumdrehung (Feld im Uhrzeigersinn, 30°-Schritte)
bei stehendem Rotor (s = 1), idealisiert φ_Z = 0. Vorgesehenes Beispielmodell
**`bsp_folien16_30_rotorstab`**: Quelle „Ideales Drehfeld“ (kinematisch, wie Teil A, φ2 wählbar)
**oder** ASM Standard mit festgebremster Welle → Rotorstab-Sonde → Drehfeld-Anzeige.
Neues Exportwerkzeug **`asmexport.querschnitt_serie`** erzeugt Einzelbilder bei vorgegebenen
Feldwinkeln (0°, −30°, …, −360°), eins zu eins zu den Folien.

Status: ✔ im Prototyp vorhanden, ◐ teilweise, ✘ **Lücke**

| Folie | Inhalt | Baustein (neu) | Beispielmodell / Plot | Prototyp |
|---|---|---|---|---|
| 16 | Aufbau Stator/Rotor, Leiterschleife aus zwei Stäben, Feldzeiger, Zerlegung in B⊥ (Beitrag zur Induktion) und B∥ (kein Beitrag), Versatz φ2, Kraft = B(t)·i(t) | Rotorstab-Sonde (B_k, B⊥, i_k, F_k), Drehfeld-Anzeige Option „Feldzerlegung“ | Plot „B⊥(t) und i(t)“ (rot cos / blau sin wie Folie 16), Querschnitt mit Zerlegungspfeilen | ◐ Plot 1, Animation; **Zerlegungspfeile ✘** |
| 17 | Stromrichtung nach Lenz über den „Änderungsvektor“ von B⊥ | Sonde Ausgang dB⊥/dt, Anzeige Option „Änderungsvektor“ | Querschnitt mit Änderungsvektor | ◐ Stromrichtung (Plot 1b); **Änderungsvektor ✘** |
| 18 | Feldzeiger waagrecht, B⊥ maximal, kein Strom (φ_el = 0) | Drehfeld-Anzeige | `querschnitt_serie`, Bild 0° | ✘ Einzelbild-Export |
| 19 | −30°: Strom aus der Ebene im oberen Stab, Kraftrichtung mit 3-Finger-Regel | Sonde F_k, Anzeige Kraftpfeil | Bild −30°; Hinweis Radialanteil (3.6 Nr. 5) | ◐ Animation (nur F_γ) |
| 20 | −60°, Strom aus der Ebene | wie 19 | Bild −60° | ◐ |
| 21 | −90°: maximaler Strom „durch Phasenversatz“ (B⊥ = 0), Kraft rein tangential | Sonde i_k, φ2 | Bild −90°; Plot „mittleres M_S über φ2“ (Maximum bei 90°) | ✔ Plot 3, ◐ Bild |
| 22 | −120° | wie 19 | Bild −120° | ◐ |
| 23 | −150°, Legende Flussdichte/Strom (Kurven fehlen im PDF) | Sonde B_k, i_k | Bild −150° + Zeitverlauf mit Zeitmarke | ◐ Plot 1; Zeitmarke nur in Animation |
| 24 | 180°: Nulldurchgang des Stromes, B⊥ maximal (negativ) | Sonde sgn(i_k) | Bild 180°; Plot Stromrichtung | ✔ Plot 1b, ◐ Bild |
| 25 | 150°: Umkehr der Stromrichtung, Kraft weiter in Feldrichtung | Sonde F_k ≥ 0 bei φ_Z = 0 | Bild 150°; Plot F_1, F_2, M_S (pulsierend, gleiches Vorzeichen) | ✔ Plot 2, Prüfung 3 |
| 26 | 120°, Strom in die Ebene | wie 25 | Bild 120° | ◐ |
| 27 | 90°: maximaler (negativer) Strom | wie 21 | Bild 90° | ◐ |
| 28 | 60° | wie 25 | Bild 60° | ◐ |
| 29 | 30° | wie 25 | Bild 30° | ◐ |
| 30 | 0°: B⊥ wieder maximal, eine Feldumdrehung = eine Rotorperiode T2 = 1/(s·f1) | Sonde, Mittelwert über T2 | Bild 360°; Plot Mittelwert M_S über T2 | ✔ Plot 2 (Mittelwert) |

Zusätzlich (über die Folien hinaus, für den Zusammenhang 16–30 → Motorverhalten):

| Thema | Folie | Baustein / Plot | Prototyp |
|---|---|---|---|
| Drehfeld, B(γ,t), φ_el | [D-ASM] 13–14, [D-DF] 37–62 | Drehfeld-Anzeige, Spulenfeld-Plot B_U, B_V, B_W, B über γ (wie Hagl Bild 6.13) | ✘ |
| M = k·I2·Φ·sin φ2 | [D-ASM] 15 | Sonde + Plot M über φ2 | ✔ Plot 3 |
| φ_Z ≠ 0 (Rotorstreuung), Vergleich ideal/real | – | Sonde am ASM-Modell, Plot i(t) bei s = 1 und s_N | ◐ Plot 1 |
| Zwei Stäbe → ganzer Käfig, M(s) | 45–50 | Sonde (Σ M_k), Kennlinienschreiber | ✔ Plot 6, 7 |
| M(n)-Kennlinie, Arbeitspunkt, Laststoß | 47–56 | Kennlinienschreiber | ✔ Plot 5 |
| Hochlaufzeit t_H | 68 | Beispielmodell Hochlauf, Prüfung | ✔ Prüfung 7 |

**Lücken (Zusammenfassung):** Zerlegungspfeile B⊥/B∥ (16), Änderungsvektor (17), Einzelbilder bei
festem Feldwinkel (18–30), Drehrichtung der Anzeige wie Folien (Uhrzeigersinn), Spulenfelder
B_U/B_V/B_W (Drehfeld-Folien), fehlende Zeitkurven in Folien 23/25/26 (Inhalt unklar).

**Stand nach Phase 4: alle Lücken geschlossen** (Umsetzung in Abschnitt 13):

| Folie | umgesetzt durch | Ergebnis (export/) |
|---|---|---|
| 16 | Rotorstab-Sonde (B⊥, Stabstrom, Kraft), Drehfeld-Anzeige mit Feldzeiger, B⊥ (rot), B∥ (grün gestrichelt) | `folie16_verlaeufe`, Querschnittsbilder |
| 17 | Änderungsvektor dB⊥/dt (dunkelrot) in Anzeige und Querschnittsbildern, Ausgang dB_perp der Sonde | `folie18` … `folie30` |
| 18–30 | `bsp_folien16_30_rotorstab` (Ideales Drehfeld p = 1, s = 1, φ2 = 90°, zwei Stäbe) + `asmexport.querschnitt_serie` | `folie18` … `folie30` (θ2 = 0°, 30°, …, 360°) |
| 23/25/26 | fehlende Zeitkurven ersetzt durch `folie16_verlaeufe` (Flussdichte rot, Strom blau) | `folie16_verlaeufe` |
| Drehfeld 58–62 | Baustein Spulenfelder, `asmbib.spulenfelder_bild` | `drehfeld_spulen_0/30/90` |
| 47–56 | Kennlinienschreiber, `asmbib.kennlinie_bild` | `motor_kennlinie` |
| φ_Z ≠ 0 | Rotorstab-Sonde am Motor (`bsp_rotorstab_motor`), Ideales Drehfeld mit „φ2 aus Rotorimpedanz“ | `motor_querschnitt` |

Bewusste Abweichung von den Folienbildern: Die Kraftpfeile zeigen nur die tangentiale Kraft
F = i·l·B_r (radiales Luftspaltfeld, drehmomentbildend); die Folien zeichnen mit homogenem Feld
zusätzlich einen Radialanteil (Abschnitt 3.6 Nr. 5, offener Punkt 8.2 Nr. 5).

---

## 6 Bausteinkatalog

Domänen: **el.** = `foundation.electrical.electrical` (skalar, Klemmen a/b/c bzw. U1…W2);
**mech.** = `foundation.mechanical.rotational.rotational` (R = Welle, C = Gehäuse/Bezug);
**LS** = eigene Domäne `asmlib.luftspalt` (Abschnitt 7); **PS** = Physical Signal;
**SL** = Simulink-Signal. Messgeräte geben SL-Signale in SI aus (Drehzahl zusätzlich in 1/min).

### 6.1 Quellen

| Baustein | Ports | Parameter | Ausgänge |
|---|---|---|---|
| Netz 3~ | a, b, c, n (el.) | U (Leiter, eff.) [V] 0…10 000; f1 [Hz] 0…1000; Phasenfolge (L1-L2-L3 / L1-L3-L2); Nullphasenwinkel [°]; Einschaltzeitpunkt t_ein [s]; Innenimpedanz R_N [Ω], L_N [H] (0 = starres Netz) | – |
| Sternpunkt / Erde | 1 el. | – | – |
| *später:* Stern-Dreieck-Schalter, Frequenzumrichter (ideal U/f), Sanftanlauf | a,b,c ein/aus | Umschaltzeit, U/f-Kennlinie | – |

### 6.2 Maschine

| Baustein | Ports | Parameter | Ausgänge |
|---|---|---|---|
| **ASM Standard** (kompakt, maskiertes Subsystem) | a, b, c (el.), R, C (mech.) | Parametersatz: Standard \| Benutzerdefiniert; Schaltung: Stern \| Dreieck; U_N [V], f_N [Hz], p [–], R1 [Ω], L1σ [H], Lh [H], R2′ [Ω], L2σ′ [H], J_M [kg·m²], k_R [N·m·s/rad], n0 [1/min]; Geometrie l, r [m], N2 [–], B̂_N [T] | PS-Bus „Messgrößen“ (ψh, i1, i2′ je αβ, M, Ω, ϑ, s, φ_el, B̂) – optional einblendbar |
| Stator (zerlegt) | U1, V1, W1, U2, V2, W2 (el.), LS | R1, L1σ | PS: i1 (αβ), u1 (αβ) |
| Luftspalt / Drehfeld (zerlegt) | LS | Lh, p, N1ξ1 bzw. B̂_N, l, r | PS: ψh (αβ), φ_el, B̂, iμ |
| Käfigläufer (zerlegt) | LS, R, C (mech.) | R2′, L2σ′, p, J_M (optional), Geometrie N2 | PS: i2′ (αβ), M, Ω, ϑ, θ2, s (mit ns) |
| Klemmbrett Stern / Dreieck | U1…W2 ↔ a,b,c | – | – |

Unter der Maske von „ASM Standard“ (Ctrl+U) liegen Stator, Luftspalt, Käfigläufer und Klemmbrett
als einzelne Bausteine. Die Maske (Simulink.Mask) gibt die Werte nach unten weiter; bei
„Standard“ sind die Felder gesperrt und zeigen die Werte aus `parameter/asm_standard.m`.

### 6.3 Mechanik

| Baustein | Ports | Parameter | Ausgänge |
|---|---|---|---|
| Schwungmasse | R (mech.) | J [kg·m²] > 0; n0 [1/min] | – |
| Welle starr / elastisch | R, C | c [N·m/rad], d [N·m·s/rad] (elastisch) | – |
| Last konstant | R, C | M_L0 [Nm] | – |
| Last Lüfter (quadratisch) | R, C | kL [Nm·min²] oder (n_N, M_N) | – |
| Last linear / Tabelle | R, C | k oder Kennlinie n–M | – |
| Laststoß | R, C | t_stoß [s], ΔM_L [Nm] | – |
| Reibung | R, C | k_R (viskos), M_C (Coulomb) | – |
| Mechanischer Bezug | C | – | – |
| *später:* Getriebe | R, C | ü, η | – |

Alle Lastmomente wirken stets gegen die Drehrichtung (wie Prototyp: kL·n·|n|).

### 6.4 Messgeräte

| Baustein | Anschluss | Ports | Ausgänge (SL) |
|---|---|---|---|
| Amperemeter 1~ | in Reihe | p, n (el.) | i [A], I_eff |
| Voltmeter 1~ | parallel | p, n (el.) | u [V], U_eff |
| Strommessung 3~ | in Reihe | a,b,c ein → a,b,c aus | i_a, i_b, i_c, I_eff, i1 (αβ) |
| Spannungsmessung 3~ | parallel | a, b, c (+ n optional) | Strang- und Leiterspannungen, U_eff |
| Leistungsmesser 3~ | in Reihe (Strompfad) + Spannungspfad | a,b,c ein/aus | P, Q, S, cos φ (gleitender Mittelwert über 1/f1) |
| Drehmomentmesswelle | in Reihe | R, C (mech.) | M [Nm] |
| Drehzahlmesser | parallel | R, C (mech.) | n [1/min], Ω [rad/s], ϑ [rad]; optional s (Parameter ns) |
| Luftspalt-Sonde | parallel am LS-Port | LS | ψh, φ_el, B̂ |
| Schreiber | SL | beliebig | Scope mit Folienstil |

### 6.5 Didaktik (Simulink-Blöcke)

| Baustein | Eingänge | Parameter | Ausgänge / Anzeige |
|---|---|---|---|
| Ideales Drehfeld (kinematisch) | – | B̂ [T], f1, s, φ2 fest oder φ_Z aus R2/L2σ | φ_el, θ2, B̂, î_Stab, φ2 (Teil A des Prototyps als Baustein) |
| Rotorstab-Sonde | Messbus der Maschine **oder** Ideales Drehfeld | Stab k1 (Standard 1), k2 (Standard 1 + N2/(2p)), Darstellung konv; N2, l, r, N1ξ1 aus Maschine | B_k, i_k, F_k, M_k, M_S, B⊥, dB⊥/dt, Stromrichtung, φ2, Σ M_k |
| Drehfeld-Anzeige | φ_el, B̂, ϑ, Stabströme | Ansicht rotor-/statorfest, Orientierung „wie Folien“, Optionen Feldzerlegung / Änderungsvektor / Kraftpfeile / alle Stäbe, Zeitlupe | Querschnittsanimation (Nachbearbeitung aus geloggten Daten, Knopf in der Maske) |
| Spulenfelder | i_a, i_b, i_c | N1ξ1, p | B_U, B_V, B_W, B über γ (wie Hagl Bild 6.13) |
| Kennlinienschreiber | n, M, M_L | stationäre Kurven ein/aus (Kloss, ESB) | M(n)-Diagramm mit Arbeitspunkten |
| *optional:* Zeigerdiagramm | u1, i1, i2′, ψh | – | Raumzeiger in der αβ-Ebene |

### 6.6 Referenz

| Baustein | Ports | Inhalt |
|---|---|---|
| ASM Referenz Simscape | a, b, c, R, C | `ee_lib` Induction Machine Squirrel Cage, Parameter aus demselben Satz (Teil C) |
| ASM Kloss (quasistationär) | R, C (über Momentenquelle) | Teil B des Prototyps, nur Validierung |
| Leiterschleife Prototyp | SL | Teil A des Prototyps zum Vergleich mit der Sonde |

### 6.7 Export (`+asmexport`)

| Funktion | Zweck |
|---|---|
| `folienbild(fig, name)` | 16:9, Schrift ≥ 14 pt, feste Farben L1/L2/L3 und Stab 1/2, PNG 300 dpi + SVG nach `export/` |
| `modellbild(modell, name)` | Modellansicht als SVG/PNG |
| `stil()` | zentrale Farb- und Schriftdefinition |
| *später:* `querschnitt_serie(out, winkel)` | Einzelbilder bei festen Feldwinkeln (Folien 18–30) |

---

## 7 Zerlegung des Motors: Schnittstelle Stator – Luftspalt – Rotor

Physikalisch koppeln Stator und Rotor nur über den Hauptfluss ψh; die Durchflutungsbilanz lautet
i1 + i2′ = iμ = ψh/Lh. Eine Schnittstelle muss deshalb ψh (bzw. dessen Ableitung) und die
Stromanteile beider Seiten übertragen, und zwar zweiachsig (α, β).

| Variante | Schnittstelle | Vorteile | Nachteile |
|---|---|---|---|
| **A Internes Signal** | Simulink-Busse zwischen Subsystemen, Klemmen über gesteuerte Quellen | einfach, jede Größe sichtbar | keine echte physikalische Kopplung, algebraische Schleifen, Bausteine nur in fester Reihenfolge verschaltbar, widerspricht „wie im Labor stecken“ |
| **B Magnetische Domäne** (`foundation.magnetic`, MMF/Fluss) | je Achse ein magnetischer Port (α und β), Luftspalt = Reluktanz R_m = (N1ξ1)²/Lh | Standarddomäne, Begriffe Durchflutung/Fluss passen zur Vorlesung | zwei Ports je Schnittstelle (Verwechslungsgefahr), Umrechnung mit N1ξ1 in jedem Baustein, Drehtransformation im Rotor über zwei skalare Ports, Fehlbedienung mit fremden Magnetik-Blöcken möglich |
| **C Elektrisches αβ-Ersatzschaltbild** (Standard-Elektrik, T-ESB) | zwei elektrische Klemmen α, β + Bezug | Standardblöcke (Induktivität Lh) nutzbar, ESB direkt sichtbar | „Spannungen“ an α/β sind keine messbaren Klemmengrößen → didaktisch irreführend (Voltmeter anschließbar); Rotor braucht trotzdem eigene Komponente (Bewegungsspannung j·p·Ω·ψ2′) |
| **D Eigene Domäne `asmlib.luftspalt`** | ein Port, Across ψh (2×1, Wb), Through i (2×1, A) | ein Stecker je Schnittstelle, Knotenregel = Durchflutungsbilanz, Luftspalt-Sonde parallel anschließbar wie ein Voltmeter, keine Verwechslung mit anderen Domänen, Gleichungen 1:1 aus 4.2 | eigene Domäne muss gepflegt werden; Across×Through ist keine Leistung (keine Simscape-Energiebilanz über den Port); nur zu eigenen Bausteinen kompatibel |

**Machbarkeitstest (13.11.2026):** Eine Testdomäne mit Vektorvariablen (ψ 2×1 Wb, i 2×1 A,
Balancing) und zwei Testkomponenten wurde mit `ssc_build` gebaut und in R2026b fehlerfrei simuliert.

**Empfehlung: Variante D.** Begründung: Sie bildet die Physik der Vorlesung direkt ab (der Luftspalt
„führt“ das Drehfeld ψh, die Ströme beider Seiten erregen es gemeinsam), erlaubt das Stecken
wie im Labor (Stator → Luftspalt ← Rotor, Sonde parallel am Luftspalt) und hält die Gleichungen
jedes Teilbausteins klein:
- Stator: u1 = R1·i1 + L1σ·di1/dt + dψh/dt (a,b,c bzw. U1…W2 → αβ, Nullsystem separat)
- Luftspalt: ψh = Lh·iμ, iμ = Summe der Through-Ströme; Ausgänge φ_el, B̂
- Käfigläufer: 0 = R2′·i2′ + d(ψh + L2σ′·i2′)/dt − j·p·Ω·(ψh + L2σ′·i2′); Moment
  M = −3/2·p·Im{ψ2′*·i2′} zwischen R und C

Alternative innerhalb von D: Across = u_h = dψh/dt (Leistungsvariable, Across×Through = Leistung).
Vorteil Energiebilanz, Nachteil: ψh muss in Stator und Rotor integriert werden (Anfangswerte doppelt).
Vorschlag: Across = ψh (anschaulicher, Anfangswert nur einmal); bei Problemen mit der Solverindexierung
auf u_h wechseln.

Elektrische Klemmen: skalare `foundation.electrical`-Knoten a, b, c (bzw. U1…W2 am zerlegten
Stator). Für Quellen aus `ee_lib` mit zusammengefasstem Drehstromport wird ein Phase Splitter in
den Quellen-Baustein gelegt. Lehre aus Teil C: Bei freiem Sternpunkt muss das Nullsystem
modelliert sein, sonst ist das Sternpunktpotenzial unbestimmt.

---

## 8 Offene Punkte

### 8.1 Klärt Fred

1. **Projektordner:** Vorschlag `OneDrive\DHBW\Seminararbeit\ASM\asm_bausteine\` (hier liegt diese
   SPEC). Soll eine unveränderliche Kopie des Prototyps als `asm_bausteine/prototyp/` angelegt werden
   (V3 + Teil C aus V2)? `V1`–`V3` werden in keinem Fall verändert.
2. **Standardparametersatz:** ESB aus Teil C übernehmen (R1 = 0,5 Ω, deckungsgleich mit Kloss)
   oder realistischer R1 ≈ 1,5 Ω (dann größere Abweichung von Kloss)?
3. **Anlaufmoment:** Einfachkäfig liefert M_A ≈ 1,1·M_N. Akzeptieren oder Doppelkäfig/Stromverdrängung
   (Folie 44) als Erweiterung einplanen?
4. **Darstellung wie Folien** (U1 oben, Feld im Uhrzeigersinn, Strom positiv aus der Zeichenebene) als
   Standard für alle Querschnittsbilder – einverstanden?
5. **Statoranschluss:** kompakt a, b, c mit Maskenwahl Stern/Dreieck, zerlegt sechs Klemmen U1…W2 mit
   Klemmbrett-Bausteinen (wie [D-DF] Folien 23–26) – passt das?
6. **Umfang Quellen:** Stern-Dreieck-Anlauf, Frequenzumrichter, Getriebe in diese Arbeit aufnehmen
   oder als „später“ markieren?
7. **Zielversion:** entwickelt und getestet wird in R2026b. Muss die erzeugte Bibliothek in R2023b
   (Labor, MATLAB Online der Hochschule) laufen? Dann `build_library` zusätzlich mit
   `save_system(..., 'ExportToVersion', 'R2023b')` und Test auf R2023b nötig.
8. **Referenzblock:** „Asynchronous Machine SI Units“ (Specialized Power Systems) ist nicht installiert;
   Referenz bleibt `ee_lib` Induction Machine Squirrel Cage wie in Teil C – einverstanden?
9. **Drehfeld-Anzeige:** Animation als Nachbearbeitung aus geloggten Daten (schnell, exportierbar)
   statt live während der Simulation – einverstanden?

### 8.2 Klärt Betreuer

1. **Vorzeichen Folie 15:** Mit der Zählrichtung von Folie 14 (Strom positiv aus der Zeichenebene,
   konsistent mit den Bildern 18–30) gilt F = −i·l·B; Folie 15 schreibt +i·l·B und erhält damit
   M = −k·I2·Φ·sin φ2. Welche Korrektur ist gewünscht (Minuszeichen im Kraftgesetz, vektoriell
   F = l·(i × B), oder Strom positiv in die Zeichenebene)?
2. **Zeitargument Folie 15:** B(γ) = B̂·cos γ ohne φ_el(t), i2 mit φ_El(t) → Integral zeitabhängig.
   Gemeint ist vermutlich B̂·cos(γ − φ_el(t)).
3. **Folie 15 Dimension:** Integral mit Strombelag A(γ) [A/m] und r·dγ statt Stabstrom; Definition k_Mo.
4. **Idealisierung Folien 18–30 (φ_Z = 0):** Soll die Simulation zusätzlich den realen Fall mit
   Rotorstreuung zeigen (Strommaximum um φ_Z später, im Stillstand ≈ 79° bei den Beispielwerten)?
5. **Radialanteil der Kraft** in Folien 19–29 (homogenes Feld): Darstellung beibehalten oder nur
   Tangentialkraft wie im Motor mit radialem Luftspaltfeld?
6. **Fehlende Kurven** in Folien 23, 25, 26 („Flussdichte / Strom“): Gibt es eine Originalfassung
   mit Animation? Die Simulation kann die Kurven ergänzen.
7. **Drehfeld-Folien 58–61:** Formel und Hagl Bild 6.13 unterscheiden sich um 180° (Vorzeichen der
   Spulenachse). Welche Bezugsachse soll die Simulation verwenden?
8. **Notation:** φ_el für Feldwinkel, γ_k für Stablage, p statt Z_p, ω statt ϖ (Folie 14) – so
   übernehmen?
9. **Kloss** nur noch zur Validierung, Motormodell dynamisch (Raumzeiger) – entspricht das der
   Erwartung an die Arbeit? Stromverdrängung außerhalb des Umfangs?
10. **Parameter:** Reicht ein fiktiver Beispielmotor, oder soll ein konkreter Labormotor
    (Typenschild/Datenblatt) als zweiter Parametersatz hinterlegt werden?

---

## 9 Änderungen in Phase 1 gegenüber diesem Entwurf

- „Netz 3~“ und „Netz 3~ mit Innenimpedanz“ zu einem Baustein zusammengefasst (R_N = L_N = 0: starres Netz).
- „Klemmbrett Stern / Dreieck“ als ein Baustein mit Auswahl der Schaltung.
- Simscape-Komponente „Luftspalt-Drehfeld“ heißt `asmlib.maschine.luftspaltfeld` (Domäne `asmlib.luftspalt`).
- Bibliothek wird mit `sscbuild` gebaut (ab R2024b; `ssc_build` ist dort als „wird entfernt“ markiert),
  Rückfall auf `ssc_build` in älteren Releases.
- Hilfsfunktionen für Katalog, Masken und Stil im Paket `+asmbib`.

## 10 Änderungen in Phase 2

- Physik umgesetzt: Stator, Luftspalt-Drehfeld, Käfigläufer, Klemmbrett, Luftspalt-Sonde
  (`.ssc`), ASM Standard (Maske gibt Parameter weiter, bei „Standard“ gelten immer die Werte aus
  `asm_standard.m`; N1ξ1 aus B̂_N berechnet). Ergebnisse: [VALIDIERUNG.md](VALIDIERUNG.md).
- Zustandsgrößen: Stator ψ1 (αβ) und i0, Käfigläufer ψ2′ **rotorfest** (numerisch robust bei
  kleinem Schlupf, VALIDIERUNG Befund 1), ϑ, Ω. Gleichungen unverändert wie 4.2.
- „ASM Standard“ hat einen Ausgang **Mess** (Simulink-Bus): i1, u1, psi_h, phi_el, Bhat, i_mu,
  i2b, M, n, Om, th_mech, theta2, s.
- J_M muss > 0 sein; n0 ist Anfangswert und nicht mehr Teil des Parametersatzes.
- Hilfsfunktionen: `asmbib.pruefstand` (Prüfstandsmodell), `asmbib.esb_kennlinie`
  (stationäre Kennlinie), `asmbib.rotorstab` (Formeln aus 4.4, Grundlage der Rotorstab-Sonde).
- Netz, Mechanik und Last im Prüfstand vorerst aus ee_lib/fl_lib (eigene Bausteine: Phase 3).

## 11 Änderungen in Phase 3

- Physik umgesetzt: Netz 3~, alle Mechanik-Bausteine, alle Messgeräte, ASM Kloss (Simscape), ASM
  Referenz (Maske über ee_lib „Induction Machine Squirrel Cage“ mit Phase Splitter, freiem Sternpunkt
  und J_M als Schwungmasse), Schreiber (Scope, Titel auf dem Baustein). Offen (Phase 4): Didaktik-
  Bausteine und Leiterschleife.
- Simscape-Komponenten liefern Augenblickswerte; Effektivwerte und Leistungsmittelwerte (gleitend über
  1/f_mess) sowie Winkel (atan2) bildet der Baustein in Simulink (Katalogfelder `roh`, `mittel`).
  Grund: Speicherbedarf von `delay`/`integ` und Solver-Ereignisse (VALIDIERUNG.md, Befunde 6 und 7).
- Alle Simscape-Gleichungen ereignisfrei: geglättete Vorzeichen (tanh(Ω/0,1 rad/s)), geglätteter
  Laststoß und Einschaltzeitpunkt (Anstieg ≈ 2 ms bzw. 0,4 ms). Die ee_lib-Maschine verträgt keine
  Solver-Ereignisse im selben Modell.
- Spannungsmessung 3~: Auswahl des Bezugs (künstlicher Sternpunkt oder Anschluss n). Schreiber ohne
  y-Beschriftung (das Scope lässt sich in einem Bibliothekslink nicht umkonfigurieren).
- `asmbib.pruefstand` besteht nur noch aus Bibliotheksbausteinen (Motor 'asm' | 'ee' | 'kloss').
- Beispielmodelle (`beispiele/baue_beispiele.m`): `bsp_hochlauf_laststoss`, `bsp_vergleich_modelle`.
- Neue Tests: QuellenMessgeraeteTest, MechanikTest, BeispieleTest; Validierung um V7 (Kloss-Baustein)
  und V8 (Stern/Dreieck) erweitert.

## 13 Änderungen in Phase 4

- Didaktik umgesetzt: Ideales Drehfeld, Rotorstab-Sonde, Drehfeld-Anzeige (Protokoll
  `out.drehfeld_anzeige`, Knopf „Animation zeigen“), Spulenfelder, Kennlinienschreiber (Protokoll
  `out.kennlinie`, Knopf „Kennlinie zeichnen“), Leiterschleife (Prototyp Teil A).
- Rechenkerne als System-Objekte (`asmbib.IdealesDrehfeld`, `asmbib.SondeRotorstab`,
  `asmbib.Leiterschleife`) in MATLAB-System-Blöcken mit interpretierter Ausführung: kein
  C-Compiler nötig (MATLAB Online, Laborrechner). Ihre Maskenparameter sind nicht abstimmbar.
- Neuer Parameter „Lage von Stab 1“ (Sonde, Anzeige): −90° legt Stab 1 in der Folienansicht nach oben.
  N2 = 2 (nur die Schleife) ist in den Didaktik-Bausteinen erlaubt.
- Vorzeichen B⊥: Mit Folienzählung (Strom aus der Zeichenebene positiv) dreht sich die
  Schleifennormale mit; die Sonde gibt dann B⊥ = −B̂·sin(γ_1 − φ_el) aus (bei Stab 1 oben
  B⊥ = B̂·cos φ_el, Strom eilt um 90° + φ_Z nach, wie Folie 16).
- Zeichnen und Export: `asmbib.querschnitt` (Folienstil), `asmbib.querschnitt_zustand`,
  `asmbib.drehfeld_animation`, `asmexport.querschnitt_serie`, `asmbib.spulenfelder_bild`,
  `asmbib.kennlinie_bild`; Skript `beispiele/folienbilder.m` erzeugt alle Folienbilder.
- Beispiele `bsp_folien16_30_rotorstab`, `bsp_rotorstab_motor`; Test `DidaktikTest`.

## 14 Ausblick (nach Freigabe)

- Phase 1: Ordnerstruktur, `build_library.m` mit Platzhalterblöcken (korrekte Ports und Masken,
  ohne Physik), `slblocks.m`, Konventionen in `doku/KONVENTIONEN.md`, Export-Gerüst, Tests.
- Phase 2 (Vorschlag): Domäne `asmlib.luftspalt`, Stator/Luftspalt/Käfigläufer in `.ssc`,
  ASM Standard, Validierung V1–V6.
- Phase 3 (Vorschlag): Quellen, Mechanik, Messgeräte vollständig; Beispielmodelle Hochlauf, Laststoß.
- Phase 4 (Vorschlag): Didaktik-Bausteine (Sonde, Drehfeld-Anzeige, Spulenfelder,
  Kennlinienschreiber), `querschnitt_serie`, Abdeckung Folien 16–30 schließen.

## 15 Überarbeitung 26.11.2026: englische Bezeichner, `run_asm`, fachliche Testfälle

- **Code englisch, Ausgaben deutsch** (KONVENTIONEN 6): Dateien, Pakete, Funktionen, Variablen,
  Felder, Maskenparameter-Namen, Simscape-Komponenten und Kommentare englisch; Bausteinnamen,
  Prompts, Auswahltexte, Hilfe, Oberfläche, Diagramme, Fehlermeldungen und Testbericht deutsch.
  Bibliothek und Beispielmodelle werden mit `build_library` und `build_examples` neu erzeugt.
- **`run_asm(P)`** ersetzt `asmapp.simuliere(betriebsart, P)`: ein Parametersatz `P` aus
  `asm_params(szenario)` mit Szenario `'lab'`, `'slides'` sowie neu `'kloss'` (Teil B,
  `ex_kloss_startup`) und `'loop'` (Teil A, `ex_conductor_loop`). Parameter nur über
  `Simulink.SimulationInput`; Motor immer „Benutzerdefiniert“ mit expliziten Werten.
- **Kennzahlen** mit festen Definitionen (`asmtools.speed_metrics`, `asmtools.operating_point`):
  Hochlaufzeit bis 0,9·n_N, Laststoß separat, Einschwingzeit nur bei gehaltenem Toleranzband.
- **Testfälle** `verify_asm` (Teil A bei s = 0, s_N, s_K, 1; Teil B Hochlauf und Laststoß;
  Zusatz dynamisches Modell; Info Bemessungspunkt). Ergebnisse: VALIDIERUNG.md Abschnitt 1.
- **Parametersatz:** MK = 71,55 N·m, sK = 0,2 sowie die abgeleiteten Schleifenwerte U20, R2_S, L2s_S
  stehen zentral in `asm_standard.m` (vorher als Literale in Katalog, Prüfstand und Tests).
  R2_S = 3,186 6·10⁻⁴ Ω (vorher gerundet 3,187·10⁻⁴ Ω), L2s_S = 5,071 7 µH. Kein Parameter wurde
  fachlich geändert; der Bemessungspunkt bleibt eine Eigenschaft des Beispieldatensatzes
  (`asmtools.rated_point`, VALIDIERUNG 2).

Zuordnung alt → neu (Auswahl; vollständig über `git log --follow`):

| alt | neu |
|---|---|
| `+asmbib/` | `+asmtools/` |
| `asmbib.katalog`, `asmbib.stil`, `asmbib.parametersatz` | `asmtools.catalog`, `asmtools.category_style`, `asmtools.param_set_callback` |
| `asmbib.pruefstand`, `asmbib.esb_kennlinie`, `asmbib.rotorstab` | `asmtools.test_bench`, `asmtools.equivalent_circuit`, `asmtools.rotor_bars` |
| `asmbib.querschnitt`, `asmbib.querschnitt_zustand`, `asmbib.drehfeld_animation`, `asmbib.drehfeld_daten` | `asmtools.draw_cross_section`, `asmtools.cross_section_state`, `asmtools.field_animation`, `asmtools.field_log_data` |
| `asmbib.kennlinie_bild`, `asmbib.spulenfelder_bild`, `asmbib.baue_didaktik` | `asmtools.torque_speed_plot`, `asmtools.coil_fields_plot`, `asmtools.build_didactic_blocks` |
| `asmbib.IdealesDrehfeld`, `asmbib.SondeRotorstab`, `asmbib.Leiterschleife` | `asmtools.IdealRotatingField`, `asmtools.RotorBarProbe`, `asmtools.ConductorLoop` |
| `asmexport.folienbild`, `.modellbild`, `.querschnitt_serie`, `.stil`, `.zielordner` | `asmexport.slide_figure`, `.model_figure`, `.cross_section_series`, `.style`, `.output_folder` |
| `asmapp.simuliere`, `asmapp.standardwerte`, `asmapp.grenzen`, `asmapp.pruefe` | `run_asm`, `asm_params`, `asmapp.limits`, `asmapp.check_value` |
| `asmlib.luftspalt` (Domäne) | `asmlib.airgap` |
| `asmlib.maschine.{kaefiglaeufer, klemmbrett, luftspaltfeld, stator}` | `asmlib.machine.{squirrel_cage, terminal_box, airgap_field, stator}` |
| `asmlib.mechanik.{schwungmasse, welle_elastisch, last_konstant, last_luefter, last_kennlinie, laststoss, reibung}` | `asmlib.mechanics.{inertia, elastic_shaft, load_constant, load_fan, load_table, load_step, friction}` |
| `asmlib.messgeraete.{amperemeter, voltmeter, strommessung3, spannungsmessung3, leistungsmesser3, drehmomentmesswelle, drehzahlmesser, luftspaltsonde}` | `asmlib.sensors.{ammeter, voltmeter, current_sensor3, voltage_sensor3, power_meter3, torque_sensor, speed_sensor, airgap_probe}` |
| `asmlib.quellen.netz3`, `asmlib.referenz.asm_kloss` | `asmlib.sources.grid3`, `asmlib.reference.kloss_motor` |
| `asm_bausteine_lib` | `asm_blocks_lib` |
| `beispiele/baue_beispiele.m`, `folienbilder.m`, `validierung_motor.m` | `examples/build_examples.m`, `export_slide_figures.m`, `benchmark_motor.m` |
| `bsp_hochlauf_laststoss`, `bsp_vergleich_modelle`, `bsp_folien16_30_rotorstab`, `bsp_rotorstab_motor` | `ex_startup_load_step`, `ex_model_comparison`, `ex_slides16_30_rotor_bars`, `ex_rotor_bars_motor` |
| Maskenparameter `parametersatz`, `schaltung`, `phasenfolge`, `t_ein`, `t_stoss`, `f_mess`, `bezug` | `param_set`, `connection`, `phase_seq`, `t_on`, `t_step`, `f_meas`, `reference` |
| Maskenparameter `lage1`, `darstellung`, `ansicht`, `orientierung`, `zerlegung`, `aenderungsvektor`, `kraftpfeile`, `alle_staebe`, `zeitlupe` | `bar1_angle`, `convention`, `view_frame`, `image_orientation`, `decomposition`, `change_vector`, `force_arrows`, `all_bars`, `slow_motion` |
| Maskenparameter `kurve_kloss`, `kurve_esb`, `konv_phi2`, `modus_phi2`, `titel` | `show_kloss`, `show_ec`, `conv_phi2`, `phi2_mode`, `title_text` |
| Protokolle `out.drehfeld_anzeige`, `out.kennlinie` | `out.field_display_log`, `out.torque_speed_log` |
| Ports `a_ein` … `c_aus`, Ausgänge `u_str`, `u_leiter` | `a_in` … `c_out`, `u_phase`, `u_line` |
| Tests `ValidierungTest`, `DidaktikTest`, `BibliothekTest`, `BeispieleTest`, `MechanikTest`, `QuellenMessgeraeteTest` | `BenchmarkTest`, `DidacticsTest`, `LibraryTest`, `ExamplesTest`, `MechanicsTest`, `SourcesSensorsTest` (neu: `TechnicalCasesTest`) |

Unverändert: Bausteinnamen in der Bibliothek, Untergruppen („Quellen“, „Maschine“, …), Formelzeichen
(MK, sK, M_B, n_B, c_W, …), Messbus-Elemente, Blocknamen in den Beispielmodellen, Dateinamen der
Folienbilder in `export/`.

