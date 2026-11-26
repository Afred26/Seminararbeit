classdef ExamplesTest < matlab.unittest.TestCase
%EXAMPLESTEST Example models can be built and simulated, results plausible.
%   The models are written by build_examples into a temporary folder.
%   Run in the project folder:  startup_asm; runtests('tests')

    properties
        Files
    end

    methods (TestClassSetup)
        function build(tc)
            if ~exist('asm_blocks_lib', 'file'), build_library(); end
            % models of the same name in examples/ are on the path: suppress the shadowing note
            tc.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                {'Simulink:Engine:MdlFileShadowedByFile', 'Simulink:Engine:MdlFileShadowing'}));
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Files = tc.verifyWarningFree(@() build_examples('Folder', f.Folder));
        end
    end

    methods (Test)
        function startupLoadStep(tc)
            n = simulate_speed(tc, 'ex_startup_load_step', {'Drehzahlmesser'});
            S = asm_standard();
            tc.verifyEqual(n{1}(end), 1427.4, 'AbsTol', 1, 'Enddrehzahl nach Laststoß');
            tc.verifyLessThan(max(n{1}), S.ns, 'Drehzahl bleibt unter ns');
        end

        function klossStartup(tc)
            % part B: same end speed as the Kloss motor in the model comparison
            n = simulate_speed(tc, 'ex_kloss_startup', {'Drehzahlmesser'});
            tc.verifyEqual(n{1}(end), 1424.5, 'AbsTol', 1, 'Kloss-Enddrehzahl nach Laststoß');
        end

        function conductorLoop(tc)
            file = tc.Files{contains(tc.Files, 'ex_conductor_loop')};
            load_system(file);  [~, m] = fileparts(file);
            tc.addTeardown(@() close_system(m, 0));
            out = sim(m, 'TimeOut', 120);
            tc.verifyEqual(out.tout(end), 0.2, 'AbsTol', 1e-9, 'zwei Rotorperioden bei s = sK');
            tc.verifyTrue(isempty(get_param(m, 'InitFcn')) && isempty(get_param(m, 'PreLoadFcn')), ...
                'Beispielmodelle haben keine Callbacks');
        end

        function slidesExample(tc)
            % slides 16-30: simulation runs, the field display logs two field revolutions
            file = tc.Files{contains(tc.Files, 'ex_slides16_30')};
            load_system(file);  [~, m] = fileparts(file);
            tc.addTeardown(@() close_system(m, 0));
            out = sim(m, 'TimeOut', 120);
            D = asmtools.field_log_data(out.get('field_display_log'));
            tc.verifyEqual(D.t(end), 0.04, 'AbsTol', 1e-9);
            tc.verifyEqual(max(hypot(D.psi_h(:,1), D.psi_h(:,2))), 2*144*0.8*0.15*0.06, 'RelTol', 1e-9, ...
                '|ψh| aus B̂ = 0,8 T (p = 1)');
        end

        function motorDidactics(tc)
            file = tc.Files{contains(tc.Files, 'ex_rotor_bars_motor')};
            load_system(file);  [~, m] = fileparts(file);
            tc.addTeardown(@() close_system(m, 0));
            set_param(m, 'StopTime', '0.5');
            out = sim(m, 'TimeOut', 120);
            tc.verifyEqual(out.tout(end), 0.5, 'AbsTol', 1e-9);
            k = out.get('torque_speed_log');
            tc.verifyGreaterThan(max(k.signals.values(:, 1)), 1300, 'Motor läuft hoch (Kennlinienschreiber)');
        end

        function modelComparison(tc)
            n = simulate_speed(tc, 'ex_model_comparison', {'Drehzahl_Standard', 'Drehzahl_Referenz', 'Drehzahl_Kloss'});
            tc.verifyEqual(n{1}(end), n{2}(end), 'AbsTol', 0.5, 'Standard und Referenz gleiche Enddrehzahl');
            tc.verifyEqual(n{3}(end), 1424.5, 'AbsTol', 1, 'Kloss-Enddrehzahl');
        end
    end

    methods (Access = private)
        function [n, out, m] = simulate_speed(tc, name, tachos)
            file = tc.Files{contains(tc.Files, name)};
            load_system(file);
            [~, m] = fileparts(file);
            tc.addTeardown(@() close_system(m, 0));
            for k = 1:numel(tachos)                   % log the speed (the model is not saved)
                add_block('simulink/Sinks/To Workspace', sprintf('%s/TW_n%d', m, k), ...
                    'VariableName', sprintf('n%d', k), 'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
                add_line(m, [tachos{k} '/1'], sprintf('TW_n%d/1', k), 'autorouting', 'on');
            end
            out = sim(m, 'TimeOut', 120);
            tc.assertEqual(out.tout(end), 2, 'AbsTol', 1e-9, 'Simulation nicht bis zum Ende gelaufen');
            n = arrayfun(@(k) out.get(sprintf('n%d', k)), 1:numel(tachos), 'UniformOutput', false);
        end
    end
end
