function files = slide_figure(fig, name, opt)
%SLIDE_FIGURE Exports a figure in the uniform slide style (16:9) as PNG and SVG.
%   files = asmexport.slide_figure(fig, name)
%   files = asmexport.slide_figure(fig, name, 'Folder', folder, 'Formats', ["png" "svg"])
%
%   fig      figure handle
%   name     file name without extension (letters, digits, _ and -)
%   Folder   target folder, default asmexport.output_folder() = <project>/export
%   Formats  "png" (300 dpi) and/or "svg" (vector)
%   Colours  true (default): set fixed colours for L1/L2/L3, bar 1/2; false: unchanged
%
%   Style (asmexport.style): format 16:9 (13.333 x 7.5 inch), font Arial at least 14 pt,
%   lines at least 1.5 pt, white background. Lines with "L1", "L2", "L3", "Stab 1",
%   "Stab 2" in DisplayName or Tag get the fixed colours. The figure itself is reformatted.
%
%   Returns: cell array with the full file names.

arguments
    fig (1,1) matlab.ui.Figure
    name {mustBeTextScalar, mustBeNonzeroLengthText}
    opt.Folder {mustBeTextScalar} = asmexport.output_folder()
    opt.Formats (1,:) string {mustBeMember(opt.Formats, ["png" "svg"])} = ["png" "svg"]
    opt.Colours (1,1) logical = true      % false: do not set line colours automatically
end

name = char(name);
if isempty(regexp(name, '^[\w-]+$', 'once'))
    error('asmexport:name', 'Ungültiger Dateiname "%s": nur Buchstaben, Ziffern, _ und - erlaubt.', name);
end
if ~exist(opt.Folder, 'dir'), mkdir(opt.Folder); end
S = asmexport.style();

% format 16:9 and light background
try, theme(fig, 'light'); catch, end                    % from R2025a; older releases without themes
fig.Color = 'w';
fig.Units = 'inches';
fig.Position(3:4) = [S.width_in, S.height_in];

% font: Arial, at least S.font_size pt
for o = findall(fig, '-property', 'FontSize')'
    if isprop(o, 'FontUnits'), o.FontUnits = 'points'; end
    o.FontSize = max(o.FontSize, S.font_size);
    if isprop(o, 'FontName'), o.FontName = S.font_name; end
end

% lines: minimum width and fixed colours
for o = findall(fig, 'Type', 'line')'
    o.LineWidth = max(o.LineWidth, S.line_width);
    key = [char(o.DisplayName) ' ' char(o.Tag)];
    for k = 1:size(S.mapping, 1)*opt.Colours
        if ~isempty(regexp(key, S.mapping{k, 1}, 'once'))
            o.Color = S.colour.(S.mapping{k, 2});
            break;
        end
    end
end
drawnow;

files = {};
for fmt = opt.Formats
    file = fullfile(opt.Folder, [name '.' char(fmt)]);
    if fmt == "png"
        args = {'Resolution', S.dpi};
    else
        args = {'ContentType', 'vector'};
    end
    try
        % 'Padding','figure' keeps the 16:9 format (no cropping to the content)
        exportgraphics(fig, file, args{:}, 'BackgroundColor', 'white', 'Padding', 'figure');
    catch
        % older releases without option 'Padding': print with figure size
        fig.PaperPositionMode = 'auto';
        if fmt == "png"
            print(fig, file, '-dpng', sprintf('-r%d', S.dpi));
        else
            print(fig, file, '-dsvg', '-vector');
        end
    end
    files{end+1} = file; %#ok<AGROW>
end
end
