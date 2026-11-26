function R = run_asm(P, opt)
%RUN_ASM Central simulation run without GUI: explicit parameter set in, result struct out.
%   R = run_asm()                       scenario 'lab' with asm_params('lab')
%   R = run_asm(P)                      P from asm_params(scenario), fields may be changed;
%                                       missing fields get the values of asm_params(P.scenario)
%   R = run_asm(P, 'TimeOut', 300)      computing time limit [s]
%
%   Scenarios (P.scenario, see asm_params)
%     'kloss'   part B: run-up and load step with the quasi-static Kloss model
%     'loop'    part A: conductor loop of two rotor bars at fixed slip P.s_loop
%     'lab'     dynamic space-vector model ASM Standard at the grid (basis of the GUI)
%     'slides'  slides 16-30: ideal rotating field, rotor at rest
%
%   Data flow
%     - All parameters reach the model ONLY via Simulink.SimulationInput (setBlockParameter,
%       setModelParameter); additional signals are logged via LoggingSpecification. The
%       example models are not modified (no set_param on the model, no save_system), have no
%       callbacks and do not read the base workspace.
%     - The motor mask is always set to "Benutzerdefiniert" together with explicit values, so
%       the mask initialization does not read parameter/asm_standard.m behind the back of the
%       caller. With P.param_set = 'standard' the motor values of asm_standard.m are copied
%       into P first (warning 'asm:standard' if other values were given).
%     - Results and the parameters actually used are returned in R and passed explicitly to
%       evaluation, plots and animation (e.g. asmtools.field_animation(R.field_data, R.field_par)).
%       run_asm neither reads nor writes the base workspace.
%
%   Result R
%     scenario, model, params (all values used, derived fields recomputed), solver (Solver,
%     RelTol, MaxStep as passed), sim_input (the Simulink.SimulationInput actually simulated),
%     duration_s
%     time          time series (columns, common time grid t):
%                   lab:    t, n [rpm], Om [rad/s], M [N*m] (air gap), M_W [N*m] (shaft),
%                           M_L [N*m] (load characteristic), s [-] (with f1), i_abc [A] (phase
%                           currents from the space vector i1), I_eff [A], psi_h, i2b, th_mech,
%                           phi_el, Bhat
%                   kloss:  t, n, Om, M (Kloss motor torque), M_W, M_L, s
%                   loop:   t, B_k, i_k, F_k, M_S, B_perp, phi2, i2hat, theta2
%                   slides: t, B_perp [T] (slide convention), i_bar [A] (bar 1/2, positive out
%                           of the drawing plane), F [N] (bar 1/2), M_S [N*m], phi_el, theta2
%     field_data, field_par   input for asmtools.cross_section_state/draw_cross_section (lab,
%                   slides), otherwise []
%     torque_speed  t, n, M, M_L for asmtools.torque_speed_plot (lab, kloss), otherwise []
%     steady_state  stationary characteristic s, n, M (lab: T equivalent circuit, kloss: Kloss)
%     metrics       scenario-specific key figures, for lab/kloss in addition
%                     startup      run-up time to n_target = n_target_rel*n_N (fixed target,
%                                  "nicht erreicht" if not exceeded before the load step)
%                     before_step  steady speed before the load step (or at the end)
%                     load_step    n_before, n_min/t_min, n_max/t_max, dn_dip, undershoot,
%                                  overshoot, n_new, dn_static, t_settle, settled, final_valid
%                                  (NaN with reason if the final window is too short)
%                     expected     stable reachable intersection motor/load before and after
%                                  the step (lab: equivalent circuit, kloss: Kloss formula);
%                                  standstill = true: no reachable operating point (no start/stall)
%                   (definitions: asmtools.speed_metrics, asmtools.operating_point)
%     notes         cell array with German notes on plausibility (shown in the GUI)
%
%   Example
%     P = asm_params('kloss');  P.dM_L = 0;  R = run_asm(P);
%     plot(R.time.t, R.time.n), R.metrics.startup
%
%   Sources: Hagl, R.: Elektrische Antriebstechnik. Hanser, Muenchen 2013; Densborn, lecture
%   notes "DS-Asynchron-Motor" (DHBW Mannheim). All default values are example values.

