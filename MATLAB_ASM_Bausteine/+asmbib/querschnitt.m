function querschnitt(ax, Z, k, par, opt)
%QUERSCHNITT Zeichnet den Rotorquerschnitt (Feld, Stabströme, Kräfte) im Stil der Folien.
%   asmbib.querschnitt(ax, Z, k, par, opt)
%
%   ax   Achsen (werden geleert)
%   Z    Zustand aus asmbib.querschnitt_zustand, k = Zeile (Zeitpunkt)
%   par  p, N2, k1, k2
%   opt  Struktur (alle Felder optional):
%          orientierung  'folien' (U1 oben, Feld im Uhrzeigersinn, Standard) | 'mathematisch'
%          ansicht       'rotorfest' (Standard) | 'statorfest'
%          zerlegung     Feldzeiger mit B⊥ / B∥ zeigen (Folie 16, nur p = 1), Standard true
%          aenderung     Änderungsvektor dB⊥/dt zeigen (Folie 17, nur p = 1), Standard true
%          kraft         Kraftpfeile an der Leiterschleife (Folie 19), Standard true
%          alle          alle Stäbe zeigen (sonst nur die Leiterschleife), Standard true
%          i_max, F_max, dB_max   Skalierung (Standard: Werte des Zeitpunkts)
%
%   Darstellung wie [D-ASM] Folien 16-30: Wicklungsseiten U1 ... W2 im Stator, Farbring =
%   Luftspaltflussdichte B (rot +, blau −), Stäbe rot • = Strom aus der Zeichenebene, blau × = in
%   die Zeichenebene, grüner Pfeil = Feldzeiger, rot = Anteil senkrecht zur Leiterschleife (B⊥),
%   grün gestrichelt = Anteil ohne Beitrag (B∥), dunkelrot = Änderungsvektor, blau = Kraft.

def = struct('orientierung', 'folien', 'ansicht', 'rotorfest', 'zerlegung', true, 'aenderung', true, ...
             'kraft', true, 'alle', true, 'i_max', [], 'F_max', [], 'dB_max', []);
if nargin < 5, opt = struct(); end
for f = fieldnames(def)', if ~isfield(opt, f{1}), opt.(f{1}) = def.(f{1}); end, end
S = asmexport.stil();
sg = 1 - 2*strcmp(opt.orientierung, 'folien');                % Bildwinkel = sg·(mathematischer Winkel)
if strcmp(opt.ansicht, 'rotorfest'), dreh = Z.th(k); else, dreh = 0; end
bild = @(a) sg*(a - dreh);                                   % mechanischer Winkel -> Bildwinkel
pol  = @(r, a) r*[cos(a), sin(a)];

cla(ax); hold(ax, 'on'); axis(ax, 'equal', 'off');
xlim(ax, [-1.75 1.75]); ylim(ax, [-1.75 1.75]);

% Stator mit Wicklungsseiten (Lage für das erste Polpaar)
ring(ax, 1.22, 1.6, [0.85 0.85 0.87]);
namen = {'U1', -90; 'U2', 90; 'V1', 30; 'V2', 210; 'W1', 150; 'W2', -30};
for j = 1:size(namen, 1)
    a = bild(deg2rad(namen{j, 2})/par.p);                     % rotorfest: Stator dreht im Bild rückwärts
    c = pol(1.41, a);
    kreis(ax, c, 0.06, 'w', [0.3 0.3 0.3]);
    text(ax, 1.66*cos(a), 1.66*sin(a), namen{j, 1}, 'HorizontalAlignment', 'center', 'FontSize', 11);
end

% Luftspaltflussdichte als Farbring
nseg = 180; al = 2*pi*(0:nseg)'/nseg;
Bseg = Z.Bhat(k)*cos(par.p*(al(1:end-1) + pi/nseg) - Z.phi_el(k));
a1 = bild(al(1:end-1)); a2 = bild(al(2:end));               % ein Patch mit nseg Flächen (schneller)
x = [1.04*cos(a1) 1.2*cos(a1) 1.2*cos(a2) 1.04*cos(a2)]';
y = [1.04*sin(a1) 1.2*sin(a1) 1.2*sin(a2) 1.04*sin(a2)]';
cseg = zeros(nseg, 3);
for j = 1:nseg, cseg(j, :) = farbe(Bseg(j)/max(Z.Bhat(k), eps), S); end
patch(ax, 'XData', x, 'YData', y, 'FaceVertexCData', cseg, 'FaceColor', 'flat', 'EdgeColor', 'none');

% Rotor
ring(ax, 0, 1.0, [0.92 0.92 0.95]);
ring(ax, 0, 0.16, [0.4 0.4 0.4]);

% Stäbe
if isempty(opt.i_max), opt.i_max = max(abs(Z.i_folie(k, :))); end
schleife = [par.k1, par.k2];
if opt.alle, staebe = 1:par.N2; else, staebe = schleife; end
for j = staebe
    c = pol(0.86, bild(Z.alpha(k, j)));
    w = max(-1, min(1, Z.i_folie(k, j)/max(opt.i_max, eps)));
    if w >= 0, col = [1, 1 - w, 1 - w]; else, col = [1 + w, 1 + w, 1]; end
    if any(j == schleife), rand = 2.5; else, rand = 0.5; end
    kreis(ax, c, 0.055, col, [0.2 0.2 0.2], rand);
    if abs(w) > 0.05
        if w > 0                                              % Punkt: Strom aus der Zeichenebene
            kreis(ax, c, 0.018, 'k', 'k');
        else                                                  % Kreuz: Strom in die Zeichenebene
            d = 0.035;
            plot(ax, c(1) + [-d d], c(2) + [-d d], 'k-', c(1) + [-d d], c(2) + [d -d], 'k-', 'LineWidth', 2);
        end
    end
