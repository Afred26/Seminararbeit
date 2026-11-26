classdef LibraryTest < matlab.unittest.TestCase
%LIBRARYTEST Checks the structure of the ASM block library against the catalogue asmtools.catalog.
%   Run in the project folder:  startup_asm; runtests('tests')
%   The class rebuilds the library once (build_library) and then checks files,
%   sub-libraries, blocks, ports, masks, value ranges and the Library Browser.

    properties (Constant)
        Lib = 'asm_blocks_lib';
    end

    properties
        K       % block catalogue
        Info    % return value of build_library
        Model   % test model for instances of the library blocks
    end

    methods (TestClassSetup)
        function buildLibrary(tc)
            tc.K = asmtools.catalog();
            tc.Info = tc.assertWarningFree(@build_library, ...
                'build_library muss ohne Fehler und Warnungen durchlaufen.');
            load_system(tc.Lib);
            tc.addTeardown(@() close_system(tc.Lib, 0));
        end
    end

    methods (TestMethodSetup)
        function createTestModel(tc)
            tc.Model = 'asm_test_model_lib';
            if bdIsLoaded(tc.Model), close_system(tc.Model, 0); end
            new_system(tc.Model);
            tc.addTeardown(@() close_system(tc.Model, 0));
        end
    end

    methods (Test)
        function filesCreated(tc)
            tc.verifyEqual(exist(tc.Info.library, 'file'), 4, 'asm_blocks_lib.slx fehlt');
            tc.verifyEqual(exist(tc.Info.simscape_library, 'file'), 4, 'asmlib_lib.slx fehlt');
            tc.verifyEqual(tc.Info.count, numel(tc.K));
        end

        function subLibrariesExist(tc)
            S = asmtools.category_style();
            for c = fieldnames(S)'
                path = [tc.Lib '/' S.(c{1}).display];
                tc.verifyGreaterThan(getSimulinkBlockHandle(path), 0, ['Untergruppe fehlt: ' path]);
            end
        end

        function allBlocksExist(tc)
            for b = tc.K
                tc.verifyGreaterThan(getSimulinkBlockHandle(block_path(tc, b)), 0, ['Baustein fehlt: ' b.name]);
            end
            % no additional blocks
            all_blocks = find_system(tc.Lib, 'SearchDepth', 2, 'RegExp', 'on', 'Tag', '^asmlib:');
            tc.verifyEqual(numel(all_blocks), numel(tc.K), 'Anzahl der Bausteine weicht vom Katalog ab');
        end

        function portsAsCatalogue(tc)
            for b = tc.K
                ph = get_param(block_path(tc, b), 'PortHandles');
                nl = sum(strcmp({b.ports.side}, 'left'));
                nr = sum(strcmp({b.ports.side}, 'right'));
                tc.verifyEqual(numel(ph.LConn), nl, [b.name ': Anzahl linker Anschlüsse']);
                tc.verifyEqual(numel(ph.RConn), nr, [b.name ': Anzahl rechter Anschlüsse']);
                tc.verifyEqual(numel(ph.Inport), numel(b.inputs), [b.name ': Anzahl Eingänge']);
                tc.verifyEqual(numel(ph.Outport), numel(b.outputs), [b.name ': Anzahl Ausgänge']);
                % names of the Connection Ports and Outports
                cp = find_system(block_path(tc, b), 'LookUnderMasks', 'all', 'SearchDepth', 1, 'BlockType', 'PMIOPort');
                actual   = cellstr(get_param(cp, 'Name'));
                expected = {b.ports.name};
                tc.verifyEqual(sort(actual(:)), sort(expected(:)), [b.name ': Namen der Anschlüsse']);
            end
        end

        function physicalDomains(tc)
            % the inner component determines the domain: Simscape source must match
            for b = tc.K(strcmp({tc.K.kind}, 'physical'))
                inner = [block_path(tc, b) '/' b.id];
                tc.verifyEqual(get_param(inner, 'SourceFile'), b.ssc, [b.name ': Simscape-Komponente']);
            end
        end

        function domainConnectionRules(tc)
            % equal domains can be connected, Simscape rejects foreign domains when connecting.
            % LS = asmlib.airgap, el = foundation.electrical, mech = foundation.mechanical.rotational
            st = instance(tc, tc.K(strcmp({tc.K.id}, 'stator')));          % U1 (el) ... LS (ls)
            ag = instance(tc, tc.K(strcmp({tc.K.id}, 'airgap_field')));    % LS
            sc = instance(tc, tc.K(strcmp({tc.K.id}, 'squirrel_cage')));   % LS, R, C (mech)
            pS = get_param(st, 'PortHandles'); pA = get_param(ag, 'PortHandles'); pC = get_param(sc, 'PortHandles');
            tc.verifyWarningFree(@() add_line(tc.Model, pS.RConn(1), pA.LConn(1)), 'LS-LS muss verbindbar sein');
            tc.verifyWarningFree(@() add_line(tc.Model, pA.LConn(1), pC.LConn(1)), 'LS-LS muss verbindbar sein');
            tc.verifyError(@() add_line(tc.Model, pS.LConn(1), pC.LConn(1)), ?MException, 'el-LS darf nicht verbindbar sein');
            tc.verifyError(@() add_line(tc.Model, pC.RConn(1), pS.RConn(1)), ?MException, 'mech-LS darf nicht verbindbar sein');
            tc.verifyError(@() add_line(tc.Model, pC.RConn(1), pS.LConn(2)), ?MException, 'mech-el darf nicht verbindbar sein');
            % source of the domain
            root = fileparts(fileparts(mfilename('fullpath')));
            tc.verifyEqual(exist(fullfile(root, '+asmlib', 'airgap.ssc'), 'file'), 2);
        end

        function decomposedMotorUnderMask(tc)
            b = tc.K(strcmp({tc.K.id}, 'asm_standard'));
            expected = {'asmlib.machine.terminal_box', 'asmlib.machine.stator', ...
                        'asmlib.machine.airgap_field', 'asmlib.machine.squirrel_cage'};
            inner = find_system(block_path(tc, b), 'LookUnderMasks', 'all', 'SearchDepth', 1, 'Type', 'block');
            sources = {};
            for k = 2:numel(inner)
                try
                    q = get_param(inner{k}, 'SourceFile');
                    if startsWith(q, 'asmlib.'), sources{end+1} = q; end %#ok<AGROW>
                catch
                end
            end
            tc.verifyEqual(sort(sources), sort(expected), 'Zerlegter Motor unvollständig');
        end

        function maskParametersAsCatalogue(tc)
            for b = tc.K
                mo = Simulink.Mask.get(block_path(tc, b));
                tc.assertNotEmpty(mo, [b.name ': keine Maske']);
                names = {mo.Parameters.Name};
                tc.verifyEqual(names, {b.par.name}, [b.name ': Maskenparameter']);
                for p = b.par
                    q = mo.getParameter(p.name);
                    tc.verifySubstring(q.Prompt, p.prompt, [b.name '/' p.name ': Prompt']);
                    if ~isempty(p.unit)
                        tc.verifySubstring(q.Prompt, ['[' p.unit ']'], [b.name '/' p.name ': Einheit im Prompt']);
                    end
                    tc.verifyEqual(q.Value, p.value, [b.name '/' p.name ': Standardwert']);
                end
            end
        end

        function helpTextsWithEquationsAndSource(tc)
            for b = tc.K
                mo = Simulink.Mask.get(block_path(tc, b));
                tc.verifySubstring(mo.Description, 'Gleichungen:', [b.name ': Beschreibung ohne Gleichungen']);
                tc.verifySubstring(mo.Description, 'Hagl', [b.name ': Beschreibung ohne Quelle']);
                tc.verifySubstring(mo.Help, 'Hagl', [b.name ': Hilfe ohne Quelle']);
                tc.verifySubstring(mo.Help, b.equations, [b.name ': Hilfe ohne Gleichungen']);
                if ~isempty(b.par)
                    tc.verifySubstring(mo.Help, 'Wertebereiche', [b.name ': Hilfe ohne Wertebereiche']);
                end
            end
        end

        function valueRangeCheck(tc)
            % for every rule an invalid value must be rejected and the default value accepted
            for b = tc.K
                edit = b.par(strcmp({b.par.type}, 'edit'));
                if isempty(edit), continue; end
                blk = instance(tc, b);
                for p = edit
                    for wrong = invalid_values(p)
                        rejected = false;
                        try
                            set_param(blk, p.name, wrong{1});
                        catch
                            rejected = true;
                        end
                        tc.verifyTrue(rejected, sprintf('%s/%s: unzulässiger Wert "%s" wurde angenommen', ...
                            b.name, p.name, wrong{1}));
                        set_param(blk, p.name, p.value);       % back to default
                    end
                end
            end
        end

        function standardParamSetLocksFields(tc)
            b   = tc.K(strcmp({tc.K.id}, 'asm_standard'));
            blk = [tc.Model '/asm'];
            add_block(block_path(tc, b), blk);                 % delivery state: Standard
            S   = asm_standard();
            mo  = Simulink.Mask.get(blk);
            tc.verifyEqual(mo.getParameter('R1').Enabled, 'off', 'Standard: R1 muss gesperrt sein');
            set_param(blk, 'param_set', 'Benutzerdefiniert');
            tc.verifyEqual(mo.getParameter('R1').Enabled, 'on', 'Benutzerdefiniert: R1 muss editierbar sein');
            set_param(blk, 'R1', '0.7');
            set_param(blk, 'param_set', 'Standard');
            tc.verifyEqual(mo.getParameter('R1').Enabled, 'off');
            tc.verifyEqual(str2double(get_param(blk, 'R1')), S.R1, 'Standard: R1 nicht zurückgesetzt');
            % the connection stays selectable
            tc.verifyEqual(mo.getParameter('connection').Enabled, 'on');
        end

        function defaultValuesFromParameterSet(tc)
            S = asm_standard();
            for id = {'asm_standard', 'asm_reference', 'asm_kloss'}
                b = tc.K(strcmp({tc.K.id}, id{1}));
                for p = b.par(strcmp({b.par.type}, 'edit'))
                    if any(strcmp(p.name, {'n0', 'ns'})), continue; end     % initial value / derived
                    tc.verifyTrue(isfield(S, p.name), [id{1} '/' p.name ' fehlt in asm_standard.m']);
                    tc.verifyEqual(str2double(p.value), S.(p.name), 'RelTol', 1e-5, [id{1} '/' p.name]);
                end
            end
        end

        function coloursPerCategory(tc)
            for b = tc.K
                st = asmtools.category_style(b.category);
                colour = str2num(get_param(block_path(tc, b), 'BackgroundColor')); %#ok<ST2NM>
                tc.verifyEqual(colour, st.background, 'AbsTol', 1e-6, [b.name ': Hintergrundfarbe']);
                tc.verifyNotEmpty(get_param(block_path(tc, b), 'MaskDisplay'), [b.name ': kein Icon']);
            end
        end

        function libraryBrowser(tc)
            s = slblocks();
            tc.verifyEqual(s.Browser.Library, tc.Lib);
            tc.verifyEqual(get_param(tc.Lib, 'EnableLBRepository'), 'on');
            % the slblocks.m of this project must be on the path (independent of the folder name)
            root = fileparts(fileparts(mfilename('fullpath')));
            all_files = which('slblocks', '-all');
            tc.verifyTrue(any(strcmpi(all_files, fullfile(root, 'slblocks.m'))), ...
                'slblocks.m der Bibliothek nicht im Pfad');
        end

        function identifiersAscii(tc)
            pattern = '^[A-Za-z][A-Za-z0-9_]*$';
            for b = tc.K
                tc.verifyNotEmpty(regexp(b.id, pattern, 'once'), ['Bezeichner: ' b.id]);
                for p = b.par
                    tc.verifyNotEmpty(regexp(p.name, pattern, 'once'), ['Parameter: ' p.name]);
                end
                for s = [b.inputs b.outputs]
                    tc.verifyNotEmpty(regexp(s.name, pattern, 'once'), ['Signal: ' s.name]);
                end
            end
        end
    end

    methods (Access = private)
        function p = block_path(tc, b)
            p = [tc.Lib '/' asmtools.category_style(b.category).display '/' b.name];
        end

        function blk = instance(tc, b)
            % copy the block into the test model (library link), enable the parameter set
            blk = [tc.Model '/' b.id];
            add_block(block_path(tc, b), blk);
            if any(strcmp({b.par.name}, 'param_set'))
                set_param(blk, 'param_set', 'Benutzerdefiniert');
            end
        end
    end
end

function w = invalid_values(p)
% invalid values for a rule (pos; int; vector; min=x; max=x)
w = {'NaN', 'Inf', '1+2i'};
rules = strsplit(p.rule, ';');
if ~any(strcmp(rules, 'vector')), w{end+1} = '[1 2]'; end
for r = rules
    t = strtrim(r{1});
    if strcmp(t, 'pos'),            w(end+1:end+2) = {'0', '-1'};
    elseif strcmp(t, 'int'),        w{end+1} = '2.5';
    elseif startsWith(t, 'min='),   w{end+1} = num2str(str2double(extractAfter(t, 'min=')) - 1);
    elseif startsWith(t, 'max='),   w{end+1} = num2str(str2double(extractAfter(t, 'max=')) + 1);
    end
end
end
