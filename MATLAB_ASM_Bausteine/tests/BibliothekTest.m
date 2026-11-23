classdef BibliothekTest < matlab.unittest.TestCase
%BIBLIOTHEKTEST Prüft Aufbau der ASM-Bausteinbibliothek gegen den Katalog asmbib.katalog.
%   Ausführen im Projektordner:  startup_asm; runtests('tests')
%   Die Klasse baut die Bibliothek einmal neu (build_library) und prüft dann
%   Dateien, Untergruppen, Bausteine, Ports, Masken, Wertebereiche und Library Browser.

    properties (Constant)
        Lib = 'asm_bausteine_lib';
    end

    properties
        K       % Bausteinkatalog
        Info    % Rückgabe von build_library
        Modell  % Testmodell für Instanzen der Bibliotheksblöcke
    end

    methods (TestClassSetup)
        function bibliothekBauen(tc)
            tc.K = asmbib.katalog();
            tc.Info = tc.assertWarningFree(@build_library, ...
                'build_library muss ohne Fehler und Warnungen durchlaufen.');
            load_system(tc.Lib);
            tc.addTeardown(@() close_system(tc.Lib, 0));
        end
    end

    methods (TestMethodSetup)
        function testmodellAnlegen(tc)
            tc.Modell = 'asm_testmodell_bib';
            if bdIsLoaded(tc.Modell), close_system(tc.Modell, 0); end
            new_system(tc.Modell);
            tc.addTeardown(@() close_system(tc.Modell, 0));
        end
    end

    methods (Test)
        function dateienErzeugt(tc)
            tc.verifyEqual(exist(tc.Info.bibliothek, 'file'), 4, 'asm_bausteine_lib.slx fehlt');
            tc.verifyEqual(exist(tc.Info.simscape_bibliothek, 'file'), 4, 'asmlib_lib.slx fehlt');
            tc.verifyEqual(tc.Info.anzahl, numel(tc.K));
        end

        function untergruppenVorhanden(tc)
            S = asmbib.stil();
            for kat = fieldnames(S)'
                pfad = [tc.Lib '/' S.(kat{1}).anzeige];
                tc.verifyGreaterThan(getSimulinkBlockHandle(pfad), 0, ['Untergruppe fehlt: ' pfad]);
            end
        end

        function alleBloeckeVorhanden(tc)
            for b = tc.K
                tc.verifyGreaterThan(getSimulinkBlockHandle(pfad(tc, b)), 0, ['Baustein fehlt: ' b.name]);
            end
            % keine zusätzlichen Bausteine
            alle = find_system(tc.Lib, 'SearchDepth', 2, 'RegExp', 'on', 'Tag', '^asmlib:');
            tc.verifyEqual(numel(alle), numel(tc.K), 'Anzahl der Bausteine weicht vom Katalog ab');
        end

        function portsWieKatalog(tc)
            for b = tc.K
                ph = get_param(pfad(tc, b), 'PortHandles');
                nl = sum(strcmp({b.ports.seite}, 'links'));
                nr = sum(strcmp({b.ports.seite}, 'rechts'));
                tc.verifyEqual(numel(ph.LConn), nl, [b.name ': Anzahl linker Anschlüsse']);
                tc.verifyEqual(numel(ph.RConn), nr, [b.name ': Anzahl rechter Anschlüsse']);
                tc.verifyEqual(numel(ph.Inport), numel(b.ein), [b.name ': Anzahl Eingänge']);
                tc.verifyEqual(numel(ph.Outport), numel(b.aus), [b.name ': Anzahl Ausgänge']);
                % Namen der Connection Ports und Outports
                cp = find_system(pfad(tc, b), 'LookUnderMasks', 'all', 'SearchDepth', 1, 'BlockType', 'PMIOPort');
                ist  = cellstr(get_param(cp, 'Name'));
                soll = {b.ports.name};
                tc.verifyEqual(sort(ist(:)), sort(soll(:)), [b.name ': Namen der Anschlüsse']);
            end
        end

        function physikalischeDomaenen(tc)
            % Die innere Komponente bestimmt die Domäne: Simscape-Quelle muss stimmen
            for b = tc.K(strcmp({tc.K.art}, 'physikalisch'))
                innen = [pfad(tc, b) '/' b.id];
                tc.verifyEqual(get_param(innen, 'SourceFile'), b.ssc, [b.name ': Simscape-Komponente']);
            end
        end

        function domaenenVerbindungsregeln(tc)
            % Gleiche Domäne lässt sich verbinden, fremde Domänen lehnt Simscape beim Verbinden ab.
            % LS = asmlib.luftspalt, el = foundation.electrical, mech = foundation.mechanical.rotational
            st = instanz(tc, tc.K(strcmp({tc.K.id}, 'stator')));          % U1 (el) ... LS (ls)
            lf = instanz(tc, tc.K(strcmp({tc.K.id}, 'luftspaltfeld')));   % LS
            kl = instanz(tc, tc.K(strcmp({tc.K.id}, 'kaefiglaeufer')));   % LS, R, C (mech)
            pS = get_param(st, 'PortHandles'); pL = get_param(lf, 'PortHandles'); pK = get_param(kl, 'PortHandles');
            tc.verifyWarningFree(@() add_line(tc.Modell, pS.RConn(1), pL.LConn(1)), 'LS-LS muss verbindbar sein');
            tc.verifyWarningFree(@() add_line(tc.Modell, pL.LConn(1), pK.LConn(1)), 'LS-LS muss verbindbar sein');
            tc.verifyError(@() add_line(tc.Modell, pS.LConn(1), pK.LConn(1)), ?MException, 'el-LS darf nicht verbindbar sein');
            tc.verifyError(@() add_line(tc.Modell, pK.RConn(1), pS.RConn(1)), ?MException, 'mech-LS darf nicht verbindbar sein');
            tc.verifyError(@() add_line(tc.Modell, pK.RConn(1), pS.LConn(2)), ?MException, 'mech-el darf nicht verbindbar sein');
            % Quelle der Domäne
            wurzel = fileparts(fileparts(mfilename('fullpath')));
            tc.verifyEqual(exist(fullfile(wurzel, '+asmlib', 'luftspalt.ssc'), 'file'), 2);
        end

        function zerlegterMotorUnterMaske(tc)
            b = tc.K(strcmp({tc.K.id}, 'asm_standard'));
            erwartet = {'asmlib.maschine.klemmbrett', 'asmlib.maschine.stator', ...
                        'asmlib.maschine.luftspaltfeld', 'asmlib.maschine.kaefiglaeufer'};
            innen = find_system(pfad(tc, b), 'LookUnderMasks', 'all', 'SearchDepth', 1, 'Type', 'block');
            quellen = {};
            for k = 2:numel(innen)
                try
                    q = get_param(innen{k}, 'SourceFile');
                    if startsWith(q, 'asmlib.'), quellen{end+1} = q; end %#ok<AGROW>
                catch
                end
            end
            tc.verifyEqual(sort(quellen), sort(erwartet), 'Zerlegter Motor unvollständig');
        end

        function maskenParameterWieKatalog(tc)
            for b = tc.K
                mo = Simulink.Mask.get(pfad(tc, b));
                tc.assertNotEmpty(mo, [b.name ': keine Maske']);
                namen = {mo.Parameters.Name};
                tc.verifyEqual(namen, {b.par.name}, [b.name ': Maskenparameter']);
                for p = b.par
                    q = mo.getParameter(p.name);
                    tc.verifySubstring(q.Prompt, p.prompt, [b.name '/' p.name ': Prompt']);
                    if ~isempty(p.einheit)
                        tc.verifySubstring(q.Prompt, ['[' p.einheit ']'], [b.name '/' p.name ': Einheit im Prompt']);
                    end
                    tc.verifyEqual(q.Value, p.wert, [b.name '/' p.name ': Standardwert']);
                end
            end
        end

        function hilfetexteMitGleichungUndQuelle(tc)
            for b = tc.K
                mo = Simulink.Mask.get(pfad(tc, b));
                tc.verifySubstring(mo.Description, 'Gleichungen:', [b.name ': Beschreibung ohne Gleichungen']);
                tc.verifySubstring(mo.Description, 'Hagl', [b.name ': Beschreibung ohne Quelle']);
                tc.verifySubstring(mo.Help, 'Hagl', [b.name ': Hilfe ohne Quelle']);
                tc.verifySubstring(mo.Help, b.gleichungen, [b.name ': Hilfe ohne Gleichungen']);
                if ~isempty(b.par)
                    tc.verifySubstring(mo.Help, 'Wertebereiche', [b.name ': Hilfe ohne Wertebereiche']);
                end
            end
        end

        function wertebereichsPruefung(tc)
            % Für jede Regel muss ein unzulässiger Wert abgelehnt und der Standardwert akzeptiert werden
            for b = tc.K
                edit = b.par(strcmp({b.par.typ}, 'edit'));
                if isempty(edit), continue; end
                blk = instanz(tc, b);
                for p = edit
                    for falsch = falsche_werte(p)
                        fehler = false;
                        try
                            set_param(blk, p.name, falsch{1});
                        catch
                            fehler = true;
                        end
                        tc.verifyTrue(fehler, sprintf('%s/%s: unzulässiger Wert "%s" wurde angenommen', ...
                            b.name, p.name, falsch{1}));
                        set_param(blk, p.name, p.wert);       % zurück auf Standard
                    end
                end
            end
        end

        function parametersatzStandardSperrtFelder(tc)
            b   = tc.K(strcmp({tc.K.id}, 'asm_standard'));
            blk = [tc.Modell '/asm'];
            add_block(pfad(tc, b), blk);                       % Auslieferungszustand: Standard
            S   = asm_standard();
            mo  = Simulink.Mask.get(blk);
            tc.verifyEqual(mo.getParameter('R1').Enabled, 'off', 'Standard: R1 muss gesperrt sein');
            set_param(blk, 'parametersatz', 'Benutzerdefiniert');
            tc.verifyEqual(mo.getParameter('R1').Enabled, 'on', 'Benutzerdefiniert: R1 muss editierbar sein');
            set_param(blk, 'R1', '0.7');
            set_param(blk, 'parametersatz', 'Standard');
            tc.verifyEqual(mo.getParameter('R1').Enabled, 'off');
            tc.verifyEqual(str2double(get_param(blk, 'R1')), S.R1, 'Standard: R1 nicht zurückgesetzt');
            % Schaltung bleibt wählbar
            tc.verifyEqual(mo.getParameter('schaltung').Enabled, 'on');
        end

        function standardwerteAusParametersatz(tc)
            S = asm_standard();
            for id = {'asm_standard', 'asm_referenz'}
                b = tc.K(strcmp({tc.K.id}, id{1}));
                for p = b.par(strcmp({b.par.typ}, 'edit'))
                    if strcmp(p.name, 'n0'), continue; end     % Anfangswert, kein Motorparameter
                    tc.verifyTrue(isfield(S, p.name), [id{1} '/' p.name ' fehlt in asm_standard.m']);
                    tc.verifyEqual(str2double(p.wert), S.(p.name), 'RelTol', 1e-5, [id{1} '/' p.name]);
                end
            end
        end

        function farbenJeKategorie(tc)
            for b = tc.K
                st = asmbib.stil(b.kategorie);
                farbe = str2num(get_param(pfad(tc, b), 'BackgroundColor')); %#ok<ST2NM>
                tc.verifyEqual(farbe, st.hintergrund, 'AbsTol', 1e-6, [b.name ': Hintergrundfarbe']);
                tc.verifyNotEmpty(get_param(pfad(tc, b), 'MaskDisplay'), [b.name ': kein Icon']);
            end
        end

        function libraryBrowser(tc)
            s = slblocks();
            tc.verifyEqual(s.Browser.Library, tc.Lib);
            tc.verifyEqual(get_param(tc.Lib, 'EnableLBRepository'), 'on');
            alle = which('slblocks', '-all');
            tc.verifyTrue(any(contains(alle, 'asm_bausteine')), 'slblocks.m der Bibliothek nicht im Pfad');
        end

        function bezeichnerOhneUmlaute(tc)
            muster = '^[A-Za-z][A-Za-z0-9_]*$';
            for b = tc.K
                tc.verifyNotEmpty(regexp(b.id, muster, 'once'), ['Bezeichner: ' b.id]);
                for p = b.par
                    tc.verifyNotEmpty(regexp(p.name, muster, 'once'), ['Parameter: ' p.name]);
                end
                for s = [b.ein b.aus]
                    tc.verifyNotEmpty(regexp(s.name, muster, 'once'), ['Signal: ' s.name]);
                end
            end
        end
    end

    methods (Access = private)
        function p = pfad(tc, b)
            p = [tc.Lib '/' asmbib.stil(b.kategorie).anzeige '/' b.name];
        end

        function blk = instanz(tc, b)
            % Baustein ins Testmodell kopieren (Bibliothekslink), Parametersatz freigeben
            blk = [tc.Modell '/' b.id];
            add_block(pfad(tc, b), blk);
            if any(strcmp({b.par.name}, 'parametersatz'))
                set_param(blk, 'parametersatz', 'Benutzerdefiniert');
            end
        end
    end
end

function w = falsche_werte(p)
% unzulässige Werte zu einer Regel (pos; ganz; vektor; min=x; max=x)
w = {'NaN', 'Inf', '1+2i'};
regeln = strsplit(p.regel, ';');
if ~any(strcmp(regeln, 'vektor')), w{end+1} = '[1 2]'; end
for r = regeln
    t = strtrim(r{1});
    if strcmp(t, 'pos'),            w(end+1:end+2) = {'0', '-1'};
    elseif strcmp(t, 'ganz'),       w{end+1} = '2.5';
    elseif startsWith(t, 'min='),   w{end+1} = num2str(str2double(extractAfter(t, 'min=')) - 1);
    elseif startsWith(t, 'max='),   w{end+1} = num2str(str2double(extractAfter(t, 'max=')) + 1);
    end
end
end
