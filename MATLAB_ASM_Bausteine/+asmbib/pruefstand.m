function E = pruefstand(opt)
%PRUEFSTAND Baut und simuliert einen Motorprüfstand (Netz -> Motor -> Welle -> Last).
%   E = asmbib.pruefstand('Name', Wert, ...)
%
%   Aufbau nur aus Bausteinen der asm_bausteine_lib, gesteckt wie im Labor:
%     Netz 3~ (Sternpunkt geerdet) -> Motor -> Drehmomentmesswelle -> Schwungmasse J_L
%     -> Last (Lüfter oder konstant) und Laststoß; Drehzahlmesser zwischen Welle und Bezug,
%     Gehäuse und Lasten am Mechanischen Bezug.
%   Ausnahme: für feste Drehzahl (n_fest) treibt eine ideale Drehzahlquelle (fl_lib) die Welle.
%
%   Optionen
%     Motor      'asm'      ASM Standard (Standard)
%                'ee'       ASM Referenz (Simscape Electrical), gleiche ESB-Werte, nur Stern
%                'kloss'    ASM Kloss (quasistationär) mit MK = 2,7·M_N, sK = 0,2
%     P          Parametersatz (Struktur wie asm_standard), Standard asm_standard()
%     Schaltung  'Stern' | 'Dreieck'
%     U, f       Netzspannung (Leiter, eff.) [V], Frequenz [Hz]; Standard P.U_N, P.f_N
%     Last       'luefter' (M_L = M_B·(n/n_B)·|n/n_B|) | 'konstant' (M_L0) | 'keine'
%     M_L0, M_B, n_B          Lastparameter [N·m], [N·m], [1/min]
%     t_stoss, dM_L           Laststoß [s], [N·m] (dM_L = 0: kein Laststoß-Baustein)
%     J_L        Trägheitsmoment der Last [kg·m²]
%     n_fest     [] oder feste Drehzahl [1/min] (stationäre Kennlinienpunkte, V1)
%     n0         Anfangsdrehzahl [1/min]
%     t_end, RelTol, MaxStep  Solvereinstellungen
%     Behalten   true: Modell bleibt geöffnet (Name in E.modell), sonst wird es geschlossen
%     TimeOut    Rechenzeitgrenze der Simulation [s] (Standard 300), danach Fehler
%
%   Rückgabe E: Struktur mit Zeitverläufen [t, y] (Spaltenvektoren)
%     E.n [1/min] (Drehzahlmesser), E.M_W [N·m] (Drehmomentmesswelle), E.M_L [N·m] (aus n berechnet)
%     E.mess  (nur Motor 'asm') alle Signale des Messbusses, z. B. E.mess.M, E.mess.psi_h
%     E.M_kloss (nur Motor 'kloss') Motormoment nach Kloss
%     E.modell, E.dauer_s, E.opt

arguments
    opt.Motor (1,:) char {mustBeMember(opt.Motor, {'asm', 'ee', 'kloss'})} = 'asm'
    opt.P struct = asm_standard()
    opt.Schaltung (1,:) char {mustBeMember(opt.Schaltung, {'Stern', 'Dreieck'})} = 'Stern'
    opt.U double = []
    opt.f double = []
    opt.Last (1,:) char {mustBeMember(opt.Last, {'luefter', 'konstant', 'keine'})} = 'luefter'
    opt.M_L0 (1,1) double = 13.25
    opt.M_B (1,1) double = 26.5
    opt.n_B (1,1) double = 1440
    opt.t_stoss (1,1) double = 1
    opt.dM_L (1,1) double = 0
    opt.J_L (1,1) double = 0.01
    opt.n_fest double = []
    opt.n0 (1,1) double = 0
    opt.t_end (1,1) double = 2
    opt.RelTol (1,1) double = 1e-5
    opt.MaxStep (1,1) double = 1e-4
    opt.Behalten (1,1) logical = false
    opt.TimeOut (1,1) double = 300
end

P = opt.P;
if isempty(opt.U), opt.U = P.U_N; end
if isempty(opt.f), opt.f = P.f_N; end
L = 'asm_bausteine_lib/';
load_system('asm_bausteine_lib');
z = @(x) num2str(x, 16);

mdl = sprintf('asm_pruefstand_%s_%d', opt.Motor, randi(1e6));
new_system(mdl);
if ~opt.Behalten, aufr = onCleanup(@() close_system(mdl, 0)); end
set_param(mdl, 'SolverType', 'Variable-step', 'Solver', 'ode23t', 'StopTime', z(opt.t_end), ...
    'RelTol', z(opt.RelTol), 'MaxStep', z(opt.MaxStep), ...
    'ReturnWorkspaceOutputs', 'on', 'ReturnWorkspaceOutputsName', 'out');

