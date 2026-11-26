function out = last_sim_output(blk)
%LAST_SIM_OUTPUT Simulation output of the model that contains blk (for mask buttons only).
%   out = asmtools.last_sim_output(blk)
%
%   After a run started from the model window, Simulink stores the result in the base
%   workspace under the name given by the model parameter ReturnWorkspaceOutputsName
%   (default "out"). Mask buttons have no other access to it, so this function is the single
%   place that reads the base workspace. Scripts and the GUI use run_asm and pass the
%   results explicitly instead.

name = get_param(bdroot(blk), 'ReturnWorkspaceOutputsName');
if isempty(name), name = 'out'; end
if ~evalin('base', sprintf('exist(''%s'', ''var'')', name))
    error('asmtools:display', ['Keine Simulationsdaten: zuerst das Modell simulieren ' ...
          '(Ergebnis in der Variablen "%s").'], name);
end
out = evalin('base', name);
end
