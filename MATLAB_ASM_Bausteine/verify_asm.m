function [T, D] = verify_asm(opt)
%VERIFY_ASM Technical test cases of parts A and B with a report table (German output).
%   T = verify_asm()                           runs all tests and prints the report
%   [T, D] = verify_asm('Tests', ["A" "B1"])   only selected tests; the others are "abgewählt"
%   T = verify_asm('Print', false)             without console output
%   T = verify_asm('ErrorOnFailure', true)     throws 'asm:verify' if any row is "nicht bestanden",
%                                              "Fehler" or "nicht verfügbar" (for batch runs)
%
%   Tests (all simulations via run_asm, i.e. through the Simulink example models)
%     A    conductor loop at fixed slip s = 0, s_N, s_K, 1 (part A, ex_conductor_loop):
%          s = 0: rotor current and loop torque must vanish (no rotor period is computed).
%          s > 0: loop torque averaged over whole rotor periods T2 = 1/(s*f1) against the
%          analytic value M = i2hat*l*Bhat*r*sin(phi2) (asmtools.loop_mean_torque).
%          A5: N_S*M(s_K) = MK. The loop parameters are derived from MK and sK, so A5 is a
%          consistency check, not an independent validation.
%     B1   run-up without load step (part B, ex_kloss_startup): steady speed against the stable
%          intersection of Kloss and load torque reachable from standstill
%          (asmtools.operating_point); run-up time to 0.9*n_N against a direct ode45 integration
%          of the same equation of motion (comparison of two implementations).
%     B2   load step after settling (part B): settled before the step, speed before the step,
%          minimum after the step, dip, new steady operating point and settling time.
%     Z    supplement: the same load step with the dynamic space-vector model (ex_startup_load_step)
%          against the intersection of the T equivalent circuit and the load. Dip and settling
%          time have no independent reference and are "Info".
%     R    rated point (information, property of the example data set).
%
%   Status values (column Status)
%     "bestanden"         |Ist - Soll| <= Toleranz
%     "nicht bestanden"   outside the tolerance, or Soll/Ist not determinable (reason given)
%     "Fehler"            the selected test was aborted (simulation error, time limit, exception);
%                         reason with error identifier and message
%     "abgewählt"         deliberately not selected (option Tests)
%     "nicht verfügbar"   required product or generated file missing (reason given)
%     "Info"              value without independent reference, not a test
%   Only "bestanden" counts as passed. Every test keeps the same rows in every case, so an abort
%   never leaves partial or duplicated rows.
%
%   Returns T: table with Test, Groesse, Sollwert, Istwert, Abweichung (Ist - Soll), Toleranz
%   (absolute, same unit), Einheit, Status, Begruendung. D holds the raw results.

arguments
    opt.Tests (1,:) string {mustBeMember(opt.Tests, ["A" "B1" "B2" "Z"])} = ["A" "B1" "B2" "Z"]
    opt.Print (1,1) logical = true
    opt.TimeOut (1,1) double {mustBePositive} = 300
    opt.ErrorOnFailure (1,1) logical = false
end

S = asm_standard();
ns = S.ns;
s_N = (ns - S.n_N)/ns;
missing = availability();
D = struct();
rows = cell(0, 9);

%% A: conductor loop at fixed slip
slips = {0, 's = 0'; s_N, sprintf('s = s_N = %s', de(s_N, '%.3g')); ...
         S.sK, sprintf('s = s_K = %s', de(S.sK, '%.3g')); 1, 's = 1'};
D.A = cell(1, 4);
defs = {'A1', 's = 0: max |i_k| (Rotorstrom)'; 'A1', 's = 0: max |M_S| (Schleifenmoment)'};
[r, D.A{1}] = run_group(defs, any(opt.Tests == "A"), missing, @() case_loop(0));
rows = [rows; r];
for k = 2:4
    defs = {sprintf('A%d', k), sprintf('%s: mittleres Schleifenmoment', slips{k, 2})};
    [r, D.A{k}] = run_group(defs, any(opt.Tests == "A"), missing, @() case_loop(slips{k, 1}));
    rows = [rows; r]; %#ok<AGROW>
