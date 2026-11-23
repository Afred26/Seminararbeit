function dateien = baue_beispiele(opt)
%BAUE_BEISPIELE Erzeugt die Beispielmodelle aus Bausteinen der asm_bausteine_lib.
%   dateien = baue_beispiele()                       speichert nach beispiele/
%   dateien = baue_beispiele('Ordner', ordner)       anderer Zielordner (z. B. für Tests)
%
%   bsp_hochlauf_laststoss   Laboraufbau: Netz 3~ -> Leistungsmesser -> Strommessung -> ASM Standard
%                            -> Drehmomentmesswelle -> Schwungmasse -> Lüfterlast + Laststoß
%                            (+ Last konstant mit M_L0 = 0, Grundlage der Bedienoberfläche ASMApp);
%                            Spannungsmessung parallel, Drehzahlmesser, Schreiber für n, M, I, P.
%   bsp_vergleich_modelle    dieselbe Mechanik an drei Motormodellen: ASM Standard (Raumzeiger),
%                            ASM Referenz (Simscape Electrical) und ASM Kloss (quasistationär).
%   bsp_folien16_30_rotorstab  Folien 16-30: Ideales Drehfeld (zweipolig, Rotor steht, φ2 = 90°)
%                            -> Rotorstab-Sonde und Drehfeld-Anzeige (Leiterschleife aus zwei Stäben).
%   bsp_rotorstab_motor      Rotorstab-Sonde, Drehfeld-Anzeige, Spulenfelder und Kennlinienschreiber
%                            am Motor ASM Standard (Hochlauf mit Laststoß).
%   Alle Werte sind Beispielwerte (parameter/asm_standard.m).

arguments
    opt.Ordner {mustBeTextScalar} = fileparts(mfilename('fullpath'))
end

load_system('asm_bausteine_lib');
if ~exist(opt.Ordner, 'dir'), mkdir(opt.Ordner); end
dateien = {hochlauf(opt.Ordner), vergleich(opt.Ordner), folien(opt.Ordner), motor_didaktik(opt.Ordner)};
end

%% ===================== Beispiel 3: Folien 16-30 =====================
function datei = folien(ordner)
m = 'bsp_folien16_30_rotorstab';
neu(m);
set_param(m, 'StopTime', '0.04', 'MaxStep', '1e-4');               % zwei Feldumdrehungen
L = 'asm_bausteine_lib/';
geo = {'p', '1', 'N2', '2', 'N1xi1', '144', 'l', '0.15', 'r', '0.06'};
add_block([L 'Didaktik/Ideales Drehfeld'], [m '/Drehfeld'], 'Position', [60 80 200 280], geo{:}, ...
    'Bhat', '0.8', 'f1', '50', 's', '1', 'modus_phi2', 'fest', 'phi2_fix', '90');
add_block([L 'Didaktik/Rotorstab-Sonde'], [m '/Sonde'], 'Position', [360 60 500 360], geo{:}, ...
    'k1', '1', 'k2', '2', 'lage1', '-90');
add_block([L 'Didaktik/Drehfeld-Anzeige'], [m '/Anzeige'], 'Position', [360 420 500 520], geo{:}, ...
    'lage1', '-90', 'zeitlupe', '0.01');
for k = 1:3
    add_line(m, sprintf('Drehfeld/%d', k), sprintf('Sonde/%d', k), 'autorouting', 'on');
    add_line(m, sprintf('Drehfeld/%d', k), sprintf('Anzeige/%d', k), 'autorouting', 'on');
end
schreiber(m, 'S_B_i', 'B⊥ und Strom Stab 1', {'Sonde/6', 'Sonde/2'}, [640 100 700 140]);
schreiber(m, 'S_F', 'Kraft Stab 1 und 2', {'Sonde/3'}, [640 200 700 240]);
schreiber(m, 'S_M', 'Moment der Schleife', {'Sonde/5'}, [640 300 700 340]);
notiz(m, ['Folien 16-30 (DS-Asynchron-Motor): zweipoliges Drehfeld, Rotor steht (s = 1), Leiterschleife ' ...
          'aus zwei Stäben oben/unten, Strom ohne Rotorstreuung (φ2 = 90°). Nach der Simulation: ' ...
          'Doppelklick auf "Anzeige" -> "Animation zeigen".'], [60 560]);