arguments
    P struct = asm_params('lab')
    opt.TimeOut (1,1) double {mustBePositive} = 300
end

[P, notes] = complete_params(P);
asmapp.check_value(P);

load_system('asm_blocks_lib');
switch P.scenario
    case 'lab',    R = run_lab(P, opt);
    case 'kloss',  R = run_kloss(P, opt);
    case 'loop',   R = run_loop(P, opt);
    case 'slides', R = run_slides(P, opt);
end
R.scenario = P.scenario;
R.params = P;
R.notes = [notes, R.notes];
R = orderfields(R);
end

%% ========================= parameters =========================
function [P, notes] = complete_params(Pin)
% add missing fields, check choices, enforce the standard motor, derived quantities
if isfield(Pin, 'scenario'), sc = char(Pin.scenario); else, sc = 'lab'; end
sc = choice(sc, {'lab', 'kloss', 'loop', 'slides'}, 'scenario');
P0 = asm_params(sc);
P = P0;
for f = fieldnames(Pin)'
    if ~strcmp(f{1}, 'info'), P.(f{1}) = Pin.(f{1}); end
end
P.scenario   = sc;
P.param_set  = choice(P.param_set, {'standard', 'custom'}, 'param_set');
P.connection = choice(P.connection, {'star', 'delta'}, 'connection');
P.phase_seq  = choice(P.phase_seq, {'L1-L2-L3', 'L1-L3-L2'}, 'phase_seq');
P.load_type  = choice(P.load_type, {'constant', 'fan'}, 'load_type');
P.phi2_mode  = choice(P.phi2_mode, {'fixed', 'impedance'}, 'phi2_mode');
if ~(isequal(P.conv_phi2, 1) || isequal(P.conv_phi2, -1))
    error('asm:value', 'Ungültige Vorzeichenkonvention conv_phi2 = %g (erlaubt: +1 | -1).', P.conv_phi2);
end

notes = {};
S = asm_standard();
derived = {'ns', 'w1', 'N1xi1', 'U20', 'R2_S', 'L2s_S', 'n_B', 'n_target', 'band'};
if strcmp(P.param_set, 'standard')
    motor = setdiff(fieldnames(S), [{'info'}, derived], 'stable')';
    differ = motor(cellfun(@(f) ~isequal(P.(f), S.(f)), motor));
    if ~isempty(differ)
        m = sprintf(['Parametersatz "Standard": Motorwerte aus parameter/asm_standard.m verwendet, ' ...
                     'Eingaben für %s ignoriert.'], strjoin(differ, ', '));
        warning('asm:standard', '%s', m);
        notes{end+1} = m;
    end
    for f = motor, P.(f{1}) = S.(f{1}); end
end
% derived quantities, always recomputed from the inputs actually used (units: rpm, rad/s)
D.ns    = 60*P.f1/P.p;
D.w1    = 2*pi*P.f1;
D.N1xi1 = P.p*(P.U_N/sqrt(3)*sqrt(2)/(2*pi*P.f_N))/(2*P.Bhat_N*P.l*P.r);   % as mask ASM Standard
L = asmtools.loop_parameters(P);                     % conductor loop from MK, sK and geometry
D.U20   = L.U20;
D.R2_S  = L.R2_S;
D.L2s_S = L.L2s_S;
D.n_B   = P.n_N/(60*P.f_N/P.p)*D.ns;                 % reference speed of the fan load (= n_N at f_N)
D.n_target = P.n_target_rel*P.n_N;                  % fixed run-up target (default 0.9*n_N)
D.band     = P.band_rel*D.ns;                       % tolerance band for settling [rpm]
ignored = {};
for f = derived
    v = D.(f{1});
    given = isfield(Pin, f{1}) && ~isempty(Pin.(f{1}));
    if given && ~same(Pin.(f{1}), v) && ~(isfield(P0, f{1}) && isequal(Pin.(f{1}), P0.(f{1})))
        ignored{end+1} = f{1}; %#ok<AGROW>
    end
    P.(f{1}) = v;