%% Mechanik (gemeinsam): Messwelle -> Welle mit Drehzahlmesser, Bezug
add_block([L 'Mechanik/Mechanischer Bezug'], [mdl '/Bezug'], 'Position', [380 420 420 460]);
add_block([L 'Messgeräte/Drehmomentmesswelle'], [mdl '/Messwelle'], 'Position', [480 280 560 340]);
add_block([L 'Messgeräte/Drehzahlmesser'], [mdl '/Tacho'], 'Position', [640 380 720 480], ...
    'ns', z(60*opt.f/P.p));
pv(mdl, 'Messwelle', 'R', 1, 'Tacho', 'L', 1);                 % Wellenknoten hinter der Messwelle
pv(mdl, 'Tacho', 'R', 1, 'Bezug', 'L', 1);
protokoll(mdl, 'Tacho/1', 'n');
protokoll(mdl, 'Messwelle/1', 'M_W');

%% Motor
switch opt.Motor
    case {'asm', 'ee'}
        netz(mdl, L, opt, z);
        if strcmp(opt.Motor, 'asm')
            add_block([L 'Maschine/ASM Standard'], [mdl '/Motor'], 'Position', [300 80 420 200]);
        else
            if ~strcmp(opt.Schaltung, 'Stern'), error('asmbib:pruefstand', 'Referenz nur in Sternschaltung.'); end
            add_block([L 'Referenz/ASM Referenz (Simscape Electrical)'], [mdl '/Motor'], 'Position', [300 80 420 200]);
        end
        set_param([mdl '/Motor'], 'parametersatz', 'Benutzerdefiniert');
        mo = Simulink.Mask.get([mdl '/Motor']);
        for f = {mo.Parameters.Name}
            if isfield(P, f{1}), set_param([mdl '/Motor'], f{1}, z(P.(f{1}))); end
        end
        if strcmp(opt.Motor, 'asm')
            set_param([mdl '/Motor'], 'n0', z(opt.n0), 'schaltung', opt.Schaltung);
            protokoll(mdl, 'Motor/1', 'mess');
        end
        for k = 1:3, pv(mdl, 'Netz', 'R', k, 'Motor', 'L', k); end
        pv(mdl, 'Motor', 'R', 1, 'Messwelle', 'L', 1);
        pv(mdl, 'Motor', 'R', 2, 'Bezug', 'L', 1);
    case 'kloss'
        add_block([L 'Referenz/ASM Kloss (quasistationär)'], [mdl '/Motor'], 'Position', [300 80 420 200], ...
            'MK', z(2.7*P.M_N), 'sK', '0.2', 'ns', z(60*opt.f/P.p));
        add_block([L 'Mechanik/Schwungmasse'], [mdl '/J_M'], 'Position', [300 240 360 280], ...
            'J', z(P.J_M), 'n0', z(opt.n0));
        add_block('nesl_utility/Solver Configuration', [mdl '/Solver'], 'Position', [200 420 260 450]);
        pv(mdl, 'Motor', 'R', 1, 'Messwelle', 'L', 1);
        pv(mdl, 'Motor', 'R', 2, 'Bezug', 'L', 1);
        pv(mdl, 'J_M', 'L', 1, 'Messwelle', 'L', 1);
        pv(mdl, 'Solver', 'R', 1, 'Bezug', 'L', 1);
        protokoll(mdl, 'Motor/1', 'M_kloss');
end

%% Last bzw. feste Drehzahl
if isempty(opt.n_fest)
    add_block([L 'Mechanik/Schwungmasse'], [mdl '/Last_J'], 'Position', [640 260 700 300], ...
        'J', z(opt.J_L), 'n0', z(opt.n0));
    pv(mdl, 'Messwelle', 'R', 1, 'Last_J', 'L', 1);
    switch opt.Last
        case 'luefter'
            add_block([L 'Mechanik/Last Lüfter'], [mdl '/Last'], 'Position', [780 260 860 300], ...
                'M_B', z(opt.M_B), 'n_B', z(opt.n_B));
        case 'konstant'
            add_block([L 'Mechanik/Last konstant'], [mdl '/Last'], 'Position', [780 260 860 300], ...
                'M_L0', z(opt.M_L0));
    end
    if ~strcmp(opt.Last, 'keine'), welle_bezug(mdl, 'Last'); end
    if opt.dM_L ~= 0
        add_block([L 'Mechanik/Laststoß'], [mdl '/Laststoss'], 'Position', [780 340 860 380], ...
            't_stoss', z(opt.t_stoss), 'dM_L', z(opt.dM_L));
        welle_bezug(mdl, 'Laststoss');
    end
