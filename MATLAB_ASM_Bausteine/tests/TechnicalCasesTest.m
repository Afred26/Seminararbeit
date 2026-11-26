classdef TechnicalCasesTest < matlab.unittest.TestCase
%TECHNICALCASESTEST Technical test cases (verify_asm), report texts, status handling and run_asm.
%   Run in the project folder:  startup_asm; runtests('tests')
%
%   - verify_asm: every checked row passes; Info rows are not counted; texts of the tolerance
%     justifications state n_s and the tolerance separately (regression of the n_s/tolerance mix-up).
%   - Status separation: deselected tests are "abgewählt", aborted selected tests are "Fehler"
%     with reason, without partial or duplicated rows; ErrorOnFailure makes batch runs fail.
%   - Part B: "no reachable stable operating point" (load above the starting torque) is detected.
%   - run_asm: explicit parameters, derived fields recomputed, solver settings passed, sequential
%     runs independent, model and base workspace unchanged, no pseudo-valid means.
%   The metric definitions themselves are tested independently in SpeedMetricsTest.

    properties
        T       % report table of verify_asm
        D       % raw results of verify_asm
    end

    methods (TestClassSetup)
        function prepare(tc)
            if ~exist('asm_blocks_lib', 'file'), build_library(); end
            tc.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                {'Simulink:Engine:MdlFileShadowedByFile', 'Simulink:Engine:MdlFileShadowing'}));
            [tc.T, tc.D] = verify_asm('Print', false);
        end
    end

    methods (Test)
        %% verify_asm report
        function allTechnicalCasesPass(tc)
            checked = tc.T(tc.T.Status ~= "Info", :);
            tc.verifyNotEmpty(checked);
            for k = 1:height(checked)
                tc.verifyEqual(checked.Status(k), "bestanden", sprintf('%s %s: Soll %.6g, Ist %.6g, Toleranz %.3g (%s)', ...
                    checked.Test(k), checked.Groesse(k), checked.Sollwert(k), checked.Istwert(k), ...
                    checked.Toleranz(k), checked.Begruendung(k)));
            end
            tc.verifyEqual(sort(unique(tc.T.Test))', ["A1" "A2" "A3" "A4" "A5" "B1" "B2" "R" "Z1" "Z2" "Z3" "Z4"]);
            tc.verifyEqual(nnz(tc.T.Status == "Info"), 3, 'Z3, Z4 und R sind Info, keine Prüfungen');
            tc.verifyTrue(all(strlength(tc.T.Begruendung) > 0), 'jede Zeile braucht eine Begründung');
        end

        function toleranceTextsStateNsAndTolerance(tc)
            % regression: the value after "von n_s =" must be the synchronous speed, the tolerance
            % must be given separately with its own value and unit
            b1 = tc.T.Begruendung(tc.T.Test == "B1" & contains(tc.T.Groesse, "stationäre"));
            z1 = tc.T.Begruendung(tc.T.Test == "Z1");
            tc.verifySubstring(char(b1), 'Toleranz 0,15 1/min = 0,01 % von n_s = 1500 1/min');
            tc.verifySubstring(char(z1), 'Toleranz 0,75 1/min = 0,05 % von n_s = 1500 1/min');
            % neighbouring texts: every "n_s = <value> 1/min" must be 1500
            for k = 1:height(tc.T)
                v = regexp(char(tc.T.Begruendung(k)), 'n_s = ([\d,]+) 1/min', 'tokens');
                for j = 1:numel(v)
                    tc.verifyEqual(v{j}{1}, '1500', sprintf('%s: falscher Wert für n_s', tc.T.Test(k)));
                end
            end
            tc.verifyEmpty(regexp(strjoin(tc.T.Begruendung', ' '), '\d\.\d+ ?(1/min|ms|s|N·m|%)', 'once'), ...
                'Messwerte in Begründungen mit Dezimalkomma');
        end

        function undershootTextFollowsTrajectory(tc)
            LS = tc.D.Z.metrics.load_step;
            z3 = char(tc.T.Begruendung(tc.T.Test == "Z3"));
            if LS.undershoot > LS.band
                tc.verifySubstring(z3, 'unter dem neuen Arbeitspunkt (Unterschwingen');
            else
                tc.verifySubstring(z3, 'kein Unterschwingen');
            end
        end

        %% status handling
        function deselectedTestsAreMarked(tc)
            T2 = verify_asm('Tests', "A", 'Print', false);
            tc.verifyEqual(height(T2), height(tc.T), 'gleiche Zeilen wie der vollständige Lauf');
            other = startsWith(T2.Test, "B") | startsWith(T2.Test, "Z");
            tc.verifyTrue(all(T2.Status(other) == "abgewählt"));
            tc.verifyTrue(all(T2.Status(startsWith(T2.Test, "A")) == "bestanden"));
        end

        function abortedTestIsErrorWithoutDuplicates(tc)
            % time limit far too short: the selected test B1 is aborted, not "nicht ausgeführt"
            tc.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture('Simulink:Commands:SimTimeExceededTimeOut'));
            T2 = verify_asm('Tests', "B1", 'Print', false, 'TimeOut', 1e-3);
            b1 = T2(T2.Test == "B1", :);
            tc.verifyEqual(height(b1), 2, 'genau die zwei B1-Zeilen, keine Teil- oder Doppelzeilen');
            tc.verifyTrue(all(b1.Status == "Fehler"));
            tc.verifyTrue(all(contains(b1.Begruendung, "Abbruch (asm:simulation)")), 'Fehlergrund mit Kennung');
            tc.verifyTrue(all(isnan(b1.Istwert)), 'kein Istwert, der einen Lauf vortäuscht');
            tc.verifyEqual(height(T2), height(tc.T));
            tc.verifyError(@() verify_asm('Tests', "B1", 'Print', false, 'TimeOut', 1e-3, 'ErrorOnFailure', true), ...
                'asm:verify', 'Batch-Lauf muss abgebrochene Prüfungen melden');
            tc.verifyWarningFree(@() verify_asm('Tests', "A", 'Print', false, 'ErrorOnFailure', true), ...
                'abgewählte Tests sind kein Fehler');
        end

        %% part B: reachable operating point
        function noStartIsDetected(tc)
            % constant load 30 N*m above the Kloss starting torque 27.5 N*m: motor does not start
            P = asm_params('kloss');  P.load_type = 'constant';  P.M_L = 30;  P.dM_L = 0;  P.t_end = 0.3;
            R = run_asm(P);
            E = R.metrics.expected.before;
            tc.verifyTrue(E.standstill, 'Stillstand erkannt');
            tc.verifyFalse(E.reachable, 'kein erreichbarer stabiler Arbeitspunkt im Motorbereich');
            tc.verifyFalse(R.metrics.startup.reached);
            tc.verifyLessThan(R.metrics.final.n, 4.77, 'Simulation: Motor bleibt praktisch stehen');
            tc.verifyTrue(any(contains(R.notes, 'läuft nicht an')));
        end

        function loadDecreaseInSimulation(tc)
            % negative load step: the speed rises; relevant are n_max and the overshoot
            P = asm_params('kloss');  P.dM_L = -0.3*P.M_N;
            R = run_asm(P);
            L = R.metrics.load_step;
            tc.verifyEqual(L.step_sign, -1);
            tc.verifyLessThan(L.dn_static, 0, 'Drehzahl steigt');
            tc.verifyEqual(L.n_new, R.metrics.expected.after.n, 'AbsTol', 0.15);
            tc.verifyLessThan(L.overshoot, L.band, 'Kloss 1. Ordnung: kein Überschwingen');
            tc.verifyTrue(L.settled);
        end

        function ratedPointFinding(tc)
            R = asmtools.rated_point(asm_standard());
            tc.verifyEqual(R.s_N, 0.04, 'AbsTol', 1e-12);
            tc.verifyEqual(R.M_kloss_sN, 27.5192, 'AbsTol', 1e-4, 'Befund: Kloss-Moment bei s_N');
            tc.verifyTrue(R.sK_squared_equals_sN, 's_N = sK² -> M(s_N) = M(1)');
            tc.verifyEqual(R.n_at_MN, 1442.40, 'AbsTol', 0.01, 'Drehzahl mit M_Kloss = M_N');
            tc.verifyEqual(R.n_op_fan_kloss, 1442.21, 'AbsTol', 0.01, 'Arbeitspunkt mit Lüfterlast (Kloss)');
            tc.verifyEqual(R.n_op_fan_ec, 1444.78, 'AbsTol', 0.01, 'Arbeitspunkt mit Lüfterlast (ESB)');
            tc.verifyEqual(asmtools.kloss_torque(R.s_N, asm_standard().MK, R.alt_sK.sK), 26.5, 'AbsTol', 1e-9);
            tc.verifyEqual(asmtools.kloss_torque(R.s_N, R.alt_MK.MK, asm_standard().sK), 26.5, 'AbsTol', 1e-9);
        end

        %% run_asm
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
            bp = R.sim_input.BlockParameters;
            j = strcmp({bp.BlockPath}, 'ex_kloss_startup/Last_J') & strcmp({bp.Name}, 'J');
            tc.verifyEqual(str2double(bp(j).Value), 0.02, 'R.sim_input dokumentiert den übergebenen Wert');
            % a larger inertia makes the run-up slower (parameter really reaches the model)
            P.J_L = 0.05;  R2 = run_asm(P);
            tc.verifyGreaterThan(R2.metrics.startup.t_target, R.metrics.startup.t_target);
        end

        function sequentialRunsAreIndependent(tc)
            P = asm_params('kloss');  P.t_end = 1.3;
            R1 = run_asm(P);
            P2 = P;  P2.dM_L = 0.5*P.M_N;
            R2 = run_asm(P2);
            R3 = run_asm(P);
            tc.verifyEqual(R3.time.n, R1.time.n, 'AbsTol', 1e-9, 'gleiche Parameter, gleiches Ergebnis');
            tc.verifyLessThan(R2.metrics.load_step.n_new, R1.metrics.load_step.n_new - 5, 'größerer Laststoß wirkt');
            tc.verifyEqual(R2.params.dM_L, 0.5*P.M_N);
            tc.verifyEqual(R3.params.dM_L, P.dM_L);
            tc.verifyEqual(get_param('ex_kloss_startup', 'Dirty'), 'off');
        end

        function derivedFieldsAreRecomputed(tc)
            % custom MK: the loop parameters follow MK (part A stays consistent with part B)
            P = asm_params('loop');  P.param_set = 'custom';  P.MK = 60;
            R = run_asm(P);
            L = asmtools.loop_parameters(R.params);
            tc.verifyEqual(R.params.R2_S, L.R2_S, 'RelTol', 1e-12);
            tc.verifyEqual(R.metrics.N_S*R.metrics.M_S_mean, ...
                asmtools.kloss_torque(P.s_loop, 60, P.sK), 'RelTol', 1e-6);
            % a wrong value for a derived field is ignored with a warning
            P = asm_params('kloss');  P.ns = 1000;  P.t_end = 0.2;  P.dM_L = 0;
            R = tc.verifyWarning(@() run_asm(P), 'asm:derived');
            tc.verifyEqual(R.params.ns, 1500);
            % a result struct can be passed back unchanged without warning
            tc.verifyWarningFree(@() run_asm(R.params));
        end

        function solverSettingsArePassed(tc)
            P = asm_params('kloss');  P.t_end = 0.3;  P.dM_L = 0;  P.max_step = 2e-4;
            R = run_asm(P);
            tc.verifyEqual(R.solver.MaxStep, 2e-4);
            tc.verifyLessThanOrEqual(max(diff(R.time.t)), 2e-4*(1 + 1e-9), 'MaxStep wirkt');
            tc.verifyEqual(get_param('ex_kloss_startup', 'MaxStep'), '1e-4', 'Modell unverändert');
        end

        function noPseudoValidMeans(tc)
            % loop and slides: without a whole rotor period no mean value is given
            P = asm_params('loop');  P.s_loop = 0.04;  P.t_end = 0.2;     % T2 = 0.5 s
            R = run_asm(P);
            tc.verifyTrue(isnan(R.metrics.M_S_mean));
            tc.verifyTrue(any(contains(R.notes, 'kürzer als eine Rotorperiode')));
            P = asm_params('loop');  P.s_loop = 0;
            R = run_asm(P);
            tc.verifyTrue(isnan(R.metrics.M_S_mean), 's = 0: kein Mittelwert, keine Periode');
            tc.verifyEqual(R.metrics.i_max, 0);
            P = asm_params('slides');  P.t_end = 0.01;
            R = run_asm(P);
            tc.verifyTrue(isnan(R.metrics.M_S_mean));
        end
    end
end
