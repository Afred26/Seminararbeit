function E = test_bench(opt)
%TEST_BENCH Builds and simulates a motor test bench (grid -> motor -> shaft -> load).
%   E = asmtools.test_bench('Name', value, ...)
%
%   Built only from blocks of asm_blocks_lib, connected as in the laboratory:
%     Netz 3~ (star point grounded) -> motor -> torque sensor -> inertia J_L
%     -> load (fan or constant) and load step; speed sensor between shaft and reference,
%     housing and loads at the mechanical reference.
%   Exception: for a fixed speed (n_fixed) an ideal speed source (fl_lib) drives the shaft.
%   The model is built from scratch for every call (independent of the example models);
%   the benchmark tests use it as an independent second set-up.
%
%   Options
%     Motor       'asm'      ASM Standard (default)
%                 'ee'       ASM Referenz (Simscape Electrical), same EC values, star only
%                 'kloss'    ASM Kloss (quasi-static) with P.MK, P.sK
%     P           parameter set (struct like asm_standard), default asm_standard()
%     Connection  'star' | 'delta'
%     U, f        grid voltage (line, RMS) [V], frequency [Hz]; default P.U_N, P.f_N
%     Load        'fan' (M_L = M_B*(n/n_B)*|n/n_B|) | 'constant' (M_L0) | 'none'
%     M_L0, M_B, n_B          load parameters [N*m], [N*m], [rpm]
%     t_step, dM_L            load step [s], [N*m] (dM_L = 0: no load-step block)
%     J_L         inertia of the load [kg*m^2]
%     n_fixed     [] or fixed speed [rpm] (stationary characteristic points, V1)
%     n0          initial speed [rpm]
%     t_end, RelTol, MaxStep  solver settings
%     Keep        true: the model stays open (name in E.model), otherwise it is closed
%     TimeOut     computing time limit of the simulation [s] (default 300), then error
%
%   Returns E: struct with time series [t, y] (column vectors)
%     E.n [rpm] (speed sensor), E.M_W [N*m] (torque sensor), E.M_L [N*m] (computed from n)
%     E.meas  (motor 'asm' only) all signals of the measurement bus, e.g. E.meas.M, E.meas.psi_h
%     E.M_kloss (motor 'kloss' only) motor torque according to Kloss
%     E.model, E.duration_s, E.opt

arguments
    opt.Motor (1,:) char {mustBeMember(opt.Motor, {'asm', 'ee', 'kloss'})} = 'asm'
    opt.P struct = asm_standard()
    opt.Connection (1,:) char {mustBeMember(opt.Connection, {'star', 'delta'})} = 'star'
    opt.U double = []
    opt.f double = []
    opt.Load (1,:) char {mustBeMember(opt.Load, {'fan', 'constant', 'none'})} = 'fan'
    opt.M_L0 (1,1) double = 13.25
    opt.M_B (1,1) double = 26.5
    opt.n_B (1,1) double = 1440
    opt.t_step (1,1) double = 1
    opt.dM_L (1,1) double = 0
    opt.J_L (1,1) double = 0.01
    opt.n_fixed double = []
    opt.n0 (1,1) double = 0
    opt.t_end (1,1) double = 2
    opt.RelTol (1,1) double = 1e-5
    opt.MaxStep (1,1) double = 1e-4
    opt.Keep (1,1) logical = false
    opt.TimeOut (1,1) double = 300
end

P = opt.P;
if isempty(opt.U), opt.U = P.U_N; end
if isempty(opt.f), opt.f = P.f_N; end
L = 'asm_blocks_lib/';
load_system('asm_blocks_lib');
z = @(x) num2str(x, 16);

mdl = sprintf('asm_test_bench_%s_%d', opt.Motor, randi(1e6));
new_system(mdl);
if ~opt.Keep, cleanup = onCleanup(@() close_system(mdl, 0)); end
set_param(mdl, 'SolverType', 'Variable-step', 'Solver', 'ode23t', 'StopTime', z(opt.t_end), ...
    'RelTol', z(opt.RelTol), 'MaxStep', z(opt.MaxStep), ...
    'ReturnWorkspaceOutputs', 'on', 'ReturnWorkspaceOutputsName', 'out');

