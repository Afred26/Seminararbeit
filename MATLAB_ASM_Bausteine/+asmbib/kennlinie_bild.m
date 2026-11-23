function fig = kennlinie_bild(daten, opt)
%KENNLINIE_BILD Drehmoment-Drehzahl-Diagramm mit dynamischem Verlauf und stationären Kennlinien.
%   fig = asmbib.kennlinie_bild(daten)
%   fig = asmbib.kennlinie_bild(daten, 'Kloss', true, 'ESB', true, 'MK', 71.55, 'sK', 0.2, 'ns', 1500)
%   fig = asmbib.kennlinie_bild(blk)     aus dem Baustein "Kennlinienschreiber" (Maskenknopf),
%                                        Daten aus out.kennlinie im Base Workspace
%
%   fig = asmbib.kennlinie_bild(daten, 'Achse', ax, 'P', P, 'U', 400, 'f', 50, 'Schaltung', 'Stern')
%                                        in vorhandene Achsen zeichnen (z. B. uiaxes der ASMApp),
%                                        ESB-Kennlinie mit Parametersatz P und Netzdaten U, f
%
%   daten  Struktur t, n [1/min], M [N·m], M_L [N·m] (oder Protokoll "Structure With Time")
%   Stationäre Kurven: Kloss M = 2·MK·s·sK/(s² + sK²); ESB mit P (Standard parameter/asm_standard.m),
%   U und f (Standard P.U_N, P.f_N) und Schaltung (Standard Stern).
%   Arbeitspunkte: Mittelwerte der letzten 5 % vor jedem Laststoß bzw. am Ende.
%   Quelle: Densborn, Skript "DS-Asynchron-Motor", Folien 47-56; Hagl, Elektrische Antriebstechnik

arguments
    daten
    opt.Kloss (1,1) logical = true
    opt.ESB (1,1) logical = false
    opt.MK (1,1) double = 71.55
    opt.sK (1,1) double = 0.2
    opt.ns (1,1) double = 1500
    opt.Achse = []
    opt.P struct = asm_standard()
    opt.U double = []
    opt.f double = []
    opt.Schaltung (1,:) char {mustBeMember(opt.Schaltung, {'Stern', 'Dreieck'})} = 'Stern'
end
if isempty(opt.U), opt.U = opt.P.U_N; end
if isempty(opt.f), opt.f = opt.P.f_N; end

if ischar(daten) || isstring(daten)
    blk = char(daten);
    out = evalin('base', 'out');
    daten = out.get('kennlinie');
    w = get_param(blk, 'MaskWSVariables');
    v = @(n) w(strcmp({w.Name}, n)).Value;
    opt.Kloss = logical(v('kurve_kloss')); opt.ESB = logical(v('kurve_esb'));
    opt.MK = v('MK'); opt.sK = v('sK'); opt.ns = v('ns');
end
if isfield(daten, 'signals')
    y = squeeze(daten.signals.values);
    if size(y, 1) ~= numel(daten.time), y = y.'; end
    daten = struct('t', daten.time, 'n', y(:,1), 'M', y(:,2), 'M_L', y(:,3));
end
S = asmexport.stil();

if isempty(opt.Achse)
    fig = figure('Name', 'Kennlinienschreiber', 'NumberTitle', 'off', 'Color', 'w');
    try, theme(fig, 'light'); catch, end
    ax = axes(fig);
else
    ax = opt.Achse;  fig = ancestor(ax, 'figure');
    cla(ax, 'reset');
end
hold(ax, 'on');
n_v = linspace(0, opt.ns, 600);  s_v = (opt.ns - n_v)/opt.ns;
if opt.ESB
    plot(ax, n_v, asmbib.esb_kennlinie(opt.P, s_v, 'U', opt.U, 'f', opt.f, 'Schaltung', opt.Schaltung), ...
         '-', 'Color', S.farbe.L1, 'DisplayName', 'ESB stationär');
end
if opt.Kloss
    plot(ax, n_v, 2*opt.MK*s_v*opt.sK./(s_v.^2 + opt.sK^2), ':', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Kloss');
end
plot(ax, daten.n, daten.M, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8, 'DisplayName', 'Motor (dynamisch)');
plot(ax, daten.n, daten.M_L, '--', 'Color', S.farbe.L2, 'DisplayName', 'Last');
ende = numel(daten.t);  ib = daten.t >= 0.95*daten.t(ende);
plot(ax, mean(daten.n(ib)), mean(daten.M(ib)), 'ko', 'MarkerFaceColor', 'k', 'DisplayName', 'Arbeitspunkt (Ende)');
grid(ax, 'on'); xlim(ax, [0 opt.ns]);
xlabel(ax, 'n in 1/min'); ylabel(ax, 'M in N·m'); legend(ax, 'Location', 'northwest');
title(ax, 'Drehmoment-Drehzahl-Kennlinie');
hold(ax, 'off');
end
