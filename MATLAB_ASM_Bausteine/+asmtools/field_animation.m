function fig = field_animation(data, par, opt)
%FIELD_ANIMATION Animation of the rotor cross-section from logged model quantities.
%   fig = asmtools.field_animation(data, par)
%   fig = asmtools.field_animation(data, par, 'SlowMotion', 0.02, 'Play', true, ...)
%   fig = asmtools.field_animation(blk)        from the block "Drehfeld-Anzeige" (mask button):
%                                              data from the last simulation output of the model
%
%   data   struct t, psi_h, i2b, th_mech (asmtools.field_log_data or run_asm result .field_data)
%   par    p, N2, l, r, N1xi1, k1, k2, bar1_angle (run_asm result .field_par)
%   Options: SlowMotion (simulation time per second of playback, default 0.02), Play
%   (false: first frame only), T (time range [t0 t1]) and the display options of
%   asmtools.draw_cross_section (orientation, view, decomposition, change_vector, force, all_bars).
%
%   Data flow: scripts and the GUI pass data and parameters explicitly. Only the mask button
%   (blk as input) has no other way to reach the simulation result than the workspace variable
%   that Simulink writes after a run from the model window (name = ReturnWorkspaceOutputsName,
%   usually "out"); this is the only remaining base-workspace access.

arguments
    data
    par struct = struct()
    opt.SlowMotion (1,1) double {mustBePositive} = 0.02
    opt.Play (1,1) logical = true
    opt.T double = []
    opt.orientation (1,:) char = 'slides'
    opt.view (1,:) char = 'rotor'
    opt.decomposition (1,1) logical = true
    opt.change_vector (1,1) logical = true
    opt.force (1,1) logical = true
    opt.all_bars (1,1) logical = true
end

if ischar(data) || isstring(data)                          % call from the mask button
    [data, par, opt] = from_block(char(data), opt);
end
if isempty(opt.T), opt.T = [data.t(1), data.t(end)]; end

fps = 25;
tt  = opt.T(1):opt.SlowMotion/fps:opt.T(2);
Z   = asmtools.cross_section_state(data, par, tt);
dopt = rmfield(opt, {'SlowMotion', 'Play', 'T'});
dopt.i_max  = max(abs(Z.i_slide(:)));                       % fixed scaling over the animation
dopt.F_max  = max(max(abs(Z.F(:, [par.k1 par.k2]))));
dopt.dB_max = max(abs(Z.dB_perp));

fig = figure('Name', 'Drehfeld-Anzeige: Rotorquerschnitt', 'NumberTitle', 'off', 'Color', 'w');
try, theme(fig, 'light'); catch, end
ax = axes(fig);
for k = 1:numel(tt)
    if ~isgraphics(fig), return; end
    asmtools.draw_cross_section(ax, Z, k, par, dopt);
    drawnow;
    if ~opt.Play, return; end
    pause(1/fps);
end
end

function [data, par, opt] = from_block(blk, opt)
% parameters from the mask, data from the last simulation output of the model
out = asmtools.last_sim_output(blk);
data = asmtools.field_log_data(out.get('field_display_log'));
w = get_param(blk, 'MaskWSVariables');
v = @(n) w(strcmp({w.Name}, n)).Value;
par = struct('p', v('p'), 'N2', v('N2'), 'l', v('l'), 'r', v('r'), 'N1xi1', v('N1xi1'), ...
             'k1', 1, 'k2', 1 + v('N2')/(2*v('p')), 'bar1_angle', v('bar1_angle')*pi/180);
views = {'rotor', 'stator'};          opt.view = views{v('view_frame')};
orients = {'slides', 'math'};         opt.orientation = orients{v('image_orientation')};
opt.decomposition = logical(v('decomposition'));  opt.change_vector = logical(v('change_vector'));
opt.force = logical(v('force_arrows'));           opt.all_bars = logical(v('all_bars'));
opt.SlowMotion = v('slow_motion');
end
