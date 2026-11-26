classdef TechnicalCasesTest < matlab.unittest.TestCase
%TECHNICALCASESTEST Technical test cases of parts A and B (verify_asm) and the metric definitions.
%   Run in the project folder:  startup_asm; runtests('tests')
%
%   - verify_asm: every test row must pass; Info rows are not checked.
%   - Not selected tests are marked "nicht ausgeführt".
%   - asmtools.speed_metrics against an analytic first-order trajectory (fixed run-up target,
%     "nicht erreicht", settling only if the band holds until the end of the window).
%   - asmtools.operating_point: reachable stable intersection, stall without intersection.
%   - asmtools.rated_point: finding on the rated point (Kloss 27.52 N*m instead of 26.5 N*m).
%   - run_asm passes the parameters explicitly: the models stay unchanged, no base workspace.

    properties
        T       % report table of verify_asm
    end

    methods (TestClassSetup)
        function prepare(tc)
            if ~exist('asm_blocks_lib', 'file'), build_library(); end
            tc.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                {'Simulink:Engine:MdlFileShadowedByFile', 'Simulink:Engine:MdlFileShadowing'}));
            tc.T = verify_asm('Print', false);
        end
    end

    methods (Test)
        function allTechnicalCasesPass(tc)
            checked = tc.T(tc.T.Status ~= "Info", :);
            tc.verifyNotEmpty(checked);
            for k = 1:height(checked)
                tc.verifyEqual(checked.Status(k), "bestanden", sprintf('%s %s: Soll %.6g, Ist %.6g, Toleranz %.3g (%s)', ...
                    checked.Test(k), checked.Groesse(k), checked.Sollwert(k), checked.Istwert(k), ...
                    checked.Toleranz(k), checked.Begruendung(k)));
            end
            tc.verifyTrue(all(ismember(["A1" "A2" "A3" "A4" "A5" "B1" "B2" "Z1" "Z2"], tc.T.Test)), ...
                'alle Testfälle müssen im Bericht stehen');
            tc.verifyTrue(all(strlength(tc.T.Begruendung) > 0), 'jede Zeile braucht eine Begründung');
        end

        function notSelectedTestsAreMarked(tc)
            T2 = verify_asm('Tests', "A", 'Print', false);
            tc.verifyTrue(all(T2.Status(startsWith(T2.Test, "B") | startsWith(T2.Test, "Z")) == "nicht ausgeführt"));
            tc.verifyTrue(all(T2.Status(startsWith(T2.Test, "A")) == "bestanden"));
        end

        function speedMetricsFirstOrder(tc)
            % n(t) = n_inf*(1 - exp(-t/tau)): t(0.9*n_inf) = tau*ln(10)
            tau = 0.1;  n_inf = 1000;
            t = linspace(0, 2, 200001)';
            n = n_inf*(1 - exp(-t/tau));
            K = asmtools.speed_metrics(t, n, struct('n_target', 900, 't_step', NaN, 'window', 0.05, 'band', 0.5));
            tc.verifyTrue(K.startup.reached);
            tc.verifyEqual(K.startup.t_target, tau*log(10), 'AbsTol', 1e-6, 'Hochlaufzeit bis 90 %');
            tc.verifyEmpty(K.step, 'ohne Laststoß keine Laststoß-Kennzahlen');
            % fixed target above the final value: not reached (no relative 90 % of the last value)
            K = asmtools.speed_metrics(t, n, struct('n_target', 1100, 't_step', NaN, 'window', 0.05, 'band', 0.5));
            tc.verifyFalse(K.startup.reached, 'Ziel oberhalb des Endwerts: nicht erreicht');
            tc.verifyTrue(isnan(K.startup.t_target));
        end

        function speedMetricsLoadStep(tc)
            % first order load step at t = 1 s from 1000 to 980 rpm with tau = 20 ms
            tau = 0.02;  t = linspace(0, 1.5, 150001)';
            n = 1000 - 20*(1 - exp(-(t - 1)/tau)).*(t >= 1);
            cfg = struct('n_target', 900, 't_step', 1, 'window', 0.05, 'band', 0.5, 'margin', 0);
            K = asmtools.speed_metrics(t, n, cfg);
            S = K.step;
            tc.verifyEqual(S.n_before, 1000, 'AbsTol', 1e-9);
            tc.verifyEqual(S.n_new, 980, 'AbsTol', 1e-6);
            tc.verifyEqual(S.n_min, S.n_new, 'AbsTol', 1e-6, '1. Ordnung: kein Unterschwingen');
            tc.verifyTrue(S.settled);
            tc.verifyEqual(S.t_settle, tau*log(20/0.5), 'AbsTol', 1e-4, 'Einschwingzeit in das Band ±0,5');
            % simulation ends too early after the step: no settling time is reported
            short = t <= 1.03;
            K = asmtools.speed_metrics(t(short), n(short), cfg);
            tc.verifyFalse(K.step.settled, 'Band nicht über das ganze Endfenster gehalten');
            tc.verifyTrue(isnan(K.step.t_settle));
        end

        function operatingPointReachable(tc)
            P = asm_standard();
            Mm = @(n) asmtools.kloss_torque((P.ns - n)/P.ns, P.MK, P.sK);
            fan = @(n) P.M_N*(n/P.n_N).^2;
            op = asmtools.operating_point(Mm, fan, P.ns, 0);
            tc.verifyTrue(op.found);
            tc.verifyEqual(Mm(op.n), fan(op.n), 'AbsTol', 1e-9, 'Schnittpunkt');
            tc.verifyLessThan(op.s, P.sK, 'stabiler Ast (s < sK)');
            % constant load above the breakdown torque: no reachable intersection after the step
            op2 = asmtools.operating_point(Mm, @(n) 0*n + 1.1*P.MK, P.ns, op.n);
            tc.verifyFalse(op2.found);
            tc.verifyTrue(op2.stalls, 'Motor kippt und bleibt stehen');
        end

        function ratedPointFinding(tc)
            R = asmtools.rated_point(asm_standard());
            tc.verifyEqual(R.s_N, 0.04, 'AbsTol', 1e-12);
            tc.verifyEqual(R.M_kloss_sN, 27.5192, 'AbsTol', 1e-4, 'Befund: Kloss-Moment bei s_N');
            tc.verifyTrue(R.sK_squared_equals_sN, 's_N = sK² -> M(s_N) = M(1)');
            tc.verifyEqual(asmtools.kloss_torque(R.s_N, asm_standard().MK, R.alt_sK.sK), 26.5, 'AbsTol', 1e-9);
            tc.verifyEqual(asmtools.kloss_torque(R.s_N, R.alt_MK.MK, asm_standard().sK), 26.5, 'AbsTol', 1e-9);
        end

        function runAsmIsExplicit(tc)
            % run_asm: no changes to the model, no variables in the base workspace
            before = evalin('base', 'who');
            P = asm_params('kloss');  P.t_end = 0.3;  P.dM_L = 0;  P.J_L = 0.02;
            R = run_asm(P);
            tc.verifyEqual(evalin('base', 'who'), before, 'run_asm darf den Base Workspace nicht ändern');
            tc.verifyEqual(get_param('ex_kloss_startup', 'Dirty'), 'off', 'Modell darf nicht verändert werden');
            tc.verifyEqual(R.params.J_L, 0.02, 'übergebener Wert wird verwendet');
            tc.verifyEqual(str2double(get_param('ex_kloss_startup/Last_J', 'J')), 0.01, ...
                'Parameter nur über SimulationInput, nicht im Modell');
            % a larger inertia makes the run-up slower (parameter really reaches the model)
            P.J_L = 0.05;  R2 = run_asm(P);
            tc.verifyGreaterThan(R2.metrics.startup.t_target, R.metrics.startup.t_target);
        end
    end
end