datei = speichern(m, ordner);
end

%% ===================== Beispiel 4: Didaktik am Motor =====================
function datei = motor_didaktik(ordner)
m = 'bsp_rotorstab_motor';
neu(m);
L = 'asm_bausteine_lib/';
S = asm_standard();

add_block([L 'Quellen/Netz 3~'], [m '/Netz'], 'Position', [40 100 120 220]);
add_block([L 'Quellen/Sternpunkt (Erde)'], [m '/Erde'], 'Position', [60 280 100 310]);
add_block('nesl_utility/Solver Configuration', [m '/Solver'], 'Position', [140 280 200 310]);
add_block([L 'Messgeräte/Strommessung 3~'], [m '/Strommessung'], 'Position', [200 100 290 220]);
add_block([L 'Maschine/ASM Standard'], [m '/Motor'], 'Position', [360 100 480 220]);
add_block([L 'Messgeräte/Drehmomentmesswelle'], [m '/Messwelle'], 'Position', [560 120 640 180]);
add_block([L 'Mechanik/Schwungmasse'], [m '/Last_J'], 'Position', [720 60 780 100], 'J', '0.01');
add_block([L 'Mechanik/Last Lüfter'], [m '/Luefter'], 'Position', [720 140 800 190], ...
    'M_B', num2str(S.M_N), 'n_B', num2str(S.n_N));
add_block([L 'Mechanik/Laststoß'], [m '/Laststoss'], 'Position', [720 220 800 270], ...
    't_stoss', '1', 'dM_L', num2str(0.3*S.M_N));
add_block([L 'Mechanik/Mechanischer Bezug'], [m '/Bezug'], 'Position', [860 320 900 350]);
pv(m, 'Netz', 'R', 4, 'Erde', 'L', 1);
pv(m, 'Solver', 'R', 1, 'Erde', 'L', 1);
for k = 1:3
    pv(m, 'Netz', 'R', k, 'Strommessung', 'L', k);
    pv(m, 'Strommessung', 'R', k, 'Motor', 'L', k);
end
pv(m, 'Motor', 'R', 1, 'Messwelle', 'L', 1);
pv(m, 'Motor', 'R', 2, 'Bezug', 'L', 1);
for b = {'Last_J', 'Luefter', 'Laststoss'}, pv(m, 'Messwelle', 'R', 1, b{1}, 'L', 1); end
for b = {'Luefter', 'Laststoss'}, pv(m, b{1}, 'R', 1, 'Bezug', 'L', 1); end

% Messbus des Motors -> Sonde, Anzeige, Kennlinienschreiber
add_block('simulink/Signal Routing/Bus Selector', [m '/Mess'], 'Position', [560 400 565 520], ...
    'OutputSignals', 'psi_h,i2b,th_mech,n,M');
add_line(m, 'Motor/1', 'Mess/1', 'autorouting', 'on');
geo = {'p', num2str(S.p), 'N2', num2str(S.N2), 'l', num2str(S.l), 'r', num2str(S.r), 'N1xi1', '144'};
add_block([L 'Didaktik/Rotorstab-Sonde'], [m '/Sonde'], 'Position', [680 400 820 700], geo{:}, 'lage1', '-90');
add_block([L 'Didaktik/Drehfeld-Anzeige'], [m '/Anzeige'], 'Position', [680 760 820 860], geo{:}, ...
    'lage1', '-90', 'ansicht', 'statorfest');
add_block([L 'Didaktik/Kennlinienschreiber'], [m '/Kennlinie'], 'Position', [680 900 820 1000], ...
    'MK', num2str(2.7*S.M_N), 'sK', '0.2', 'ns', num2str(S.ns), 'kurve_esb', 'on');
add_block([L 'Didaktik/Spulenfelder'], [m '/Spulenfelder'], 'Position', [360 300 480 400], ...
    'Lh', num2str(S.Lh), 'N1xi1', '144', 'p', num2str(S.p), 'l', num2str(S.l), 'r', num2str(S.r));