else
    add_block('simulink/Sources/Constant', [mdl '/n_fest'], 'Position', [860 480 920 510], ...
        'Value', z(opt.n_fest*2*pi/60));
    add_block('nesl_utility/Simulink-PS Converter', [mdl '/SL_W'], 'Position', [960 485 980 505], 'Unit', 'rad/s');
    add_block('fl_lib/Mechanical/Mechanical Sources/Ideal Angular Velocity Source', [mdl '/Antrieb'], ...
        'Position', [640 500 700 560]);
    add_line(mdl, 'n_fest/1', 'SL_W/1');
    pv(mdl, 'SL_W', 'R', 1, 'Antrieb', 'R', 1);
    pv(mdl, 'Messwelle', 'R', 1, 'Antrieb', 'L', 1);
    pv(mdl, 'Antrieb', 'R', 2, 'Bezug', 'L', 1);
end

%% Simulation (mit Zeitgrenze, damit ein hängender Solver nicht blockiert)
t0 = tic;
out = sim(mdl, 'TimeOut', opt.TimeOut);
E.dauer_s = toc(t0);
if out.tout(end) < opt.t_end*(1 - 1e-9)
    error('asmbib:pruefstand', 'Simulation nach %.0f s abgebrochen bei t = %.4g s (Zeitgrenze TimeOut).', ...
          E.dauer_s, out.tout(end));
end
E.modell = mdl;
E.opt = opt;
E.n   = ts2mat(out.get('n'));
E.M_W = ts2mat(out.get('M_W'));
E.M_L = [];
if isempty(opt.n_fest)                                    % Lastmoment aus der Drehzahl (Kennlinie)
    n = E.n(:,2);  t = E.n(:,1);
    switch opt.Last
        case 'luefter', ML = opt.M_B*(n/opt.n_B).*abs(n/opt.n_B);
        case 'konstant', ML = opt.M_L0*tanh(n*2*pi/60/0.1);
        otherwise, ML = 0*n;
    end
    ML = ML + opt.dM_L*0.5*(1 + tanh((t - opt.t_stoss)/0.5e-3)).*tanh(n*2*pi/60/0.1);
    E.M_L = [t, ML];
end
if strcmp(opt.Motor, 'asm')
    m = out.get('mess');
    for f = fieldnames(m)'
        E.mess.(f{1}) = ts2mat(m.(f{1}));
    end
end
if strcmp(opt.Motor, 'kloss'), E.M_kloss = ts2mat(out.get('M_kloss')); end
end

%% ========================= Hilfsfunktionen =========================
function netz(mdl, L, opt, z)
% Netz 3~ mit geerdetem Sternpunkt und Solver Configuration
add_block([L 'Quellen/Netz 3~'], [mdl '/Netz'], 'Position', [40 80 120 200], 'U_L', z(opt.U), 'f1', z(opt.f));
add_block([L 'Quellen/Sternpunkt (Erde)'], [mdl '/Erde'], 'Position', [140 240 180 270]);
add_block('nesl_utility/Solver Configuration', [mdl '/Solver'], 'Position', [40 240 100 270]);
pv(mdl, 'Netz', 'R', 4, 'Erde', 'L', 1);
pv(mdl, 'Solver', 'R', 1, 'Erde', 'L', 1);
end

function welle_bezug(mdl, blk)
% Baustein mit R an die Welle (hinter der Messwelle) und C an den Bezug
pv(mdl, 'Messwelle', 'R', 1, blk, 'L', 1);
pv(mdl, blk, 'R', 1, 'Bezug', 'L', 1);
end

function pv(sys, a, sa, na, b, sb, nb)
% physikalische Verbindung zwischen Anschluss na auf Seite sa von a und nb/sb von b
add_line(sys, port(sys, a, sa, na), port(sys, b, sb, nb), 'autorouting', 'on');
end

function h = port(sys, blk, seite, nr)
ph = get_param([sys '/' blk], 'PortHandles');
if seite == 'L', h = ph.LConn(nr); else, h = ph.RConn(nr); end
end

function protokoll(sys, quelle, name)
% Simulink-Ausgang -> To Workspace "name" (Timeseries bzw. Struktur bei Bus)
add_block('simulink/Sinks/To Workspace', [sys '/TW_' name], 'VariableName', name, ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf');
add_line(sys, quelle, ['TW_' name '/1'], 'autorouting', 'on');
end

function x = ts2mat(ts)
% Timeseries -> [t, y], doppelte Zeitpunkte entfernt
y = squeeze(ts.Data);
if size(y, 1) ~= numel(ts.Time), y = y.'; end
[t, iu] = unique(ts.Time(:), 'last');
x = [t, y(iu, :)];
end
