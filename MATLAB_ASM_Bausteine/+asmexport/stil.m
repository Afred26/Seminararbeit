function S = stil()
%STIL Einheitlicher Folienstil für alle Diagramme und Modellbilder.
%   S = asmexport.stil() liefert Format, Schrift und feste Farben.
%
%   Farben wie in den Folien (Densborn): L1/L2/L3 blau/orange/grau wie der Spannungsverlauf
%   der Drehstromversorgung ([D-ASM] Folie 13), Flussdichte rot, Strom blau ([D-ASM] Folie 16),
%   Feldzeiger grün. Stab 1/Stab 2 der Leiterschleife grün/violett.
%   Linien, deren DisplayName oder Tag "L1", "L2", "L3", "Stab 1" oder "Stab 2" enthält,
%   färbt asmexport.folienbild automatisch ein.

% Format 16:9 (PowerPoint-Standardfolie 13,333 x 7,5 Zoll)
S.breite_in      = 13.333;
S.hoehe_in       = 7.5;
S.dpi            = 300;

% Schrift
S.schriftart     = 'Arial';
S.schriftgroesse = 14;          % Mindestgröße in pt
S.linienbreite   = 1.5;         % Mindestlinienbreite in pt

% feste Farben [r g b]
S.farbe.L1     = [0.27 0.45 0.77];
S.farbe.L2     = [0.93 0.49 0.19];
S.farbe.L3     = [0.55 0.55 0.55];
S.farbe.Stab1  = [0.00 0.50 0.27];
S.farbe.Stab2  = [0.55 0.20 0.65];
S.farbe.B      = [0.85 0.10 0.10];   % Flussdichte
S.farbe.i      = [0.15 0.25 0.80];   % Strom
S.farbe.Feld   = [0.10 0.65 0.30];   % Feldzeiger
S.farbe.Kraft  = [0.15 0.25 0.80];   % Kraftpfeil

% Zuordnung Schlüsselwort -> Farbe für folienbild
S.zuordnung = {
    '(^|[^\w])L1($|[^\w])',     'L1'
    '(^|[^\w])L2($|[^\w])',     'L2'
    '(^|[^\w])L3($|[^\w])',     'L3'
    '(^|[^\w])Stab ?1($|[^\w])', 'Stab1'
    '(^|[^\w])Stab ?2($|[^\w])', 'Stab2'
    };
end
