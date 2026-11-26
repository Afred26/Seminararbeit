function files = build_examples(opt)
%BUILD_EXAMPLES Creates the example models from blocks of asm_blocks_lib.
%   files = build_examples()                       saves to examples/
%   files = build_examples('Folder', folder)       other target folder (e.g. for tests)
%
%   ex_startup_load_step       laboratory set-up: Netz 3~ -> power meter -> current sensor ->
%                              ASM Standard -> torque sensor -> inertia -> fan load + load step
%                              (+ constant load with M_L0 = 0); voltage sensor in parallel,
%                              speed sensor, recorders for n, M, I, P. Basis of run_asm('lab')
%                              and of the GUI ASMApp.
%   ex_kloss_startup           part B: run-up and load step with the quasi-static Kloss model,
%                              same mechanics (J_M as separate inertia). Basis of run_asm('kloss').
%   ex_conductor_loop          part A: conductor loop of two rotor bars at fixed slip (constant
%                              input). Basis of run_asm('loop').
%   ex_model_comparison        the same mechanics at three motor models: ASM Standard (space
%                              vector), ASM Referenz (Simscape Electrical) and ASM Kloss.
%   ex_slides16_30_rotor_bars  slides 16-30: ideal rotating field (two poles, rotor at rest,
%                              phi2 = 90 deg) -> rotor bar probe and field display. Basis of
%                              run_asm('slides').
%   ex_rotor_bars_motor        rotor bar probe, field display, coil fields and torque-speed
%                              recorder at the motor ASM Standard (run-up with load step).
%   No model has callbacks (PreLoadFcn, InitFcn, ...); run_asm passes all parameters via
%   Simulink.SimulationInput. Block names and annotations are German (shown in the diagram).
%   All values are example values (parameter/asm_standard.m).

arguments
    opt.Folder {mustBeTextScalar} = fileparts(mfilename('fullpath'))
end

load_system('asm_blocks_lib');
if ~exist(opt.Folder, 'dir'), mkdir(opt.Folder); end
files = {startup_load_step(opt.Folder), kloss_startup(opt.Folder), conductor_loop(opt.Folder), ...
         model_comparison(opt.Folder), slides(opt.Folder), motor_didactics(opt.Folder)};
end

%% ===================== Example: slides 16-30 =====================
function file = slides(folder)
m = 'ex_slides16_30_rotor_bars';
new_model(m);
set_param(m, 'StopTime', '0.04', 'MaxStep', '1e-4');               % two field revolutions
L = 'asm_blocks_lib/';
geo = {'p', '1', 'N2', '2', 'N1xi1', '144', 'l', '0.15', 'r', '0.06'};
add_block([L 'Didaktik/Ideales Drehfeld'], [m '/Drehfeld'], 'Position', [60 80 200 280], geo{:}, ...
    'Bhat', '0.8', 'f1', '50', 's', '1', 'phi2_mode', 'fest', 'phi2_fix', '90');
add_block([L 'Didaktik/Rotorstab-Sonde'], [m '/Sonde'], 'Position', [360 60 500 360], geo{:}, ...
    'k1', '1', 'k2', '2', 'bar1_angle', '-90');
add_block([L 'Didaktik/Drehfeld-Anzeige'], [m '/Anzeige'], 'Position', [360 420 500 520], geo{:}, ...
    'bar1_angle', '-90', 'slow_motion', '0.01');
for k = 1:3
    add_line(m, sprintf('Drehfeld/%d', k), sprintf('Sonde/%d', k), 'autorouting', 'on');
    add_line(m, sprintf('Drehfeld/%d', k), sprintf('Anzeige/%d', k), 'autorouting', 'on');
end
recorder(m, 'S_B_i', 'B⊥ und Strom Stab 1', {'Sonde/6', 'Sonde/2'}, [640 100 700 140]);
recorder(m, 'S_F', 'Kraft Stab 1 und 2', {'Sonde/3'}, [640 200 700 240]);
recorder(m, 'S_M', 'Moment der Schleife', {'Sonde/5'}, [640 300 700 340]);
note(m, ['Folien 16-30 (DS-Asynchron-Motor): zweipoliges Drehfeld, Rotor steht (s = 1), Leiterschleife ' ...
         'aus zwei Stäben oben/unten, Strom ohne Rotorstreuung (φ2 = 90°). Nach der Simulation: ' ...
         'Doppelklick auf "Anzeige" -> "Animation zeigen".'], [60 560]);
file = save_model(m, folder);
end