end
if ~isempty(ignored)
    m = sprintf(['Abgeleitete Größen %s werden aus den Eingaben neu berechnet; die übergebenen Werte ' ...
                 'wurden ignoriert.'], strjoin(ignored, ', '));
    warning('asm:derived', '%s', m);
    notes{end+1} = m;
end
if strcmp(P.scenario, 'loop') && isempty(P.t_end)   % loop: whole rotor periods T2 = 1/(s*f1)
    if P.s_loop ~= 0, P.t_end = P.loop_periods/(abs(P.s_loop)*P.f1); else, P.t_end = 0.1; end
end
end

function tf = same(a, b)
tf = isnumeric(a) && isscalar(a) && abs(a - b) <= 1e-12*max(1, abs(b));
end

function w = choice(w, options, name)
w = char(w);
if ~any(strcmp(w, options))
    error('asm:value', 'Ungültige Auswahl für %s: "%s" (erlaubt: %s).', name, w, strjoin(options, ' | '));
end
end

%% ========================= scenario lab (dynamic model) =========================
function R = run_lab(P, opt)
m = 'ex_startup_load_step';
load_system(m);
b = @(n) [m '/' n];
z = @(x) sprintf('%.17g', x);
in = Simulink.SimulationInput(m);

% grid
dp = get_param(b('Netz'), 'DialogParameters');
seq = dp.phase_seq.Enum{1 + strcmp(P.phase_seq, 'L1-L3-L2')};
in = in.setBlockParameter(b('Netz'), 'U_L', z(P.U_L), b('Netz'), 'f1', z(P.f1), ...
                          b('Netz'), 'phase_seq', seq, b('Netz'), 't_on', z(P.t_on));
% motor: always "Benutzerdefiniert" with explicit values
in = in.setBlockParameter(b('Motor'), 'param_set', 'Benutzerdefiniert', ...
                          b('Motor'), 'connection', connection_option(P.connection), b('Motor'), 'n0', '0');
for f = {'U_N', 'f_N', 'p', 'R1', 'L1s', 'Lh', 'R2b', 'L2sb', 'J_M', 'k_R', 'l', 'r', 'N2', 'Bhat_N'}
    in = in.setBlockParameter(b('Motor'), f{1}, z(P.(f{1})));
end
% sensors follow grid frequency and number of pole pairs
in = in.setBlockParameter(b('Drehzahlmesser'), 'ns', z(P.ns), b('Strommessung'), 'f_meas', z(P.f1), ...
                          b('Leistungsmesser'), 'f_meas', z(P.f1), b('Spannungsmessung'), 'f_meas', z(P.f1));
in = set_load(in, b, P, z);
% simulation and additional logging
in = in.setModelParameter('StopTime', z(P.t_end), 'TimeOut', opt.TimeOut, 'SimscapeLogType', 'none');
ls = Simulink.Simulation.LoggingSpecification;
addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Motor')), 1);          % measurement bus
addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Messwelle')), 1);      % shaft torque
addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Strommessung')), 2);   % I_eff
in.LoggingSpecification = ls;

[out, R] = simulate(in, m, P);

meas = logged(out, b('Motor'));
t = unique(meas.n.Time(:));
v = @(ts) on_grid(ts, t);
vz = 1 - 2*strcmp(P.phase_seq, 'L1-L3-L2');            % direction of the rotating field
Z.t = t;
Z.n = v(meas.n);   Z.Om = v(meas.Om);   Z.M = v(meas.M);
Z.M_W = v(logged(out, b('Messwelle')));
Z.I_eff = v(logged(out, b('Strommessung')));
Z.s = (vz*P.ns - Z.n)/(vz*P.ns);
i1 = v(meas.i1);  i1 = i1(:,1) + 1j*i1(:,2);  a = exp(2j*pi/3);
Z.i_abc = [real(i1), real(a^2*i1), real(a*i1)];        % phase currents U, V, W (star: = line currents)
Z.psi_h = v(meas.psi_h);  Z.i2b = v(meas.i2b);  Z.th_mech = v(meas.th_mech);
Z.phi_el = v(meas.phi_el);  Z.Bhat = v(meas.Bhat);
Z.M_L = vz*load_torque(P, vz*Z.n, t) + P.k_R*Z.Om;      % load characteristic and friction k_R*Om
R.time = Z;

