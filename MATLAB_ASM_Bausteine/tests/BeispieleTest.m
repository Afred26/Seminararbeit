classdef BeispieleTest < matlab.unittest.TestCase
%BEISPIELETEST Beispielmodelle lassen sich bauen und simulieren, Ergebnisse plausibel.
%   Die Modelle werden mit baue_beispiele in einen temporären Ordner geschrieben.
%   Ausführen im Projektordner:  startup_asm; runtests('tests')

    properties
        Dateien
    end

    methods (TestClassSetup)
        function bauen(tc)
            if ~exist('asm_bausteine_lib', 'file'), build_library(); end
            % gleichnamige Modelle in beispiele/ liegen im Pfad: Hinweis auf Verdeckung unterdrücken
            tc.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                {'Simulink:Engine:MdlFileShadowedByFile', 'Simulink:Engine:MdlFileShadowing'}));
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Dateien = tc.verifyWarningFree(@() baue_beispiele('Ordner', f.Folder));
        end
    end

    methods (Test)
        function hochlaufLaststoss(tc)
            [n, out, m] = simuliere(tc, 'bsp_hochlauf_laststoss', {'Drehzahlmesser'});  %#ok<ASGLU>
            S = asm_standard();
            tc.verifyEqual(n{1}(end), 1427.4, 'AbsTol', 1, 'Enddrehzahl nach Laststoß');
            tc.verifyLessThan(max(n{1}), S.ns, 'Drehzahl bleibt unter ns');
        end

        function folienBeispiel(tc)
            % Folien 16-30: Simulation läuft, Drehfeld-Anzeige protokolliert zwei Feldumdrehungen
            datei = tc.Dateien{contains(tc.Dateien, 'bsp_folien16_30')};
            load_system(datei);  [~, m] = fileparts(datei);
            tc.addTeardown(@() close_system(m, 0));
            out = sim(m, 'TimeOut', 120);
            D = asmbib.drehfeld_daten(out.get('drehfeld_anzeige'));
            tc.verifyEqual(D.t(end), 0.04, 'AbsTol', 1e-9);
            tc.verifyEqual(max(hypot(D.psi_h(:,1), D.psi_h(:,2))), 2*144*0.8*0.15*0.06, 'RelTol', 1e-9, ...
                '|ψh| aus B̂ = 0,8 T (p = 1)');
        end

        function motorDidaktik(tc)
            datei = tc.Dateien{contains(tc.Dateien, 'bsp_rotorstab_motor')};
            load_system(datei);  [~, m] = fileparts(datei);
            tc.addTeardown(@() close_system(m, 0));
            set_param(m, 'StopTime', '0.5');
            out = sim(m, 'TimeOut', 120);
            tc.verifyEqual(out.tout(end), 0.5, 'AbsTol', 1e-9);
            k = out.get('kennlinie');
            tc.verifyGreaterThan(max(k.signals.values(:, 1)), 1300, 'Motor läuft hoch (Kennlinienschreiber)');
        end

        function vergleichModelle(tc)
            n = simuliere(tc, 'bsp_vergleich_modelle', {'Drehzahl_Standard', 'Drehzahl_Referenz', 'Drehzahl_Kloss'});
            tc.verifyEqual(n{1}(end), n{2}(end), 'AbsTol', 0.5, 'Standard und Referenz gleiche Enddrehzahl');
            tc.verifyEqual(n{3}(end), 1424.5, 'AbsTol', 1, 'Kloss-Enddrehzahl');
        end
    end

    methods (Access = private)
        function [n, out, m] = simuliere(tc, name, tachos)
            datei = tc.Dateien{contains(tc.Dateien, name)};
            load_system(datei);
            [~, m] = fileparts(datei);
            tc.addTeardown(@() close_system(m, 0));
            for k = 1:numel(tachos)                   % Drehzahl protokollieren (Modell wird nicht gespeichert)
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
