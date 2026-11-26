function E = rl_test_circuit(opt)
%RL_TEST_CIRCUIT Test circuit for grid and sensors (helper function of the tests).
%   E = rl_test_circuit('R', 10, 'L', 0.02, 'U', 400, 'f', 50, ...)
%   Netz 3~ -> power meter 3~ -> current sensor 3~ -> ammeter (line a)
%   -> RL load in star (star point floating). In parallel: voltage sensor 3~ at a, b, c (n at the
%   grid star point), voltmeter between a and b. Grid star point grounded.
%   Returns E: last values and time series of all sensor outputs ([t y]).

arguments
    opt.R (1,1) double = 10
    opt.L (1,1) double = 0.02
    opt.U (1,1) double = 400
    opt.f (1,1) double = 50
    opt.phase_seq (1,:) char = 'L1-L2-L3 (Rechtsdrehfeld)'
    opt.phi0 (1,1) double = 0
    opt.t_on (1,1) double = 0
    opt.reference (1,:) char = 'künstlicher Sternpunkt'
    opt.R_N (1,1) double = 0
    opt.L_N (1,1) double = 0
    opt.t_end (1,1) double = 0.2
end

L = 'asm_blocks_lib/';
load_system('asm_blocks_lib');
m = sprintf('asm_test_rl_%d', randi(1e6));
new_system(m);
cleanup = onCleanup(@() close_system(m, 0));
set_param(m, 'Solver', 'ode23t', 'StopTime', num2str(opt.t_end), 'RelTol', '1e-6', 'MaxStep', '1e-4', ...
    'ReturnWorkspaceOutputs', 'on');

add_block([L 'Quellen/Netz 3~'], [m '/Netz'], 'U_L', num2str(opt.U), 'f1', num2str(opt.f), ...
    'phase_seq', opt.phase_seq, 'phi0', num2str(opt.phi0), 't_on', num2str(opt.t_on), ...
    'R_N', num2str(opt.R_N), 'L_N', num2str(opt.L_N));
add_block([L 'Quellen/Sternpunkt (Erde)'], [m '/Erde']);
add_block('nesl_utility/Solver Configuration', [m '/Solver']);
add_block([L 'Messgeräte/Leistungsmesser 3~'], [m '/W']);
add_block([L 'Messgeräte/Strommessung 3~'], [m '/A3']);
add_block([L 'Messgeräte/Amperemeter'], [m '/A']);
add_block([L 'Messgeräte/Spannungsmessung 3~'], [m '/V3'], 'reference', opt.reference);
add_block([L 'Messgeräte/Voltmeter'], [m '/V']);
for k = 1:3
    add_block('fl_lib/Electrical/Electrical Elements/Resistor', sprintf('%s/R%d', m, k), 'R', num2str(opt.R));
    add_block('fl_lib/Electrical/Electrical Elements/Inductor', sprintf('%s/L%d', m, k), 'l', num2str(opt.L));
end

pn = ph(m, 'Netz'); pe = ph(m, 'Erde'); ps = ph(m, 'Solver');
pw = ph(m, 'W'); pa3 = ph(m, 'A3'); pa = ph(m, 'A'); pv3 = ph(m, 'V3'); pv = ph(m, 'V');
add_line(m, pn.RConn(4), pe.LConn(1));
add_line(m, ps.RConn(1), pe.LConn(1));
add_line(m, pv3.LConn(4), pn.RConn(4));                   % n of the voltage sensor at the grid star point
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
    if k > 1, add_line(m, pl.RConn(1), ph(m, 'L1').RConn(1)); end   % star point of the load
end
add_line(m, pn.RConn(1), pv.LConn(1));
add_line(m, pn.RConn(2), pv.RConn(1));

% log all sensor outputs
outputs = {'W', {'P', 'Q', 'S', 'cosphi'}; 'A3', {'i_abc', 'I_eff', 'i1'}; 'A', {'i', 'I_eff_a'}; ...
           'V3', {'u_phase', 'u_line', 'U_eff'}; 'V', {'u', 'U_eff_ab'}};
for z = 1:size(outputs, 1)
    for k = 1:numel(outputs{z, 2})
        nm = outputs{z, 2}{k};
        add_block('simulink/Sinks/To Workspace', [m '/TW_' nm], 'VariableName', nm, ...
            'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf');
        add_line(m, sprintf('%s/%d', outputs{z, 1}, k), ['TW_' nm '/1']);
    end
end

out = sim(m, 'TimeOut', 120);
E.out = out;
for z = 1:size(outputs, 1)
    for k = 1:numel(outputs{z, 2})
        nm = outputs{z, 2}{k};
        ts = out.get(nm);
        y = squeeze(ts.Data);
        if size(y, 1) ~= numel(ts.Time), y = y.'; end
        E.(nm) = [ts.Time(:), y];
        E.last.(nm) = y(end, :);
    end
end
end

function h = ph(m, b)
h = get_param([m '/' b], 'PortHandles');
end
