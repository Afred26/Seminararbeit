function files = cross_section_series(data, par, opt)
%CROSS_SECTION_SERIES Single frames of the rotor cross-section at fixed field angles (slides 18-30).
%   files = asmexport.cross_section_series(data, par)
%   files = asmexport.cross_section_series(data, par, 'Angles', 0:30:360, 'Name', 'folie', ...
%                                          'Numbers', 18:30, 'Folder', folder)
%
%   data     struct t, psi_h, i2b, th_mech (asmtools.field_log_data), at least one full
%            revolution of the field relative to the rotor
%   par      p, N2, l, r, N1xi1, k1, k2, bar1_angle (see asmtools.rotor_bars)
%   Angles   field angle relative to the rotor theta2 in degrees (mathematically positive; in the
%            slide view the field turns clockwise, 0:30:360 corresponds to slides 18-30)
%   Further options: display options of asmtools.draw_cross_section, Folder, Formats (slide_figure)
%   Frames from the last full field revolution. Returns: file names.

arguments
    data struct
    par struct
    opt.Angles (1,:) double = 0:30:360
    opt.Name {mustBeTextScalar} = 'folie'
    opt.Numbers (1,:) double = []
    opt.Folder {mustBeTextScalar} = asmexport.output_folder()
    opt.Formats (1,:) string = ["png" "svg"]
    opt.orientation (1,:) char = 'slides'
    opt.view (1,:) char = 'rotor'
    opt.decomposition (1,1) logical = true
    opt.change_vector (1,1) logical = true
    opt.force (1,1) logical = true
    opt.all_bars (1,1) logical = true
end
if isempty(opt.Numbers), opt.Numbers = 18 + (0:numel(opt.Angles) - 1); end

% field angle relative to the rotor over time, last full revolution
tg = linspace(data.t(1), data.t(end), 20*numel(data.t))';
Zg = asmtools.cross_section_state(data, par, tg);
thu = unwrap(Zg.theta2);
if thu(end) - thu(1) < 2*pi
    error('asmexport:series', 'Die Daten enthalten keine volle Feldumdrehung relativ zum Rotor.');
end
base = 2*pi*floor((thu(end) - 2*pi)/(2*pi));
base = max(base, 2*pi*ceil(thu(1)/(2*pi)));
[thu_e, iu] = unique(thu);
tz = interp1(thu_e, tg(iu), base + deg2rad(opt.Angles));

Z = asmtools.cross_section_state(data, par, tz);
dopt = struct('orientation', opt.orientation, 'view', opt.view, 'decomposition', opt.decomposition, ...
              'change_vector', opt.change_vector, 'force', opt.force, 'all_bars', opt.all_bars, ...
              'i_max', max(abs(Zg.i_slide(:))), 'F_max', max(max(abs(Zg.F(:, [par.k1 par.k2])))), ...
              'dB_max', max(abs(Zg.dB_perp)));
files = {};
for k = 1:numel(tz)
    f = figure('Visible', 'off', 'Color', 'w');
    ax = axes(f);
    asmtools.draw_cross_section(ax, Z, k, par, dopt);
    title(ax, sprintf('Feldwinkel relativ zum Rotor θ_2 = %g°   (Folie %d)', opt.Angles(k), opt.Numbers(k)), ...
          'FontWeight', 'normal', 'Color', 'k');
    d = asmexport.slide_figure(f, sprintf('%s%02d', opt.Name, opt.Numbers(k)), ...
                               'Folder', opt.Folder, 'Formats', opt.Formats);
    files = [files, d]; %#ok<AGROW>
    close(f);
end
end
