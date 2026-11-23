function dateien = folienbilder(opt)
%FOLIENBILDER Erzeugt alle Folienbilder der Didaktik (Folien 16-30, Drehfeld, Kennlinie) in export/.
%   dateien = folienbilder()
%   dateien = folienbilder('Ordner', ordner)
%
%   Simuliert bsp_folien16_30_rotorstab und bsp_rotorstab_motor (aus beispiele/) und exportiert:
%     folie18 ... folie30         Rotorquerschnitt bei θ2 = 0°, 30°, ..., 360° ([D-ASM] Folien 18-30)
%     folie16_verlaeufe           B⊥(t), Strom in Stab 1/2, Kraft, Schleifenmoment ([D-ASM] Folie 16)
%     drehfeld_spulen_0/30/90     Spulenfelder und Drehfeld über γ ([D-DF] Folien 60/61, Hagl Bild 6.13)
%     motor_querschnitt           Rotorquerschnitt des 4-poligen Motors im Bemessungsbetrieb
%     motor_kennlinie             M(n) mit Hochlauf, Kloss und ESB ([D-ASM] Folien 47-56)
%   Alle Werte sind Beispielwerte (parameter/asm_standard.m). Laufzeit etwa 1 Minute.

arguments
    opt.Ordner {mustBeTextScalar} = asmexport.zielordner()
end
hier = fileparts(mfilename('fullpath'));
load_system('asm_bausteine_lib');
dateien = {};
S = asmexport.stil();

%% Folien 16-30: Ideales Drehfeld, Rotor steht, φ2 = 90°
m = 'bsp_folien16_30_rotorstab';
load_system(fullfile(hier, [m '.slx']));
out = sim(m, 'TimeOut', 120);
close_system(m, 0);
D = asmbib.drehfeld_daten(out.get('drehfeld_anzeige'));
par = struct('p', 1, 'N2', 2, 'l', 0.15, 'r', 0.06, 'N1xi1', 144, 'k1', 1, 'k2', 2, 'lage1', -pi/2);
dateien = [dateien, asmexport.querschnitt_serie(D, par, 'Ordner', opt.Ordner)];

% Folie 16: Zeitverläufe (Flussdichte senkrecht zur Schleife rot, Strom blau)
t = linspace(0, 0.02, 801)';
Z = asmbib.querschnitt_zustand(D, par, t);
f = figure('Visible', 'off');
tl = tiledlayout(f, 2, 1);
ax = nexttile(tl);
yyaxis(ax, 'left');  plot(ax, t*1e3, -Z.B_perp, '-', 'Color', S.farbe.B, 'DisplayName', 'B_⊥ (Beitrag zur Induktion)');
ylabel(ax, 'B_⊥ in T');  ax.YColor = S.farbe.B;
yyaxis(ax, 'right'); plot(ax, t*1e3, Z.i_folie(:, 1), '-', 'Color', S.farbe.i, 'DisplayName', 'Strom Stab 1');
ylabel(ax, 'i in A');  ax.YColor = S.farbe.i;
grid(ax, 'on');  legend(ax, 'Location', 'southoutside', 'Orientation', 'horizontal');
title(ax, 'Folie 16: Flussdichte senkrecht zur Schleife und Stabstrom (aus der Ebene positiv)');
ax = nexttile(tl);
plot(ax, t*1e3, Z.F(:, 1), '-', 'Color', S.farbe.Stab1, 'DisplayName', 'Kraft Stab 1');  hold(ax, 'on');
plot(ax, t*1e3, Z.F(:, 2), '--', 'Color', S.farbe.Stab2, 'DisplayName', 'Kraft Stab 2');
yyaxis(ax, 'right');  plot(ax, t*1e3, Z.M_S, ':', 'Color', [0.3 0.3 0.3], 'DisplayName', 'M_S Schleife');
ylabel(ax, 'M_S in N·m');  ax.YColor = [0.3 0.3 0.3];
yyaxis(ax, 'left');  ylabel(ax, 'F in N');  grid(ax, 'on');  xlabel(ax, 't in ms');
legend(ax, 'Location', 'southoutside', 'Orientation', 'horizontal');
dateien = [dateien, asmexport.folienbild(f, 'folie16_verlaeufe', 'Ordner', opt.Ordner, 'Farben', false)];
close(f);

%% Drehfeld: Spulenfelder (Hagl Bild 6.13)
for w = [0 30 90]
    f = asmbib.spulenfelder_bild(w);  set(f, 'Visible', 'off');
    dateien = [dateien, asmexport.folienbild(f, sprintf('drehfeld_spulen_%d', w), 'Ordner', opt.Ordner)]; %#ok<AGROW>
    close(f);
end

%% Motor: Querschnitt im Bemessungsbetrieb und Kennlinie
m = 'bsp_rotorstab_motor';
load_system(fullfile(hier, [m '.slx']));
out = sim(m, 'TimeOut', 300);
close_system(m, 0);
P = asm_standard();
Dm = asmbib.drehfeld_daten(out.get('drehfeld_anzeige'));
parm = struct('p', P.p, 'N2', P.N2, 'l', P.l, 'r', P.r, 'N1xi1', 144, 'k1', 1, 'k2', 1 + P.N2/(2*P.p), ...
              'lage1', -pi/2);
Zm = asmbib.querschnitt_zustand(Dm, parm, 0.95);
f = figure('Visible', 'off');  ax = axes(f);
asmbib.querschnitt(ax, Zm, 1, parm, struct('ansicht', 'statorfest'));
title(ax, sprintf('Motor (4-polig, 28 Stäbe) im Bemessungsbetrieb, t = 0,95 s, M_S = %.2f N·m', Zm.M_S), ...
      'FontWeight', 'normal', 'Color', 'k');
dateien = [dateien, asmexport.folienbild(f, 'motor_querschnitt', 'Ordner', opt.Ordner)];
close(f);
f = asmbib.kennlinie_bild(out.get('kennlinie'), 'ESB', true);  set(f, 'Visible', 'off');
dateien = [dateien, asmexport.folienbild(f, 'motor_kennlinie', 'Ordner', opt.Ordner)];
close(f);
fprintf('folienbilder: %d Dateien in %s\n', numel(dateien), opt.Ordner);
end
