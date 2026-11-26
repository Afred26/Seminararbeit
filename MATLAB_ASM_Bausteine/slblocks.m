function blkStruct = slblocks
%SLBLOCKS Registers the ASM block library with the Simulink Library Browser.
%   Prerequisite: startup_asm has been run (folder on the path) and the library has been
%   created with build_library. Then press "Refresh" (F5) in the Library Browser.

Browser.Library = 'asm_blocks_lib';
Browser.Name    = 'ASM-Bausteine (Drehstrom-Asynchronmotor)';
blkStruct.Browser = Browser;
end
