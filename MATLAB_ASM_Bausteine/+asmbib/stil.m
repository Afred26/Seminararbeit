function S = stil(kategorie)
%STIL Farbschema und Anzeigenamen der Bibliothekskategorien.
%   S = asmbib.stil()            Struktur mit allen Kategorien
%   s = asmbib.stil(kategorie)   Eintrag einer Kategorie
%   Felder je Kategorie: anzeige (Name in der Bibliothek), hintergrund, vordergrund [r g b]
%
%   Die Farben der Diagramme (L1/L2/L3, Stab 1/2) stehen in asmexport.stil.

S.Quellen     = eintrag('Quellen',     [1.00 0.86 0.66], [0.60 0.30 0.00]);
S.Maschine    = eintrag('Maschine',    [0.74 0.86 1.00], [0.00 0.25 0.55]);
S.Mechanik    = eintrag('Mechanik',    [0.82 0.92 0.76], [0.15 0.40 0.10]);
S.Messgeraete = eintrag('Messgeräte',  [1.00 0.98 0.70], [0.45 0.38 0.00]);
S.Didaktik    = eintrag('Didaktik',    [0.90 0.82 1.00], [0.35 0.15 0.55]);
S.Referenz    = eintrag('Referenz',    [0.88 0.88 0.88], [0.25 0.25 0.25]);

if nargin > 0
    S = S.(kategorie);
end
end

function e = eintrag(anzeige, hintergrund, vordergrund)
e = struct('anzeige', anzeige, 'hintergrund', hintergrund, 'vordergrund', vordergrund);
end
