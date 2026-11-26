classdef ExportTest < matlab.unittest.TestCase
%EXPORTTEST Checks the export package +asmexport (slide figures and model figures).
%   Run in the project folder:  startup_asm; runtests('tests')
%   All files are created in a temporary folder, export/ stays untouched.

    properties
        Folder
        Fig
    end

    methods (TestMethodSetup)
        function prepare(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Folder = f.Folder;
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
            ax.FontSize = 9;                                % deliberately too small
        end
    end

    methods (Test)
        function slideFigureCreatesPngAndSvg(tc)
            d = asmexport.slide_figure(tc.Fig, 'testbild', 'Folder', tc.Folder);
            tc.verifyEqual(numel(d), 2);
            for k = 1:numel(d)
                info = dir(d{k});
                tc.verifyNotEmpty(info, ['Datei fehlt: ' d{k}]);
                tc.verifyGreaterThan(info.bytes, 1000, ['Datei leer: ' d{k}]);
            end
            tc.verifyTrue(endsWith(d{1}, '.png') && endsWith(d{2}, '.svg'));
        end

        function slideFigureFormat16to9at300dpi(tc)
            d = asmexport.slide_figure(tc.Fig, 'format', 'Folder', tc.Folder, 'Formats', "png");
            info = imfinfo(d{1});
            S = asmexport.style();
            tc.verifyEqual(info.Width / info.Height, 16/9, 'RelTol', 0.01, 'Seitenverhältnis nicht 16:9');
            tc.verifyEqual(info.Width, round(S.width_in*S.dpi), 'RelTol', 0.01, 'Auflösung nicht 300 dpi');
        end

        function slideFigureStyle(tc)
            asmexport.slide_figure(tc.Fig, 'stil', 'Folder', tc.Folder, 'Formats', "png");
            S = asmexport.style();
            for o = findall(tc.Fig, '-property', 'FontSize')'
                tc.verifyGreaterThanOrEqual(o.FontSize, S.font_size, 'Schrift kleiner als 14 pt');
            end
            lines_found = findall(tc.Fig, 'Type', 'line');
            colour = @(n) lines_found(strcmp({lines_found.DisplayName}, n)).Color;
            tc.verifyEqual(colour('u_{L1}'), S.colour.L1);
            tc.verifyEqual(colour('u_{L2}'), S.colour.L2);
            tc.verifyEqual(colour('u_{L3}'), S.colour.L3);
            tc.verifyEqual(colour('i Stab 1'), S.colour.bar1);
            tc.verifyEqual(colour('i Stab 2'), S.colour.bar2);
        end

        function invalidFileName(tc)
            tc.verifyError(@() asmexport.slide_figure(tc.Fig, 'a/b', 'Folder', tc.Folder), 'asmexport:name');
            tc.verifyError(@() asmexport.model_figure('x', 'a b', 'Folder', tc.Folder), 'asmexport:name');
        end

        function modelFigureCreatesSvgAndPng(tc)
            m = 'asm_test_model_export';
            if bdIsLoaded(m), close_system(m, 0); end
            new_system(m);
            tc.addTeardown(@() close_system(m, 0));
            add_block('simulink/Sources/Constant', [m '/Konstante']);
            add_block('simulink/Sinks/Terminator', [m '/Ende'], 'Position', [200 40 220 60]);
            add_line(m, 'Konstante/1', 'Ende/1');
            d = asmexport.model_figure(m, 'modell', 'Folder', tc.Folder);
            tc.verifyEqual(numel(d), 2);
            for k = 1:numel(d)
                info = dir(d{k});
                tc.verifyNotEmpty(info, ['Datei fehlt: ' d{k}]);
                tc.verifyGreaterThan(info.bytes, 500, ['Datei leer: ' d{k}]);
            end
        end

        function modelFigureOfLibrary(tc)
            tc.assumeEqual(exist('asm_blocks_lib', 'file'), 4, 'Bibliothek noch nicht gebaut');
            was = bdIsLoaded('asm_blocks_lib');
            d = asmexport.model_figure('asm_blocks_lib/Maschine', 'maschine', 'Folder', tc.Folder);
            if ~was, close_system('asm_blocks_lib', 0); end
            tc.verifyEqual(numel(d), 2);
            tc.verifyTrue(all(cellfun(@(f) exist(f, 'file') == 2, d)));
        end

        function unknownSystem(tc)
            tc.verifyError(@() asmexport.model_figure('asm_does_not_exist', 'x', 'Folder', tc.Folder), ?MException);
        end

        function defaultOutputFolder(tc)
            z = asmexport.output_folder();
            tc.verifyTrue(endsWith(z, [filesep 'export']));
            tc.verifyEqual(exist(z, 'dir'), 7);
        end
    end
end