%% ===================== Example: didactics at the motor =====================
function file = motor_didactics(folder)
m = 'ex_rotor_bars_motor';
new_model(m);
L = 'asm_blocks_lib/';
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
    't_step', '1', 'dM_L', num2str(0.3*S.M_N));
add_block([L 'Mechanik/Mechanischer Bezug'], [m '/Bezug'], 'Position', [860 320 900 350]);
pc(m, 'Netz', 'R', 4, 'Erde', 'L', 1);
pc(m, 'Solver', 'R', 1, 'Erde', 'L', 1);
for k = 1:3
    pc(m, 'Netz', 'R', k, 'Strommessung', 'L', k);
    pc(m, 'Strommessung', 'R', k, 'Motor', 'L', k);
end
pc(m, 'Motor', 'R', 1, 'Messwelle', 'L', 1);
pc(m, 'Motor', 'R', 2, 'Bezug', 'L', 1);
for b = {'Last_J', 'Luefter', 'Laststoss'}, pc(m, 'Messwelle', 'R', 1, b{1}, 'L', 1); end
for b = {'Luefter', 'Laststoss'}, pc(m, b{1}, 'R', 1, 'Bezug', 'L', 1); end

% measurement bus of the motor -> probe, display, torque-speed recorder
add_block('simulink/Signal Routing/Bus Selector', [m '/Mess'], 'Position', [560 400 565 520], ...
    'OutputSignals', 'psi_h,i2b,th_mech,n,M');
add_line(m, 'Motor/1', 'Mess/1', 'autorouting', 'on');
geo = {'p', num2str(S.p), 'N2', num2str(S.N2), 'l', num2str(S.l), 'r', num2str(S.r), 'N1xi1', '144'};
add_block([L 'Didaktik/Rotorstab-Sonde'], [m '/Sonde'], 'Position', [680 400 820 700], geo{:}, 'bar1_angle', '-90');
add_block([L 'Didaktik/Drehfeld-Anzeige'], [m '/Anzeige'], 'Position', [680 760 820 860], geo{:}, ...
    'bar1_angle', '-90', 'view_frame', 'statorfest');
add_block([L 'Didaktik/Kennlinienschreiber'], [m '/Kennlinie'], 'Position', [680 900 820 1000], ...
    'MK', num2str(S.MK), 'sK', num2str(S.sK), 'ns', num2str(S.ns), 'show_ec', 'on');
add_block([L 'Didaktik/Spulenfelder'], [m '/Spulenfelder'], 'Position', [360 300 480 400], ...
    'Lh', num2str(S.Lh), 'N1xi1', '144', 'p', num2str(S.p), 'l', num2str(S.l), 'r', num2str(S.r));
for k = 1:3
    add_line(m, sprintf('Mess/%d', k), sprintf('Sonde/%d', k), 'autorouting', 'on');
    add_line(m, sprintf('Mess/%d', k), sprintf('Anzeige/%d', k), 'autorouting', 'on');
end
add_line(m, 'Mess/4', 'Kennlinie/1', 'autorouting', 'on');
add_line(m, 'Mess/5', 'Kennlinie/2', 'autorouting', 'on');
add_line(m, 'Messwelle/1', 'Kennlinie/3', 'autorouting', 'on');   % shaft torque ~ load torque (stationary)
add_line(m, 'Strommessung/1', 'Spulenfelder/1', 'autorouting', 'on');
recorder(m, 'S_Stab', 'Strom Stab 1 und 2', {'Sonde/2'}, [900 400 960 440]);
recorder(m, 'S_M', 'Summe der Stabmomente und Luftspaltmoment', {'Sonde/10', 'Mess/5'}, [900 500 960 540]);
recorder(m, 'S_B', 'Spulenfelder B_U, B_V, B_W', {'Spulenfelder/1'}, [560 300 620 340]);
note(m, ['Didaktik am Motor: Rotorstab-Sonde (Summe der Stabmomente = Luftspaltmoment), Drehfeld-Anzeige ' ...
         '(Animation nach der Simulation), Spulenfelder, Kennlinienschreiber (Knopf "Kennlinie zeichnen").'], ...
     [40 1040]);
file = save_model(m, folder);
end

%% ===================== Example: run-up with load step (dynamic model) =====================
function file = startup_load_step(folder)
m = 'ex_startup_load_step';
new_model(m);
L = 'asm_blocks_lib/';
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
    't_step', '1', 'dM_L', num2str(0.3*S.M_N));
