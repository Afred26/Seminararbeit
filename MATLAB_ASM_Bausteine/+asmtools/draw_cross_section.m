function draw_cross_section(ax, Z, k, par, opt)
%DRAW_CROSS_SECTION Draws the rotor cross-section (field, bar currents, forces) in the slide style.
%   asmtools.draw_cross_section(ax, Z, k, par, opt)
%
%   ax   axes (cleared)
%   Z    state from asmtools.cross_section_state, k = row (time instant)
%   par  p, N2, k1, k2
%   opt  struct (all fields optional):
%          orientation    'slides' (U1 on top, field clockwise, default) | 'math'
%          view           'rotor' (rotor-fixed, default) | 'stator' (stator-fixed)
%          decomposition  show field vector with B_perp / B_par (slide 16, only p = 1), default true
%          change_vector  show change vector dB_perp/dt (slide 17, only p = 1), default true
%          force          force arrows at the conductor loop (slide 19), default true
%          all_bars       show all bars (otherwise only the conductor loop), default true
%          i_max, F_max, dB_max   scaling (default: values of the time instant)
%
%   Display as in [D-ASM] slides 16-30: winding sides U1 ... W2 in the stator, colour ring =
%   air-gap flux density B (red +, blue -), bars red dot = current out of the drawing plane,
%   blue cross = into the plane, green arrow = field vector, red = component perpendicular to the
%   conductor loop (B_perp), green dashed = component without contribution (B_par), dark red =
%   change vector, blue = force. All texts in the figure are German.

def = struct('orientation', 'slides', 'view', 'rotor', 'decomposition', true, 'change_vector', true, ...
             'force', true, 'all_bars', true, 'i_max', [], 'F_max', [], 'dB_max', []);
if nargin < 5, opt = struct(); end
for f = fieldnames(def)', if ~isfield(opt, f{1}), opt.(f{1}) = def.(f{1}); end, end
S = asmexport.style();
sg = 1 - 2*strcmp(opt.orientation, 'slides');                % image angle = sg*(mathematical angle)
if strcmp(opt.view, 'rotor'), rot = Z.th(k); else, rot = 0; end
to_image = @(a) sg*(a - rot);                                % mechanical angle -> image angle
pol  = @(r, a) r*[cos(a), sin(a)];

cla(ax); hold(ax, 'on'); axis(ax, 'equal', 'off');
xlim(ax, [-1.75 1.75]); ylim(ax, [-1.75 1.75]);

% stator with winding sides (position for the first pole pair)
ring(ax, 1.22, 1.6, [0.85 0.85 0.87]);
names = {'U1', -90; 'U2', 90; 'V1', 30; 'V2', 210; 'W1', 150; 'W2', -30};
for j = 1:size(names, 1)
    a = to_image(deg2rad(names{j, 2})/par.p);                % rotor-fixed: stator turns backwards in the image
    c = pol(1.41, a);
    circle(ax, c, 0.06, 'w', [0.3 0.3 0.3]);
    text(ax, 1.66*cos(a), 1.66*sin(a), names{j, 1}, 'HorizontalAlignment', 'center', 'FontSize', 11);
end

% air-gap flux density as colour ring
nseg = 180; al = 2*pi*(0:nseg)'/nseg;
Bseg = Z.Bhat(k)*cos(par.p*(al(1:end-1) + pi/nseg) - Z.phi_el(k));
a1 = to_image(al(1:end-1)); a2 = to_image(al(2:end));        % one patch with nseg faces (faster)
x = [1.04*cos(a1) 1.2*cos(a1) 1.2*cos(a2) 1.04*cos(a2)]';
y = [1.04*sin(a1) 1.2*sin(a1) 1.2*sin(a2) 1.04*sin(a2)]';
cseg = zeros(nseg, 3);
for j = 1:nseg, cseg(j, :) = colour(Bseg(j)/max(Z.Bhat(k), eps), S); end
patch(ax, 'XData', x, 'YData', y, 'FaceVertexCData', cseg, 'FaceColor', 'flat', 'EdgeColor', 'none');

% rotor
ring(ax, 0, 1.0, [0.92 0.92 0.95]);
ring(ax, 0, 0.16, [0.4 0.4 0.4]);

% bars
if isempty(opt.i_max), opt.i_max = max(abs(Z.i_slide(k, :))); end
loop = [par.k1, par.k2];
if opt.all_bars, bars = 1:par.N2; else, bars = loop; end
for j = bars
    c = pol(0.86, to_image(Z.alpha(k, j)));
    w = max(-1, min(1, Z.i_slide(k, j)/max(opt.i_max, eps)));
    if w >= 0, col = [1, 1 - w, 1 - w]; else, col = [1 + w, 1 + w, 1]; end
    if any(j == loop), edge_width = 2.5; else, edge_width = 0.5; end
    circle(ax, c, 0.055, col, [0.2 0.2 0.2], edge_width);
    if abs(w) > 0.05
        if w > 0                                              % dot: current out of the drawing plane
            circle(ax, c, 0.018, 'k', 'k');
        else                                                  % cross: current into the drawing plane
            d = 0.035;
            plot(ax, c(1) + [-d d], c(2) + [-d d], 'k-', c(1) + [-d d], c(2) + [d -d], 'k-', 'LineWidth', 2);
        end
    end