for k = 1:3
    add_line(m, sprintf('Mess/%d', k), sprintf('Sonde/%d', k), 'autorouting', 'on');
    add_line(m, sprintf('Mess/%d', k), sprintf('Anzeige/%d', k), 'autorouting', 'on');
end
add_line(m, 'Mess/4', 'Kennlinie/1', 'autorouting', 'on');
add_line(m, 'Mess/5', 'Kennlinie/2', 'autorouting', 'on');
add_line(m, 'Messwelle/1', 'Kennlinie/3', 'autorouting', 'on');   % Wellenmoment ≈ Lastmoment (stationär)
add_line(m, 'Strommessung/1', 'Spulenfelder/1', 'autorouting', 'on');
schreiber(m, 'S_Stab', 'Strom Stab 1 und 2', {'Sonde/2'}, [900 400 960 440]);
schreiber(m, 'S_M', 'Summe der Stabmomente und Luftspaltmoment', {'Sonde/10', 'Mess/5'}, [900 500 960 540]);
schreiber(m, 'S_B', 'Spulenfelder B_U, B_V, B_W', {'Spulenfelder/1'}, [560 300 620 340]);
notiz(m, ['Didaktik am Motor: Rotorstab-Sonde (Summe der Stabmomente = Luftspaltmoment), Drehfeld-Anzeige ' ...
          '(Animation nach der Simulation), Spulenfelder, Kennlinienschreiber (Knopf "Kennlinie zeichnen").'], ...
     [40 1040]);
datei = speichern(m, ordner);
end

%% ===================== Beispiel 1: Hochlauf mit Laststoß =====================
function datei = hochlauf(ordner)
m = 'bsp_hochlauf_laststoss';
neu(m);
L = 'asm_bausteine_lib/';
S = asm_standard();

add_block([L 'Quellen/Netz 3~'], [m '/Netz'], 'Position', [40 100 120 220]);
add_block([L 'Quellen/Sternpunkt (Erde)'], [m '/Erde'], 'Position', [60 280 100 310]);
add_block('nesl_utility/Solver Configuration', [m '/Solver'], 'Position', [140 280 200 310]);
add_block([L 'Messgeräte/Leistungsmesser 3~'], [m '/Leistungsmesser'], 'Position', [190 100 280 220]);
add_block([L 'Messgeräte/Strommessung 3~'], [m '/Strommessung'], 'Position', [340 100 430 220]);
add_block([L 'Messgeräte/Spannungsmessung 3~'], [m '/Spannungsmessung'], 'Position', [340 300 430 400]);
add_block([L 'Maschine/ASM Standard'], [m '/Motor'], 'Position', [500 100 620 220]);
add_block([L 'Messgeräte/Drehmomentmesswelle'], [m '/Messwelle'], 'Position', [700 120 780 180]);
add_block([L 'Mechanik/Schwungmasse'], [m '/Last_J'], 'Position', [860 60 920 100], 'J', '0.01');
add_block([L 'Mechanik/Last Lüfter'], [m '/Luefter'], 'Position', [860 140 940 190], ...
    'M_B', num2str(S.M_N), 'n_B', num2str(S.n_N));
add_block([L 'Mechanik/Laststoß'], [m '/Laststoss'], 'Position', [860 220 940 270], ...
    't_stoss', '1', 'dM_L', num2str(0.3*S.M_N));
% konstante Grundlast, hier 0 (Bedienoberfläche ASMApp: Lasttyp "konstant" setzt M_L0)
add_block([L 'Mechanik/Last konstant'], [m '/Last_konstant'], 'Position', [980 140 1060 190], 'M_L0', '0');
add_block([L 'Messgeräte/Drehzahlmesser'], [m '/Drehzahlmesser'], 'Position', [860 300 940 400]);
add_block([L 'Mechanik/Mechanischer Bezug'], [m '/Bezug'], 'Position', [1000 440 1040 470]);

pv(m, 'Netz', 'R', 4, 'Erde', 'L', 1);
pv(m, 'Solver', 'R', 1, 'Erde', 'L', 1);
for k = 1:3
    pv(m, 'Netz', 'R', k, 'Leistungsmesser', 'L', k);
    pv(m, 'Leistungsmesser', 'R', k, 'Strommessung', 'L', k);
    pv(m, 'Strommessung', 'R', k, 'Motor', 'L', k);
    pv(m, 'Netz', 'R', k, 'Spannungsmessung', 'L', k);
