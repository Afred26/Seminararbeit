classdef ExportTest < matlab.unittest.TestCase
%EXPORTTEST Prüft das Export-Gerüst +asmexport (Folienbilder und Modellbilder).
%   Ausführen im Projektordner:  startup_asm; runtests('tests')
%   Alle Dateien entstehen in einem temporären Ordner, export/ bleibt unberührt.

    properties
        Ordner
        Fig
    end

    methods (TestMethodSetup)
        function vorbereiten(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Ordner = f.Folder;
            tc.Fig = figure('Visible', 'off');
            tc.addTeardown(@() close(tc.Fig));
            t = linspace(0, 0.04, 400);
            ax = axes(tc.Fig); hold(ax, 'on');
            plot(ax, t, sin(2*pi*50*t), 'DisplayName', 'u_{L1}');
            plot(ax, t, sin(2*pi*50*t - 2*pi/3), 'DisplayName', 'u_{L2}');
            plot(ax, t, sin(2*pi*50*t - 4*pi/3), 'DisplayName', 'u_{L3}');
            plot(ax, t, 0.5*sin(2*pi*50*t), 'DisplayName', 'i Stab 1');
            plot(ax, t, -0.5*sin(2*pi*50*t), 'DisplayName', 'i Stab 2');
            legend(ax); xlabel(ax, 't in s'); ylabel(ax, 'u / û'); title(ax, 'Testbild');
            text(ax, 0.01, 0.8, 'kleiner Text', 'FontSize', 8);
            ax.FontSize = 9;                                % absichtlich zu klein
        end
    end

    methods (Test)
        function folienbildErzeugtPngUndSvg(tc)
            d = asmexport.folienbild(tc.Fig, 'testbild', 'Ordner', tc.Ordner);
            tc.verifyEqual(numel(d), 2);
            for k = 1:numel(d)
                info = dir(d{k});
                tc.verifyNotEmpty(info, ['Datei fehlt: ' d{k}]);
                tc.verifyGreaterThan(info.bytes, 1000, ['Datei leer: ' d{k}]);
            end
            tc.verifyTrue(endsWith(d{1}, '.png') && endsWith(d{2}, '.svg'));
        end

        function folienbildFormat16zu9mit300dpi(tc)
            d = asmexport.folienbild(tc.Fig, 'format', 'Ordner', tc.Ordner, 'Formate', "png");
            info = imfinfo(d{1});
            S = asmexport.stil();
            tc.verifyEqual(info.Width / info.Height, 16/9, 'RelTol', 0.01, 'Seitenverhältnis nicht 16:9');
            tc.verifyEqual(info.Width, round(S.breite_in*S.dpi), 'RelTol', 0.01, 'Auflösung nicht 300 dpi');
        end

        function folienbildStil(tc)
            asmexport.folienbild(tc.Fig, 'stil', 'Ordner', tc.Ordner, 'Formate', "png");
            S = asmexport.stil();
            for o = findall(tc.Fig, '-property', 'FontSize')'
                tc.verifyGreaterThanOrEqual(o.FontSize, S.schriftgroesse, 'Schrift kleiner als 14 pt');
            end
            linien = findall(tc.Fig, 'Type', 'line');
            farbe = @(n) linien(strcmp({linien.DisplayName}, n)).Color;
            tc.verifyEqual(farbe('u_{L1}'), S.farbe.L1);
            tc.verifyEqual(farbe('u_{L2}'), S.farbe.L2);
            tc.verifyEqual(farbe('u_{L3}'), S.farbe.L3);
            tc.verifyEqual(farbe('i Stab 1'), S.farbe.Stab1);
            tc.verifyEqual(farbe('i Stab 2'), S.farbe.Stab2);
        end

        function ungueltigerDateiname(tc)
            tc.verifyError(@() asmexport.folienbild(tc.Fig, 'a/b', 'Ordner', tc.Ordner), 'asmexport:name');
            tc.verifyError(@() asmexport.modellbild('x', 'a b', 'Ordner', tc.Ordner), 'asmexport:name');
        end

        function modellbildErzeugtSvgUndPng(tc)
            m = 'asm_testmodell_export';
            if bdIsLoaded(m), close_system(m, 0); end
            new_system(m);
            tc.addTeardown(@() close_system(m, 0));
            add_block('simulink/Sources/Constant', [m '/Konstante']);
            add_block('simulink/Sinks/Terminator', [m '/Ende'], 'Position', [200 40 220 60]);
            add_line(m, 'Konstante/1', 'Ende/1');
            d = asmexport.modellbild(m, 'modell', 'Ordner', tc.Ordner);
            tc.verifyEqual(numel(d), 2);
            for k = 1:numel(d)
                info = dir(d{k});
                tc.verifyNotEmpty(info, ['Datei fehlt: ' d{k}]);
                tc.verifyGreaterThan(info.bytes, 500, ['Datei leer: ' d{k}]);
            end
        end

        function modellbildDerBibliothek(tc)
            tc.assumeEqual(exist('asm_bausteine_lib', 'file'), 4, 'Bibliothek noch nicht gebaut');
            war = bdIsLoaded('asm_bausteine_lib');
            d = asmexport.modellbild('asm_bausteine_lib/Maschine', 'maschine', 'Ordner', tc.Ordner);
            if ~war, close_system('asm_bausteine_lib', 0); end
            tc.verifyEqual(numel(d), 2);
            tc.verifyTrue(all(cellfun(@(f) exist(f, 'file') == 2, d)));
        end

        function unbekanntesSystem(tc)
            tc.verifyError(@() asmexport.modellbild('asm_gibt_es_nicht', 'x', 'Ordner', tc.Ordner), ?MException);
        end

        function zielordnerStandard(tc)
            z = asmexport.zielordner();
            tc.verifyTrue(endsWith(z, [filesep 'export']));
            tc.verifyEqual(exist(z, 'dir'), 7);
        end
    end
end