end
c1 = pol(0.86, to_image(Z.alpha(k, par.k1)));  c2 = pol(0.86, to_image(Z.alpha(k, par.k2)));
plot(ax, [c1(1) c2(1)], [c1(2) c2(2)], '--', 'Color', [0.3 0.3 0.3]);
text(ax, 0.62*c1(1)/0.86, 0.62*c1(2)/0.86, 'Stab 1', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(ax, 0.62*c2(1)/0.86, 0.62*c2(2)/0.86, 'Stab 2', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% force arrows (tangential, positive in field direction = mathematically positive)
if opt.force
    if isempty(opt.F_max), opt.F_max = max(abs(Z.F(k, loop))); end
    for j = loop
        a = to_image(Z.alpha(k, j));
        c = pol(0.86, a);
        tang = sg*[-sin(a), cos(a)];                          % unit vector in field direction in the image
        L = 0.45*Z.F(k, j)/max(opt.F_max, eps);
        arrow(ax, c, c + L*tang, S.colour.force, 2.5);
    end
end

% field vector with decomposition and change vector (only meaningful for two poles, as on the slides)
if par.p == 1 && (opt.decomposition || opt.change_vector)
    aF = to_image(Z.phi_el(k));                              % field vector
    beta = to_image(Z.alpha(k, par.k1) - pi/2);              % normal of the conductor loop
    nvec = [cos(beta), sin(beta)];
    if opt.decomposition
        tip = 0.75*[cos(aF), sin(aF)];
        perp = 0.75*Z.B_perp(k)/max(Z.Bhat(k), eps)*nvec;
        arrow(ax, -tip, tip, S.colour.field, 3);
        arrow(ax, -perp, perp, S.colour.B, 3);
        plot(ax, [perp(1) tip(1)], [perp(2) tip(2)], '--', 'Color', S.colour.field, 'LineWidth', 2);
    end
    if opt.change_vector
        if isempty(opt.dB_max), opt.dB_max = max(abs(Z.dB_perp)); end
        d = 0.5*Z.dB_perp(k)/max(opt.dB_max, eps)*nvec;
        start = 0.1*[-nvec(2), nvec(1)];
        arrow(ax, start, start + d, [0.55 0 0], 2);
    end
end

title(ax, sprintf('t = %.4f s   θ_2 = %.0f°   M_S = %.2f N·m', Z.t(k), rad2deg(Z.theta2(k)), Z.M_S(k)), ...
      'FontWeight', 'normal', 'Color', 'k');
set(findobj(ax, 'Type', 'text'), 'Color', 'k');               % independent of the MATLAB colour theme
hold(ax, 'off');
end

%% ========================= helper functions =========================
function ring(ax, ri, ra, col)
a = linspace(0, 2*pi, 181);
if ri == 0
    patch(ax, ra*cos(a), ra*sin(a), col, 'EdgeColor', [0.5 0.5 0.5]);
else
    patch(ax, [ra*cos(a) ri*cos(fliplr(a))], [ra*sin(a) ri*sin(fliplr(a))], col, 'EdgeColor', 'none');
    plot(ax, ra*cos(a), ra*sin(a), '-', ri*cos(a), ri*sin(a), '-', 'Color', [0.5 0.5 0.5]);
end
end

function circle(ax, c, r, col, edge, width)
if nargin < 6, width = 0.5; end
a = linspace(0, 2*pi, 37);
patch(ax, c(1) + r*cos(a), c(2) + r*sin(a), col, 'EdgeColor', edge, 'LineWidth', width);
end

function arrow(ax, p0, p1, col, width)
d = p1 - p0;  L = norm(d);
if L < 1e-3, return; end
e = d/L;  n = [-e(2), e(1)];  s = min(0.08, 0.4*L);
plot(ax, [p0(1) p1(1) - 0.8*s*e(1)], [p0(2) p1(2) - 0.8*s*e(2)], '-', 'Color', col, 'LineWidth', width);
patch(ax, p1(1) + [0, -s*e(1) + 0.5*s*n(1), -s*e(1) - 0.5*s*n(1)], ...
          p1(2) + [0, -s*e(2) + 0.5*s*n(2), -s*e(2) - 0.5*s*n(2)], col, 'EdgeColor', 'none');
end

function c = colour(w, S)
% -1 ... 1 -> blue ... white ... red
w = max(-1, min(1, w));
if w >= 0, c = (1 - w)*[1 1 1] + w*S.colour.B; else, c = (1 + w)*[1 1 1] - w*[0.2 0.35 0.85]; end
end
