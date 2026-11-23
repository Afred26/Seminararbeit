%% startup_asm.m
% Setzt die MATLAB-Pfade für die ASM-Bausteinbibliothek.
% Aufruf im Projektordner: startup_asm
%
% Danach:
%   build_library            Bibliothek neu bauen (lib/ wird überschrieben)
%   runtests('tests')        Tests ausführen
%   asm_bausteine_lib        Bibliothek öffnen (oder Library Browser, Eintrag "ASM-Bausteine")

asm_wurzel = fileparts(mfilename('fullpath'));
addpath(asm_wurzel, ...                                  % Pakete +asmlib, +asmexport, +asmbib
        fullfile(asm_wurzel, 'lib'), ...                 % generierte Bibliotheken
        fullfile(asm_wurzel, 'parameter'), ...           % Parametersätze
        fullfile(asm_wurzel, 'beispiele'));              % Beispielmodelle
fprintf('ASM-Bausteine: Pfade gesetzt (%s)\n', asm_wurzel);
if ~exist(fullfile(asm_wurzel, 'lib', 'asm_bausteine_lib.slx'), 'file')
    fprintf('  Bibliothek fehlt noch - build_library ausführen.\n');
end
clear asm_wurzel
