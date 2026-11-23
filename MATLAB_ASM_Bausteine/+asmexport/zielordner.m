function ordner = zielordner()
%ZIELORDNER Standard-Ausgabeordner für Folienbilder: <Projekt>/export (wird bei Bedarf angelegt).

ordner = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'export');
if ~exist(ordner, 'dir')
    mkdir(ordner);
end
end
