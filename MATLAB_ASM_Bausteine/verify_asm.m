function [T, D] = verify_asm(opt)
%VERIFY_ASM Technical test cases of parts A and B with a report table (German output).
%   T = verify_asm()                           runs all tests and prints the report
%   [T, D] = verify_asm('Tests', ["A" "B1"])   only selected tests; the others are listed as
%                                              "nicht ausgeführt"
%   T = verify_asm('Print', false)             without console output
%
%   Tests (all simulations via run_asm, i.e. through the Simulink example models)
%     A    conductor loop at fixed slip s = 0, s_N, s_K, 1 (part A, ex_conductor_loop):
%          s = 0: rotor current and loop torque must vanish (exact, tolerance = rounding).
%          s > 0: loop torque averaged over whole rotor periods T2 = 1/(s*f1) against the
%          analytic value M = i2hat*l*Bhat*r*sin(phi2) (asmtools.loop_mean_torque).
%          Plus one consistency row N_S*M(s_K) = MK: the loop parameters are derived from MK and
%          sK, so this is a consistency check, not an independent validation.
%     B1   run-up without load step (part B, ex_kloss_startup): simulated steady speed against
%          the stable intersection of Kloss and load torque that is reachable from standstill
%          (asmtools.operating_point); run-up time to 0.9*n_N against a direct ode45 integration
%          of the same equation of motion.
%     B2   load step after settling (part B): settled before the step, speed before the step,
%          minimum after the step, speed dip, new steady operating point and settling time
%          against the computed expectation.
%     Z    supplement: the same load step with the dynamic space-vector model (ex_startup_load_step)
%          against the intersection of the T equivalent circuit and the load. Dip and settling
%          time of this model have no analytic reference and are listed as "Info".
%     R    rated point (information): Kloss torque at s_N against M_N (property of the example
%          data set, see asmtools.rated_point).
%
%   Returns T: table with the columns Test, Groesse, Sollwert, Istwert, Abweichung (Ist - Soll),
%   Toleranz (absolute, same unit), Einheit, Status ("bestanden" | "nicht bestanden" |
%   "nicht ausgeführt" | "Info") and Begruendung (reason for the tolerance or why a test was
%   not executed). D holds the raw results (run_asm results, ode45 reference, rated point).

arguments
    opt.Tests (1,:) string {mustBeMember(opt.Tests, ["A" "B1" "B2" "Z"])} = ["A" "B1" "B2" "Z"]
    opt.Print (1,1) logical = true
    opt.TimeOut (1,1) double {mustBePositive} = 300
end

S = asm_standard();
ns = S.ns;
rows = {};
D = struct();

%% A: conductor loop at fixed slip
s_N = (ns - S.n_N)/ns;
slips = {0, 's = 0'; s_N, sprintf('s = s_N = %.3g', s_N); S.sK, sprintf('s = s_K = %.3g', S.sK); 1, 's = 1'};
if any(opt.Tests == "A")
    try
        D.A = cell(1, size(slips, 1));
        for k = 1:size(slips, 1)
            P = asm_params('loop');  P.s_loop = slips{k, 1};
            R = run_asm(P, 'TimeOut', opt.TimeOut);
            D.A{k} = R;
            M = R.metrics;
            if slips{k, 1} == 0
                why = ['s = 0: keine Relativbewegung, induzierte Spannung und Strom exakt null; ' ...
                       'Toleranz nur Rundung'];
                rows(end+1, :) = row('A1', 's = 0: max |i_k| (Rotorstrom)', 0, M.i_max, 1e-9, 'A', why); %#ok<AGROW>
                rows(end+1, :) = row('A1', 's = 0: max |M_S| (Schleifenmoment)', 0, M.M_S_max, 1e-9, 'N·m', why); %#ok<AGROW>
            else
                why = sprintf(['Soll: î2·l·B̂·r·sin φ2 (analytisch, SPEC 3.1). Mittel über %d ganze ' ...
                               'Rotorperioden T2 = %.3g s. Erwartet ist Gleichheit bis auf Rundung: θ2 = s·ω1·t ' ...
                               'wird bei konstantem s exakt integriert, die Pulsation (2·s·f1) mittelt sich über ' ...
                               'ganze Perioden heraus; Toleranz 1e-6 relativ deckt die Interpolation zwischen ' ...
                               'Solverschritten ab'], M.n_periods, M.T2);
                rows(end+1, :) = row(sprintf('A%d', k), sprintf('%s: mittleres Schleifenmoment', slips{k, 2}), ...
                    M.M_S_mean_expected, M.M_S_mean, 1e-6*abs(M.M_S_mean_expected), 'N·m', why); %#ok<AGROW>
            end
        end
        Mk = D.A{3}.metrics;
        rows(end+1, :) = row('A5', 'Konsistenz: N_S·M̄_S(s_K) = MK', S.MK, Mk.N_S*Mk.M_S_mean, 1e-6*S.MK, 'N·m', ...
            ['Konsistenzprüfung, keine unabhängige Validierung: R2, L2σ der Schleife sind aus MK und sK ' ...
             'abgeleitet (asmtools.loop_parameters)']);
    catch err
        rows = [rows; not_run({'A1', 'A2', 'A3', 'A4', 'A5'}, err.message)];
    end
