#import "@local/templat-projektarbeit:0.1.22": *

// ============================================================================
// Kapitel: Theoretische Grundlagen
// Notation wie Vorlesungsfolien (Densborn): Index 1 = Stator, 2 = Rotor,
// Strich = auf den Stator bezogen, Winkel am Umfang elektrisch.
// Abbildungen: Bilder/Grundlagen/ (MATLAB-Export aus MATLAB_ASM_Bausteine/export
// sowie asm_esb.svg und asm_kennlinie.svg, erzeugt aus dem T-ESB mit den
// Beispielparametern aus parameter/asm_standard.m)
// ============================================================================

= Theoretische Grundlagen <kap:grundlagen>

Dieses Kapitel stellt die physikalischen und mathematischen Grundlagen zusammen, auf denen die Simulation aufbaut. Nach Aufbau und Wirkprinzip des Drehstrom-Asynchronmotors wird die Entstehung des magnetischen Drehfeldes beschrieben. Den Schwerpunkt bildet die Induktion des Stromes in den Rotorstäben und die daraus folgende Kraft- und Drehmomentbildung, die im Vorlesungsskript anhand einer Leiterschleife aus zwei Rotorstäben entwickelt wird @densborn_asm[Folien 13--30]. Daran schließen sich das stationäre Betriebsverhalten, das dynamische Maschinenmodell in Raumzeigerdarstellung und die Grundlagen der physikalischen Modellierung in MATLAB/Simulink an.

Die Formelzeichen folgen den Vorlesungsunterlagen @densborn_asm @densborn_drehfeld: Der Index 1 kennzeichnet Größen des Stators, der Index 2 Größen des Rotors. Auf die Statorseite umgerechnete Rotorgrößen tragen einen Strich ($R'_2$, $underline(I)'_2$). Winkel entlang des Luftspalts werden als elektrische Winkel angegeben; sie gehen aus dem mechanischen Winkel durch Multiplikation mit der Polpaarzahl $p$ hervor.

== Aufbau und Wirkprinzip <sec:aufbau>

Die #acr("ASM") besteht aus dem feststehenden Stator und dem drehbar gelagerten Rotor, die durch einen schmalen Luftspalt voneinander getrennt sind. In den Nuten des geblechten Statorpakets liegt eine dreisträngige Wicklung. Anfang und Ende jedes Strangs (U1--U2, V1--V2, W1--W2) sind in den Klemmenkasten geführt, sodass dieselbe Maschine wahlweise im Stern oder im Dreieck betrieben werden kann @densborn_drehfeld[Folien 23--26].

Nach der Ausführung des Rotors werden zwei Bauformen unterschieden @densborn_asm[Folien 2--11] @hagl2013[S. 138 f.]. Beim _Käfigläufer_ liegen in den Rotornuten Stäbe, die an beiden Stirnseiten über Kurzschlussringe miteinander verbunden sind. Stäbe und Ringe bilden zusammen einen käfigartigen Leiter ohne Verbindung nach außen; der induzierte Strom fließt ausschließlich im Käfig. Beim _Schleifringläufer_ trägt der Rotor dagegen eine Drehstromwicklung, deren Anschlüsse über Schleifringe und Bürsten nach außen geführt sind. Über zugeschaltete Widerstände lässt sich so der Rotorstrom und damit das Anlaufverhalten beeinflussen. Diese Arbeit behandelt ausschließlich den Käfigläufer.

Das Wirkprinzip beider Bauformen beruht auf der elektromagnetischen Induktion @densborn_asm[Folien 2, 45]: Die Statorströme erzeugen ein im Luftspalt umlaufendes Magnetfeld, das Drehfeld. Dreht sich der Rotor langsamer als dieses Feld, bewegen sich seine Leiter relativ zum Feld, und in ihnen wird eine Spannung induziert. Weil die Leiter kurzgeschlossen sind, treibt diese Spannung einen Strom. Auf die stromdurchflossenen Leiter im Magnetfeld wirken Kräfte, die ein Drehmoment in Drehrichtung des Feldes bilden. Würde der Rotor die Drehzahl des Feldes erreichen, entfiele die Relativbewegung und mit ihr Induktion, Strom und Drehmoment. Die Rotordrehzahl weicht deshalb im motorischen Betrieb stets von der Felddrehzahl ab; daher rührt die Bezeichnung _asynchron_.

== Drehstromsystem und Schaltung der Statorwicklung <sec:drehstrom>

Das speisende Drehstromnetz stellt drei sinusförmige Spannungen gleicher Amplitude bereit, die zeitlich um jeweils $2pi slash 3$ gegeneinander verschoben sind @densborn_drehfeld[Folie 8]:

$ u_"U" (t) = hat(u) sin(omega_1 t), quad
  u_"V" (t) = hat(u) sin(omega_1 t - (2 pi)/3), quad
  u_"W" (t) = hat(u) sin(omega_1 t - (4 pi)/3) $ <eq:drehstrom>

