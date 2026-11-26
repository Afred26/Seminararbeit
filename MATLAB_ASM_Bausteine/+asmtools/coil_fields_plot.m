function fig = coil_fields_plot(phi_el_deg, opt)
%COIL_FIELDS_PLOT Fields of the coils U, V, W over the air-gap angle and their sum (rotating field).
%   fig = asmtools.coil_fields_plot(phi_el_deg)      e.g. 0, 30 or 90 (as Hagl figure 6.13)
%
%   Symmetrical currents i_U = I*cos(phi_el), i_V = I*cos(phi_el - 120 deg), i_W = I*cos(phi_el - 240 deg).
%   Each coil creates a stationary, pulsating field B_k(gamma) = Bhat_ph*cos(phi_el - delta_k)*cos(gamma - delta_k)
%   with the coil axis delta_k = 0, 120, 240 deg (el.). The sum is the rotating field
%   B(gamma) = 1.5*Bhat_ph*cos(gamma - phi_el)  ([D-DF] slides 58-61; Hagl, Elektrische Antriebstechnik, p. 114 ff.).
%   Reference axis gamma = 0: axis of coil U (in [D-DF] slide 60 the maximum is shifted by 180 deg,
%   see doku/SPEC.md 3.6 no. 7). Normalisation: B/Bhat_ph.

arguments
    phi_el_deg (1,1) double = 0
    opt.Axes = []
end
S = asmexport.style();
g = linspace(0, 360, 721);  phi = deg2rad(phi_el_deg);
d = [0 120 240];  colours = {S.colour.L1, S.colour.L2, S.colour.L3};  names = {'B_U', 'B_V', 'B_W'};
if isempty(opt.Axes)
    fig = figure('Name', 'Spulenfelder', 'NumberTitle', 'off', 'Color', 'w');
    try, theme(fig, 'light'); catch, end
    ax = axes(fig);
else
    ax = opt.Axes;  fig = ancestor(ax, 'figure');
end
hold(ax, 'on');
total = 0;
for k = 1:3
    Bk = cos(phi - deg2rad(d(k)))*cos(deg2rad(g - d(k)));
    total = total + Bk;
    plot(ax, g, Bk, '-', 'Color', colours{k}, 'DisplayName', sprintf('%s (Strang L%d)', names{k}, k));
end
plot(ax, g, total, '-', 'Color', S.colour.B, 'LineWidth', 3, 'DisplayName', 'B = B_U + B_V + B_W');
grid(ax, 'on'); xlim(ax, [0 360]); xticks(ax, 0:90:360); ylim(ax, [-2 2]);
xlabel(ax, 'Luftspaltwinkel γ in Grad (el.)'); ylabel(ax, 'B / B̂_{Str}');
legend(ax, 'Location', 'southoutside', 'Orientation', 'horizontal');
title(ax, sprintf('Spulenfelder und Drehfeld für φ_{el} = %g°', phi_el_deg));
hold(ax, 'off');
end
