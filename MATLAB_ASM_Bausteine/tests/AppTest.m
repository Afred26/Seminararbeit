classdef AppTest < matlab.unittest.TestCase
%APPTEST Computational core run_asm (scenarios lab and slides) and the GUI ASMApp.
%   Run in the project folder:  startup_asm; runtests('tests')
%
%   Lab: default values against the unchanged example model ex_startup_load_step
%   (tolerance as BenchmarkTest V2: 1 % of ns or MK) and against ExamplesTest (n_end);
%   parameter passing (custom, constant load) against asmtools.test_bench.
%   Slides: default values against ex_slides16_30_rotor_bars and the slide states (DidacticsTest).
%   Plus input check and a smoke test of the GUI.

    properties
        P           % parameter set asm_standard
        R_lab       % run_asm(asm_params('lab'))
        R_slides    % run_asm(asm_params('slides'))
    end

    methods (TestClassSetup)
        function prepare(tc)
            if ~exist('asm_blocks_lib', 'file'), build_library(); end
            was = bdIsLoaded('asm_blocks_lib');
            load_system('asm_blocks_lib');
            if ~was, tc.addTeardown(@() close_system('asm_blocks_lib', 0)); end
            tc.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                {'Simulink:Engine:MdlFileShadowedByFile', 'Simulink:Engine:MdlFileShadowing'}));
            for m = {'ex_startup_load_step', 'ex_slides16_30_rotor_bars'}
                if ~bdIsLoaded(m{1}), tc.addTeardown(@() close_system(m{1}, 0)); end
            end
            tc.P = asm_standard();
            tc.R_lab    = run_asm(asm_params('lab'));
            tc.R_slides = run_asm(asm_params('slides'));
        end
    end

    methods (Test)
        function labLikeExampleModel(tc)
            % default values = unchanged example model (only the measurement bus is logged)
            m = 'ex_startup_load_step';
            in = Simulink.SimulationInput(m).setModelParameter('TimeOut', 300);
            ls = Simulink.Simulation.LoggingSpecification;
            addSignalsToLog(ls, Simulink.SimulationData.BlockPath([m '/Motor']), 1);
            in.LoggingSpecification = ls;
            out = sim(in);
            meas = out.logsout{1}.Values;
            Z = tc.R_lab.time;
            ns = tc.P.ns;  MK = max(asmtools.equivalent_circuit(tc.P, linspace(1e-3, 1, 5000)));
            t = linspace(0, 2, 8001)';
            dn = max(abs(ip(meas.n, t) - interp1(Z.t, Z.n, t)));
            dM = max(abs(ip(meas.M, t) - interp1(Z.t, Z.M, t)));
            tc.verifyLessThan(dn/ns, 0.01, sprintf('Drehzahl weicht um %.3g 1/min ab', dn));
            tc.verifyLessThan(dM/MK, 0.01, sprintf('Moment weicht um %.3g N·m ab', dM));
            tc.verifyEqual(Z.n(end), 1427.4, 'AbsTol', 1, 'Enddrehzahl wie ExamplesTest');
            tc.verifyEqual(get_param(m, 'Dirty'), 'off', 'Modell darf nicht verändert werden');
        end

        function labMetrics(tc)
            K = tc.R_lab.metrics;
            tc.verifyEqual(K.ns, 1500);
            tc.verifyEqual(K.s_end, (1500 - K.n_end)/1500, 'AbsTol', 1e-12);
            tc.verifyEqual(K.M_K, tc.P.MK, 'RelTol', 1e-3, 'Kippmoment = MK des Beispielmotors');
            tc.verifyEqual(K.s_K, tc.P.sK, 'AbsTol', 1e-3, 'Kippschlupf sK');
            tc.verifyEqual(K.M_A, asmtools.equivalent_circuit(tc.P, 1), 'RelTol', 1e-12, 'Anzugsmoment (ESB)');
            % final state: motor torque = load torque (fan + load step), stationary
            ML = tc.P.M_N*(K.n_end/1440)^2 + 0.3*tc.P.M_N;
            tc.verifyEqual(K.M_end, ML, 'RelTol', 0.01, 'Gleichgewicht M = M_L am Ende');
            % phase currents from the space vector: sum zero (star without N)
            tc.verifyLessThan(max(abs(sum(tc.R_lab.time.i_abc, 2))), 1e-9);
            % fixed run-up target 0.9*n_N, load step evaluated separately
            tc.verifyEqual(K.startup.n_target, 0.9*tc.P.n_N);
            tc.verifyTrue(K.startup.reached);
            tc.verifyTrue(K.load_step.settled_before && K.load_step.settled);
            tc.verifyGreaterThan(K.load_step.dn_dip, K.load_step.dn_static, ...
                'dynamisches Modell: Unterschwingen nach dem Laststoß');
        end

        function labCustomLikeTestBench(tc)
            % parameter passing: changed motor and grid against the independently built test bench
            P = asm_params('lab');
            P.param_set = 'custom';
            P.R2b = 1.8;  P.J_M = 0.02;  P.t_end = 1.5;  P.U_L = 380;  P.J_L = 0.015;
            R = run_asm(P);
            Pm = tc.P;  Pm.R2b = 1.8;  Pm.J_M = 0.02;
            B = asmtools.test_bench('P', Pm, 'U', 380, 'J_L', 0.015, 'dM_L', 0.3*tc.P.M_N, 't_step', 1, 't_end', 1.5);
            t = linspace(0, 1.5, 6001)';
            dn = max(abs(interp1(B.n(:,1), B.n(:,2), t) - interp1(R.time.t, R.time.n, t)));
            tc.verifyLessThan(dn/tc.P.ns, 0.01, sprintf('Benutzerdefiniert: Abweichung %.3g 1/min', dn));
            tc.verifyLessThan(R.metrics.n_end, tc.R_lab.metrics.n_end - 10, 'größeres R2′ -> mehr Schlupf');
        end

        function labConstantLoad(tc)
            % load type constant (block Last konstant) against the test bench; V3: rated point n_N
            P = asm_params('lab');
            P.load_type = 'constant';  P.M_L = tc.P.M_N;  P.dM_L = 0;  P.t_end = 1.5;
            R = run_asm(P);
            B = asmtools.test_bench('Load', 'constant', 'M_L0', tc.P.M_N, 't_end', 1.5);
            t = linspace(0, 1.5, 6001)';
            dn = max(abs(interp1(B.n(:,1), B.n(:,2), t) - interp1(R.time.t, R.time.n, t)));
            tc.verifyLessThan(dn/tc.P.ns, 0.01, sprintf('konstante Last: Abweichung %.3g 1/min', dn));
            tc.verifyLessThan(abs(R.metrics.n_end - tc.P.n_N)/tc.P.ns, 0.01, 'Bemessungspunkt n_N');
            tc.verifyEmpty(R.metrics.load_step, 'ohne Laststoß keine Laststoß-Kennzahlen');
        end

        function slidesLikeExampleModel(tc)
            % data of the field display and outputs of the rotor bar probe (B_perp, bar currents, M_S)
            m = 'ex_slides16_30_rotor_bars';
            in = Simulink.SimulationInput(m).setModelParameter('TimeOut', 120);
            ls = Simulink.Simulation.LoggingSpecification;
            for port = [2 5 6]                                   % i_k, M_S, B_perp
                addSignalsToLog(ls, Simulink.SimulationData.BlockPath([m '/Sonde']), port);
            end
            in.LoggingSpecification = ls;
            out = sim(in);
            D = asmtools.field_log_data(out.get('field_display_log'));
            R = tc.R_slides;
            L = out.logsout;  probe = struct();
            for k = 1:L.numElements, probe.(sprintf('p%d', L{k}.PortIndex)) = L{k}.Values; end
            t = R.time.t;
            tc.verifyEqual(R.time.B_perp, ip(probe.p6, t), 'AbsTol', 1e-6*0.8, 'B⊥ wie Rotorstab-Sonde');
            tc.verifyEqual(R.time.i_bar, ip(probe.p2, t), 'AbsTol', 1e-6*max(abs(R.time.i_bar(:))), ...
                'Stabströme wie Rotorstab-Sonde');
            tc.verifyEqual(R.time.M_S, ip(probe.p5, t), 'AbsTol', 1e-6*max(abs(R.time.M_S)), 'M_S wie Sonde');
            tc.verifyEqual(R.time.B_perp(1), 0.8, 'RelTol', 1e-6, 'Folie 18: B⊥ maximal');
            tc.verifyEqual(R.field_data.t, D.t, 'AbsTol', 1e-12);
            tc.verifyEqual(R.field_data.psi_h, D.psi_h, 'AbsTol', 1e-9*max(abs(D.psi_h(:))));
            tc.verifyEqual(R.field_data.i2b, D.i2b, 'AbsTol', 1e-9*max(abs(D.i2b(:))));
            tc.verifyEqual(max(hypot(R.field_data.psi_h(:,1), R.field_data.psi_h(:,2))), 2*144*0.8*0.15*0.06, ...
                'RelTol', 1e-9, '|ψh| aus B̂ = 0,8 T (p = 1)');
        end

        function slideStates(tc)
            % slides 18/21/27 (as DidacticsTest): no current, maximum out of the plane, reversed
            Z = tc.R_slides.time;
            w = @(t) interp1(Z.t, Z.i_bar, t);
            ih = tc.R_slides.metrics.ihat_bar;
            tc.verifyEqual(w(0), [0 0], 'AbsTol', 1e-6*ih, 'Folie 18: kein Strom');
            tc.verifyEqual(w(0.005), [ih -ih], 'RelTol', 1e-3, 'Folie 21: Stab 1 aus der Ebene maximal');
            tc.verifyEqual(w(0.015), [-ih ih], 'RelTol', 1e-3, 'Folie 27: Stromrichtung umgekehrt');
            tc.verifyGreaterThan(min(Z.F, [], 'all'), -1e-6*ih, 'Kraft stets in Feldrichtung');
            tc.verifyEqual(tc.R_slides.metrics.M_S_mean, ih*0.15*0.8*0.06, 'RelTol', 1e-3, ...
                'mittleres Schleifenmoment î·l·B̂·r·sin φ2');
        end

        function slidesPhi2FromRotorImpedance(tc)
            % phi2 = 90 deg + phiZ with tan(phiZ) = s*w1*L2sigma/R2 (loop values of the prototype, s = 1)
            P = asm_params('slides');  P.phi2_mode = 'impedance';
            R = run_asm(P);
            phiZ = atand(2*pi*50*tc.P.L2s_S/tc.P.R2_S);
            tc.verifyEqual(R.metrics.phiZ_deg, phiZ, 'AbsTol', 0.05);
        end

        function inputCheck(tc)
            G = asmapp.limits();
            tc.verifyFalse(asmapp.check_value('R1', -1, G));
            tc.verifyFalse(asmapp.check_value('R1', 0, G), 'R1 > 0 (Regel pos)');
            tc.verifyFalse(asmapp.check_value('p', 2.5, G), 'p ganzzahlig');
            tc.verifyFalse(asmapp.check_value('p', 13, G), 'p ≤ 12');
            tc.verifyFalse(asmapp.check_value('J_L', 0, G), 'Zusatzträgheit > 0');
            tc.verifyFalse(asmapp.check_value('U_L', NaN, G));
            tc.verifyTrue(asmapp.check_value('U_L', 0, G), 'U = 0 erlaubt (min=0)');
            tc.verifyTrue(asmapp.check_value('dM_L', -5, G), 'Entlastung erlaubt');
            P = asm_params();  P.param_set = 'custom';  P.R1 = -1;
            tc.verifyError(@() run_asm(P), 'asm:value');
            P = asm_params();  P.load_type = 'quadratic';
            tc.verifyError(@() run_asm(P), 'asm:value');
            P = asm_params();  P.scenario = 'unknown';
            tc.verifyError(@() run_asm(P), 'asm:value');
        end

        function appSmokeTest(tc)
            % open the GUI, check inputs, simulate, export, close
            app = ASMApp('Visible', false);
            tc.addTeardown(@() delete(app));
            tc.verifyTrue(isvalid(app.Figure));
            tc.verifyError(@() app.set_input('p', 2.5), 'asm:value', 'p muss ganzzahlig sein');
            tc.verifyError(@() app.set_input('J_L', 0), 'asm:value', 'Zusatzträgheit > 0');
            app.set_input('param_set', 'custom');
            app.set_input('R2b', 1.5);
            P = app.parameters();
            tc.verifyEqual(P.R2b, 1.5);
            app.set_input('param_set', 'standard');
            tc.verifyEqual(app.parameters().R2b, asm_standard().R2b, 'Standard setzt die Felder zurück');
            app.select_mode('slides');
            tc.verifyEqual(app.parameters().t_end, 0.04);
            app.simulate();
            tc.assertNotEmpty(app.Result, 'Simulation in der Oberfläche fehlgeschlagen');
            tc.verifyEqual(app.Result.metrics.ihat_bar, tc.R_slides.metrics.ihat_bar, 'RelTol', 1e-9);
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            d = app.export_figure(f.Folder);
            tc.verifyEqual(numel(d), 2, 'PNG und SVG');
            tc.verifyTrue(all(cellfun(@isfile, d)));
            fig = app.Figure;
            app.close_app();
            tc.verifyFalse(isvalid(fig), 'Fenster geschlossen');
        end

        function standardIgnoresMotorValues(tc)
            % parameter set "standard": motor values from asm_standard.m, with warning
            P = asm_params();  P.R2b = 2.5;  P.t_end = 0.05;
            R = tc.verifyWarning(@() run_asm(P), 'asm:standard');
            tc.verifyEqual(R.params.R2b, tc.P.R2b);
        end
    end
end

function y = ip(ts, t)
d = squeeze(ts.Data);
if size(d, 1) ~= numel(ts.Time), d = d.'; end
[tt, iu] = unique(ts.Time(:), 'last');
y = interp1(tt, d(iu, :), t);
end