end
c1 = pol(0.86, bild(Z.alpha(k, par.k1)));  c2 = pol(0.86, bild(Z.alpha(k, par.k2)));
plot(ax, [c1(1) c2(1)], [c1(2) c2(2)], '--', 'Color', [0.3 0.3 0.3]);
text(ax, 0.62*c1(1)/0.86, 0.62*c1(2)/0.86, 'Stab 1', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(ax, 0.62*c2(1)/0.86, 0.62*c2(2)/0.86, 'Stab 2', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% Kraftpfeile (tangential, positiv in Feldrichtung = mathematisch positiv)
if opt.kraft
    if isempty(opt.F_max), opt.F_max = max(abs(Z.F(k, schleife))); end
    for j = schleife
        a = bild(Z.alpha(k, j));
        c = pol(0.86, a);
        tang = sg*[-sin(a), cos(a)];                          % Einheitsvektor in Feldrichtung im Bild
        L = 0.45*Z.F(k, j)/max(opt.F_max, eps);
        pfeil(ax, c, c + L*tang, S.farbe.Kraft, 2.5);
    end
end

% Feldzeiger mit Zerlegung und Änderungsvektor (nur zweipolig sinnvoll, wie Folien)
if par.p == 1 && (opt.zerlegung || opt.aenderung)
    aF = bild(Z.phi_el(k));                                  % Feldzeiger
    beta = bild(Z.alpha(k, par.k1) - pi/2);                  % Normale der Leiterschleife
    nvec = [cos(beta), sin(beta)];
    if opt.zerlegung
        spitze = 0.75*[cos(aF), sin(aF)];
        senk = 0.75*Z.B_perp(k)/max(Z.Bhat(k), eps)*nvec;
        pfeil(ax, -spitze, spitze, S.farbe.Feld, 3);
        pfeil(ax, -senk, senk, S.farbe.B, 3);
        plot(ax, [senk(1) spitze(1)], [senk(2) spitze(2)], '--', 'Color', S.farbe.Feld, 'LineWidth', 2);
    end
    if opt.aenderung
        if isempty(opt.dB_max), opt.dB_max = max(abs(Z.dB_perp)); end
        d = 0.5*Z.dB_perp(k)/max(opt.dB_max, eps)*nvec;
        start = 0.1*[-nvec(2), nvec(1)];
        pfeil(ax, start, start + d, [0.55 0 0], 2);
    end
end

title(ax, sprintf('t = %.4f s   θ_2 = %.0f°   M_S = %.2f N·m', Z.t(k), rad2deg(Z.theta2(k)), Z.M_S(k)), ...
      'FontWeight', 'normal', 'Color', 'k');
set(findobj(ax, 'Type', 'text'), 'Color', 'k');               % unabhängig vom MATLAB-Farbschema
hold(ax, 'off');
end

%% ========================= Hilfsfunktionen =========================
function ring(ax, ri, ra, col)
a = linspace(0, 2*pi, 181);
if ri == 0
    patch(ax, ra*cos(a), ra*sin(a), col, 'EdgeColor', [0.5 0.5 0.5]);
else
    patch(ax, [ra*cos(a) ri*cos(fliplr(a))], [ra*sin(a) ri*sin(fliplr(a))], col, 'EdgeColor', 'none');
    plot(ax, ra*cos(a), ra*sin(a), '-', ri*cos(a), ri*sin(a), '-', 'Color', [0.5 0.5 0.5]);
end
end

function kreis(ax, c, r, col, rand, breite)
if nargin < 6, breite = 0.5; end
a = linspace(0, 2*pi, 37);
patch(ax, c(1) + r*cos(a), c(2) + r*sin(a), col, 'EdgeColor', rand, 'LineWidth', breite);
end

function pfeil(ax, p0, p1, col, breite)
d = p1 - p0;  L = norm(d);
if L < 1e-3, return; end
e = d/L;  n = [-e(2), e(1)];  s = min(0.08, 0.4*L);
plot(ax, [p0(1) p1(1) - 0.8*s*e(1)], [p0(2) p1(2) - 0.8*s*e(2)], '-', 'Color', col, 'LineWidth', breite);
patch(ax, p1(1) + [0, -s*e(1) + 0.5*s*n(1), -s*e(1) - 0.5*s*n(1)], ...
          p1(2) + [0, -s*e(2) + 0.5*s*n(2), -s*e(2) - 0.5*s*n(2)], col, 'EdgeColor', 'none');
end

function c = farbe(w, S)
% −1 … 1 -> blau … weiß … rot
w = max(-1, min(1, w));
if w >= 0, c = (1 - w)*[1 1 1] + w*S.farbe.B; else, c = (1 + w)*[1 1 1] - w*[0.2 0.35 0.85]; end
end
