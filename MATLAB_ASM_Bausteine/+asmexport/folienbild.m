function dateien = folienbild(fig, name, opt)
%FOLIENBILD Exportiert eine Abbildung im einheitlichen Folienstil (16:9) als PNG und SVG.
%   dateien = asmexport.folienbild(fig, name)
%   dateien = asmexport.folienbild(fig, name, 'Ordner', ordner, 'Formate', ["png" "svg"])
%
%   fig      Figure-Handle
%   name     Dateiname ohne Endung (Buchstaben, Ziffern, _ und -)
%   Ordner   Zielordner, Standard asmexport.zielordner() = <Projekt>/export
%   Formate  "png" (300 dpi) und/oder "svg" (Vektor)
%   Farben   true (Standard): feste Farben für L1/L2/L3, Stab 1/2 setzen; false: unverändert
%
%   Stil (asmexport.stil): Format 16:9 (13,333 x 7,5 Zoll), Schrift Arial mindestens 14 pt,
%   Linien mindestens 1,5 pt, weißer Hintergrund. Linien mit "L1", "L2", "L3", "Stab 1",
%   "Stab 2" im DisplayName oder Tag erhalten die festen Farben.
%   Die Abbildung selbst wird dabei umformatiert.
%
%   Rückgabe: Zellenfeld mit den vollständigen Dateinamen.

arguments
    fig (1,1) matlab.ui.Figure
    name {mustBeTextScalar, mustBeNonzeroLengthText}
    opt.Ordner {mustBeTextScalar} = asmexport.zielordner()
    opt.Formate (1,:) string {mustBeMember(opt.Formate, ["png" "svg"])} = ["png" "svg"]
    opt.Farben (1,1) logical = true      % false: Linienfarben nicht automatisch setzen
end

name = char(name);
if isempty(regexp(name, '^[\w-]+$', 'once'))
    error('asmexport:name', 'Ungültiger Dateiname "%s": nur Buchstaben, Ziffern, _ und - erlaubt.', name);
end
if ~exist(opt.Ordner, 'dir'), mkdir(opt.Ordner); end
S = asmexport.stil();

% Format 16:9 und heller Hintergrund
try, theme(fig, 'light'); catch, end                    % ab R2025a; ältere Releases ohne Themes
fig.Color = 'w';
fig.Units = 'inches';
fig.Position(3:4) = [S.breite_in, S.hoehe_in];

% Schrift: Arial, mindestens S.schriftgroesse pt
for o = findall(fig, '-property', 'FontSize')'
    if isprop(o, 'FontUnits'), o.FontUnits = 'points'; end
    o.FontSize = max(o.FontSize, S.schriftgroesse);
    if isprop(o, 'FontName'), o.FontName = S.schriftart; end
end

% Linien: Mindestbreite und feste Farben
for o = findall(fig, 'Type', 'line')'
    o.LineWidth = max(o.LineWidth, S.linienbreite);
    schluessel = [char(o.DisplayName) ' ' char(o.Tag)];
    for k = 1:size(S.zuordnung, 1)*opt.Farben
        if ~isempty(regexp(schluessel, S.zuordnung{k, 1}, 'once'))
            o.Color = S.farbe.(S.zuordnung{k, 2});
            break;
        end
    end
end
drawnow;

dateien = {};
for fmt = opt.Formate
    datei = fullfile(opt.Ordner, [name '.' char(fmt)]);
    if fmt == "png"
        argumente = {'Resolution', S.dpi};
    else
        argumente = {'ContentType', 'vector'};
    end
    try
        % 'Padding','figure' behält das 16:9-Format (ohne Zuschnitt auf den Inhalt)
        exportgraphics(fig, datei, argumente{:}, 'BackgroundColor', 'white', 'Padding', 'figure');
    catch
        % ältere Releases ohne Option 'Padding': print mit Figure-Größe
        fig.PaperPositionMode = 'auto';
        if fmt == "png"
            print(fig, datei, '-dpng', sprintf('-r%d', S.dpi));
        else
            print(fig, datei, '-dsvg', '-vector');
        end
    end
    dateien{end+1} = datei; %#ok<AGROW>
end
end
