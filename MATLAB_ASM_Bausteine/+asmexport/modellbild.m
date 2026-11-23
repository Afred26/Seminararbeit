function dateien = modellbild(modell, name, opt)
%MODELLBILD Exportiert eine Modell- oder Subsystemansicht als SVG und PNG.
%   dateien = asmexport.modellbild(modell, name)
%   dateien = asmexport.modellbild(modell, name, 'Ordner', ordner, 'Formate', ["svg" "png"])
%
%   modell   Modellname oder Pfad eines Subsystems, z. B. 'asm_bausteine_lib/Maschine'
%            (das Modell wird bei Bedarf geladen)
%   name     Dateiname ohne Endung (Buchstaben, Ziffern, _ und -)
%   Ordner   Zielordner, Standard asmexport.zielordner() = <Projekt>/export
%   Formate  "svg" (Vektor) und/oder "png" (300 dpi)
%
%   Rückgabe: Zellenfeld mit den vollständigen Dateinamen.

arguments
    modell {mustBeTextScalar, mustBeNonzeroLengthText}
    name {mustBeTextScalar, mustBeNonzeroLengthText}
    opt.Ordner {mustBeTextScalar} = asmexport.zielordner()
    opt.Formate (1,:) string {mustBeMember(opt.Formate, ["png" "svg"])} = ["svg" "png"]
end

modell = char(modell);
name   = char(name);
if isempty(regexp(name, '^[\w-]+$', 'once'))
    error('asmexport:name', 'Ungültiger Dateiname "%s": nur Buchstaben, Ziffern, _ und - erlaubt.', name);
end
if ~exist(opt.Ordner, 'dir'), mkdir(opt.Ordner); end

wurzel = strtok(modell, '/');
if ~bdIsLoaded(wurzel), load_system(wurzel); end
if getSimulinkBlockHandle(modell) < 0 && ~strcmp(modell, wurzel)
    error('asmexport:modell', 'System "%s" nicht gefunden.', modell);
end
S = asmexport.stil();

dateien = {};
for fmt = opt.Formate
    datei = fullfile(opt.Ordner, [name '.' char(fmt)]);
    if fmt == "png"
        print(['-s' modell], '-dpng', sprintf('-r%d', S.dpi), datei);
    else
        print(['-s' modell], '-dsvg', datei);
    end
    dateien{end+1} = datei; %#ok<AGROW>
end
end
