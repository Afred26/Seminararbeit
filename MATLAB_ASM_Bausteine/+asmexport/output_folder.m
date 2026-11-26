function folder = output_folder()
%OUTPUT_FOLDER Default output folder for slide figures: <project>/export (created if needed).

folder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'export');
if ~exist(folder, 'dir')
    mkdir(folder);
end
end