R.field_data = struct('t', t, 'psi_h', Z.psi_h, 'i2b', Z.i2b, 'th_mech', Z.th_mech);
R.field_par = struct('p', P.p, 'N2', P.N2, 'l', P.l, 'r', P.r, 'N1xi1', P.N1xi1, ...
                     'k1', 1, 'k2', 1 + round(P.N2/(2*P.p)), 'bar1_angle', -pi/2);
R.torque_speed = struct('t', t, 'n', Z.n, 'M', Z.M, 'M_L', Z.M_L);

% stationary characteristic (T equivalent circuit) with the current values
ec = @(s) asmtools.equivalent_circuit(P, s, 'U', P.U_L, 'f', P.f1, 'Connection', P.connection);
s_v = linspace(1, 0, 601);
R.steady_state = struct('s', s_v, 'n', vz*P.ns*(1 - s_v), 'M', vz*ec(s_v));
s_f = linspace(1e-4, 1, 20000);
[M_K, iK] = max(ec(s_f));

K = speed_evaluation(P, t, vz*Z.n, @(n) ec((P.ns - n)/P.ns), 'ESB', P.k_R);
K.ns = P.ns;
K.n_end = K.final.n*vz;
K.s_end = (vz*P.ns - K.n_end)/(vz*P.ns);
K.M_end = window_mean(t, Z.M, t(end) - P.window, t(end));
K.I_eff_end = window_mean(t, Z.I_eff, t(end) - P.window, t(end));
K.M_A = ec(1);
K.M_K = M_K;
K.s_K = s_f(iK);
K.n_K = P.ns*(1 - K.s_K);
K.M_max_dyn = max(abs(Z.M));
R.metrics = orderfields(K);

% notes on plausibility (German)
h = {};
if strcmp(P.connection, 'delta') && P.U_L > 1.1*P.U_N/sqrt(3)
    h{end+1} = sprintf(['Dreieckschaltung: Strangspannung %g V statt U_N/√3 = %.0f V – die Wicklung ' ...
                        'liegt an der %.2f-fachen Bemessungs-Strangspannung.'], P.U_L, P.U_N/sqrt(3), P.U_L*sqrt(3)/P.U_N);
end
if abs(P.f1 - P.f_N) > 1e-9
    h{end+1} = sprintf(['Netzfrequenz f1 = %g Hz ≠ Bemessungsfrequenz f_N = %g Hz: Schlupf aus n und f1 ' ...
                        'berechnet (der Messbus-Schlupf s des Motors bezieht sich auf f_N).'], P.f1, P.f_N);
end
if K.s_K >= 1 - 1e-3
    h{end+1} = 'Kippschlupf s_K ≥ 1: das Kippmoment liegt nicht im Motorbereich (M_K = M_A).';
end
R.notes = [step_notes(P, K), h];
end

%% ========================= scenario kloss (part B) =========================
function R = run_kloss(P, opt)
m = 'ex_kloss_startup';
load_system(m);
b = @(n) [m '/' n];
z = @(x) sprintf('%.17g', x);
in = Simulink.SimulationInput(m);
in = in.setBlockParameter(b('Motor'), 'MK', z(P.MK), b('Motor'), 'sK', z(P.sK), b('Motor'), 'ns', z(P.ns), ...
                          b('J_M'), 'J', z(P.J_M), b('J_M'), 'n0', '0', b('Drehzahlmesser'), 'ns', z(P.ns));
in = set_load(in, b, P, z);
in = in.setModelParameter('StopTime', z(P.t_end), 'TimeOut', opt.TimeOut, 'SimscapeLogType', 'none');
ls = Simulink.Simulation.LoggingSpecification;
addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Drehzahlmesser')), 1);   % n
addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Motor')), 1);            % M (Kloss)
addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Motor')), 2);            % s
addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Messwelle')), 1);        % shaft torque
in.LoggingSpecification = ls;