mit der Statorkreisfrequenz $omega_1 = 2 pi f_1$. Welche Spannung an einem Wicklungsstrang anliegt, hängt von der Schaltung ab (@tab:stern-dreieck). Bei Sternschaltung liegt jeder Strang zwischen Außenleiter und Sternpunkt, die Strangspannung ist um den Faktor $sqrt(3)$ kleiner als die Außenleiterspannung $U$. Bei Dreieckschaltung liegt jeder Strang direkt zwischen zwei Außenleitern; dafür ist der Außenleiterstrom $I$ um den Faktor $sqrt(3)$ größer als der Strangstrom @densborn_drehfeld[Folien 12--26].

#figure(
  caption: [Strang- und Außenleitergrößen bei Stern- und Dreieckschaltung nach @densborn_drehfeld[Folie 26]],
  table(
    columns: (2.2fr, 1.5fr, 1.5fr),
    inset: 8pt,
    align: (left + horizon, center + horizon, center + horizon),
    fill: (_, y) => if y == 0 { luma(220) } else { white },
    table.header([*Größe*], [*Stern*], [*Dreieck*]),
    [Strangspannung $U_"Str"$], [$U slash sqrt(3)$], [$U$],
    [Strangstrom $I_"Str"$], [$I$], [$I slash sqrt(3)$],
    [Wirkleistung $P$ (symmetrisch)], table.cell(colspan: 2)[$sqrt(3) dot U dot I dot cos phi$],
  ),
) <tab:stern-dreieck>

Für den Motor folgt daraus: Eine Wicklung, die im Dreieck an einem Netz mit 230 V Außenleiterspannung betrieben wird, erhält dieselbe Strangspannung wie im Stern an 400 V und verhält sich elektrisch gleich. Auf dem Wechsel zwischen beiden Schaltungen beruht der Stern-Dreieck-Anlauf.

== Entstehung des magnetischen Drehfeldes <sec:drehfeld>

Ein einzelner Wicklungsstrang, der von einem sinusförmigen Wechselstrom durchflossen wird, erzeugt im Luftspalt ein _Wechselfeld_. Die radiale Flussdichte ist entlang des Umfangs näherungsweise sinusförmig verteilt. Lage von Maximum und Nulldurchgängen bleibt fest an die Achse des Strangs gebunden; nur die Höhe der Verteilung ändert sich im Takt des Stromes @densborn_drehfeld[Folien 55--57]. Zählt man den Luftspaltwinkel $gamma$ von der Achse des Strangs U aus und liegen die Achsen der Stränge V und W bei $2pi slash 3$ und $4 pi slash 3$, so gilt für die drei Teilfelder

$ B_"U" (gamma, t) &= hat(B)_"Str" cos(omega_1 t) cos(gamma) \
  B_"V" (gamma, t) &= hat(B)_"Str" cos(omega_1 t - (2 pi)/3) cos(gamma - (2 pi)/3) \
  B_"W" (gamma, t) &= hat(B)_"Str" cos(omega_1 t - (4 pi)/3) cos(gamma - (4 pi)/3). $ <eq:teilfelder>

Jedes Produkt lässt sich mit $cos a cos b = 1/2 [cos(a - b) + cos(a + b)]$ zerlegen. Die drei Anteile $cos(a + b)$ sind um jeweils $4 pi slash 3$ gegeneinander verschoben und heben sich in der Summe auf; die Anteile $cos(a - b)$ sind identisch. Die Überlagerung ergibt#footnote[Im Skript @densborn_drehfeld[Folie 58] sind die Teilfelder in der Form $hat(B) sin(omega t) sin(gamma)$ angesetzt. Der Ansatz unterscheidet sich von @eq:teilfelder nur in der Lage der Strangachsen gegenüber dem Bezugspunkt $gamma = 0$ und führt auf dasselbe Gesamtfeld.]

$ B(gamma, t) = B_"U" + B_"V" + B_"W" = 3/2 hat(B)_"Str" cos(gamma - omega_1 t) = hat(B) cos(gamma - phi_"el" (t)). $ <eq:drehfeld>

@eq:drehfeld beschreibt eine Flussdichtewelle konstanter Amplitude $hat(B) = 1,5 dot hat(B)_"Str"$, deren Maximum mit der elektrischen Winkelgeschwindigkeit $omega_1$ am Umfang umläuft: das Drehfeld @densborn_drehfeld[Folien 59--61] @hagl2013[S. 114 ff.]. Der Feldwinkel $phi_"el" (t) = omega_1 t$ gibt die Lage des Flussdichtemaximums an und entspricht der Richtung des Drehfeldzeigers $arrow(B)$ in den Folienbildern. @fig:spulenfelder zeigt die Teilfelder und ihre Summe für $phi_"el" = 0$. Die Drehrichtung des Feldes folgt der Phasenfolge der Ströme; das Vertauschen zweier Außenleiter kehrt sie um.

