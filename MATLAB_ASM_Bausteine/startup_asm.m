%% startup_asm.m
% Sets the MATLAB paths for the ASM block library.
% Call in the project folder: startup_asm
%
% Afterwards:
%   build_library            rebuild the library (lib/ is overwritten)
%   build_examples           rebuild the example models (examples/)
%   R = run_asm(asm_params('kloss'))   simulation without GUI (see run_asm)
%   T = verify_asm()         technical test cases with report table
%   runtests('tests')        all unit tests
%   ASMApp                   graphical user interface

asm_root = fileparts(mfilename('fullpath'));
addpath(asm_root, ...                                  % packages +asmlib, +asmtools, +asmexport, +asmapp
        fullfile(asm_root, 'lib'), ...                 % generated libraries
        fullfile(asm_root, 'parameter'), ...           % parameter sets
        fullfile(asm_root, 'examples'));               % example models
fprintf('ASM-Bausteine: Pfade gesetzt (%s)\n', asm_root);
if ~exist(fullfile(asm_root, 'lib', 'asm_blocks_lib.slx'), 'file')
    fprintf('  Bibliothek fehlt noch - build_library ausführen.\n');
end
clear asm_root