[out, R] = simulate(in, m, P);

n_ts = logged(out, b('Drehzahlmesser'), 1);
t = unique(n_ts.Time(:));
v = @(ts) on_grid(ts, t);
Z.t = t;
Z.n = v(n_ts);
Z.Om = Z.n*2*pi/60;
Z.M = v(logged(out, b('Motor'), 1));
Z.s = v(logged(out, b('Motor'), 2));
Z.M_W = v(logged(out, b('Messwelle'), 1));
Z.M_L = load_torque(P, Z.n, t);
R.time = Z;
R.field_data = [];
R.field_par = [];
R.torque_speed = struct('t', t, 'n', Z.n, 'M', Z.M, 'M_L', Z.M_L);
kl = @(s) asmtools.kloss_torque(s, P.MK, P.sK);
s_v = linspace(1, 0, 601);
R.steady_state = struct('s', s_v, 'n', P.ns*(1 - s_v), 'M', kl(s_v));

K = speed_evaluation(P, t, Z.n, @(n) kl((P.ns - n)/P.ns), 'Kloss', 0);
K.ns = P.ns;
K.n_end = K.final.n;
K.s_end = (P.ns - K.n_end)/P.ns;
K.M_end = window_mean(t, Z.M, t(end) - P.window, t(end));
K.M_A = kl(1);
K.M_K = P.MK;
K.s_K = P.sK;
K.n_K = P.ns*(1 - P.sK);
K.M_max_dyn = max(abs(Z.M));
R.metrics = orderfields(K);

h = {};
if abs(P.U_L - P.U_N) > 1e-9 || strcmp(P.connection, 'delta') || strcmp(P.phase_seq, 'L1-L3-L2')
    h{end+1} = ['Kloss-Modell: MK und sK gelten für Bemessungsspannung und Sternschaltung; Netzspannung, ' ...
                'Schaltung und Phasenfolge werden nicht berücksichtigt.'];
end
R.notes = [step_notes(P, K), h];
end

%% ========================= scenario loop (part A) =========================
function R = run_loop(P, opt)
m = 'ex_conductor_loop';
load_system(m);
b = @(n) [m '/' n];
z = @(x) sprintf('%.17g', x);
s = P.s_loop;
if s ~= 0, T2 = 1/(abs(s)*P.f1); else, T2 = Inf; end
modes = {'aus Rotorimpedanz', 'fest'};
in = Simulink.SimulationInput(m);
in = in.setBlockParameter(b('Schlupf'), 'Value', z(s), ...
    b('Schleife'), 'Bhat', z(P.Bhat), b('Schleife'), 'l', z(P.l), b('Schleife'), 'r', z(P.r), ...
    b('Schleife'), 'f1', z(P.f1), b('Schleife'), 'p', z(P.p), b('Schleife'), 'R2_S', z(P.R2_S), ...
    b('Schleife'), 'L2s_S', z(P.L2s_S), b('Schleife'), 'conv_phi2', sprintf('%+d', P.conv_phi2), ...
    b('Schleife'), 'phi2_mode', modes{1 + strcmp(P.phi2_mode, 'fixed')}, b('Schleife'), 'phi2_fix', z(P.phi2_fix));
in = in.setModelParameter('StopTime', z(P.t_end), 'TimeOut', opt.TimeOut);
ls = Simulink.Simulation.LoggingSpecification;
ports = struct('B_k', 1, 'i_k', 2, 'F_k', 3, 'M_S', 5, 'B_perp', 6, 'phi2', 7, 'i2hat', 8, 'theta2', 9);
for f = fieldnames(ports)'
    addSignalsToLog(ls, Simulink.SimulationData.BlockPath(b('Schleife')), ports.(f{1}));
end
in.LoggingSpecification = ls;