#figure(
  image("../Bilder/Grundlagen/drehfeld_spulen_0.png", width: 92%),
  caption: [Teilfelder der drei Stränge und resultierendes Drehfeld entlang des Luftspaltwinkels für $phi_"el" = 0$, bezogen auf die Amplitude $hat(B)_"Str"$ eines Strangs (eigene Darstellung, erzeugt mit der Simulation)],
) <fig:spulenfelder>

Bei einer Maschine mit $p$ Polpaaren wiederholt sich die Wicklungsanordnung $p$-mal am Umfang; die Stränge sind mechanisch um $2 pi slash (3 p)$ gegeneinander versetzt @densborn_drehfeld[Folie 66]. Während einer Periode der Netzspannung legt das Feld $360 degree$ elektrisch und damit $1 slash p$ Umdrehung zurück. Die Drehzahl des Feldes, die _Synchrondrehzahl_, beträgt daher

$ n_"s" = (60 dot f_1) / p quad "mit" n_"s" "in" "min"^(-1) "und" f_1 "in" "Hz". $ <eq:ns>

Am 50-Hz-Netz ergeben sich für $p = 1, 2, 3, 4$ die Synchrondrehzahlen $3000$, $1500$, $1000$ und $750 thin "min"^(-1)$. Der in dieser Arbeit simulierte Beispielmotor ist vierpolig ($p = 2$, $n_"s" = 1500 thin "min"^(-1)$).

== Induktion und Drehmomentbildung im Käfigläufer <sec:drehmoment>

=== Schlupf und Rotorfrequenz <sec:schlupf>

Die Abweichung der Rotordrehzahl $n$ von der Synchrondrehzahl wird durch den _Schlupf_ beschrieben @densborn_asm[Folie 46]:

$ s = (n_"s" - n) / n_"s". $ <eq:schlupf>

Im Stillstand ist $s = 1$, bei synchroner Drehzahl $s = 0$. Im Bemessungsbetrieb liegt der Schlupf realer Maschinen im unteren einstelligen Prozentbereich @densborn_asm[Folie 46]. Für $n > n_"s"$ wird der Schlupf negativ, und die Maschine arbeitet als Generator.

Vom Rotor aus betrachtet läuft das Drehfeld mit der Differenzdrehzahl $n_"s" - n = s dot n_"s"$ um. Alle im Rotor induzierten Größen haben deshalb die _Rotorfrequenz_

$ f_2 = s dot f_1. $ <eq:f2>

Mit dem mechanischen Drehwinkel $theta.alt$ des Rotors lautet der Feldwinkel relativ zum Rotor $theta_2 = phi_"el" - p theta.alt$. Im stationären Betrieb gilt $dif theta_2 slash dif t = s omega_1$: Im Stillstand dreht das Feld mit Netzfrequenz über die Rotorstäbe hinweg, bei kleinem Schlupf nur noch langsam.

=== Induktion in einer Leiterschleife aus zwei Rotorstäben <sec:leiterschleife>

Das Skript erklärt die Vorgänge im Käfig an zwei Rotorstäben, die um eine Polteilung ($180 degree$ elektrisch) versetzt liegen und über die Kurzschlussringe eine Leiterschleife bilden @densborn_asm[Folie 16]. Der Drehfeldzeiger $arrow(B)$ wird dazu in eine Komponente $B_perp$ senkrecht zur Schleifenebene und eine Komponente $B_parallel$ in der Schleifenebene zerlegt. Nur $B_perp$ durchsetzt die Schleife und trägt zur Induktion bei; $B_parallel$ liefert keinen Beitrag. Mit der Stablänge $l$ und dem Radius $r$ der Stabmitte beträgt der mit der Schleife verkettete Fluss

$ Phi_"S" (t) = Phi cos theta_2 (t), quad Phi = (2 hat(B) l r) / p, $ <eq:polfluss>

wobei $Phi$ der Polfluss ist und $theta_2$ von der Stellung aus gezählt wird, in der das Feld senkrecht auf der Schleife steht (@fig:querschnitt a). Nach dem Induktionsgesetz entsteht in der Schleife die Spannung

$ u_"i" = - (dif Phi_"S") / (dif t) = s omega_1 Phi sin theta_2 . $ <eq:induktion>

Ihre Amplitude $s omega_1 Phi$ wächst proportional zum Schlupf, ihre Frequenz ist die Rotorfrequenz $f_2$.

