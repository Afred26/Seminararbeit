function C = compare_kloss_dynamic(opt)
%COMPARE_KLOSS_DYNAMIC Speed n(t) of the Kloss model and the space-vector model at the same load step.
%   C = compare_kloss_dynamic()                   simulates both models, plots and exports the figure
%   C = compare_kloss_dynamic('Export', false)    without export
%   C = compare_kloss_dynamic('Folder', folder)   other export folder
%
%   Both runs use run_asm with the default parameters of asm_params: same fan load
%   (M_B = M_N at n_B = n_N), same inertia J = J_M + J_L, start from standstill, load step
%   0.3*M_N at t = 1 s, t_end = 2 s, same evaluation (asmtools.speed_metrics).
%   Unavoidable differences (shown in C.differences):
%     - Kloss (part B): quasi-static torque M = 2*MK*s*sK/(s^2 + sK^2) with MK = 71.55 N*m,
%       sK = 0.2; no electrical dynamics, no grid.
%     - space-vector model ASM Standard: grid 400 V / 50 Hz switched on at t = 0 from the
%       currentless state, stator and rotor flux dynamics; its stationary curve is the T
%       equivalent circuit (breakdown torque 71.55 N*m at s = 0.2, starting torque 28.8 N*m
%       instead of 27.5 N*m with Kloss).
%
%   The figure (German labels) shows the whole run-up and an enlarged view of the load step with
%   the step time, the new steady operating point of each model and - only where the trajectory
%   dips below the new operating point by more than the tolerance band - the transient minimum.
%   Export: export/vergleich_kloss_raumzeiger.png/.svg (asmexport.slide_figure).
%
%   Returns C with fields kloss, dynamic (run_asm results), table (key figures per model, German
%   row names), differences (German text), files.

arguments
    opt.Export (1,1) logical = true
    opt.Folder {mustBeTextScalar} = asmexport.output_folder()
end

Rk = run_asm(asm_params('kloss'));
Rd = run_asm(asm_params('lab'));
C.kloss = Rk;
C.dynamic = Rd;
C.table = key_figures(Rk, Rd);
C.differences = {
    'Kloss (Teil B): quasistationäres Moment nach Kloss, MK = 71,55 N·m, sK = 0,2; keine elektrische Dynamik, kein Netz.'
    'Raumzeigermodell (ASM Standard): Netz 400 V / 50 Hz, Einschalten bei t = 0 aus dem stromlosen Zustand, Stator- und Rotorflussdynamik; stationäre Kennlinie = T-Ersatzschaltbild.'
    'Gleich: Lüfterlast (M_B = M_N bei n_B = n_N), Trägheit J_M + J_L = 0,022 kg·m², Start aus dem Stillstand, Laststoß 0,3·M_N bei t = 1 s, Auswertung und Toleranzband.'};
disp(C.table);
fprintf('%s\n', C.differences{:});

S = asmexport.style();
f = figure('Visible', ~opt.Export, 'Color', 'w');
cleanup = onCleanup(@() close_if(f, opt.Export));
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact');
models = {Rk, 'Kloss (quasistationär)', [0.35 0.35 0.35], ':'; Rd, 'Raumzeigermodell (dynamisch)', S.colour.L1, '-'};

ax = nexttile(tl);  hold(ax, 'on');
for k = 1:2
    plot(ax, models{k, 1}.time.t, models{k, 1}.time.n, models{k, 4}, 'Color', models{k, 3}, ...
         'LineWidth', 2, 'DisplayName', models{k, 2});