else
    rows = [rows; not_run({'A1', 'A2', 'A3', 'A4', 'A5'}, 'nicht ausgewählt (Option Tests)')];
end

%% B1: run-up without load step (Kloss)
tol_n = 1e-4*ns;              % 0.15 rpm
why_n = sprintf(['Soll: stabiler, aus n = 0 erreichbarer Schnittpunkt M_Kloss(n) = M_L(n) ' ...
                 '(asmtools.operating_point). Toleranz 0,01 %% von n_s = %.2g 1/min: stationärer Endwert, ' ...
                 'Solver-RelTol 1e-5, geglättete Last nur < 1e-6·M_B'], tol_n);
tol_t = 5e-4;                 % 0.5 ms = 5*MaxStep
why_t = ['Soll: direkte Integration derselben Bewegungsgleichung J·dΩ/dt = M_Kloss − M_L (ode45, ' ...
         'RelTol 1e-10) mit derselben Auswertung – Konsistenz der Lösungsverfahren, keine unabhängige ' ...
         'Physik. Toleranz 0,5 ms = 5·MaxStep: Zeitpunkte werden zwischen Solverschritten interpoliert'];
if any(opt.Tests == "B1")
    try
        P = asm_params('kloss');  P.dM_L = 0;  P.t_end = 1;
        R = run_asm(P, 'TimeOut', opt.TimeOut);
        D.B1 = R;
        ref = kloss_reference(R.params);
        D.B1_ref = ref;
        E = R.metrics.expected.before;
        rows(end+1, :) = row('B1', 'stationäre Drehzahl nach dem Hochlauf', E.n, R.metrics.final.n, tol_n, '1/min', why_n);
        rows(end+1, :) = row('B1', sprintf('Hochlaufzeit bis 0,9·n_N = %.0f 1/min', R.params.n_target), ...
            ref.metrics.startup.t_target, R.metrics.startup.t_target, tol_t, 's', why_t);
    catch err
        rows = [rows; not_run({'B1', 'B1'}, err.message)];
    end
else
    rows = [rows; not_run({'B1', 'B1'}, 'nicht ausgewählt (Option Tests)')];
end