Die Richtung des induzierten Stromes folgt aus der Lenz'schen Regel: Das Magnetfeld des Stromes wirkt der _Änderung_ von $B_perp$ entgegen @densborn_asm[Folie 17]. Das Skript bestimmt die Stromrichtung deshalb über den „Änderungsvektor“, die Differenz der senkrechten Feldkomponente zwischen zwei aufeinanderfolgenden Zeitpunkten. Über eine Feldumdrehung relativ zum Rotor ergibt sich folgender Ablauf @densborn_asm[Folien 18--30]:

- Bei $theta_2 = 0$ steht das Feld senkrecht auf der Schleife. $B_perp$ ist maximal, seine Änderung aber null; es fließt kein Strom (Folie 18, @fig:querschnitt a).
- Mit weiterdrehendem Feld nimmt $B_perp$ ab. Der Änderungsvektor zeigt von rechts nach links, der Strom im oberen Stab fließt aus der Zeichenebene heraus (Folien 19--23).
- Bei $theta_2 = 90 degree$ liegt das Feld in der Schleifenebene. $B_perp$ ist null, ändert sich aber am schnellsten; der Strom ist maximal (Folie 21, @fig:querschnitt b).
- Bei $theta_2 = 180 degree$ ist $B_perp$ betragsmäßig wieder maximal, der Strom geht durch null (Folie 24). Anschließend kehrt sich die Stromrichtung um (Folien 25--29), bis nach einer vollen Umdrehung der Ausgangszustand erreicht ist (Folie 30).

#figure(
  grid(
    columns: 2,
    gutter: 1.2em,
    [#image("../Bilder/Grundlagen/folie18.png", width: 100%) a) $theta_2 = 0 degree$],
    [#image("../Bilder/Grundlagen/folie21.png", width: 100%) b) $theta_2 = 90 degree$],
  ),
  caption: [Leiterschleife aus zwei Rotorstäben im Drehfeld, Darstellung wie im Skript (U1 oben, Feld dreht im Uhrzeigersinn). Rot: Komponente $B_perp$, grün: Drehfeldzeiger, dunkelrot: Änderungsvektor, blau: Kraft auf die Stäbe; Punkt bzw. Kreuz: Strom aus der bzw. in die Zeichenebene; Farbring: radiale Flussdichte (rot austretend, blau eintretend). Eigene Darstellung nach @densborn_asm[Folien 18, 21], erzeugt mit der Simulation],
) <fig:querschnitt>

Der Stromverlauf eilt dem Verlauf von $B_perp$ damit um eine Viertelperiode nach (@fig:verlaeufe, oben). Diese idealisierte Betrachtung der Folien vernachlässigt die Streuinduktivität der Schleife. Tatsächlich besitzt jede Rotormasche neben dem Widerstand $R_2$ eine Streuinduktivität $L_(2 sigma)$, deren Reaktanz wegen @eq:f2 mit dem Schlupf wächst. Amplitude und Nacheilwinkel $phi_Z$ des Stromes gegenüber der induzierten Spannung betragen

$ hat(i)_2 = (s omega_1 Phi) / sqrt(R_2^2 + (s omega_1 L_(2 sigma))^2), quad
  tan phi_Z = (s omega_1 L_(2 sigma)) / R_2 . $ <eq:rotorstrom>

Bei kleinem Schlupf überwiegt der Widerstand: Der Strom ist nahezu phasengleich mit der induzierten Spannung und wächst proportional zu $s$. Bei großem Schlupf, also im Anlauf, überwiegt die Reaktanz: Der Strom eilt der Spannung um fast $90 degree$ nach, und seine Amplitude nähert sich dem vom Schlupf unabhängigen Grenzwert $Phi slash L_(2 sigma)$.

=== Kraft und Drehmoment <sec:kraft>

Auf einen stromdurchflossenen Stab der Länge $l$ im Magnetfeld wirkt die Kraft $arrow(F) = i dot (arrow(l) times arrow(B))$, wobei $arrow(l)$ in Richtung des Stromes zeigt. Da das Luftspaltfeld radial und der Stab axial gerichtet ist, wirkt die Kraft tangential, also in Umfangsrichtung, und hat den Betrag $F = i l B$; ihre Richtung ergibt sich aus der Drei-Finger-Regel der rechten Hand @densborn_asm[Folie 19]. Mit dem Hebelarm $r$ trägt jeder Stab das Moment $M = F r$ bei.

Das Skript beschreibt die Stromverteilung entlang des Umfangs, den Strombelag, durch @densborn_asm[Folie 14]

$ i_2 (gamma, t) = hat(i)_2 sin(gamma - phi_"el" (t) - phi_2), quad phi_2 = 90 degree - phi_Z , $ <eq:strombelag>

wobei der Strom wie in den Folienbildern aus der Zeichenebene heraus positiv gezählt wird. Der Winkel $phi_2$ ist der räumliche Versatz zwischen der Flussdichtewelle nach @eq:drehfeld und dem Strombelag; im idealisierten Fall der Folien ($phi_Z = 0$) beträgt er $90 degree$. Ein Stab $k$ an der Stelle $gamma_k$ führt den Strom $i_k = i_2 (gamma_k, t)$ und liegt in der Flussdichte $B_k = hat(B) cos(gamma_k - phi_"el")$. Die tangentiale Kraft in Drehrichtung des Feldes ist dann#footnote[Das Minuszeichen folgt aus $arrow(F) = i dot (arrow(l) times arrow(B))$: In der Darstellung der Folien läuft das Feld im Uhrzeigersinn um, und die Zählrichtung „aus der Zeichenebene“ ist der Richtung $arrow(e)_r times arrow(e)_gamma$ entgegengesetzt. Das Skript gibt das örtliche Moment ohne dieses Vorzeichen an @densborn_asm[Folie 15]; sein Endergebnis $M = k_"Mo" I_2 Phi sin phi_2$ stimmt mit @eq:moment überein.] $F_k = -i_k l B_k$.

Für die Leiterschleife aus zwei Stäben im Abstand von $180 degree$ ergibt die Summe der beiden Stabmomente mit $x_1 = gamma_1 - phi_"el"$

$ M_"S" (t) = hat(i)_2 l hat(B) r [sin phi_2 - sin(2 x_1 (t) - phi_2)], quad
  overline(M)_"S" = hat(i)_2 l hat(B) r sin phi_2 . $ <eq:schleifenmoment>

Das Schleifenmoment pulsiert mit der doppelten Rotorfrequenz um den Mittelwert $overline(M)_"S"$. Für $phi_2 = 90 degree$ wird es nie negativ: Strom und Flussdichte am Stab wechseln ihr Vorzeichen gleichzeitig, sodass die Kraft stets in Drehrichtung des Feldes wirkt (@fig:verlaeufe, unten; @densborn_asm[Folie 25]). Der Mittelwert ist bei $phi_2 = 90 degree$ am größten.

#figure(
  image("../Bilder/Grundlagen/folie16_verlaeufe.png", width: 100%),
  caption: [Flussdichte $B_perp$ senkrecht zur Schleife und Strom in Stab 1 (oben) sowie Kräfte auf beide Stäbe und Schleifenmoment $M_"S"$ (unten) während einer Feldumdrehung relativ zum Rotor; idealisiert mit $phi_Z = 0$, $s = 1$, Beispielwerte (eigene Darstellung nach @densborn_asm[Folie 16], erzeugt mit der Simulation)],
) <fig:verlaeufe>