end
xline(ax, Rk.params.t_step, '--', 'Laststoß', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
grid(ax, 'on');  xlabel(ax, 't in s');  ylabel(ax, 'n in 1/min');  xlim(ax, [0 Rk.params.t_end]);
title(ax, 'Hochlauf und Laststoß', 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast');

ax = nexttile(tl);  hold(ax, 'on');
zoom = [Rk.params.t_step - 0.03, Rk.params.t_step + 0.12];
for k = 1:2
    R = models{k, 1};  L = R.metrics.load_step;
    plot(ax, R.time.t, R.time.n, models{k, 4}, 'Color', models{k, 3}, 'LineWidth', 2, 'DisplayName', models{k, 2});
    plot(ax, zoom, [L.n_new L.n_new], '--', 'Color', models{k, 3}, 'LineWidth', 1, ...
         'DisplayName', sprintf('n_{neu} = %s 1/min', de(L.n_new, '%.1f')));
    if L.undershoot > L.band                     % own transient minimum below the new operating point
        plot(ax, L.t_min, L.n_min, 'v', 'Color', models{k, 3}, 'MarkerFaceColor', models{k, 3}, ...
             'MarkerSize', 9, 'DisplayName', sprintf('n_{min} = %s 1/min', de(L.n_min, '%.1f')));
    end
end
xline(ax, Rk.params.t_step, '--', 't_{stoß}', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
grid(ax, 'on');  xlabel(ax, 't in s');  ylabel(ax, 'n in 1/min');  xlim(ax, zoom);
ylim(ax, [min(Rd.metrics.load_step.n_min, Rk.metrics.load_step.n_min) - 5, ...
          max(Rd.metrics.load_step.n_before, Rk.metrics.load_step.n_before) + 5]);
title(ax, 'Ausschnitt Laststoß (ΔM_L = 0,3·M_N)', 'FontWeight', 'normal');
legend(ax, 'Location', 'northeast');
title(tl, 'Drehzahl beim Laststoß: Kloss-Modell und dynamisches Raumzeigermodell (Beispielparameter)');

C.files = {};
if opt.Export
    C.files = asmexport.slide_figure(f, 'vergleich_kloss_raumzeiger', 'Folder', opt.Folder, 'Colours', false);
    fprintf('Abbildung: %s\n', strjoin(C.files, ', '));
end
end

function T = key_figures(Rk, Rd)
% key figures per model (German row names), values in the units given in the row name
rows = {'Hochlaufzeit bis 0,9·n_N in s', @(R) R.metrics.startup.t_target
        'n_vor (vor dem Laststoß) in 1/min', @(R) R.metrics.load_step.n_before
        'erwartet n_vor (stationär) in 1/min', @(R) R.metrics.expected.before.n
        'n_min nach dem Laststoß in 1/min', @(R) R.metrics.load_step.n_min
        'eigenes Minimum unter n_neu − Band (1 = ja, 0 = nein)', @(R) double(own_minimum(R))
        't_min − t_stoß in s (nur bei eigenem Minimum)', @(R) min_time(R)
        'Einbruch n_vor − n_min in 1/min', @(R) R.metrics.load_step.dn_dip
        'Unterschwingen n_neu − n_min in 1/min', @(R) R.metrics.load_step.undershoot
        'n_neu (neuer Arbeitspunkt) in 1/min', @(R) R.metrics.load_step.n_new
        'erwartet n_neu (stationär) in 1/min', @(R) R.metrics.expected.after.n
        'statischer Unterschied n_vor − n_neu in 1/min', @(R) R.metrics.load_step.dn_static
        'Einschwingzeit (±1,5 1/min) in s', @(R) R.metrics.load_step.t_settle};
v = zeros(size(rows, 1), 2);
for k = 1:size(rows, 1)
    v(k, :) = [rows{k, 2}(Rk), rows{k, 2}(Rd)];
end
T = array2table(v, 'VariableNames', {'Kloss', 'Raumzeigermodell'}, 'RowNames', rows(:, 1));
end

function tf = own_minimum(R)
% transient minimum below the new operating point by more than the tolerance band
L = R.metrics.load_step;
tf = L.undershoot > L.band;
end

function t = min_time(R)
% time of the transient minimum after the step; NaN if the trajectory approaches the new
% operating point monotonically (then the "minimum" is only the end of the approach)
L = R.metrics.load_step;
if own_minimum(R), t = L.t_min - L.t_step; else, t = NaN; end
end

function s = de(x, fmt)
s = strrep(sprintf(fmt, x), '.', ',');
end

function close_if(f, yes)
if yes && isgraphics(f), close(f); end
end
