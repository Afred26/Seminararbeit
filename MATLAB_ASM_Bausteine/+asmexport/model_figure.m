function files = model_figure(model, name, opt)
%MODEL_FIGURE Exports a model or subsystem view as SVG and PNG.
%   files = asmexport.model_figure(model, name)
%   files = asmexport.model_figure(model, name, 'Folder', folder, 'Formats', ["svg" "png"])
%
%   model    model name or path of a subsystem, e.g. 'asm_blocks_lib/Maschine'
%            (the model is loaded if needed)
%   name     file name without extension (letters, digits, _ and -)
%   Folder   target folder, default asmexport.output_folder() = <project>/export
%   Formats  "svg" (vector) and/or "png" (300 dpi)
%
%   Returns: cell array with the full file names.

arguments
    model {mustBeTextScalar, mustBeNonzeroLengthText}
    name {mustBeTextScalar, mustBeNonzeroLengthText}
    opt.Folder {mustBeTextScalar} = asmexport.output_folder()
    opt.Formats (1,:) string {mustBeMember(opt.Formats, ["png" "svg"])} = ["svg" "png"]
end

model = char(model);
name  = char(name);
if isempty(regexp(name, '^[\w-]+$', 'once'))
    error('asmexport:name', 'Ungültiger Dateiname "%s": nur Buchstaben, Ziffern, _ und - erlaubt.', name);
end
if ~exist(opt.Folder, 'dir'), mkdir(opt.Folder); end

root = strtok(model, '/');
if ~bdIsLoaded(root), load_system(root); end
if getSimulinkBlockHandle(model) < 0 && ~strcmp(model, root)
    error('asmexport:model', 'System "%s" nicht gefunden.', model);
end
S = asmexport.style();

files = {};
for fmt = opt.Formats
    file = fullfile(opt.Folder, [name '.' char(fmt)]);
    if fmt == "png"
        print(['-s' model], '-dpng', sprintf('-r%d', S.dpi), file);
    else
        print(['-s' model], '-dsvg', file);
    end
    files{end+1} = file; %#ok<AGROW>
end
end