end
pv(m, 'Netz', 'R', 4, 'Spannungsmessung', 'L', 4);
pv(m, 'Motor', 'R', 1, 'Messwelle', 'L', 1);
pv(m, 'Motor', 'R', 2, 'Bezug', 'L', 1);
for b = {'Last_J', 'Luefter', 'Laststoss', 'Last_konstant', 'Drehzahlmesser'}
    pv(m, 'Messwelle', 'R', 1, b{1}, 'L', 1);
end
for b = {'Luefter', 'Laststoss', 'Last_konstant', 'Drehzahlmesser'}
    pv(m, b{1}, 'R', 1, 'Bezug', 'L', 1);
end

schreiber(m, 'S_n', 'Drehzahl', {'Drehzahlmesser/1'}, [1100 300 1160 340]);
schreiber(m, 'S_M', 'Wellenmoment', {'Messwelle/1'}, [1100 120 1160 160]);
schreiber(m, 'S_I', 'Strom (Effektivwert)', {'Strommessung/2'}, [520 300 580 340]);
schreiber(m, 'S_P', 'Wirk- und Blindleistung', {'Leistungsmesser/1', 'Leistungsmesser/2'}, ...
          [520 20 580 60]);
notiz(m, ['Hochlauf am starren Netz 400 V / 50 Hz mit Lüfterlast, Laststoß 0,3·M_N bei t = 1 s. ' ...
          'Alle Werte sind Beispielwerte (parameter/asm_standard.m).'], [40 480]);
datei = speichern(m, ordner);
end

%% ===================== Beispiel 2: Vergleich der Motormodelle =====================
function datei = vergleich(ordner)
m = 'bsp_vergleich_modelle';
neu(m);
L = 'asm_bausteine_lib/';
S = asm_standard();

add_block([L 'Quellen/Netz 3~'], [m '/Netz'], 'Position', [40 200 120 320]);
add_block([L 'Quellen/Sternpunkt (Erde)'], [m '/Erde'], 'Position', [60 380 100 410]);
add_block('nesl_utility/Solver Configuration', [m '/Solver'], 'Position', [140 380 200 410]);
pv(m, 'Netz', 'R', 4, 'Erde', 'L', 1);
pv(m, 'Solver', 'R', 1, 'Erde', 'L', 1);

motoren = {'Standard', [L 'Maschine/ASM Standard'], 40;
           'Referenz', [L 'Referenz/ASM Referenz (Simscape Electrical)'], 280;
           'Kloss',    [L 'Referenz/ASM Kloss (quasistationär)'], 520};
for i = 1:3
    nm = motoren{i, 1};  y = motoren{i, 3};
    add_block(motoren{i, 2}, [m '/Motor_' nm], 'Position', [300 y 420 y + 120]);
    add_block([L 'Messgeräte/Drehmomentmesswelle'], [m '/Messwelle_' nm], 'Position', [500 y + 20 580 y + 80]);
    add_block([L 'Mechanik/Schwungmasse'], [m '/J_' nm], 'Position', [660 y 720 y + 40], 'J', '0.01');
    add_block([L 'Mechanik/Last Lüfter'], [m '/Luefter_' nm], 'Position', [660 y + 50 740 y + 90], ...
        'M_B', num2str(S.M_N), 'n_B', num2str(S.n_N));
    add_block([L 'Mechanik/Laststoß'], [m '/Laststoss_' nm], 'Position', [660 y + 100 740 y + 140], ...
        't_stoss', '1', 'dM_L', num2str(0.3*S.M_N));
    add_block([L 'Messgeräte/Drehzahlmesser'], [m '/Drehzahl_' nm], 'Position', [800 y + 40 880 y + 140]);
    add_block([L 'Mechanik/Mechanischer Bezug'], [m '/Bezug_' nm], 'Position', [960 y + 160 1000 y + 190]);
    if strcmp(nm, 'Kloss')
        set_param([m '/Motor_' nm], 'MK', num2str(2.7*S.M_N), 'sK', '0.2', 'ns', num2str(S.ns));
        add_block([L 'Mechanik/Schwungmasse'], [m '/J_M_' nm], 'Position', [500 y + 100 560 y + 140], ...
            'J', num2str(S.J_M));                               % Kloss-Baustein hat keine eigene Trägheit
        add_block('nesl_utility/Solver Configuration', [m '/Solver_' nm], 'Position', [800 y + 180 860 y + 210]);
        pv(m, ['J_M_' nm], 'L', 1, ['Messwelle_' nm], 'L', 1);
        pv(m, ['Solver_' nm], 'R', 1, ['Bezug_' nm], 'L', 1);
    else
        for k = 1:3, pv(m, 'Netz', 'R', k, ['Motor_' nm], 'L', k); end
    end
    pv(m, ['Motor_' nm], 'R', 1, ['Messwelle_' nm], 'L', 1);
    pv(m, ['Motor_' nm], 'R', 2, ['Bezug_' nm], 'L', 1);
    for b = {'J_', 'Luefter_', 'Laststoss_', 'Drehzahl_'}
        pv(m, ['Messwelle_' nm], 'R', 1, [b{1} nm], 'L', 1);
    end
    for b = {'Luefter_', 'Laststoss_', 'Drehzahl_'}
        pv(m, [b{1} nm], 'R', 1, ['Bezug_' nm], 'L', 1);
    end