end
defs = {'A5', 'Konsistenz: N_S·M̄_S(s_K) = MK'};
if any(opt.Tests == "A") && isempty(missing) && isempty(D.A{3})
    rows = [rows; status_rows(defs, 'Fehler', 'hängt von A3 ab, A3 wurde abgebrochen')];
else
    rows = [rows; run_group(defs, any(opt.Tests == "A"), missing, @() case_consistency(D.A{3}))];
end

%% B1: run-up without load step (Kloss)
tol_n = 1e-4*ns;              % 0.01 % of ns
tol_t = 1e-4;                 % 0.1 ms = MaxStep of the test runs
defs = {'B1', 'stationäre Drehzahl nach dem Hochlauf'; ...
        'B1', sprintf('Hochlaufzeit bis 0,9·n_N = %s 1/min', de(0.9*S.n_N, '%.0f'))};
[r, D.B1] = run_group(defs, any(opt.Tests == "B1"), missing, @() case_b1());
rows = [rows; r];

%% B2: load step after settling (Kloss)
defs = {'B2', 'vor dem Laststoß eingeschwungen (max. Abweichung)'; ...
        'B2', 'Drehzahl vor dem Laststoß'; ...
        'B2', 'minimale Drehzahl nach dem Laststoß'; ...
        'B2', 'Drehzahleinbruch n_vor − n_min'; ...
        'B2', 'neuer stationärer Arbeitspunkt'; ...
        'B2', 'Einschwingzeit nach dem Laststoß'};
[r, D.B2] = run_group(defs, any(opt.Tests == "B2"), missing, @() case_b2());
rows = [rows; r];

%% Z: supplement, dynamic space-vector model
tol_z = 5e-4*ns;              % 0.05 % of ns
defs = {'Z1', 'dyn. Modell: Drehzahl vor dem Laststoß'; ...
        'Z2', 'dyn. Modell: neuer stationärer Arbeitspunkt'; ...
        'Z3', 'dyn. Modell: Drehzahleinbruch n_vor − n_min'; ...
        'Z4', 'dyn. Modell: Einschwingzeit nach dem Laststoß'};
[r, D.Z] = run_group(defs, any(opt.Tests == "Z"), missing, @() case_z());
rows = [rows; r];

%% R: rated point (information, no simulation)
RP = asmtools.rated_point(S);
D.rated_point = RP;
rows(end+1, :) = {'R', 'Bemessungspunkt: Kloss-Moment bei s_N (Soll = M_N)', S.M_N, RP.M_kloss_sN, ...
    RP.M_kloss_sN - S.M_N, NaN, 'N·m', 'Info', ...
    sprintf(['Eigenschaft des Beispieldatensatzes (%s %%): MK und sK sind abgeglichen, (n_N, M_N) nur ' ...
             'Information. M = M_N wird erreicht bei %s 1/min (Kloss) bzw. %s 1/min (stationäre ' ...
             'ESB-Kennlinie); der Arbeitspunkt mit der angesetzten Lüfterlast (M_B = M_N bei n_B = n_N) ' ...
             'liegt bei %s 1/min (Kloss) bzw. %s 1/min (ESB)'], de(100*RP.dev_rel, '%+.1f'), ...
            de(RP.n_at_MN, '%.1f'), de(RP.n_at_MN_ec, '%.1f'), de(RP.n_op_fan_kloss, '%.1f'), ...
            de(RP.n_op_fan_ec, '%.1f'))};

T = cell2table(rows, 'VariableNames', {'Test', 'Groesse', 'Sollwert', 'Istwert', 'Abweichung', ...
                                       'Toleranz', 'Einheit', 'Status', 'Begruendung'});