% constant base load, here 0 (run_asm with load_type "constant" sets M_L0)
add_block([L 'Mechanik/Last konstant'], [m '/Last_konstant'], 'Position', [980 140 1060 190], 'M_L0', '0');
add_block([L 'Messgeräte/Drehzahlmesser'], [m '/Drehzahlmesser'], 'Position', [860 300 940 400]);
add_block([L 'Mechanik/Mechanischer Bezug'], [m '/Bezug'], 'Position', [1000 440 1040 470]);

pc(m, 'Netz', 'R', 4, 'Erde', 'L', 1);
pc(m, 'Solver', 'R', 1, 'Erde', 'L', 1);
for k = 1:3
    pc(m, 'Netz', 'R', k, 'Leistungsmesser', 'L', k);
    pc(m, 'Leistungsmesser', 'R', k, 'Strommessung', 'L', k);
    pc(m, 'Strommessung', 'R', k, 'Motor', 'L', k);
    pc(m, 'Netz', 'R', k, 'Spannungsmessung', 'L', k);
end
pc(m, 'Netz', 'R', 4, 'Spannungsmessung', 'L', 4);
pc(m, 'Motor', 'R', 1, 'Messwelle', 'L', 1);
pc(m, 'Motor', 'R', 2, 'Bezug', 'L', 1);
for b = {'Last_J', 'Luefter', 'Laststoss', 'Last_konstant', 'Drehzahlmesser'}
    pc(m, 'Messwelle', 'R', 1, b{1}, 'L', 1);
end
for b = {'Luefter', 'Laststoss', 'Last_konstant', 'Drehzahlmesser'}
    pc(m, b{1}, 'R', 1, 'Bezug', 'L', 1);
end

recorder(m, 'S_n', 'Drehzahl', {'Drehzahlmesser/1'}, [1100 300 1160 340]);
recorder(m, 'S_M', 'Wellenmoment', {'Messwelle/1'}, [1100 120 1160 160]);
recorder(m, 'S_I', 'Strom (Effektivwert)', {'Strommessung/2'}, [520 300 580 340]);
recorder(m, 'S_P', 'Wirk- und Blindleistung', {'Leistungsmesser/1', 'Leistungsmesser/2'}, ...
         [520 20 580 60]);
note(m, ['Hochlauf am starren Netz 400 V / 50 Hz mit Lüfterlast, Laststoß 0,3·M_N bei t = 1 s. ' ...
         'Alle Werte sind Beispielwerte (parameter/asm_standard.m). Ohne Oberfläche: run_asm(asm_params(''lab'')).'], [40 480]);
file = save_model(m, folder);
end

%% ===================== Example: part B, Kloss run-up =====================
function file = kloss_startup(folder)
m = 'ex_kloss_startup';
new_model(m);
L = 'asm_blocks_lib/';
S = asm_standard();

add_block([L 'Referenz/ASM Kloss (quasistationär)'], [m '/Motor'], 'Position', [300 100 420 220], ...
    'MK', num2str(S.MK), 'sK', num2str(S.sK), 'ns', num2str(S.ns));
add_block([L 'Mechanik/Schwungmasse'], [m '/J_M'], 'Position', [520 20 580 60], 'J', num2str(S.J_M));
add_block('nesl_utility/Solver Configuration', [m '/Solver'], 'Position', [300 320 360 350]);
add_block([L 'Messgeräte/Drehmomentmesswelle'], [m '/Messwelle'], 'Position', [500 120 580 180]);
add_block([L 'Mechanik/Schwungmasse'], [m '/Last_J'], 'Position', [660 20 720 60], 'J', '0.01');
add_block([L 'Mechanik/Last Lüfter'], [m '/Luefter'], 'Position', [660 100 740 150], ...
    'M_B', num2str(S.M_N), 'n_B', num2str(S.n_N));
add_block([L 'Mechanik/Last konstant'], [m '/Last_konstant'], 'Position', [660 180 740 230], 'M_L0', '0');
add_block([L 'Mechanik/Laststoß'], [m '/Laststoss'], 'Position', [660 260 740 310], ...
    't_step', '1', 'dM_L', num2str(0.3*S.M_N));
add_block([L 'Messgeräte/Drehzahlmesser'], [m '/Drehzahlmesser'], 'Position', [800 100 880 200], ...
    'ns', num2str(S.ns));
add_block([L 'Mechanik/Mechanischer Bezug'], [m '/Bezug'], 'Position', [800 400 840 430]);

pc(m, 'Motor', 'R', 1, 'Messwelle', 'L', 1);
pc(m, 'Motor', 'R', 2, 'Bezug', 'L', 1);
pc(m, 'J_M', 'L', 1, 'Messwelle', 'L', 1);                  % motor inertia on the motor side
pc(m, 'Solver', 'R', 1, 'Bezug', 'L', 1);
for b = {'Last_J', 'Luefter', 'Last_konstant', 'Laststoss', 'Drehzahlmesser'}
    pc(m, 'Messwelle', 'R', 1, b{1}, 'L', 1);