%% B2: load step after settling (Kloss)
if any(opt.Tests == "B2")
    try
        P = asm_params('kloss');
        R = run_asm(P, 'TimeOut', opt.TimeOut);
        D.B2 = R;
        ref = kloss_reference(R.params);
        D.B2_ref = ref;
        LS = R.metrics.load_step;  E1 = R.metrics.expected.before;  E2 = R.metrics.expected.after;
        band = R.params.band;
        rows(end+1, :) = row('B2', 'vor dem Laststoß eingeschwungen (max. Abweichung)', 0, ...
            R.metrics.before_step.max_dev, band, '1/min', sprintf(['Fenster %.0f ms, endet %.0f ms vor t_stoß ' ...
            '(Laststoß mit 0,5 ms geglättet); Toleranzband ±%.2g 1/min (0,1 %% von n_s) wie für die ' ...
            'Einschwingzeit'], 1e3*R.params.window, 1e3*R.params.step_margin, band));
        rows(end+1, :) = row('B2', 'Drehzahl vor dem Laststoß', E1.n, LS.n_before, tol_n, '1/min', why_n);
        rows(end+1, :) = row('B2', 'minimale Drehzahl nach dem Laststoß', E2.n, LS.n_min, tol_n, '1/min', ...
            ['Soll: neuer Schnittpunkt mit M_L + ΔM_L, erreichbar vom alten Arbeitspunkt. Das Kloss-Modell ' ...
             'ist 1. Ordnung (keine elektrische Dynamik): monotoner Übergang ohne Unterschwingen, Minimum = neuer Arbeitspunkt']);
        rows(end+1, :) = row('B2', 'Drehzahleinbruch n_vor − n_min', E1.n - E2.n, LS.dn_dip, 2*tol_n, '1/min', ...
            'Differenz zweier Drehzahlen, daher doppelte Toleranz');
        rows(end+1, :) = row('B2', 'neuer stationärer Arbeitspunkt', E2.n, LS.n_new, tol_n, '1/min', why_n);
        why_s = sprintf(['Einschwingzeit = Zeit nach t_stoß, ab der |n − n_neu| ≤ %.2g 1/min bis zum Ende ' ...
                         'des Auswertefensters gilt (nur angegeben, wenn das Band auch im ganzen Endfenster ' ...
                         'gehalten wird). Soll aus ode45-Referenz mit derselben Auswertung; Toleranz 0,5 ms ' ...
                         '= 5·MaxStep'], band);
        rows(end+1, :) = row('B2', 'Einschwingzeit nach dem Laststoß', ref.metrics.load_step.t_settle, ...
            LS.t_settle, tol_t, 's', why_s);
    catch err
        rows = [rows; not_run({'B2', 'B2', 'B2', 'B2', 'B2', 'B2'}, err.message)];
    end
else
    rows = [rows; not_run({'B2', 'B2', 'B2', 'B2', 'B2', 'B2'}, 'nicht ausgewählt (Option Tests)')];
end

%% Z: supplement, dynamic space-vector model
tol_z = 5e-4*ns;              % 0.75 rpm
why_z = sprintf(['Soll: Schnittpunkt der stationären ESB-Kennlinie mit M_L (+ ΔM_L). Toleranz 0,05 %% ' ...
                 'von n_s = %.2g 1/min: Modell und ESB stimmen stationär auf 0,02 %% im Moment überein ' ...
                 '(BenchmarkTest V1), Restwelligkeit im Mittelungsfenster'], tol_z);
if any(opt.Tests == "Z")
    try
        R = run_asm(asm_params('lab'), 'TimeOut', opt.TimeOut);
        D.Z = R;
        LS = R.metrics.load_step;  E1 = R.metrics.expected.before;  E2 = R.metrics.expected.after;
        rows(end+1, :) = row('Z1', 'dyn. Modell: Drehzahl vor dem Laststoß', E1.n, LS.n_before, tol_z, '1/min', why_z);
        rows(end+1, :) = row('Z2', 'dyn. Modell: neuer stationärer Arbeitspunkt', E2.n, LS.n_new, tol_z, '1/min', why_z);
        rows(end+1, :) = info_row('Z3', 'dyn. Modell: Drehzahleinbruch n_vor − n_min', LS.dn_dip, '1/min', ...
            sprintf(['kein analytischer Sollwert: elektromagnetische Ausgleichsvorgänge führen zum Unterschwingen ' ...
                     '(statischer Unterschied %.3g 1/min)'], LS.dn_static));
        rows(end+1, :) = info_row('Z4', 'dyn. Modell: Einschwingzeit nach dem Laststoß', LS.t_settle, 's', ...
            sprintf('Toleranzband ±%.2g 1/min; NaN = nicht eingeschwungen', LS.band));
    catch err
        rows = [rows; not_run({'Z1', 'Z2', 'Z3', 'Z4'}, err.message)];
    end
else
    rows = [rows; not_run({'Z1', 'Z2', 'Z3', 'Z4'}, 'nicht ausgewählt (Option Tests)')];
end

%% R: rated point (information)
RP = asmtools.rated_point(S);
D.rated_point = RP;
rows(end+1, :) = {'R', 'Bemessungspunkt: Kloss-Moment bei s_N (Soll = M_N)', S.M_N, RP.M_kloss_sN, ...
    RP.M_kloss_sN - S.M_N, NaN, 'N·m', 'Info', ...
    sprintf(['Eigenschaft des Beispieldatensatzes (%+.1f %%): MK, sK sind abgeglichen, (n_N, M_N) nur Information. ' ...
             'Kloss erreicht M_N bei %.1f 1/min, das dynamische Modell bei %.1f 1/min'], ...
            100*RP.dev_rel, RP.n_at_MN, RP.n_at_MN_ec)};