[out, R] = simulate(in, m, P);
ref = logged(out, b('Schleife'), ports.M_S);
t = unique(ref.Time(:));
Z.t = t;
for f = fieldnames(ports)'
    Z.(f{1}) = on_grid(logged(out, b('Schleife'), ports.(f{1})), t);
end
R.time = Z;
R.field_data = [];
R.field_par = [];
R.torque_speed = [];
R.steady_state = [];

% Mean over whole rotor periods T2 = 1/(|s|*f1), ending at t_end. The loop model is algebraic in
% theta2 = s*w1*t (no electrical time constant, no transient), so the window may start at t = 0.
% Without at least one whole period (t_end < T2, or s = 0 without any period) no mean is given.
if isfinite(T2)
    n_per = floor((t(end) - t(1))/T2 + 1e-9);
else
    n_per = 0;
end
[M_exp, i2hat_exp, phiZ_exp] = asmtools.loop_mean_torque(s, P);
K.s = s;
K.T2 = T2;
K.n_periods = n_per;
if n_per >= 1
    t0 = t(end) - n_per*T2;
    K.window = [t0, t(end)];
    K.M_S_mean = window_mean(t, Z.M_S, t0, t(end));
else
    K.window = [NaN, NaN];
    K.M_S_mean = NaN;
end
K.M_S_mean_expected = M_exp;
N_S = P.N2/2;                                          % equal loops in the cage
K.M_kloss_per_loop = asmtools.kloss_torque(s, P.MK, P.sK)/N_S;
K.i2hat = Z.i2hat(end);
K.i2hat_expected = i2hat_exp;
K.phiZ_deg = rad2deg(phiZ_exp);
K.phi2_deg = rad2deg(Z.phi2(end));
K.i_max = max(abs(Z.i_k(:)));
K.M_S_max = max(abs(Z.M_S));
K.N_S = N_S;
R.metrics = orderfields(K);
R.notes = {};
if s == 0
    R.notes{end+1} = 's = 0: keine Rotorperiode, kein Mittelwert; geprüft werden Strom und Moment direkt.';
elseif n_per < 1
    R.notes{end+1} = sprintf(['t_End = %g s ist kürzer als eine Rotorperiode T2 = %g s: kein Mittelwert ' ...
                              'des Schleifenmoments.'], P.t_end, T2);
end
end

%% ========================= scenario slides 16-30 =========================
function R = run_slides(P, opt)
m = 'ex_slides16_30_rotor_bars';
load_system(m);
b = @(n) [m '/' n];
z = @(x) sprintf('%.17g', x);
dp = get_param(b('Drehfeld'), 'DialogParameters');
modes = dp.phi2_mode.Enum;                             % 'aus Rotorimpedanz (...)' | 'fest'
mode = modes{1 + strcmp(P.phi2_mode, 'fixed')};
in = Simulink.SimulationInput(m);
in = in.setBlockParameter(b('Drehfeld'), 'f1', z(P.f1), b('Drehfeld'), 'Bhat', z(P.Bhat), ...
                          b('Drehfeld'), 'phi2_mode', mode, b('Drehfeld'), 'phi2_fix', z(P.phi2_fix));
in = in.setModelParameter('StopTime', z(P.t_end), 'TimeOut', opt.TimeOut);
[out, R] = simulate(in, m, P);

D = asmtools.field_log_data(out.get('field_display_log'));
w = @(blk, n) str2double(get_param(b(blk), n));        % geometry as in probe and display of the model
par = struct('p', w('Anzeige', 'p'), 'N2', w('Anzeige', 'N2'), 'l', w('Anzeige', 'l'), ...
             'r', w('Anzeige', 'r'), 'N1xi1', w('Anzeige', 'N1xi1'), ...
             'k1', w('Sonde', 'k1'), 'k2', w('Sonde', 'k2'), 'bar1_angle', w('Anzeige', 'bar1_angle')*pi/180);