end
for b = {'Luefter', 'Last_konstant', 'Laststoss', 'Drehzahlmesser'}
    pc(m, b{1}, 'R', 1, 'Bezug', 'L', 1);
end
recorder(m, 'S_n', 'Drehzahl', {'Drehzahlmesser/1'}, [960 100 1020 140]);
recorder(m, 'S_M', 'Motormoment (Kloss) und Wellenmoment', {'Motor/1', 'Messwelle/1'}, [960 200 1020 240]);
note(m, ['Teil B: Hochlauf und Laststoß mit dem quasistationären Kloss-Modell (R1 = 0, konstanter Fluss, ' ...
         'keine elektrische Dynamik). Trägheit J = J_M + J_L, Lüfterlast, Laststoß 0,3·M_N bei t = 1 s. ' ...
         'Ohne Oberfläche: run_asm(asm_params(''kloss'')).'], [40 480]);
file = save_model(m, folder);
end

%% ===================== Example: part A, conductor loop =====================
function file = conductor_loop(folder)
m = 'ex_conductor_loop';
new_model(m);
set_param(m, 'StopTime', '0.2', 'RelTol', '1e-6');               % two rotor periods at s = sK
L = 'asm_blocks_lib/';
S = asm_standard();
add_block('simulink/Sources/Constant', [m '/Schlupf'], 'Position', [60 140 120 170], ...
    'Value', num2str(S.sK));
add_block([L 'Referenz/Leiterschleife (Prototyp Teil A)'], [m '/Schleife'], 'Position', [220 40 360 360]);
add_line(m, 'Schlupf/1', 'Schleife/1', 'autorouting', 'on');
recorder(m, 'S_i', 'Strom Stab 1 und 2', {'Schleife/2'}, [480 60 540 100]);
recorder(m, 'S_M', 'Moment der Leiterschleife', {'Schleife/5'}, [480 220 540 260]);
note(m, ['Teil A: Leiterschleife aus zwei Rotorstäben bei festem Schlupf s (Konstante "Schlupf"). ' ...
         'Der Schlupf ist eine Vorgabe; das Schleifenmoment wirkt nicht auf eine Mechanik zurück. ' ...
         'Ohne Oberfläche: run_asm(asm_params(''loop'')).'], [60 420]);
file = save_model(m, folder);
end

%% ===================== Example: comparison of the motor models =====================
function file = model_comparison(folder)
m = 'ex_model_comparison';
new_model(m);
L = 'asm_blocks_lib/';
S = asm_standard();

add_block([L 'Quellen/Netz 3~'], [m '/Netz'], 'Position', [40 200 120 320]);
add_block([L 'Quellen/Sternpunkt (Erde)'], [m '/Erde'], 'Position', [60 380 100 410]);
add_block('nesl_utility/Solver Configuration', [m '/Solver'], 'Position', [140 380 200 410]);
pc(m, 'Netz', 'R', 4, 'Erde', 'L', 1);
pc(m, 'Solver', 'R', 1, 'Erde', 'L', 1);

motors = {'Standard', [L 'Maschine/ASM Standard'], 40;
          'Referenz', [L 'Referenz/ASM Referenz (Simscape Electrical)'], 280;
          'Kloss',    [L 'Referenz/ASM Kloss (quasistationär)'], 520};