Der Käfig besteht aus $N_2$ gleichmäßig verteilten Stäben. Summiert man die Stabmomente über alle Stäbe, heben sich die pulsierenden Anteile auf, sofern $N_2 slash p > 2$ ist, und es bleibt ein konstantes Moment:

$ M = N_2/2 hat(i)_2 l hat(B) r sin phi_2 = k_"Mo" dot I_2 dot Phi dot sin phi_2 , quad k_"Mo" = (sqrt(2) N_2 p) / 4 . $ <eq:moment>

Dabei ist $I_2 = hat(i)_2 slash sqrt(2)$ der Effektivwert des Stabstroms. @eq:moment entspricht der Momentengleichung des Skripts @densborn_asm[Folie 15]: Das Drehmoment hängt vom Fluss im Luftspalt, vom Rotorstrom und von der räumlichen Lage zwischen Flussdichte und Strombelag ab. Wegen $sin phi_2 = cos phi_Z$ trägt nur der Anteil des Rotorstroms zum Moment bei, der in Phase mit der induzierten Spannung ist. Das erklärt, warum der hohe Strom im Anlauf vergleichsweise wenig Drehmoment bildet.

== Betriebsverhalten am starren Netz <sec:betrieb>

=== Drehmoment-Drehzahl-Kennlinie und Kloss'sche Gleichung <sec:kennlinie>

Setzt man @eq:rotorstrom in @eq:moment ein und nimmt den Luftspaltfluss $Phi$ als lastunabhängig an, so ergibt sich das Drehmoment als Funktion des Schlupfes:

$ M(s) = (N_2 p)/4 dot Phi^2 omega_1 dot (s R_2) / (R_2^2 + (s omega_1 L_(2 sigma))^2) . $ <eq:moment-s>

Das Moment ist bei kleinem Schlupf proportional zu $s$, bei großem Schlupf proportional zu $1 slash s$ und erreicht dazwischen beim _Kippschlupf_ $s_"K" = R_2 slash (omega_1 L_(2 sigma))$ sein Maximum, das _Kippmoment_ $M_"K"$. Bezieht man @eq:moment-s auf diese beiden Größen, erhält man die Kloss'sche Gleichung @schroeder2021[S. 199--284]:

$ M / M_"K" = 2 / (s / s_"K" + s_"K" / s) . $ <eq:kloss>

