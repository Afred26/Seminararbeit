function fig = torque_speed_plot(data, opt)
%TORQUE_SPEED_PLOT Torque-speed diagram with dynamic trajectory and stationary characteristics.
%   fig = asmtools.torque_speed_plot(data)
%   fig = asmtools.torque_speed_plot(data, 'Kloss', true, 'EC', true, 'MK', 71.55, 'sK', 0.2, 'ns', 1500)
%   fig = asmtools.torque_speed_plot(blk)  from the block "Kennlinienschreiber" (mask button),
%                                          data from the last simulation output of the model
%
%   fig = asmtools.torque_speed_plot(data, 'Axes', ax, 'P', P, 'U', 400, 'f', 50, 'Connection', 'star')
%                                          draw into existing axes (e.g. uiaxes of ASMApp),
%                                          EC characteristic with parameter set P and grid data U, f
%
%   data  struct t, n [rpm], M [N*m], M_L [N*m] (or log "Structure With Time")
%   Stationary curves: Kloss M = 2*MK*s*sK/(s^2 + sK^2); equivalent circuit (EC) with P (default
%   parameter/asm_standard.m), U and f (default P.U_N, P.f_N) and connection (default star).
%   Operating point: mean of the last 5 % of the simulation time.
%   Source: Densborn, lecture notes "DS-Asynchron-Motor", slides 47-56; Hagl, Elektrische Antriebstechnik

arguments
    data
    opt.Kloss (1,1) logical = true
    opt.EC (1,1) logical = false
    opt.MK double = []
    opt.sK double = []
    opt.ns double = []
    opt.Axes = []
    opt.P struct = asm_standard()
    opt.U double = []
    opt.f double = []
    opt.Connection (1,:) char {mustBeMember(opt.Connection, {'star', 'delta'})} = 'star'
end
if isempty(opt.U),  opt.U = opt.P.U_N; end
if isempty(opt.f),  opt.f = opt.P.f_N; end
if isempty(opt.MK), opt.MK = opt.P.MK; end
if isempty(opt.sK), opt.sK = opt.P.sK; end
if isempty(opt.ns), opt.ns = 60*opt.f/opt.P.p; end

if ischar(data) || isstring(data)                          % call from the mask button
    blk = char(data);
    out = asmtools.last_sim_output(blk);
    data = out.get('torque_speed_log');
    w = get_param(blk, 'MaskWSVariables');
    v = @(n) w(strcmp({w.Name}, n)).Value;
    opt.Kloss = logical(v('show_kloss')); opt.EC = logical(v('show_ec'));
    opt.MK = v('MK'); opt.sK = v('sK'); opt.ns = v('ns');
end
if isfield(data, 'signals')
    y = squeeze(data.signals.values);
    if size(y, 1) ~= numel(data.time), y = y.'; end
    data = struct('t', data.time, 'n', y(:,1), 'M', y(:,2), 'M_L', y(:,3));
end
S = asmexport.style();

if isempty(opt.Axes)
    fig = figure('Name', 'Kennlinienschreiber', 'NumberTitle', 'off', 'Color', 'w');
    try, theme(fig, 'light'); catch, end
    ax = axes(fig);
else
    ax = opt.Axes;  fig = ancestor(ax, 'figure');
    cla(ax, 'reset');
end
hold(ax, 'on');
n_v = linspace(0, opt.ns, 600);  s_v = (opt.ns - n_v)/opt.ns;
if opt.EC
    plot(ax, n_v, asmtools.equivalent_circuit(opt.P, s_v, 'U', opt.U, 'f', opt.f, 'Connection', opt.Connection), ...
         '-', 'Color', S.colour.L1, 'DisplayName', 'ESB stationär');
end
if opt.Kloss
    plot(ax, n_v, asmtools.kloss_torque(s_v, opt.MK, opt.sK), ':', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Kloss');
end
plot(ax, data.n, data.M, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8, 'DisplayName', 'Motor (dynamisch)');
plot(ax, data.n, data.M_L, '--', 'Color', S.colour.L2, 'DisplayName', 'Last');
last = numel(data.t);  ib = data.t >= 0.95*data.t(last);
plot(ax, mean(data.n(ib)), mean(data.M(ib)), 'ko', 'MarkerFaceColor', 'k', 'DisplayName', 'Arbeitspunkt (Ende)');
grid(ax, 'on'); xlim(ax, [0 opt.ns]);
xlabel(ax, 'n in 1/min'); ylabel(ax, 'M in N·m'); legend(ax, 'Location', 'northwest');
title(ax, 'Drehmoment-Drehzahl-Kennlinie');
hold(ax, 'off');
end