for i = 1:3
    nm = motors{i, 1};  y = motors{i, 3};
    add_block(motors{i, 2}, [m '/Motor_' nm], 'Position', [300 y 420 y + 120]);
    add_block([L 'Messgeräte/Drehmomentmesswelle'], [m '/Messwelle_' nm], 'Position', [500 y + 20 580 y + 80]);
    add_block([L 'Mechanik/Schwungmasse'], [m '/J_' nm], 'Position', [660 y 720 y + 40], 'J', '0.01');
    add_block([L 'Mechanik/Last Lüfter'], [m '/Luefter_' nm], 'Position', [660 y + 50 740 y + 90], ...
        'M_B', num2str(S.M_N), 'n_B', num2str(S.n_N));
    add_block([L 'Mechanik/Laststoß'], [m '/Laststoss_' nm], 'Position', [660 y + 100 740 y + 140], ...
        't_step', '1', 'dM_L', num2str(0.3*S.M_N));
    add_block([L 'Messgeräte/Drehzahlmesser'], [m '/Drehzahl_' nm], 'Position', [800 y + 40 880 y + 140]);
    add_block([L 'Mechanik/Mechanischer Bezug'], [m '/Bezug_' nm], 'Position', [960 y + 160 1000 y + 190]);
    if strcmp(nm, 'Kloss')
        set_param([m '/Motor_' nm], 'MK', num2str(S.MK), 'sK', num2str(S.sK), 'ns', num2str(S.ns));
        add_block([L 'Mechanik/Schwungmasse'], [m '/J_M_' nm], 'Position', [500 y + 100 560 y + 140], ...
            'J', num2str(S.J_M));                               % the Kloss block has no inertia of its own
        add_block('nesl_utility/Solver Configuration', [m '/Solver_' nm], 'Position', [800 y + 180 860 y + 210]);
        pc(m, ['J_M_' nm], 'L', 1, ['Messwelle_' nm], 'L', 1);
        pc(m, ['Solver_' nm], 'R', 1, ['Bezug_' nm], 'L', 1);
    else
        for k = 1:3, pc(m, 'Netz', 'R', k, ['Motor_' nm], 'L', k); end
    end
    pc(m, ['Motor_' nm], 'R', 1, ['Messwelle_' nm], 'L', 1);
    pc(m, ['Motor_' nm], 'R', 2, ['Bezug_' nm], 'L', 1);
    for b = {'J_', 'Luefter_', 'Laststoss_', 'Drehzahl_'}
        pc(m, ['Messwelle_' nm], 'R', 1, [b{1} nm], 'L', 1);
    end
    for b = {'Luefter_', 'Laststoss_', 'Drehzahl_'}
        pc(m, [b{1} nm], 'R', 1, ['Bezug_' nm], 'L', 1);
    end
end
recorder(m, 'S_n', 'Drehzahl: Standard / Referenz / Kloss', ...
         {'Drehzahl_Standard/1', 'Drehzahl_Referenz/1', 'Drehzahl_Kloss/1'}, [1100 200 1160 240]);
recorder(m, 'S_M', 'Wellenmoment: Standard / Referenz / Kloss', ...
         {'Messwelle_Standard/1', 'Messwelle_Referenz/1', 'Messwelle_Kloss/1'}, [1100 400 1160 440]);
note(m, ['Vergleich der Motormodelle bei gleicher Mechanik: Raumzeigermodell (ASM Standard), ' ...
         'Simscape-Electrical-Referenz und Kloss-Formel (quasistationär, ohne elektrische Dynamik). ' ...
         'Modellvergleich (Benchmark), keine Messung.'], [40 700]);
file = save_model(m, folder);
end

%% ========================= helper functions =========================
function new_model(m)
if bdIsLoaded(m), close_system(m, 0); end
w = warning('off', 'Simulink:Engine:MdlFileShadowing');   % an existing .slx on the path is replaced
new_system(m);
warning(w);
set_param(m, 'Solver', 'ode23t', 'StopTime', '2', 'RelTol', '1e-5', 'MaxStep', '1e-4', ...
    'ReturnWorkspaceOutputs', 'on');
end

function file = save_model(m, folder)
file = fullfile(folder, [m '.slx']);
save_system(m, file);
close_system(m, 0);
end

function recorder(m, name, title_text, sources, pos)
% recorder block with title; several signals via a Mux
add_block('asm_blocks_lib/Messgeräte/Schreiber', [m '/' name], 'Position', pos, ...
    'title_text', title_text);
if isscalar(sources)
    add_line(m, sources{1}, [name '/1'], 'autorouting', 'on');
else
    mux = [name '_mux'];
    add_block('simulink/Signal Routing/Mux', [m '/' mux], 'Inputs', num2str(numel(sources)), ...
        'Position', [pos(1) - 40, pos(2), pos(1) - 35, pos(4)]);
    for k = 1:numel(sources)
        add_line(m, sources{k}, sprintf('%s/%d', mux, k), 'autorouting', 'on');
    end
    add_line(m, [mux '/1'], [name '/1']);
end
end

function note(m, text, xy)
a = Simulink.Annotation([m '/Beschreibung']);
a.Text = text;
a.Position = [xy, xy + [700 40]];
end

function pc(m, a, sa, na, b, sb, nb)
% physical connection between port na on side sa of a and nb/sb of b
pa = get_param([m '/' a], 'PortHandles');  pb = get_param([m '/' b], 'PortHandles');
if sa == 'L', ha = pa.LConn(na); else, ha = pa.RConn(na); end
if sb == 'L', hb = pb.LConn(nb); else, hb = pb.RConn(nb); end
add_line(m, ha, hb, 'autorouting', 'on');
end