T = cell2table(rows, 'VariableNames', {'Test', 'Groesse', 'Sollwert', 'Istwert', 'Abweichung', ...
                                       'Toleranz', 'Einheit', 'Status', 'Begruendung'});
T.Test = string(T.Test);  T.Groesse = string(T.Groesse);  T.Einheit = string(T.Einheit);
T.Status = string(T.Status);  T.Begruendung = string(T.Begruendung);
if opt.Print, print_report(T); end
end

%% ========================= helper functions =========================
function r = row(test, quantity, expected, actual, tol, unit, why)
% one test row: status from |actual - expected| <= tol
dev = actual - expected;
if isnan(actual) || isnan(expected)
    status = 'nicht bestanden';
    why = [why '; Istwert nicht bestimmbar (z. B. nicht erreicht / nicht eingeschwungen)'];
elseif abs(dev) <= tol
    status = 'bestanden';
else
    status = 'nicht bestanden';
end
r = {test, quantity, expected, actual, dev, tol, unit, status, why};
end

function r = info_row(test, quantity, actual, unit, why)
r = {test, quantity, NaN, actual, NaN, NaN, unit, 'Info', why};
end

function rows = not_run(tests, reason)
rows = cell(numel(tests), 9);
for k = 1:numel(tests)
    rows(k, :) = {tests{k}, '–', NaN, NaN, NaN, NaN, '', 'nicht ausgeführt', reason};
end
end

function ref = kloss_reference(P)
% direct integration of J*dOm/dt = M_Kloss(Om) - M_L(Om, t) with ode45 (same load model as the
% blocks: smoothed sign tanh(Om/0.1 rad/s), smoothed load step with 0.5 ms), then the same
% evaluation as run_asm (asmtools.speed_metrics)
J = P.J_M + P.J_L;
ws = 2*pi*P.ns/60;
Mk = @(w) asmtools.kloss_torque((ws - w)/ws, P.MK, P.sK);
if strcmp(P.load_type, 'fan')
    ML = @(w) P.M_L*(60*w/(2*pi)/P.n_B).*sqrt((60*w/(2*pi)/P.n_B).^2 + 1e-6);
else
    ML = @(w) P.M_L*tanh(w/0.1);
end
step = @(t) P.dM_L*0.5*(1 + tanh((t - P.t_step)/0.5e-3));
f = @(t, w) (Mk(w) - ML(w) - step(t).*tanh(w/0.1))/J;
[t, w] = ode45(f, [0 P.t_end], 0, odeset('RelTol', 1e-10, 'AbsTol', 1e-10, 'MaxStep', 1e-4));
n = 60*w/(2*pi);
if P.dM_L ~= 0 && P.t_step < P.t_end, ts = P.t_step; else, ts = NaN; end
ref.t = t;
ref.n = n;
ref.metrics = asmtools.speed_metrics(t, n, struct('n_target', P.n_target, 't_step', ts, ...
                                                  'window', P.window, 'band', P.band, 'margin', P.step_margin));
ref.metrics.load_step = ref.metrics.step;
end

function print_report(T)
% compact console report (German)
fprintf('\n=== Fachliche Testfälle (verify_asm) ===\n');
fprintf('%-4s %-58s %12s %12s %11s %10s %-6s %s\n', 'Test', 'Größe', 'Soll', 'Ist', 'Abweichung', 'Toleranz', 'Einh.', 'Status');
for k = 1:height(T)
    fprintf('%-4s %-58s %12s %12s %11s %10s %-6s %s\n', T.Test(k), extractBefore(T.Groesse(k) + blanks(58), 59), ...
            num(T.Sollwert(k)), num(T.Istwert(k)), num(T.Abweichung(k)), num(T.Toleranz(k)), T.Einheit(k), T.Status(k));
end
c = @(s) nnz(T.Status == s);
fprintf('Zusammenfassung: %d bestanden, %d nicht bestanden, %d nicht ausgeführt, %d Info\n', ...
        c("bestanden"), c("nicht bestanden"), c("nicht ausgeführt"), c("Info"));
fprintf('Begründungen der Toleranzen: Spalte "Begruendung" der Rückgabetabelle.\n\n');
end

function s = num(x)
if isnan(x), s = '–'; else, s = sprintf('%.6g', x); end
end