C = asmtools.cross_section_state(D, par, D.t);
ks = [par.k1 par.k2];
% slide convention as the rotor bar probe: current out of the drawing plane positive, the loop
% normal turns with it, B_perp = -Bhat*sin(gamma_1 - phi_el) (SPEC section 13)
R.time = struct('t', D.t, 'B_perp', -C.B_perp, 'i_bar', C.i_slide(:, ks), 'F', C.F(:, ks), ...
                'M_S', C.M_S, 'phi_el', C.phi_el, 'theta2', C.theta2);
R.field_data = D;
R.field_par = par;
R.torque_speed = [];
R.steady_state = [];

s = str2double(get_param(b('Drehfeld'), 's'));
T2 = 1/(abs(s)*P.f1);                                  % period of the field relative to the rotor
K.ns = 60*P.f1/par.p;
K.s = s;
K.ihat_bar = max(abs(C.i_slide(:)));
K.Bhat = mean(C.Bhat);
K.phi2_deg = rad2deg(window_mean(D.t, C.phi2, D.t(1), D.t(end)));
K.phiZ_deg = K.phi2_deg - 90;
R.notes = {};
if D.t(end) - D.t(1) >= T2*(1 - 1e-9)                  % mean over the last whole field revolution
    K.M_S_mean = window_mean(D.t, C.M_S, D.t(end) - T2, D.t(end));
else
    K.M_S_mean = NaN;
    R.notes{end+1} = sprintf(['t_End = %g s ist kürzer als eine Feldumdrehung (%g s): kein Mittelwert ' ...
                              'des Schleifenmoments.'], P.t_end, T2);
end
R.metrics = orderfields(K);
end

%% ========================= evaluation =========================
function K = speed_evaluation(P, t, n, M_motor, model_name, k_R)
% run-up and load-step metrics with fixed definitions plus the expected operating points
if P.dM_L ~= 0 && P.t_step < P.t_end, t_step = P.t_step; else, t_step = NaN; end
SM = asmtools.speed_metrics(t, n, struct('n_target', P.n_target, 't_step', t_step, ...
                                         'window', P.window, 'band', P.band, 'margin', P.step_margin, ...
                                         'step_sign', sign(P.dM_L)));
K.startup = SM.startup;
K.before_step = SM.before_step;
K.final = SM.final;
K.load_step = SM.step;
% expected: stable intersection reachable from standstill, then from the old operating point
Om = @(n) n*2*pi/60;
ML1 = @(n) load_torque(P, n, -Inf) + k_R*Om(n);
op1 = asmtools.operating_point(M_motor, ML1, P.ns, 0);
E = struct('model', model_name, 'before', op1, 'after', []);
if isfinite(t_step)
    ML2 = @(n) load_torque(P, n, Inf) + k_R*Om(n);
    E.after = asmtools.operating_point(M_motor, ML2, P.ns, op1.n);
end
K.expected = E;
end

function h = step_notes(P, K)
% German notes on the run-up and the load step
h = {};
if ~K.startup.reached
    h{end+1} = sprintf('Hochlaufziel %.0f 1/min (%.0f %% von n_N) vor dem Laststoß nicht erreicht.', ...
                       P.n_target, 100*P.n_target_rel);
end
E = K.expected;
if E.before.standstill
    h{end+1} = ['Kein erreichbarer stabiler Arbeitspunkt im Motorbereich: das Lastmoment ist im Stillstand ' ...
                'mindestens so groß wie das Anzugsmoment, der Motor läuft nicht an.'];
end
if ~isempty(E.after) && E.after.standstill
    h{end+1} = 'Nach dem Laststoß kein stabiler Arbeitspunkt im Motorbereich: der Motor kippt und bleibt stehen.';
end
if P.dM_L ~= 0 && P.t_step >= P.t_end
    h{end+1} = sprintf('Der Laststoß bei t = %g s liegt nach dem Simulationsende t_End = %g s.', P.t_step, P.t_end);
end
if ~isempty(K.load_step)
    if ~K.load_step.settled_before
        h{end+1} = 'Vor dem Laststoß noch nicht eingeschwungen: Drehzahleinbruch nur eingeschränkt aussagekräftig.';
    end
    if ~K.load_step.final_valid
        h{end+1} = sprintf('Kein neuer stationärer Arbeitspunkt bestimmbar: %s.', K.load_step.reason);
    elseif ~K.load_step.settled
        h{end+1} = sprintf('Nach dem Laststoß nicht im Toleranzband ±%.2g 1/min eingeschwungen.', K.load_step.band);
    end
