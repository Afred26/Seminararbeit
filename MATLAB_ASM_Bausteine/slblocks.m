function blkStruct = slblocks
%SLBLOCKS Meldet die ASM-Bausteinbibliothek beim Simulink Library Browser an.
%   Voraussetzung: startup_asm wurde ausgeführt (Ordner im Pfad) und die Bibliothek
%   wurde mit build_library erzeugt. Danach im Library Browser "Aktualisieren" (F5).

Browser.Library = 'asm_bausteine_lib';
Browser.Name    = 'ASM-Bausteine (Drehstrom-Asynchronmotor)';
blkStruct.Browser = Browser;
end