%% mechanics (common): torque sensor -> shaft with speed sensor, reference
add_block([L 'Mechanik/Mechanischer Bezug'], [mdl '/Bezug'], 'Position', [380 420 420 460]);
add_block([L 'Messgeräte/Drehmomentmesswelle'], [mdl '/Messwelle'], 'Position', [480 280 560 340]);
add_block([L 'Messgeräte/Drehzahlmesser'], [mdl '/Tacho'], 'Position', [640 380 720 480], ...
    'ns', z(60*opt.f/P.p));
pc(mdl, 'Messwelle', 'R', 1, 'Tacho', 'L', 1);                 % shaft node behind the torque sensor
pc(mdl, 'Tacho', 'R', 1, 'Bezug', 'L', 1);
log_signal(mdl, 'Tacho/1', 'n');
log_signal(mdl, 'Messwelle/1', 'M_W');

%% motor
switch opt.Motor
    case {'asm', 'ee'}
        add_grid(mdl, L, opt, z);
        if strcmp(opt.Motor, 'asm')
            add_block([L 'Maschine/ASM Standard'], [mdl '/Motor'], 'Position', [300 80 420 200]);
        else
            if ~strcmp(opt.Connection, 'star')
                error('asmtools:testbench', 'Referenz nur in Sternschaltung.');
            end
            add_block([L 'Referenz/ASM Referenz (Simscape Electrical)'], [mdl '/Motor'], 'Position', [300 80 420 200]);
        end
        set_param([mdl '/Motor'], 'param_set', 'Benutzerdefiniert');
        mo = Simulink.Mask.get([mdl '/Motor']);
        for f = {mo.Parameters.Name}
            if isfield(P, f{1}), set_param([mdl '/Motor'], f{1}, z(P.(f{1}))); end
        end
        if strcmp(opt.Motor, 'asm')
            set_param([mdl '/Motor'], 'n0', z(opt.n0), 'connection', connection_option(opt.Connection));
            log_signal(mdl, 'Motor/1', 'meas');
        end
        for k = 1:3, pc(mdl, 'Netz', 'R', k, 'Motor', 'L', k); end
        pc(mdl, 'Motor', 'R', 1, 'Messwelle', 'L', 1);
        pc(mdl, 'Motor', 'R', 2, 'Bezug', 'L', 1);
    case 'kloss'
        add_block([L 'Referenz/ASM Kloss (quasistationär)'], [mdl '/Motor'], 'Position', [300 80 420 200], ...
            'MK', z(P.MK), 'sK', z(P.sK), 'ns', z(60*opt.f/P.p));
        add_block([L 'Mechanik/Schwungmasse'], [mdl '/J_M'], 'Position', [300 240 360 280], ...
            'J', z(P.J_M), 'n0', z(opt.n0));
        add_block('nesl_utility/Solver Configuration', [mdl '/Solver'], 'Position', [200 420 260 450]);
        pc(mdl, 'Motor', 'R', 1, 'Messwelle', 'L', 1);
        pc(mdl, 'Motor', 'R', 2, 'Bezug', 'L', 1);
        pc(mdl, 'J_M', 'L', 1, 'Messwelle', 'L', 1);
        pc(mdl, 'Solver', 'R', 1, 'Bezug', 'L', 1);
        log_signal(mdl, 'Motor/1', 'M_kloss');
end

%% load or fixed speed
if isempty(opt.n_fixed)
    add_block([L 'Mechanik/Schwungmasse'], [mdl '/Last_J'], 'Position', [640 260 700 300], ...
        'J', z(opt.J_L), 'n0', z(opt.n0));
    pc(mdl, 'Messwelle', 'R', 1, 'Last_J', 'L', 1);
    switch opt.Load
        case 'fan'
            add_block([L 'Mechanik/Last Lüfter'], [mdl '/Last'], 'Position', [780 260 860 300], ...
                'M_B', z(opt.M_B), 'n_B', z(opt.n_B));
        case 'constant'
            add_block([L 'Mechanik/Last konstant'], [mdl '/Last'], 'Position', [780 260 860 300], ...
                'M_L0', z(opt.M_L0));
    end
    if ~strcmp(opt.Load, 'none'), shaft_reference(mdl, 'Last'); end
    if opt.dM_L ~= 0
        add_block([L 'Mechanik/Laststoß'], [mdl '/Laststoss'], 'Position', [780 340 860 380], ...
            't_step', z(opt.t_step), 'dM_L', z(opt.dM_L));
        shaft_reference(mdl, 'Laststoss');
    end
