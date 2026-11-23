function fig = spulenfelder_bild(phi_el_grad, opt)
%SPULENFELDER_BILD Felder der Spulen U, V, W über dem Luftspaltwinkel und ihre Summe (Drehfeld).
%   fig = asmbib.spulenfelder_bild(phi_el_grad)      z. B. 0, 30 oder 90 (wie Hagl Bild 6.13)
%
%   Symmetrische Ströme i_U = Î·cos(φ_el), i_V = Î·cos(φ_el − 120°), i_W = Î·cos(φ_el − 240°).
%   Jede Spule erzeugt ein ruhendes, zeitlich pulsierendes Feld B_k(γ) = B̂_Str·cos(φ_el − δ_k)·cos(γ − δ_k)
%   mit der Spulenachse δ_k = 0°, 120°, 240° (el.). Die Summe ist das Drehfeld
%   B(γ) = 1,5·B̂_Str·cos(γ − φ_el)  ([D-DF] Folien 58-61; Hagl, Elektrische Antriebstechnik, S. 114 ff.).
%   Bezugsachse γ = 0: Achse der Spule U (in [D-DF] Folie 60 liegt das Maximum um 180° versetzt,
%   siehe doku/SPEC.md 3.6 Nr. 7). Normierung: B/B̂_Str.

arguments
    phi_el_grad (1,1) double = 0
    opt.Achse = []
end
S = asmexport.stil();
g = linspace(0, 360, 721);  phi = deg2rad(phi_el_grad);
d = [0 120 240];  farben = {S.farbe.L1, S.farbe.L2, S.farbe.L3};  namen = {'B_U', 'B_V', 'B_W'};
if isempty(opt.Achse)
    fig = figure('Name', 'Spulenfelder', 'NumberTitle', 'off', 'Color', 'w');
    try, theme(fig, 'light'); catch, end
    ax = axes(fig);
else
    ax = opt.Achse;  fig = ancestor(ax, 'figure');
end
hold(ax, 'on');
summe = 0;
for k = 1:3
    Bk = cos(phi - deg2rad(d(k)))*cos(deg2rad(g - d(k)));
    summe = summe + Bk;
    plot(ax, g, Bk, '-', 'Color', farben{k}, 'DisplayName', sprintf('%s (Strang L%d)', namen{k}, k));
end
plot(ax, g, summe, '-', 'Color', S.farbe.B, 'LineWidth', 3, 'DisplayName', 'B = B_U + B_V + B_W');
grid(ax, 'on'); xlim(ax, [0 360]); xticks(ax, 0:90:360); ylim(ax, [-2 2]);
xlabel(ax, 'Luftspaltwinkel γ in Grad (el.)'); ylabel(ax, 'B / B̂_{Str}');
legend(ax, 'Location', 'southoutside', 'Orientation', 'horizontal');
title(ax, sprintf('Spulenfelder und Drehfeld für φ_{el} = %g°', phi_el_grad));
hold(ax, 'off');
end