Mit $s_"K"$ lässt sich auch der Nacheilwinkel aus @eq:rotorstrom kompakt schreiben: $tan phi_Z = s slash s_"K"$. Im Kipppunkt beträgt er genau $45 degree$.

Den Zusammenhang zwischen Drehmoment und Drehzahl beschreibt die _Drehmoment-Drehzahl-Kennlinie_ (@fig:kennlinie). Sie gilt für eine feste Netzfrequenz und damit eine feste Synchrondrehzahl @densborn_asm[Folie 52] und wird durch folgende Kenngrößen charakterisiert @densborn_asm[Folien 48--50]:

- das _Anlaufmoment_ $M_"A"$ bei $n = 0$,
- das _Sattelmoment_ $M_"S"$, das kleinste Moment während des Hochlaufs,
- das _Kippmoment_ $M_"K"$, das größte Moment, bei der Kippdrehzahl $n_"K"$,
- das _Bemessungsmoment_ $M_"N"$ bei der Bemessungsdrehzahl $n_"N"$.

#figure(
  image("../Bilder/Grundlagen/asm_kennlinie.svg", width: 100%),
  caption: [Stationäre Drehmoment-Drehzahl-Kennlinie des Beispielmotors ($p = 2$, $U = 400 "V"$, $f_1 = 50 "Hz"$, Beispielparameter der Simulation) nach dem Ersatzschaltbild aus @sec:esb, Näherung nach Kloss und Lastkennlinie eines Lüfters (eigene Darstellung)],
) <fig:kennlinie>
// TODO: In der Bildunterschrift auf die Parametertabelle im Simulationskapitel verweisen.

Der _Arbeitspunkt_ ergibt sich als Schnittpunkt der Motorkennlinie mit der Kennlinie der angetriebenen Last @densborn_asm[Folie 56]. Er ist stabil, wenn das Motormoment bei einer kleinen Drehzahlerhöhung stärker abnimmt als das Lastmoment ($dif M slash dif n < dif M_"L" slash dif n$). Für übliche Lasten trifft dies auf den Bereich zwischen Kippdrehzahl und Synchrondrehzahl zu. Steigt das Lastmoment über das Kippmoment, bricht die Drehzahl ein, und der Motor „kippt“ @densborn_asm[Folie 54].

Die Kloss'sche Gleichung beschreibt die Kennlinie einer Maschine mit einfachem Käfig und vernachlässigtem Statorwiderstand. Reale Käfigläufer erreichen durch Stromverdrängung in hohen oder doppelten Rotorstäben ein deutlich höheres Anlaufmoment @densborn_asm[Folie 44]; das Sattelmoment geht auf Oberwellen des Luftspaltfeldes zurück. Beide Effekte enthält ein Grundwellenmodell mit einfachem Käfig nicht, wie es auch dieser Arbeit zugrunde liegt. In @fig:kennlinie ist das Anlaufmoment deshalb nur wenig größer als das Bemessungsmoment, und ein Sattel tritt nicht auf.

=== Hochlauf <sec:hochlauf>

Die Drehzahländerung folgt aus dem Gleichgewicht der Momente an der Welle:

$ J (dif Omega) / (dif t) = M - M_"L", quad J = J_"M" + J_"L", quad Omega = (2 pi n) / 60 . $ <eq:bewegung>

Darin sind $J_"M"$ und $J_"L"$ die Trägheitsmomente von Motor und Arbeitsmaschine, $Omega$ die mechanische Winkelgeschwindigkeit und $M_"L"$ das Lastmoment. Die Differenz $M - M_"L"$ ist das Beschleunigungsmoment. Die Hochlaufzeit bis zur Enddrehzahl ergibt sich durch Integration von @eq:bewegung; mit einem mittleren Beschleunigungsmoment $overline(M)_"B"$ lässt sie sich abschätzen zu (vgl. @densborn_asm[Folie 68])

$ t_"H" = J integral_0^(Omega_"E") (dif Omega) / (M - M_"L") approx (J dot Omega_"E") / overline(M)_"B" . $ <eq:hochlaufzeit>

Beim direkten Einschalten nimmt der Motor ein Mehrfaches seines Bemessungsstroms auf. Um das Netz zu entlasten, werden größere Motoren deshalb über Anlaufverfahren wie Stern-Dreieck-Anlauf, Sanftstarter, Frequenzumrichter oder Polumschaltung angefahren @densborn_asm[Folie 56].

Die Kennlinie in @fig:kennlinie gilt nur für eingeschwungene elektrische Größen. Während eines schnellen Hochlaufs und unmittelbar nach dem Einschalten treten elektromagnetische Ausgleichsvorgänge auf, die das Drehmoment kurzzeitig stark von der stationären Kennlinie abweichen lassen. Für ihre Simulation wird ein dynamisches Maschinenmodell benötigt (@sec:raumzeiger).