else
    add_block('simulink/Sources/Constant', [mdl '/n_fixed'], 'Position', [860 480 920 510], ...
        'Value', z(opt.n_fixed*2*pi/60));
    add_block('nesl_utility/Simulink-PS Converter', [mdl '/SL_W'], 'Position', [960 485 980 505], 'Unit', 'rad/s');
    add_block('fl_lib/Mechanical/Mechanical Sources/Ideal Angular Velocity Source', [mdl '/Antrieb'], ...
        'Position', [640 500 700 560]);
    add_line(mdl, 'n_fixed/1', 'SL_W/1');
    pc(mdl, 'SL_W', 'R', 1, 'Antrieb', 'R', 1);
    pc(mdl, 'Messwelle', 'R', 1, 'Antrieb', 'L', 1);
    pc(mdl, 'Antrieb', 'R', 2, 'Bezug', 'L', 1);
end

%% simulation (with time limit so that a hanging solver does not block)
t0 = tic;
out = sim(mdl, 'TimeOut', opt.TimeOut);
E.duration_s = toc(t0);
if out.tout(end) < opt.t_end*(1 - 1e-9)
    error('asmtools:testbench', 'Simulation nach %.0f s abgebrochen bei t = %.4g s (Zeitgrenze TimeOut).', ...
          E.duration_s, out.tout(end));
end
E.model = mdl;
E.opt = opt;
E.n   = ts2mat(out.get('n'));
E.M_W = ts2mat(out.get('M_W'));
E.M_L = [];
if isempty(opt.n_fixed)                                   % load torque from the speed (characteristic)
    n = E.n(:,2);  t = E.n(:,1);
    switch opt.Load
        case 'fan',      ML = opt.M_B*(n/opt.n_B).*abs(n/opt.n_B);
        case 'constant', ML = opt.M_L0*tanh(n*2*pi/60/0.1);
        otherwise,       ML = 0*n;
    end
    ML = ML + opt.dM_L*0.5*(1 + tanh((t - opt.t_step)/0.5e-3)).*tanh(n*2*pi/60/0.1);
    E.M_L = [t, ML];
end
if strcmp(opt.Motor, 'asm')
    m = out.get('meas');
    for f = fieldnames(m)'
        E.meas.(f{1}) = ts2mat(m.(f{1}));
    end
end
if strcmp(opt.Motor, 'kloss'), E.M_kloss = ts2mat(out.get('M_kloss')); end
end

%% ========================= helper functions =========================
function add_grid(mdl, L, opt, z)
% Netz 3~ with grounded star point and Solver Configuration
add_block([L 'Quellen/Netz 3~'], [mdl '/Netz'], 'Position', [40 80 120 200], 'U_L', z(opt.U), 'f1', z(opt.f));
add_block([L 'Quellen/Sternpunkt (Erde)'], [mdl '/Erde'], 'Position', [140 240 180 270]);
add_block('nesl_utility/Solver Configuration', [mdl '/Solver'], 'Position', [40 240 100 270]);
pc(mdl, 'Netz', 'R', 4, 'Erde', 'L', 1);
pc(mdl, 'Solver', 'R', 1, 'Erde', 'L', 1);
end

function c = connection_option(connection)
% code value -> German popup option of the mask
if strcmp(connection, 'star'), c = 'Stern'; else, c = 'Dreieck'; end
end

function shaft_reference(mdl, blk)
% block with R at the shaft (behind the torque sensor) and C at the reference
pc(mdl, 'Messwelle', 'R', 1, blk, 'L', 1);
pc(mdl, blk, 'R', 1, 'Bezug', 'L', 1);
end

function pc(sys, a, sa, na, b, sb, nb)
% physical connection between port na on side sa of a and nb/sb of b
add_line(sys, port(sys, a, sa, na), port(sys, b, sb, nb), 'autorouting', 'on');
end

function h = port(sys, blk, side, nr)
ph = get_param([sys '/' blk], 'PortHandles');
if side == 'L', h = ph.LConn(nr); else, h = ph.RConn(nr); end
end

function log_signal(sys, src, name)
% Simulink output -> To Workspace "name" (timeseries, or struct for a bus)
add_block('simulink/Sinks/To Workspace', [sys '/TW_' name], 'VariableName', name, ...
    'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf');
add_line(sys, src, ['TW_' name '/1'], 'autorouting', 'on');
end

function x = ts2mat(ts)
% timeseries -> [t, y], duplicate time instants removed
y = squeeze(ts.Data);
if size(y, 1) ~= numel(ts.Time), y = y.'; end
[t, iu] = unique(ts.Time(:), 'last');
x = [t, y(iu, :)];
end
