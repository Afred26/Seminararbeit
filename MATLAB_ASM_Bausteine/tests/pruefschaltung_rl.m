function E = pruefschaltung_rl(opt)
%PRUEFSCHALTUNG_RL Prüfschaltung für Netz und Messgeräte (Hilfsfunktion der Tests).
%   E = pruefschaltung_rl('R', 10, 'L', 0.02, 'U', 400, 'f', 50, ...)
%   Netz 3~ -> Leistungsmesser 3~ -> Strommessung 3~ -> Amperemeter (Leiter a)
%   -> RL-Last in Stern (Sternpunkt frei). Parallel: Spannungsmessung 3~ an a, b, c (n am
%   Netzsternpunkt), Voltmeter zwischen a und b. Netzsternpunkt geerdet.
%   Rückgabe E: letzte Werte und Zeitverläufe aller Messausgänge ([t y]).

arguments
    opt.R (1,1) double = 10
    opt.L (1,1) double = 0.02
    opt.U (1,1) double = 400
    opt.f (1,1) double = 50
    opt.phasenfolge (1,:) char = 'L1-L2-L3 (Rechtsdrehfeld)'
    opt.phi0 (1,1) double = 0
    opt.t_ein (1,1) double = 0
    opt.bezug (1,:) char = 'künstlicher Sternpunkt'
    opt.R_N (1,1) double = 0
    opt.L_N (1,1) double = 0
    opt.t_end (1,1) double = 0.2
end

L = 'asm_bausteine_lib/';
load_system('asm_bausteine_lib');
m = sprintf('asm_pruef_rl_%d', randi(1e6));
new_system(m);
aufr = onCleanup(@() close_system(m, 0));
set_param(m, 'Solver', 'ode23t', 'StopTime', num2str(opt.t_end), 'RelTol', '1e-6', 'MaxStep', '1e-4', ...
    'ReturnWorkspaceOutputs', 'on');

add_block([L 'Quellen/Netz 3~'], [m '/Netz'], 'U_L', num2str(opt.U), 'f1', num2str(opt.f), ...
    'phasenfolge', opt.phasenfolge, 'phi0', num2str(opt.phi0), 't_ein', num2str(opt.t_ein), ...
    'R_N', num2str(opt.R_N), 'L_N', num2str(opt.L_N));
add_block([L 'Quellen/Sternpunkt (Erde)'], [m '/Erde']);
add_block('nesl_utility/Solver Configuration', [m '/Solver']);
add_block([L 'Messgeräte/Leistungsmesser 3~'], [m '/W']);
add_block([L 'Messgeräte/Strommessung 3~'], [m '/A3']);
add_block([L 'Messgeräte/Amperemeter'], [m '/A']);
add_block([L 'Messgeräte/Spannungsmessung 3~'], [m '/V3'], 'bezug', opt.bezug);
add_block([L 'Messgeräte/Voltmeter'], [m '/V']);
for k = 1:3
    add_block('fl_lib/Electrical/Electrical Elements/Resistor', sprintf('%s/R%d', m, k), 'R', num2str(opt.R));
    add_block('fl_lib/Electrical/Electrical Elements/Inductor', sprintf('%s/L%d', m, k), 'l', num2str(opt.L));
end

pn = ph(m, 'Netz'); pe = ph(m, 'Erde'); ps = ph(m, 'Solver');
pw = ph(m, 'W'); pa3 = ph(m, 'A3'); pa = ph(m, 'A'); pv3 = ph(m, 'V3'); pv = ph(m, 'V');
add_line(m, pn.RConn(4), pe.LConn(1));
add_line(m, ps.RConn(1), pe.LConn(1));
add_line(m, pv3.LConn(4), pn.RConn(4));                   % n der Spannungsmessung am Netzsternpunkt
for k = 1:3
    add_line(m, pn.RConn(k), pw.LConn(k));
    add_line(m, pw.RConn(k), pa3.LConn(k));
    add_line(m, pn.RConn(k), pv3.LConn(k));
    pr = ph(m, sprintf('R%d', k)); pl = ph(m, sprintf('L%d', k));
    if k == 1
        add_line(m, pa3.RConn(1), pa.LConn(1));
        add_line(m, pa.RConn(1), pr.LConn(1));
    else
        add_line(m, pa3.RConn(k), pr.LConn(1));
    end
    add_line(m, pr.RConn(1), pl.LConn(1));
    if k > 1, add_line(m, pl.RConn(1), ph(m, 'L1').RConn(1)); end   % Sternpunkt der Last
end
add_line(m, pn.RConn(1), pv.LConn(1));
add_line(m, pn.RConn(2), pv.RConn(1));

% alle Messausgänge protokollieren
ausg = {'W', {'P', 'Q', 'S', 'cosphi'}; 'A3', {'i_abc', 'I_eff', 'i1'}; 'A', {'i', 'I_eff_a'}; ...
        'V3', {'u_str', 'u_leiter', 'U_eff'}; 'V', {'u', 'U_eff_ab'}};
for z = 1:size(ausg, 1)
    for k = 1:numel(ausg{z, 2})
        nm = ausg{z, 2}{k};
        add_block('simulink/Sinks/To Workspace', [m '/TW_' nm], 'VariableName', nm, ...
            'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf');
        add_line(m, sprintf('%s/%d', ausg{z, 1}, k), ['TW_' nm '/1']);
    end
end

out = sim(m, 'TimeOut', 120);
E.out = out;
for z = 1:size(ausg, 1)
    for k = 1:numel(ausg{z, 2})
        nm = ausg{z, 2}{k};
        ts = out.get(nm);
        y = squeeze(ts.Data);
        if size(y, 1) ~= numel(ts.Time), y = y.'; end
        E.(nm) = [ts.Time(:), y];
        E.ende.(nm) = y(end, :);
    end
end
end

function h = ph(m, b)
h = get_param([m '/' b], 'PortHandles');
end