end
end

function ML = load_torque(P, n, t)
% load torque as modelled in the load blocks (smoothed sign functions as in the .ssc files)
%   t = -Inf: before the load step, t = Inf: after the load step, otherwise smoothed step
Om = n*2*pi/60;
sgn = tanh(Om/0.1);
if strcmp(P.load_type, 'fan')
    x = n/P.n_B;
    ML = P.M_L*x.*sqrt(x.^2 + 1e-6);
else
    ML = P.M_L*sgn;
end
if P.dM_L ~= 0
    if isscalar(t) && isinf(t), step = double(t > 0); else, step = 0.5*(1 + tanh((t - P.t_step)/0.5e-3)); end
    ML = ML + P.dM_L*step.*sgn;
end
end

function in = set_load(in, b, P, z)
% load blocks of the lab and Kloss models (same block names)
constant = strcmp(P.load_type, 'constant');
in = in.setBlockParameter(b('Last_konstant'), 'M_L0', z(constant*P.M_L), ...
                          b('Luefter'), 'M_B', z(~constant*P.M_L), b('Luefter'), 'n_B', z(P.n_B), ...
                          b('Laststoss'), 't_step', z(P.t_step), b('Laststoss'), 'dM_L', z(P.dM_L), ...
                          b('Last_J'), 'J', z(P.J_L), b('Last_J'), 'n0', '0');
end

function c = connection_option(connection)
% code value -> German popup option of the mask
if strcmp(connection, 'star'), c = 'Stern'; else, c = 'Dreieck'; end
end

%% ========================= helper functions =========================
function [out, R] = simulate(in, m, P)
% solver settings explicitly from P (the saved model values are not used)
in = in.setModelParameter('MaxStep', sprintf('%.17g', P.max_step), 'RelTol', sprintf('%.17g', P.rel_tol));
t0 = tic;
out = sim(in);
R.duration_s = toc(t0);
if isprop(out, 'ErrorMessage') && ~isempty(out.ErrorMessage)
    error('asm:simulation', '%s', out.ErrorMessage);
end
if out.tout(end) < P.t_end*(1 - 1e-9)
    error('asm:simulation', 'Simulation nach %.0f s abgebrochen bei t = %.4g s (Zeitgrenze TimeOut).', ...
          R.duration_s, out.tout(end));
end
R.model = m;
R.solver = struct('Solver', get_param(m, 'Solver'), 'RelTol', P.rel_tol, 'MaxStep', P.max_step);
R.sim_input = in;                                      % exactly what was passed to the model
end

function x = logged(out, block_path, port)
% logged signal of output port (default 1) of block_path (LoggingSpecification) from out.logsout
if nargin < 3, port = []; end
L = out.logsout;
for k = 1:L.numElements
    e = L{k};
    if strcmp(e.BlockPath.getBlock(1), block_path) && (isempty(port) || e.PortIndex == port)
        x = e.Values;
        return;
    end
end
error('asm:log', 'Kein Protokoll für %s.', block_path);
end

function y = on_grid(ts, t)
% timeseries on the time grid t (duplicate time instants at events: last value)
d = squeeze(ts.Data);
if size(d, 1) ~= numel(ts.Time), d = d.'; end
[tt, iu] = unique(ts.Time(:), 'last');
y = interp1(tt, d(iu, :), t, 'linear', 'extrap');
end

function m = window_mean(t, y, t0, t1)
% time-weighted mean of y over [t0, t1] (non-uniform time grid)
t0 = max(t0, t(1));
if t1 <= t0 || numel(t) < 2, m = mean(y); return; end
tt = linspace(t0, t1, 20001)';
[tu, iu] = unique(t(:), 'last');
yy = interp1(tu, y(iu, :), tt);
m = trapz(tt, yy)/(t1 - t0);
end