end
schreiber(m, 'S_n', 'Drehzahl: Standard / Referenz / Kloss', ...
          {'Drehzahl_Standard/1', 'Drehzahl_Referenz/1', 'Drehzahl_Kloss/1'}, [1100 200 1160 240]);
schreiber(m, 'S_M', 'Wellenmoment: Standard / Referenz / Kloss', ...
          {'Messwelle_Standard/1', 'Messwelle_Referenz/1', 'Messwelle_Kloss/1'}, [1100 400 1160 440]);
notiz(m, ['Vergleich der Motormodelle bei gleicher Mechanik: Raumzeigermodell (ASM Standard), ' ...
          'Simscape-Electrical-Referenz und Kloss-Formel (quasistationär, ohne elektrische Dynamik).'], [40 700]);
datei = speichern(m, ordner);
end

%% ========================= Hilfsfunktionen =========================
function neu(m)
if bdIsLoaded(m), close_system(m, 0); end
w = warning('off', 'Simulink:Engine:MdlFileShadowing');   % vorhandene .slx im Pfad wird ersetzt
new_system(m);
warning(w);
set_param(m, 'Solver', 'ode23t', 'StopTime', '2', 'RelTol', '1e-5', 'MaxStep', '1e-4', ...
    'ReturnWorkspaceOutputs', 'on');
end

function datei = speichern(m, ordner)
datei = fullfile(ordner, [m '.slx']);
save_system(m, datei);
close_system(m, 0);
end

function schreiber(m, name, titel, quellen, pos)
% Schreiber-Baustein mit Titel; mehrere Signale über einen Mux
add_block('asm_bausteine_lib/Messgeräte/Schreiber', [m '/' name], 'Position', pos, ...
    'titel', titel);
if isscalar(quellen)
    add_line(m, quellen{1}, [name '/1'], 'autorouting', 'on');
else
    mux = [name '_mux'];
    add_block('simulink/Signal Routing/Mux', [m '/' mux], 'Inputs', num2str(numel(quellen)), ...
        'Position', [pos(1) - 40, pos(2), pos(1) - 35, pos(4)]);
    for k = 1:numel(quellen)
        add_line(m, quellen{k}, sprintf('%s/%d', mux, k), 'autorouting', 'on');
    end
    add_line(m, [mux '/1'], [name '/1']);
end
end

function notiz(m, text, xy)
a = Simulink.Annotation([m '/Beschreibung']);
a.Text = text;
a.Position = [xy, xy + [700 40]];
end

function pv(m, a, sa, na, b, sb, nb)
pa = get_param([m '/' a], 'PortHandles');  pb = get_param([m '/' b], 'PortHandles');
if sa == 'L', ha = pa.LConn(na); else, ha = pa.RConn(na); end
if sb == 'L', hb = pb.LConn(nb); else, hb = pb.RConn(nb); end
add_line(m, ha, hb, 'autorouting', 'on');
end