== Mathematisches Modell der Asynchronmaschine <sec:modell>

=== Stationäres Ersatzschaltbild <sec:esb>

Bei sinusförmiger Speisung im eingeschwungenen Zustand lässt sich ein Strang der Maschine wie ein Transformator mit kurzgeschlossener Sekundärwicklung beschreiben, wenn die Rotorgrößen auf die Statorseite umgerechnet werden @schroeder2021[S. 199--284]. @fig:esb zeigt das zugehörige T-#acr("ESB"). $R_1$ und $X_(1 sigma)$ sind Widerstand und Streureaktanz des Stators, $X_"h"$ ist die Hauptreaktanz, $R'_2$ und $X'_(2 sigma)$ sind Widerstand und Streureaktanz des Rotors. Der Schlupf erscheint im lastabhängigen Widerstand $R'_2 (1 - s) slash s$, an dem die in mechanische Leistung umgesetzte Leistung abfällt.

#figure(
  image("../Bilder/Grundlagen/asm_esb.svg", width: 95%),
  caption: [T-Ersatzschaltbild eines Strangs der Asynchronmaschine mit statorbezogenen Rotorgrößen und Zählpfeilen im Verbraucherzählpfeilsystem (eigene Darstellung nach @schroeder2021)],
) <fig:esb>

Aus @fig:esb folgen die Spannungsgleichungen

$ underline(U)_1 &= (R_1 + upright(j) X_(1 sigma)) underline(I)_1 + upright(j) X_"h" underline(I)_mu \
  0 &= (R'_2 / s + upright(j) X'_(2 sigma)) underline(I)'_2 + upright(j) X_"h" underline(I)_mu , quad underline(I)_mu = underline(I)_1 + underline(I)'_2 . $ <eq:esb>

Die über den Luftspalt übertragene Leistung $P_delta = 3 I'^2_2 R'_2 slash s$ teilt sich in die Rotorkupferverluste $s P_delta$ und die mechanische Leistung $(1 - s) P_delta$ auf. Mit der synchronen Winkelgeschwindigkeit $Omega_"s" = omega_1 slash p$ ergibt sich das Luftspaltmoment

$ M = P_delta / Omega_"s" = (3 p) / omega_1 dot I'^2_2 dot R'_2 / s . $ <eq:esb-moment>

Vernachlässigt man den Statorwiderstand $R_1$, so lässt sich @eq:esb-moment exakt in die Form von @eq:kloss bringen @schroeder2021[S. 199--284]. Mit $R_1 > 0$ weicht die Kennlinie davon geringfügig ab (@fig:kennlinie).

=== Dynamisches Modell in Raumzeigerdarstellung <sec:raumzeiger>

Das Ersatzschaltbild setzt sinusförmige, eingeschwungene Größen voraus. Für Einschaltvorgänge, Hochlauf und Laststöße werden die Differentialgleichungen der Maschine benötigt. Sie lassen sich kompakt mit _Raumzeigern_ formulieren, die die drei Stranggrößen $x_"U"$, $x_"V"$, $x_"W"$ (Spannungen, Ströme oder Flussverkettungen) zu einer komplexen Größe zusammenfassen @schroeder2021[S. 199--284]:

$ underline(x) = 2/3 (x_"U" + underline(a) x_"V" + underline(a)^2 x_"W"), quad underline(a) = e^(upright(j) 2 pi slash 3) . $ <eq:raumzeiger>

Bei symmetrischen sinusförmigen Stranggrößen hat der Raumzeiger den Betrag der Strangamplitude und läuft mit $omega_1$ um. Der Raumzeiger der Statorströme zeigt in Richtung der Durchflutung und ist damit das mathematische Gegenstück zum Drehfeldzeiger der Folienbilder. Im statorfesten Koordinatensystem und unter Vernachlässigung von Sättigung, Eisenverlusten und Stromverdrängung lautet das Modell @schroeder2021[S. 199--284]:

$ underline(u)_1 &= R_1 underline(i)_1 + (dif underline(psi)_1) / (dif t) \
  0 &= R'_2 underline(i)'_2 + (dif underline(psi)'_2) / (dif t) - upright(j) p Omega underline(psi)'_2 \
  underline(psi)_1 &= L_(1 sigma) underline(i)_1 + underline(psi)_"h", quad
  underline(psi)'_2 = L'_(2 sigma) underline(i)'_2 + underline(psi)_"h", quad
  underline(psi)_"h" = L_"h" (underline(i)_1 + underline(i)'_2) . $ <eq:rz-spannung>

Der Term $-upright(j) p Omega underline(psi)'_2$ ist die Bewegungsinduktion, die entsteht, weil die Rotorgleichung in statorfesten Koordinaten geschrieben wird. Das Luftspaltmoment und die Bewegungsgleichung lauten

$ M = 3/2 p op("Im") lr(\{ underline(psi)_"h"^* underline(i)_1 \}), quad
  J (dif Omega) / (dif t) = M - M_"L", quad (dif theta.alt) / (dif t) = Omega . $ <eq:rz-moment>

Die Größen der Folien lassen sich direkt aus dem Modell gewinnen. Die Richtung des Hauptflusses $underline(psi)_"h"$ ist der Feldwinkel $phi_"el"$, sein Betrag ist über die wirksame Windungszahl $N_1 xi_1$ mit dem Polfluss verknüpft: $abs(underline(psi)_"h") = N_1 xi_1 Phi$. Wegen $underline(psi)_"h" = L_"h" (underline(i)_1 + underline(i)'_2)$ gilt $op("Im") lr(\{ underline(psi)_"h"^* underline(i)_1 \}) = - op("Im") lr(\{ underline(psi)_"h"^* underline(i)'_2 \})$, und das Moment lässt sich schreiben als

$ M = 3/2 p abs(underline(psi)_"h") abs(underline(i)'_2) sin(angle underline(psi)_"h" - angle underline(i)'_2) . $ <eq:rz-moment-betrag>

Im stationären Betrieb eilt $underline(i)'_2$ dem Hauptfluss um $90 degree + phi_Z$ nach. Der Sinus dieses Winkels ist $cos phi_Z = sin phi_2$, sodass @eq:rz-moment-betrag dieselbe Struktur wie die aus den Folien abgeleitete @eq:moment hat.

Das Raumzeigermodell enthält die bisher beschriebenen Modelle als Sonderfälle: Für sinusförmige Speisung im eingeschwungenen Zustand führt es auf die Gleichungen des Ersatzschaltbilds (@eq:esb), mit zusätzlich vernachlässigtem Statorwiderstand auf die Kloss'sche Gleichung (@eq:kloss). Darüber hinaus bildet es die Ausgleichsvorgänge ab, die beim Einschalten durch Gleichanteile der Flussverkettungen entstehen.

== Physikalische Modellierung in MATLAB/Simulink <sec:simscape>

Simulink beschreibt ein System als _Signalflussplan_: Jeder Block bildet Eingangs- auf Ausgangssignale ab, und das verschaltete Blockdiagramm ist unmittelbar das mathematische Modell @mathworks_physnet. Differentialgleichungen wie @eq:rz-spannung werden dabei mit Integratoren nachgebildet; Ursache und Wirkung jeder Verbindung müssen vorab festgelegt werden.

Die Erweiterung Simscape folgt dagegen dem Ansatz _physikalischer Netzwerke_. Komponenten tauschen über ungerichtete Anschlüsse Energie aus, und ein Simscape-Modell bildet den Aufbau des realen Systems nach @mathworks_physnet. Jeder Anschluss ist einer physikalischen Domäne zugeordnet und durch eine _Across_-Größe und eine _Through_-Größe gekennzeichnet (@tab:domaenen). Across-Größen werden parallel zum Element gemessen, Through-Größen in Reihe; ihr Produkt ist in der Regel die übertragene Leistung @mathworks_through. Aus den Gleichungen der Komponenten und den Verbindungen stellt Simscape die Netzwerkgleichungen selbst auf; Knoten- und Maschenregel müssen nicht von Hand formuliert werden. Eigene Komponenten und Domänen lassen sich in der textbasierten Simscape-Sprache beschreiben.

#figure(
  caption: [Across- und Through-Größen ausgewählter Simscape-Domänen nach @mathworks_physnet],
  table(
    columns: (1.6fr, 1.4fr, 1.4fr),
    inset: 8pt,
    align: (left + horizon, center + horizon, center + horizon),
    fill: (_, y) => if y == 0 { luma(220) } else { white },
    table.header([*Domäne*], [*Across-Größe*], [*Through-Größe*]),
    [elektrisch], [Spannung], [Strom],
    [mechanisch rotatorisch], [Winkelgeschwindigkeit], [Drehmoment],
    [magnetisch], [magnetomotorische Kraft], [magnetischer Fluss],
  ),
) <tab:domaenen>

Physikalische Netzwerke führen auf differential-algebraische Gleichungssysteme, die häufig _steif_ sind: Zeitkonstanten sehr unterschiedlicher Größe treten gleichzeitig auf, etwa die Netzperiode von 20 ms und der mechanische Hochlauf im Sekundenbereich. Für solche Modelle empfiehlt MathWorks implizite Lösungsverfahren wie `daessc`, `ode23t` oder `ode15s`, die mit deutlich weniger Zeitschritten auskommen als explizite Verfahren @mathworks_solver. Verfahren mit variabler Schrittweite passen den Zeitschritt dem Verlauf der Lösung an; eine Begrenzung der maximalen Schrittweite stellt sicher, dass netzfrequente Schwingungen ausreichend fein aufgelöst werden.
