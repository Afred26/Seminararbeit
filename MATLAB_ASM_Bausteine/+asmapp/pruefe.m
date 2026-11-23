function [ok, meldung] = pruefe(feld, wert, G)
%PRUEFE Prüft einen Eingabewert gegen den Wertebereich aus dem Katalog.
%   [ok, meldung] = asmapp.pruefe(feld, wert)
%   [ok, meldung] = asmapp.pruefe(feld, wert, G)     G = asmapp.grenzen() (spart das Neuladen)
%   asmapp.pruefe(P)                                 prüft alle Felder der Struktur P, Fehler
%                                                    'asmapp:wert' beim ersten ungültigen Wert
%
%   Zusätzlich gilt immer: reell, endlich, Skalar (Konventionen, Abschnitt 4).

if nargin < 3, G = asmapp.grenzen(); end
if isstruct(feld)                                       % ganze Parameterstruktur
    P = feld;
    for f = fieldnames(G)'
        if isfield(P, f{1})
            [ok1, m] = asmapp.pruefe(f{1}, P.(f{1}), G);
            if ~ok1, error('asmapp:wert', '%s', m); end
        end
    end
    ok = true;  meldung = '';
    return;
end

g = G.(feld);
name = sprintf('%s [%s]', g.prompt, g.einheit);
ok = false;
if ~(isnumeric(wert) && isscalar(wert) && isreal(wert) && isfinite(wert))
    meldung = sprintf('%s: endliche reelle Zahl erwartet.', name);
elseif g.ganz && wert ~= round(wert)
    meldung = sprintf('%s: ganze Zahl erwartet.', name);
elseif g.min_offen && wert <= g.min
    meldung = sprintf('%s muss > %g sein.', name, g.min);
elseif ~g.min_offen && wert < g.min
    meldung = sprintf('%s muss ≥ %g sein.', name, g.min);
elseif wert > g.max
    meldung = sprintf('%s muss ≤ %g sein.', name, g.max);
else
    ok = true;  meldung = '';
end
end
