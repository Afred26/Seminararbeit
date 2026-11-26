function files = export_slide_figures(opt)
%EXPORT_SLIDE_FIGURES Creates all slide figures of the didactics (slides 16-30, rotating field,
%   characteristic) in export/.
%   files = export_slide_figures()
%   files = export_slide_figures('Folder', folder)
%
%   Simulates ex_slides16_30_rotor_bars and ex_rotor_bars_motor (from examples/) and exports
%   (file names and figure texts German, as used in the thesis):
%     folie18 ... folie30         rotor cross-section at theta2 = 0, 30, ..., 360 deg ([D-ASM] slides 18-30)
%     folie16_verlaeufe           B_perp(t), current in bar 1/2, force, loop torque ([D-ASM] slide 16)
%     drehfeld_spulen_0/30/90     coil fields and rotating field over gamma ([D-DF] slides 60/61, Hagl fig. 6.13)
%     motor_querschnitt           rotor cross-section of the 4-pole motor in rated operation
%     motor_kennlinie             M(n) with run-up, Kloss and EC ([D-ASM] slides 47-56)
%   All values are example values (parameter/asm_standard.m). Run time about 1 minute.

arguments
    opt.Folder {mustBeTextScalar} = asmexport.output_folder()
end
here = fileparts(mfilename('fullpath'));
load_system('asm_blocks_lib');
files = {};
S = asmexport.style();

%% slides 16-30: ideal rotating field, rotor at rest, phi2 = 90 deg (via run_asm)
R = run_asm(asm_params('slides'));
D = R.field_data;
par = R.field_par;
files = [files, asmexport.cross_section_series(D, par, 'Folder', opt.Folder)];

% slide 16: time plots (flux density perpendicular to the loop red, current blue)
t = linspace(0, 0.02, 801)';
Z = asmtools.cross_section_state(D, par, t);
f = figure('Visible', 'off');
tl = tiledlayout(f, 2, 1);
ax = nexttile(tl);
yyaxis(ax, 'left');  plot(ax, t*1e3, -Z.B_perp, '-', 'Color', S.colour.B, 'DisplayName', 'B_⊥ (Beitrag zur Induktion)');
ylabel(ax, 'B_⊥ in T');  ax.YColor = S.colour.B;
yyaxis(ax, 'right'); plot(ax, t*1e3, Z.i_slide(:, 1), '-', 'Color', S.colour.i, 'DisplayName', 'Strom Stab 1');
ylabel(ax, 'i in A');  ax.YColor = S.colour.i;
grid(ax, 'on');  legend(ax, 'Location', 'southoutside', 'Orientation', 'horizontal');
title(ax, 'Folie 16: Flussdichte senkrecht zur Schleife und Stabstrom (aus der Ebene positiv)');
ax = nexttile(tl);
plot(ax, t*1e3, Z.F(:, 1), '-', 'Color', S.colour.bar1, 'DisplayName', 'Kraft Stab 1');  hold(ax, 'on');
plot(ax, t*1e3, Z.F(:, 2), '--', 'Color', S.colour.bar2, 'DisplayName', 'Kraft Stab 2');
yyaxis(ax, 'right');  plot(ax, t*1e3, Z.M_S, ':', 'Color', [0.3 0.3 0.3], 'DisplayName', 'M_S Schleife');
ylabel(ax, 'M_S in N·m');  ax.YColor = [0.3 0.3 0.3];
yyaxis(ax, 'left');  ylabel(ax, 'F in N');  grid(ax, 'on');  xlabel(ax, 't in ms');
legend(ax, 'Location', 'southoutside', 'Orientation', 'horizontal');
files = [files, asmexport.slide_figure(f, 'folie16_verlaeufe', 'Folder', opt.Folder, 'Colours', false)];
close(f);

%% rotating field: coil fields (Hagl figure 6.13)
for w = [0 30 90]
    f = asmtools.coil_fields_plot(w);  set(f, 'Visible', 'off');
    files = [files, asmexport.slide_figure(f, sprintf('drehfeld_spulen_%d', w), 'Folder', opt.Folder)]; %#ok<AGROW>
    close(f);
end

%% motor: cross-section in rated operation and characteristic
m = 'ex_rotor_bars_motor';
load_system(fullfile(here, [m '.slx']));
out = sim(m, 'TimeOut', 300);
close_system(m, 0);
P = asm_standard();
Dm = asmtools.field_log_data(out.get('field_display_log'));
parm = struct('p', P.p, 'N2', P.N2, 'l', P.l, 'r', P.r, 'N1xi1', 144, 'k1', 1, 'k2', 1 + P.N2/(2*P.p), ...
              'bar1_angle', -pi/2);
Zm = asmtools.cross_section_state(Dm, parm, 0.95);
f = figure('Visible', 'off');  ax = axes(f);
asmtools.draw_cross_section(ax, Zm, 1, parm, struct('view', 'stator'));
title(ax, sprintf('Motor (4-polig, 28 Stäbe) im Bemessungsbetrieb, t = 0,95 s, M_S = %.2f N·m', Zm.M_S), ...
      'FontWeight', 'normal', 'Color', 'k');
files = [files, asmexport.slide_figure(f, 'motor_querschnitt', 'Folder', opt.Folder)];
close(f);
f = asmtools.torque_speed_plot(out.get('torque_speed_log'), 'EC', true);  set(f, 'Visible', 'off');
files = [files, asmexport.slide_figure(f, 'motor_kennlinie', 'Folder', opt.Folder)];
close(f);
fprintf('export_slide_figures: %d Dateien in %s\n', numel(files), opt.Folder);
end