T.Test = string(T.Test);  T.Groesse = string(T.Groesse);  T.Einheit = string(T.Einheit);
T.Status = string(T.Status);  T.Begruendung = string(T.Begruendung);
if opt.Print, print_report(T); end
bad = ismember(T.Status, ["nicht bestanden" "Fehler" "nicht verfügbar"]);
if opt.ErrorOnFailure && any(bad)
    error('asm:verify', 'verify_asm: %d Prüfzeile(n) nicht bestanden, abgebrochen oder nicht verfügbar: %s', ...
          nnz(bad), strjoin(unique(T.Test(bad))', ', '));
end

    %% ===================== test cases (nested: use opt, S, tolerances) =====================
    function [r, R] = case_loop(s)
        P = asm_params('loop');  P.s_loop = s;
        R = run_asm(P, 'TimeOut', opt.TimeOut);
        M = R.metrics;
        if s == 0
            why = ['s = 0: keine Relativbewegung, induzierte Spannung, Strom und Moment exakt null; ' ...
                   'es wird keine Rotorperiode berechnet. Toleranz nur Rundung'];
            r = [row('A1', '', 0, M.i_max, 1e-9, 'A', why); row('A1', '', 0, M.M_S_max, 1e-9, 'N·m', why)];
        else
            why = sprintf(['Soll: î2·l·B̂·r·sin φ2 (analytisch, SPEC 3.1). Mittelungsfenster: %d ganze ' ...
                           'Rotorperioden T2 = %s s bis t_End = %s s. Das Schleifenmodell hat keinen ' ...
                           'Einschwingvorgang (algebraisch in θ2 = s·ω1·t, keine Zeitkonstante), daher ist ' ...
                           'das Fenster ab t = 0 zulässig; ohne ganze Periode wird kein Mittelwert gebildet. ' ...
                           'Toleranz 1e-6 relativ: erwartet ist Gleichheit bis auf Rundung, die Toleranz ' ...
                           'deckt die Interpolation zwischen Solverschritten ab'], ...
                          M.n_periods, de(M.T2, '%.3g'), de(R.params.t_end, '%.3g'));
            r = row('', '', M.M_S_mean_expected, M.M_S_mean, 1e-6*abs(M.M_S_mean_expected), 'N·m', why);
        end
    end

    function [r, R] = case_consistency(RA3)
        M = RA3.metrics;
        R = [];
        r = row('', '', S.MK, M.N_S*M.M_S_mean, 1e-6*S.MK, 'N·m', ...
            ['Konsistenzprüfung, keine unabhängige Validierung: R2 und L2σ der Schleife sind aus MK und sK ' ...
             'abgeleitet (asmtools.loop_parameters); N_S = N2/2 gleiche Schleifen']);
    end

    function [r, R] = case_b1()
        P = asm_params('kloss');  P.dM_L = 0;  P.t_end = 1;
        R = run_asm(P, 'TimeOut', opt.TimeOut);
        R.reference = kloss_reference(R.params);
        E = R.metrics.expected.before;
        n_exp = E.n;
        why_n = why_speed(R.params, 'M_Kloss(n) = M_L(n)', 0.01, tol_n);
        if ~E.reachable
            n_exp = NaN;
            why_n = [why_n '; kein erreichbarer stabiler Arbeitspunkt'];
        end
        r = [row('', '', n_exp, R.metrics.final.n, tol_n, '1/min', why_n)
             row('', '', R.reference.metrics.startup.t_target, R.metrics.startup.t_target, tol_t, 's', ...
                 why_time(R.params))];
    end

    function [r, R] = case_b2()
        P = asm_params('kloss');
        R = run_asm(P, 'TimeOut', opt.TimeOut);
        R.reference = kloss_reference(R.params);
        LS = R.metrics.load_step;  E1 = R.metrics.expected.before;  E2 = R.metrics.expected.after;
        band = R.params.band;
        n1 = E1.n;  n2 = E2.n;
        if ~E1.reachable, n1 = NaN; end
        if ~E2.reachable, n2 = NaN; end
        why_n = why_speed(R.params, 'M_Kloss(n) = M_L(n) + ΔM_L (nach dem Stoß ausgehend vom alten Arbeitspunkt)', ...
                          0.01, tol_n);
        why_min = [why_n '. Kein Unterschwingen wird nur für diesen Testfall erwartet: Kloss-Modell ' ...
                   'mit starrer Welle und nur drehzahlabhängiger Last ist ein System 1. Ordnung ' ...
                   '(J·dΩ/dt = f(Ω)); nach dem Stoß strebt Ω monoton gegen den neuen Arbeitspunkt, das ' ...
                   'Minimum ist der neue Arbeitspunkt. Für das dynamische Modell gilt das nicht (Z3)'];
        r = [row('', '', 0, R.metrics.before_step.max_dev, band, '1/min', ...
                 sprintf(['Fenster %s ms, endet %s ms vor t_stoß (Laststoß mit 0,5 ms geglättet); ' ...
                          'Toleranzband ±%s 1/min = 0,1 %% von n_s = %s 1/min'], de(1e3*R.params.window, '%.0f'), ...
                         de(1e3*R.params.step_margin, '%.0f'), de(band, '%.2f'), de(R.params.ns, '%.0f')))
             row('', '', n1, LS.n_before, tol_n, '1/min', why_n)
             row('', '', n2, LS.n_min, tol_n, '1/min', why_min)
             row('', '', n1 - n2, LS.dn_dip, 2*tol_n, '1/min', ...
                 'Differenz zweier Drehzahlen mit je 0,01 % von n_s Toleranz, daher doppelte Toleranz')
             row('', '', n2, LS.n_new, tol_n, '1/min', why_n)
             row('', '', R.reference.metrics.step.t_settle, LS.t_settle, tol_t, 's', ...
                 [sprintf(['Einschwingzeit = Zeit nach t_stoß bis zum letzten Eintritt in das Band ' ...
                           '|n − n_neu| ≤ %s 1/min (linear interpoliert), nur angegeben, wenn das Band bis ' ...
                           'zum Ende des Auswertefensters gehalten wird. '], de(band, '%.2f')) why_time(R.params)])];
    end

    function [r, R] = case_z()
        R = run_asm(asm_params('lab'), 'TimeOut', opt.TimeOut);
        LS = R.metrics.load_step;  E1 = R.metrics.expected.before;  E2 = R.metrics.expected.after;
        n1 = E1.n;  n2 = E2.n;
        if ~E1.reachable, n1 = NaN; end
        if ~E2.reachable, n2 = NaN; end
        why_z = sprintf(['Soll: Schnittpunkt der stationären ESB-Kennlinie mit M_L (+ ΔM_L). Toleranz %s 1/min ' ...
                         '= 0,05 %% von n_s = %s 1/min: Modell und ESB stimmen stationär auf 0,02 %% bis ' ...
                         '0,06 %% im Moment überein (BenchmarkTest V1), Restwelligkeit im Mittelungsfenster'], ...
                        de(tol_z, '%.2f'), de(R.params.ns, '%.0f'));
        if LS.undershoot > LS.band
            why3 = sprintf(['kein unabhängiger Sollwert. Im berechneten Verlauf liegt n_min %s 1/min unter dem ' ...
                            'neuen Arbeitspunkt (Unterschwingen; Einbruch %s 1/min, statischer Unterschied ' ...
                            '%s 1/min)'], de(LS.undershoot, '%.3g'), de(LS.dn_dip, '%.3g'), de(LS.dn_static, '%.3g'));
        else
            why3 = sprintf(['kein unabhängiger Sollwert. Im berechneten Verlauf kein Unterschwingen über das ' ...
                            'Toleranzband ±%s 1/min hinaus (Einbruch %s 1/min, statischer Unterschied %s 1/min)'], ...
                           de(LS.band, '%.2f'), de(LS.dn_dip, '%.3g'), de(LS.dn_static, '%.3g'));
        end
        r = [row('', '', n1, LS.n_before, tol_z, '1/min', why_z)
             row('', '', n2, LS.n_new, tol_z, '1/min', why_z)
             info_row(LS.dn_dip, '1/min', why3)
             info_row(LS.t_settle, 's', sprintf(['kein unabhängiger Sollwert; Toleranzband ±%s 1/min, NaN = ' ...
                      'nicht eingeschwungen'], de(LS.band, '%.2f')))];
    end

    function why = why_speed(P, what, percent, tol)
        why = sprintf(['Soll: stabiler, aus der Anfangsbedingung erreichbarer Schnittpunkt %s ' ...
                       '(asmtools.operating_point, dieselbe geglättete Lastkennlinie wie im Lastbaustein). ' ...
                       'Toleranz %s 1/min = %s %% von n_s = %s 1/min: stationärer Endwert (Mittel über %s ms), ' ...
                       'Solver-RelTol %s, MaxStep %s ms; die Glättung der Lüfterlast verschiebt den ' ...
                       'Schnittpunkt um weniger als 1e-6·M_B'], what, de(tol, '%.2f'), de(percent, '%.2f'), ...
                      de(P.ns, '%.0f'), de(1e3*P.window, '%.0f'), de(P.rel_tol, '%.0e'), de(1e3*P.max_step, '%.2g'));
    end

    function why = why_time(P)
        why = sprintf(['Soll: direkte Integration derselben Bewegungsgleichung J·dΩ/dt = M_Kloss − M_L ' ...
                       '(ode45, RelTol 1e-10, gleiche Trägheit J_M + J_L, Anfangsdrehzahl 0, gleiche Last-, ' ...
                       'Vorzeichen- und Sprungglättung) mit derselben Auswertung – Vergleich zweier ' ...
                       'Implementierungen, keine unabhängige Physik (die Auswertung selbst prüft ' ...
                       'SpeedMetricsTest). Toleranz 0,1 ms = MaxStep (%s ms), die Zeitauflösung der ' ...
                       'Simulation; Schrittweitenstudie (MaxStep 0,05/0,1/0,2 ms) in doku/VALIDIERUNG.md'], ...
                      de(1e3*P.max_step, '%.2g'));
    end
end

%% ========================= helper functions =========================
function [rows, R] = run_group(defs, selected, missing, fcn)
% run one test group; always returns exactly size(defs, 1) rows with the labels of defs
R = [];
if ~selected
    rows = status_rows(defs, 'abgewählt', 'nicht ausgewählt (Option Tests)');
    return;
end
if ~isempty(missing)
    rows = status_rows(defs, 'nicht verfügbar', missing);
    return;
end
try
    [rows, R] = fcn();
    if size(rows, 1) ~= size(defs, 1)
        error('asm:verify', 'interner Fehler: %d statt %d Zeilen', size(rows, 1), size(defs, 1));
    end
    rows(:, 1:2) = defs;
catch err
    R = [];
    rows = status_rows(defs, 'Fehler', sprintf('Abbruch (%s): %s', err.identifier, ...
                       strtrim(regexprep(err.message, '\s+', ' '))));
end
end

function rows = status_rows(defs, status, reason)
rows = cell(size(defs, 1), 9);
for k = 1:size(defs, 1)
    rows(k, :) = {defs{k, 1}, defs{k, 2}, NaN, NaN, NaN, NaN, '', status, reason};
end
end

function r = row(test, quantity, expected, actual, tol, unit, why)
% one test row: status from |actual - expected| <= tol
dev = actual - expected;
if isnan(actual) || isnan(expected)
    status = 'nicht bestanden';
    why = [why '; Soll- oder Istwert nicht bestimmbar (z. B. nicht erreicht, nicht eingeschwungen, ' ...
           'kein Arbeitspunkt)'];
elseif abs(dev) <= tol
    status = 'bestanden';
else
    status = 'nicht bestanden';
end
r = {test, quantity, expected, actual, dev, tol, unit, status, why};
end

function r = info_row(actual, unit, why)
r = {'', '', NaN, actual, NaN, NaN, unit, 'Info', why};
end

function reason = availability()
% required products and generated files; '' if everything is available
reason = '';
need = {'Simulink', 'simulink'; 'Simscape', 'simscape'};
for k = 1:size(need, 1)
    if ~license('test', need{k, 1}) || isempty(ver(need{k, 2}))
        reason = sprintf('%s nicht installiert oder nicht lizenziert', need{k, 1});
        return;
    end
end
if exist('asm_blocks_lib', 'file') ~= 4
    reason = 'Bibliothek asm_blocks_lib fehlt (startup_asm; build_library ausführen)';
elseif any(cellfun(@(m) exist(m, 'file') ~= 4, {'ex_conductor_loop', 'ex_kloss_startup', 'ex_startup_load_step'}))
    reason = 'Beispielmodelle fehlen (build_examples ausführen)';
end
end

function ref = kloss_reference(P)
% direct integration of J*dOm/dt = M_Kloss(Om) - M_L(Om, t) with ode45 (same load model as the
% blocks: smoothed sign tanh(Om/0.1 rad/s), smoothed load step with 0.5 ms, J = J_M + J_L,
% initial speed 0), then the same evaluation as run_asm (asmtools.speed_metrics)
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
[t, iu] = unique(t);
n = 60*w(iu)/(2*pi);
if P.dM_L ~= 0 && P.t_step < P.t_end, ts = P.t_step; else, ts = NaN; end
ref.t = t;
ref.n = n;
ref.metrics = asmtools.speed_metrics(t, n, struct('n_target', P.n_target, 't_step', ts, ...
    'window', P.window, 'band', P.band, 'margin', P.step_margin, 'step_sign', sign(P.dM_L)));
end

function s = de(x, fmt)
% number with German decimal comma
s = strrep(sprintf(fmt, x), '.', ',');
end

function print_report(T)
% compact console report (German)
fprintf('\n=== Fachliche Testfälle (verify_asm) ===\n');
fprintf('%-4s %-58s %12s %12s %11s %10s %-6s %s\n', 'Test', 'Größe', 'Soll', 'Ist', 'Abweichung', 'Toleranz', 'Einh.', 'Status');
for k = 1:height(T)
    fprintf('%-4s %-58s %12s %12s %11s %10s %-6s %s\n', T.Test(k), extractBefore(T.Groesse(k) + blanks(58), 59), ...
            num(T.Sollwert(k)), num(T.Istwert(k)), num(T.Abweichung(k)), num(T.Toleranz(k)), T.Einheit(k), T.Status(k));
    if ismember(T.Status(k), ["Fehler" "nicht verfügbar" "nicht bestanden"])
        fprintf('     -> %s\n', T.Begruendung(k));
    end
end
c = @(s) nnz(T.Status == s);
fprintf(['Zusammenfassung: %d bestanden, %d nicht bestanden, %d Fehler, %d nicht verfügbar, ' ...
         '%d abgewählt, %d Info\n'], c("bestanden"), c("nicht bestanden"), c("Fehler"), ...
        c("nicht verfügbar"), c("abgewählt"), c("Info"));
fprintf('Nur "bestanden" zählt als bestanden. Begründungen: Spalte "Begruendung" der Rückgabetabelle.\n\n');
end

function s = num(x)
if isnan(x), s = '–'; else, s = sprintf('%.6g', x); end
end
