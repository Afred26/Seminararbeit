classdef ASMApp < handle
%ASMAPP Bedienoberfläche für die ASM-Bausteinbibliothek (Drehstrom-Asynchronmotor).
%   app = ASMApp                    öffnet die Oberfläche
%   app = ASMApp('Sichtbar', false) unsichtbar (Tests)
%
%   Aufbau wie im Labor von links nach rechts: Netz 3~ | Motor (ASM) | Welle/Last, darunter
%   Ausgaben (Zeitverläufe, Kennlinie M(n), Querschnitt, Kennzahlen) und Simulationsparameter.
%   Simulink bleibt der Rechenkern: die Oberfläche sammelt nur die Eingaben, ruft
%   asmapp.simuliere auf (Beispielmodelle, Parameter über Simulink.SimulationInput) und stellt
%   die Ergebnisse dar. Gezeichnet wird mit den Funktionen der Bibliothek (asmbib.querschnitt,
%   asmbib.kennlinie_bild), exportiert mit asmexport.folienbild.
%
%   Betriebsarten
%     Laboraufbau Motor               beispiele/bsp_hochlauf_laststoss.slx
%     Folien 16–30 (Stillstand, s = 1) beispiele/bsp_folien16_30_rotorstab.slx
%
%   Öffentliche Methoden (auch für Tests und Skripte)
%     setze(app, feld, wert)         Eingabe setzen (Feldnamen wie asmapp.standardwerte)
%     waehle_betriebsart(app, ba)    'labor' | 'folien'
%     simulieren(app)                Simulation starten, Ergebnis in app.Ergebnis
%     exportieren(app, ordner)       aktuelle Abbildung über asmexport.folienbild
%     schliessen(app)
%
%   Alle Standardwerte sind Beispielwerte (parameter/asm_standard.m).

    properties (SetAccess = private)
        Figur                       % uifigure
        Ergebnis = []               % Rückgabe von asmapp.simuliere
        Betriebsart = 'labor'       % 'labor' | 'folien'
    end

    properties (Access = private)
        G                           % Wertebereiche (asmapp.grenzen)
        Standardmotor               % Standardmotor (asm_standard)
        Feld = struct()             % Zahlenfelder, Feldname wie asmapp.standardwerte
        Wahl = struct()             % Auswahlfelder
        Panel = struct()
        AxSymbol = struct()
        Radio = struct()
        KnopfSim
        KnopfExport
        Status
        Hinweise
        SolverText
        Tabs
        Tab = struct()
        AxZeit
        AxKenn
        AxQuer
        Regler
        KnopfPlay
        ZeitText
        Zeitlupe
        Ansicht
        AlleStaebe
        Tabelle
        Animation                   % timer
        Q = struct()                % Darstellungsoptionen des Querschnitts
        Gesperrt = false
    end

    %% ========================= Öffentliche Methoden =========================
    methods
        function app = ASMApp(opt)
            arguments
                opt.Sichtbar (1,1) logical = true
            end
            app.G = asmapp.grenzen();
            app.Standardmotor = asm_standard();
            app.baue_oberflaeche();
            app.uebernehme(asmapp.standardwerte('labor'));
            app.aktualisiere_zustand();
            app.zeichne_symbole();
            app.leere_ausgaben();
            if opt.Sichtbar, app.Figur.Visible = 'on'; end
        end

        function delete(app)
            app.stoppe_animation();
            if ~isempty(app.Animation) && isvalid(app.Animation), delete(app.Animation); end
            if ~isempty(app.Figur) && isvalid(app.Figur), delete(app.Figur); end
        end

        function schliessen(app)
            delete(app);
        end

        function setze(app, feld, wert)
            %SETZE Eingabe setzen wie in der Oberfläche (mit Prüfung des Wertebereichs)
            if isfield(app.Feld, feld)
                [ok, m] = asmapp.pruefe(feld, wert, app.G);
                if ~ok, error('asmapp:wert', '%s', m); end
                app.Feld.(feld).Value = wert;
            elseif isfield(app.Wahl, feld)
                w = app.Wahl.(feld);
                if ~any(strcmp(w.ItemsData, wert))
                    error('asmapp:wert', 'Ungültige Auswahl für %s: "%s".', feld, wert);
                end
                w.Value = wert;
                if strcmp(feld, 'parametersatz'), app.parametersatz_geaendert(); end
            else
                error('asmapp:feld', 'Unbekanntes Eingabefeld "%s".', feld);
            end
            app.eingabe_geaendert();
        end

        function waehle_betriebsart(app, ba)
            ba = validatestring(ba, {'labor', 'folien'});
            app.Radio.(ba).Value = true;
            app.betriebsart_geaendert(ba);
        end

        function P = parameter(app)
            %PARAMETER Eingaben als Parameterstruktur für asmapp.simuliere
            P = asmapp.standardwerte(app.Betriebsart);
            for f = fieldnames(app.Feld)', P.(f{1}) = app.Feld.(f{1}).Value; end
            for f = fieldnames(app.Wahl)', P.(f{1}) = app.Wahl.(f{1}).Value; end
        end

        function simulieren(app)
            %SIMULIEREN Simulation starten; Oberfläche währenddessen gesperrt
            app.stoppe_animation();
            P = app.parameter();
            modell = struct('labor', 'bsp_hochlauf_laststoss', 'folien', 'bsp_folien16_30_rotorstab');
            app.sperren(true);
            app.melde(sprintf('Simulation läuft … (%s, t_End = %g s)', modell.(app.Betriebsart), P.t_end), 'info');
            dlg = [];
            try
                dlg = uiprogressdlg(app.Figur, 'Title', 'Simulation', 'Indeterminate', 'on', ...
                    'Message', sprintf('Modell %s wird simuliert …', modell.(app.Betriebsart)));
            catch
            end
            drawnow;
            try
                E = asmapp.simuliere(app.Betriebsart, P);
                app.Ergebnis = E;
                app.SolverText.Text = sprintf('%s,  RelTol %g,  MaxStep %g s', E.solver.Solver, ...
                                              E.solver.RelTol, E.solver.MaxStep);
                app.Hinweise.Value = leer_zu_text(E.hinweise);
                app.zeichne_ausgaben();
                app.melde(sprintf('Simulation fertig (Rechenzeit %.1f s).', E.dauer_s), 'ok');
            catch err
                app.Ergebnis = [];
                app.leere_ausgaben();
                app.Hinweise.Value = {err.message};
                app.melde(['Fehler: ' err.message], 'fehler');
            end
            if ~isempty(dlg) && isvalid(dlg), close(dlg); end
            app.sperren(false);
        end

        function dateien = exportieren(app, ordner)
            %EXPORTIEREN aktuelle Abbildung im Folienstil (asmexport.folienbild)
            if nargin < 2, ordner = asmexport.zielordner(); end
            dateien = {};
            if isempty(app.Ergebnis), app.melde('Erst simulieren, dann exportieren.', 'fehler'); return; end
            tab = app.aktiver_tab();
            f = figure('Visible', 'off', 'Color', 'w');
            aufr = onCleanup(@() close(f));
            switch tab
                case 'zeit'
                    tl = tiledlayout(f, 3, 1);
                    ax = gobjects(1, 3);
                    for k = 1:3, ax(k) = nexttile(tl); end
                    app.zeichne_zeit(ax);
                case 'kennlinie'
                    app.zeichne_kennlinie(axes(f));
                case 'querschnitt'
                    app.zeichne_querschnitt(axes(f), app.Regler.Value);
                otherwise
                    app.melde('Für die Kennzahlen gibt es keine Abbildung.', 'fehler');
                    return;
            end
            name = sprintf('asmapp_%s_%s', app.Betriebsart, tab);
            dateien = asmexport.folienbild(f, name, 'Ordner', ordner);
            app.melde(sprintf('Exportiert: %s', strjoin(dateien, ', ')), 'ok');
        end
    end

    %% ========================= Aufbau =========================
    methods (Access = private)
        function baue_oberflaeche(app)
            fig = uifigure('Name', 'ASM-Bausteine – Bedienoberfläche Drehstrom-Asynchronmotor', ...
                           'Position', [40 40 1440 940], 'Visible', 'off', 'Color', 'w');
            try, theme(fig, 'light'); catch, end              % ab R2025a; ältere Releases hell
            fig.CloseRequestFcn = @(~, ~) app.schliessen();
            app.Figur = fig;
            haupt = uigridlayout(fig, [3 3], 'RowHeight', {40, 290, '1x'}, ...
                                 'ColumnWidth', {'0.95x', '1.6x', '1x'}, 'BackgroundColor', 'w');

            % Betriebsart
            bg = uibuttongroup(haupt, 'BorderType', 'none', 'BackgroundColor', 'w', ...
                               'SelectionChangedFcn', @(~, ev) app.betriebsart_geaendert(ev.NewValue.Tag));
            bg.Layout.Row = 1;  bg.Layout.Column = [1 3];
            uilabel(bg, 'Text', 'Betriebsart:', 'FontWeight', 'bold', 'Position', [10 8 90 22]);
            app.Radio.labor = uiradiobutton(bg, 'Text', 'Laboraufbau Motor (Hochlauf, Laststoß)', ...
                'Tag', 'labor', 'Position', [100 8 290 22], 'Value', true);
            app.Radio.folien = uiradiobutton(bg, 'Text', 'Folien 16–30 (Stillstand, s = 1)', ...
                'Tag', 'folien', 'Position', [400 8 290 22]);

            app.baue_netz(haupt);
            app.baue_motor(haupt);
            app.baue_last(haupt);
            app.baue_ausgaben(haupt);
            app.baue_simulation(haupt);
        end

        function baue_netz(app, haupt)
            p = uipanel(haupt, 'Title', 'Netz 3~', 'FontWeight', 'bold', 'BackgroundColor', 'w');
            p.Layout.Row = 2;  p.Layout.Column = 1;  app.Panel.netz = p;
            gl = raster(p, 6, {160, 'fit', 85, 'fit'});
            app.AxSymbol.netz = symbolachse(gl, 1:6);
            app.zahlfeld(gl, 1, 2, 'U_L', 'U (Leiter, eff.)', 'V');
            app.zahlfeld(gl, 2, 2, 'f1', 'f<sub>1</sub>', 'Hz');
            app.auswahl(gl, 3, 2, 'phasenfolge', 'Phasenfolge', ...
                {'L1-L2-L3 (rechts)', 'L1-L3-L2 (links)'}, {'L1-L2-L3', 'L1-L3-L2'}, [3 4]);
            app.zahlfeld(gl, 4, 2, 't_ein', 't<sub>ein</sub>', 's');
        end

        function baue_motor(app, haupt)
            p = uipanel(haupt, 'Title', 'Motor (ASM)', 'FontWeight', 'bold', 'BackgroundColor', 'w');
            p.Layout.Row = 2;  p.Layout.Column = 2;  app.Panel.motor = p;
            gl = raster(p, 8, {120, 'fit', 75, 'fit', 'fit', 75, 'fit'});
            app.AxSymbol.motor = symbolachse(gl, 1:8);
            app.auswahl(gl, 1, 2, 'parametersatz', 'Parametersatz', {'Standard', 'Benutzerdefiniert'}, ...
                {'Standard', 'Benutzerdefiniert'}, [3 4]);
            app.auswahl(gl, 1, 5, 'schaltung', 'Schaltung', {'Stern', 'Dreieck'}, {'Stern', 'Dreieck'}, [6 7]);
            app.zahlfeld(gl, 2, 2, 'R1',   'R<sub>1</sub>', 'Ω');
            app.zahlfeld(gl, 2, 5, 'R2b',  'R<sub>2</sub>′', 'Ω');
            app.zahlfeld(gl, 3, 2, 'L1s',  'L<sub>1σ</sub>', 'H');
            app.zahlfeld(gl, 3, 5, 'L2sb', 'L<sub>2σ</sub>′', 'H');
            app.zahlfeld(gl, 4, 2, 'Lh',   'L<sub>h</sub>', 'H');
            app.zahlfeld(gl, 4, 5, 'p',    'p', '–');
            app.zahlfeld(gl, 5, 2, 'J_M',  'J<sub>M</sub>', 'kg·m²');
            t = uilabel(gl, 'Text', 'Ideales Drehfeld (nur Folien 16–30): zweipolig, Rotor steht (s = 1)', ...
                        'FontAngle', 'italic');
            t.Layout.Row = 6;  t.Layout.Column = [2 7];
            app.zahlfeld(gl, 7, 2, 'Bhat', 'B̂', 'T');
            app.auswahl(gl, 8, 2, 'modus_phi2', 'φ<sub>2</sub>', {'fest', 'aus Rotorimpedanz (90° + φZ)'}, ...
                {'fest', 'Rotorimpedanz'}, [3 4]);
            app.zahlfeld(gl, 8, 5, 'phi2_fix', 'φ<sub>2</sub> (fest)', '°');
            app.Wahl.parametersatz.ValueChangedFcn = @(~, ~) app.parametersatz_geaendert();
        end

        function baue_last(app, haupt)
            p = uipanel(haupt, 'Title', 'Welle / Last', 'FontWeight', 'bold', 'BackgroundColor', 'w');
            p.Layout.Row = 2;  p.Layout.Column = 3;  app.Panel.last = p;
            gl = raster(p, 6, {160, 'fit', 85, 'fit'});
            app.AxSymbol.last = symbolachse(gl, 1:6);
            app.auswahl(gl, 1, 2, 'last_typ', 'Lasttyp', {'konstant', 'Lüfter (M ~ n²)'}, ...
                {'konstant', 'luefter'}, [3 4]);
            app.zahlfeld(gl, 2, 2, 'M_L', 'M<sub>L</sub>', 'N·m');
            app.zahlfeld(gl, 3, 2, 'dM_L', 'ΔM<sub>L</sub> (Laststoß)', 'N·m');
            app.zahlfeld(gl, 4, 2, 't_stoss', 't<sub>stoß</sub>', 's');
            app.zahlfeld(gl, 5, 2, 'J_L', 'J<sub>L</sub> (Zusatz)', 'kg·m²');
            app.Feld.M_L.Tooltip = ['Grundlast. Konstant: M_L0. Lüfter: Moment bei der Bezugsdrehzahl ' ...
                                    'n_B = 0,96·n_s (Beispielmotor 1440 1/min).'];
            app.Feld.dM_L.Tooltip = 'Höhe des Laststoßes (0 = kein Laststoß, negativ = Entlastung).';
        end

        function baue_ausgaben(app, haupt)
            p = uipanel(haupt, 'Title', 'Ausgaben', 'FontWeight', 'bold', 'BackgroundColor', 'w');
            p.Layout.Row = 3;  p.Layout.Column = [1 2];
            gl = uigridlayout(p, [2 2], 'RowHeight', {'1x', 30}, 'ColumnWidth', {'1x', 190}, ...
                              'BackgroundColor', 'w');
            app.Tabs = uitabgroup(gl, 'SelectionChangedFcn', @(~, ~) app.aktualisiere_zustand());
            app.Tabs.Layout.Row = 1;  app.Tabs.Layout.Column = [1 2];

            app.Tab.zeit = uitab(app.Tabs, 'Title', 'Zeitverläufe', 'Tag', 'zeit');
            g = uigridlayout(app.Tab.zeit, [3 1], 'RowSpacing', 2, 'BackgroundColor', 'w');
            app.AxZeit = gobjects(1, 3);
            for k = 1:3, app.AxZeit(k) = uiaxes(g); end

            app.Tab.kennlinie = uitab(app.Tabs, 'Title', 'Kennlinie M(n)', 'Tag', 'kennlinie');
            g = uigridlayout(app.Tab.kennlinie, [1 1], 'BackgroundColor', 'w');
            app.AxKenn = uiaxes(g);

            app.Tab.querschnitt = uitab(app.Tabs, 'Title', 'Querschnitt', 'Tag', 'querschnitt');
            g = uigridlayout(app.Tab.querschnitt, [2 1], 'RowHeight', {'1x', 30}, 'BackgroundColor', 'w');
            app.AxQuer = uiaxes(g);
            app.AxQuer.Toolbar.Visible = 'off';
            s = uigridlayout(g, [1 8], 'Padding', 0, 'BackgroundColor', 'w', ...
                             'ColumnWidth', {40, '1x', 110, 'fit', 70, 'fit', 'fit', 'fit'});
            app.KnopfPlay = uibutton(s, 'Text', '▶', 'Tooltip', 'Animation abspielen / anhalten', ...
                                     'ButtonPushedFcn', @(~, ~) app.play());
            app.Regler = uislider(s, 'Limits', [0 1], 'MajorTicks', [], 'MinorTicks', [], ...
                'ValueChangingFcn', @(~, ev) app.zeige_zeitpunkt(ev.Value), ...
                'ValueChangedFcn', @(src, ~) app.zeige_zeitpunkt(src.Value));
            app.ZeitText = uilabel(s, 'Text', 't = – s');
            uilabel(s, 'Text', 'Zeitlupe [s/s]', 'Tooltip', 'Simulationszeit je Sekunde Abspielzeit');
            app.Zeitlupe = uieditfield(s, 'numeric', 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', ...
                                       'Value', 0.02, 'ValueDisplayFormat', '%.4g');
            uilabel(s, 'Text', 'Ansicht');
            app.Ansicht = uidropdown(s, 'Items', {'rotorfest', 'statorfest'}, 'Value', 'statorfest', ...
                                     'ValueChangedFcn', @(~, ~) app.querschnitt_optionen());
            app.AlleStaebe = uicheckbox(s, 'Text', 'alle Stäbe', 'Value', true, ...
                                        'ValueChangedFcn', @(~, ~) app.querschnitt_optionen());

            app.Tab.kennzahlen = uitab(app.Tabs, 'Title', 'Kennzahlen', 'Tag', 'kennzahlen');
            g = uigridlayout(app.Tab.kennzahlen, [1 1], 'BackgroundColor', 'w');
            app.Tabelle = uitable(g, 'ColumnName', {'Größe', 'Zeichen', 'Wert', 'Einheit', 'Herkunft'}, ...
                                  'ColumnWidth', {260, 80, 100, 70, 'auto'}, 'RowName', {});

            hinweis = uilabel(gl, 'Text', 'Export: 16:9, PNG 300 dpi und SVG nach export/ (asmexport.folienbild)', ...
                              'FontColor', [0.4 0.4 0.4]);
            hinweis.Layout.Row = 2;  hinweis.Layout.Column = 1;
            app.KnopfExport = uibutton(gl, 'Text', 'Abbildung exportieren', ...
                                       'ButtonPushedFcn', @(~, ~) app.exportieren());
            app.KnopfExport.Layout.Row = 2;  app.KnopfExport.Layout.Column = 2;
        end

        function baue_simulation(app, haupt)
            p = uipanel(haupt, 'Title', 'Simulationsparameter', 'FontWeight', 'bold', 'BackgroundColor', 'w');
            p.Layout.Row = 3;  p.Layout.Column = 3;
            gl = uigridlayout(p, [7 3], 'RowHeight', {22, 22, 22, 44, 22, 22, '1x'}, ...
                              'ColumnWidth', {70, '1x', 'fit'}, 'BackgroundColor', 'w');
            app.zahlfeld(gl, 1, 1, 't_end', 't<sub>End</sub>', 's');
            l = uilabel(gl, 'Text', 'Solver (wie Anleitung, Abschnitt 3):');
            l.Layout.Row = 2;  l.Layout.Column = [1 3];
            app.SolverText = uilabel(gl, 'Text', 'ode23t,  RelTol 1e-05,  MaxStep 0.0001 s', ...
                                     'FontColor', [0.3 0.3 0.3]);
            app.SolverText.Layout.Row = 3;  app.SolverText.Layout.Column = [1 3];
            app.KnopfSim = uibutton(gl, 'Text', 'Simulieren', 'FontSize', 16, 'FontWeight', 'bold', ...
                                    'ButtonPushedFcn', @(~, ~) app.simulieren());
            app.KnopfSim.Layout.Row = 4;  app.KnopfSim.Layout.Column = [1 3];
            app.Status = uilabel(gl, 'Text', 'Bereit.', 'WordWrap', 'on');
            app.Status.Layout.Row = [5 6];  app.Status.Layout.Column = [1 3];
            app.Hinweise = uitextarea(gl, 'Editable', 'off', 'Value', {''}, ...
                                      'Tooltip', 'Hinweise zur Plausibilität der Eingaben und Ergebnisse');
            app.Hinweise.Layout.Row = 7;  app.Hinweise.Layout.Column = [1 3];
        end

        function zahlfeld(app, gl, zeile, spalte, name, beschriftung, einheit)
            % Zahlenfeld mit Formelzeichen und Einheit; Wertebereich aus dem Katalog
            g = app.G.(name);
            l = uilabel(gl, 'Text', beschriftung, 'Interpreter', 'html', 'HorizontalAlignment', 'right');
            l.Layout.Row = zeile;  l.Layout.Column = spalte;
            f = uieditfield(gl, 'numeric', 'Limits', [g.min g.max], 'ValueDisplayFormat', '%.6g', ...
                            'Tooltip', sprintf('%s [%s], %s', g.prompt, g.einheit, bereich_text(g)), ...
                            'ValueChangedFcn', @(src, ev) app.feld_geaendert(name, src, ev));
            if g.min_offen, f.LowerLimitInclusive = 'off'; end
            f.Layout.Row = zeile;  f.Layout.Column = spalte + 1;
            u = uilabel(gl, 'Text', einheit);
            u.Layout.Row = zeile;  u.Layout.Column = spalte + 2;
            app.Feld.(name) = f;
        end

        function auswahl(app, gl, zeile, spalte, name, beschriftung, items, daten, spalten)
            l = uilabel(gl, 'Text', beschriftung, 'Interpreter', 'html', 'HorizontalAlignment', 'right');
            l.Layout.Row = zeile;  l.Layout.Column = spalte;
            d = uidropdown(gl, 'Items', items, 'ItemsData', daten, ...
                           'ValueChangedFcn', @(~, ~) app.eingabe_geaendert());
            d.Layout.Row = zeile;  d.Layout.Column = spalten;
            app.Wahl.(name) = d;
        end

        function uebernehme(app, P)
            for f = fieldnames(app.Feld)', app.Feld.(f{1}).Value = P.(f{1}); end
            for f = fieldnames(app.Wahl)', app.Wahl.(f{1}).Value = P.(f{1}); end
        end
    end

    %% ========================= Rückrufe und Zustand =========================
    methods (Access = private)
        function feld_geaendert(app, name, src, ev)
            % zweite Prüfung (ganze Zahl usw.), die Grenzen prüft das Feld selbst
            [ok, m] = asmapp.pruefe(name, src.Value, app.G);
            if ~ok
                src.Value = ev.PreviousValue;
                app.melde(['Ungültige Eingabe – ' m], 'fehler');
                return;
            end
            app.eingabe_geaendert();
        end

        function eingabe_geaendert(app)
            app.aktualisiere_zustand();
            if ~isempty(app.Ergebnis)
                app.melde('Eingaben geändert – „Simulieren“ drücken, um die Ausgaben zu aktualisieren.', 'info');
            end
        end

        function parametersatz_geaendert(app)
            if strcmp(app.Wahl.parametersatz.Value, 'Standard')
                for f = {'R1', 'L1s', 'Lh', 'R2b', 'L2sb', 'p', 'J_M'}
                    app.Feld.(f{1}).Value = app.Standardmotor.(f{1});
                end
            end
            app.eingabe_geaendert();
        end

        function betriebsart_geaendert(app, ba)
            if strcmp(ba, app.Betriebsart), return; end
            app.stoppe_animation();
            app.Betriebsart = ba;
            app.Feld.t_end.Value = asmapp.standardwerte(ba).t_end;
            app.Ergebnis = [];
            app.Hinweise.Value = {''};
            app.leere_ausgaben();
            app.zeichne_symbole();
            app.aktualisiere_zustand();
            app.melde('Betriebsart gewechselt – Bereit.', 'info');
        end

        function aktualisiere_zustand(app)
            % Felder je Betriebsart freigeben bzw. ausgrauen
            if app.Gesperrt, return; end
            lab = strcmp(app.Betriebsart, 'labor');
            std = strcmp(app.Wahl.parametersatz.Value, 'Standard');
            fest = strcmp(app.Wahl.modus_phi2.Value, 'fest');
            an = {'U_L', lab; 'f1', true; 'phasenfolge', lab; 't_ein', lab; ...
                  'parametersatz', lab; 'schaltung', lab; ...
                  'R1', lab && ~std; 'L1s', lab && ~std; 'Lh', lab && ~std; 'R2b', lab && ~std; ...
                  'L2sb', lab && ~std; 'p', lab && ~std; 'J_M', lab && ~std; ...
                  'Bhat', ~lab; 'modus_phi2', ~lab; 'phi2_fix', ~lab && fest; ...
                  'last_typ', lab; 'M_L', lab; 'dM_L', lab; 't_stoss', lab && app.Feld.dM_L.Value ~= 0; ...
                  'J_L', lab; 't_end', true};
            for k = 1:size(an, 1)
                h = app.element(an{k, 1});
                h.Enable = onoff(an{k, 2});
            end
            if lab
                app.Panel.motor.Title = 'Motor (ASM)';
                app.Panel.last.Title = 'Welle / Last';
            else
                app.Panel.motor.Title = 'Motor (ASM) – Folienmodus: Ideales Drehfeld';
                app.Panel.last.Title = 'Welle / Last – Folienmodus: Rotor festgebremst';
            end
            hat = ~isempty(app.Ergebnis);
            app.KnopfSim.Enable = 'on';
            app.Radio.labor.Enable = 'on';  app.Radio.folien.Enable = 'on';
            app.KnopfExport.Enable = onoff(hat && ~strcmp(app.aktiver_tab(), 'kennzahlen'));
            regler = {app.KnopfPlay, app.Regler, app.Zeitlupe, app.Ansicht, app.AlleStaebe};
            for k = 1:numel(regler)
                regler{k}.Enable = onoff(hat);
            end
        end

        function h = element(app, name)
            if isfield(app.Feld, name), h = app.Feld.(name); else, h = app.Wahl.(name); end
        end

        function sperren(app, ja)
            % Oberfläche während der Simulation sperren
            if ja
                app.Gesperrt = true;
                alle = [struct2cell(app.Feld); struct2cell(app.Wahl); ...
                        {app.KnopfSim; app.KnopfExport; app.Radio.labor; app.Radio.folien; ...
                         app.KnopfPlay; app.Regler; app.Zeitlupe; app.Ansicht; app.AlleStaebe}];
                for k = 1:numel(alle), alle{k}.Enable = 'off'; end
                app.Figur.Pointer = 'watch';
            else
                app.Gesperrt = false;
                app.Figur.Pointer = 'arrow';
                app.aktualisiere_zustand();
            end
            drawnow;
        end

        function melde(app, text, art)
            farben = struct('ok', [0 0.45 0.15], 'info', [0.1 0.1 0.1], 'fehler', [0.8 0 0]);
            app.Status.Text = text;
            app.Status.FontColor = farben.(art);
        end

        function t = aktiver_tab(app)
            t = app.Tabs.SelectedTab.Tag;
        end
    end

    %% ========================= Schaltbild-Symbole =========================
    methods (Access = private)
        function zeichne_symbole(app)
            lab = strcmp(app.Betriebsart, 'labor');
            symbol_netz(app.AxSymbol.netz, lab);
            symbol_motor(app.AxSymbol.motor, lab);
            symbol_last(app.AxSymbol.last, lab);
        end
    end

    %% ========================= Ausgaben =========================
    methods (Access = private)
        function leere_ausgaben(app)
            for ax = [app.AxZeit, app.AxKenn, app.AxQuer]
                cla(ax, 'reset');  axis(ax, 'off');
            end
            text(app.AxZeit(2), 0.5, 0.5, 'Noch keine Ergebnisse – „Simulieren“ drücken.', ...
                 'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontSize', 14);
            app.Tabelle.Data = cell(0, 5);
            app.ZeitText.Text = 't = – s';
            app.aktualisiere_zustand();
        end

        function zeichne_ausgaben(app)
            app.zeichne_zeit(app.AxZeit);
            app.zeichne_kennlinie(app.AxKenn);
            app.bereite_querschnitt_vor();
            app.zeige_kennzahlen();
        end

        function zeichne_zeit(app, ax)
            % Zeitverläufe: Labor M(t), n(t), i1(t); Folien B⊥/i, F, M_S
            E = app.Ergebnis;  Z = E.zeit;  S = asmexport.stil();
            for k = 1:3, cla(ax(k), 'reset'); hold(ax(k), 'on'); grid(ax(k), 'on'); end
            if strcmp(E.betriebsart, 'labor')
                plot(ax(1), Z.t, Z.M, '-', 'Color', S.farbe.i, 'DisplayName', 'Luftspaltmoment M');
                plot(ax(1), Z.t, Z.M_W, '-', 'Color', [0.6 0.6 0.6], 'DisplayName', 'Wellenmoment M_W');
                plot(ax(1), Z.t, Z.M_L, '--', 'Color', S.farbe.L2, 'DisplayName', 'Lastmoment M_L');
                ylabel(ax(1), 'M in N·m');
                plot(ax(2), Z.t, Z.n, '-', 'Color', S.farbe.i, 'DisplayName', 'Drehzahl n');
                yline(ax(2), (1 - 2*strcmp(E.P.phasenfolge, 'L1-L3-L2'))*E.P.ns, '--', ...
                      'Color', [0.4 0.4 0.4], 'DisplayName', 'Synchrondrehzahl n_s');
                ylabel(ax(2), 'n in 1/min');
                strang = {'U', 'V', 'W'};
                for j = 1:3
                    plot(ax(3), Z.t, Z.i_abc(:, j), '-', 'LineWidth', 0.8, ...
                         'Color', S.farbe.(sprintf('L%d', j)), 'DisplayName', sprintf('i_%s (L%d)', strang{j}, j));
                end
                plot(ax(3), Z.t, Z.I_eff, 'k--', 'DisplayName', 'I_{eff} (Leiter)');
                ylabel(ax(3), 'i_1 in A');
                titel = {'Drehmoment', 'Drehzahl', 'Statorstrom (Strang, aus dem Raumzeiger i_1)'};
                ort = {'north', 'southeast', 'northeast'};
            else
                yyaxis(ax(1), 'left');
                plot(ax(1), Z.t, Z.B_perp, '-', 'Color', S.farbe.B, 'DisplayName', 'B_⊥ (Schleife)');
                ylabel(ax(1), 'B_⊥ in T');  ax(1).YColor = S.farbe.B;
                yyaxis(ax(1), 'right');
                plot(ax(1), Z.t, Z.i_stab(:, 1), '-', 'Color', S.farbe.i, 'DisplayName', 'i Stab 1');
                ylabel(ax(1), 'i in A');  ax(1).YColor = S.farbe.i;
                plot(ax(2), Z.t, Z.F(:, 1), '-', 'Color', S.farbe.Stab1, 'DisplayName', 'F Stab 1');
                plot(ax(2), Z.t, Z.F(:, 2), '--', 'Color', S.farbe.Stab2, 'DisplayName', 'F Stab 2');
                ylabel(ax(2), 'F in N');
                plot(ax(3), Z.t, Z.M_S, '-', 'Color', S.farbe.Kraft, 'DisplayName', 'M_S (Schleife)');
                yline(ax(3), E.kennzahlen.M_S_mittel, '--', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Mittelwert');
                ylabel(ax(3), 'M_S in N·m');
                titel = {'Flussdichte senkrecht zur Schleife (rot) und Stabstrom (blau, positiv aus der Zeichenebene) – Folie 16', ...
                         'Kraft auf die Stäbe (positiv in Feldrichtung)', 'Moment der Leiterschleife'};
                ort = {'eastoutside', 'eastoutside', 'eastoutside'};
            end
            for k = 1:3
                title(ax(k), titel{k}, 'FontWeight', 'normal');
                if contains(ort{k}, 'outside'), ri = 'vertical'; else, ri = 'horizontal'; end
                legend(ax(k), 'Location', ort{k}, 'Orientation', ri);
                xlim(ax(k), [Z.t(1) Z.t(end)]);
                hold(ax(k), 'off');
            end
            xlabel(ax(3), 't in s');
        end

        function zeichne_kennlinie(app, ax)
            E = app.Ergebnis;
            if ~strcmp(E.betriebsart, 'labor')
                cla(ax, 'reset');  axis(ax, 'off');
                text(ax, 0.5, 0.5, {'Im Folienmodus steht der Rotor (s = 1):', ...
                     'keine Drehmoment-Drehzahl-Kennlinie.'}, 'Units', 'normalized', ...
                     'HorizontalAlignment', 'center', 'FontSize', 14);
                return;
            end
            P = E.P;  K = E.kennzahlen;  d = E.kennlinie;
            vz = 1 - 2*strcmp(P.phasenfolge, 'L1-L3-L2');       % Linksdrehfeld: Beträge zeigen
            d.n = vz*d.n;  d.M = vz*d.M;  d.M_L = vz*d.M_L;
            asmbib.kennlinie_bild(d, 'Achse', ax, 'Kloss', true, 'ESB', true, 'MK', K.M_K, 'sK', K.s_K, ...
                'ns', P.ns, 'P', P, 'U', P.U_L, 'f', P.f1, 'Schaltung', P.schaltung);
            t = sprintf('Drehmoment-Drehzahl-Kennlinie (%s, U = %g V, f_1 = %g Hz)', P.schaltung, P.U_L, P.f1);
            if vz < 0, t = [t ', Linksdrehfeld: Beträge']; end
            title(ax, t, 'FontWeight', 'normal');
        end

        function bereite_querschnitt_vor(app)
            E = app.Ergebnis;
            t0 = E.daten.t(1);  t1 = E.daten.t(end);
            lab = strcmp(E.betriebsart, 'labor');
            if lab
                app.Ansicht.Value = 'statorfest';  app.Zeitlupe.Value = 0.02;  tz = t1;
            else
                app.Ansicht.Value = 'rotorfest';   app.Zeitlupe.Value = 0.01;  tz = t0;
            end
            app.Regler.Limits = [t0 t1];
            app.Regler.Value = tz;
            app.querschnitt_optionen();
        end

        function querschnitt_optionen(app)
            % feste Skalierung über den ganzen Verlauf (wie asmbib.drehfeld_animation)
            E = app.Ergebnis;
            if isempty(E), return; end
            par = E.par;
            tg = linspace(E.daten.t(1), E.daten.t(end), 4000);
            Zg = asmbib.querschnitt_zustand(E.daten, par, tg);
            app.Q.dopt = struct('orientierung', 'folien', 'ansicht', app.Ansicht.Value, ...
                'zerlegung', true, 'aenderung', true, 'kraft', true, 'alle', app.AlleStaebe.Value, ...
                'i_max', max(abs(Zg.i_folie(:))), 'F_max', max(max(abs(Zg.F(:, [par.k1 par.k2])))), ...
                'dB_max', max(abs(Zg.dB_perp)));
            app.zeige_zeitpunkt(app.Regler.Value);
        end

        function zeige_zeitpunkt(app, t)
            if isempty(app.Ergebnis), return; end
            app.zeichne_querschnitt(app.AxQuer, t);
            app.ZeitText.Text = sprintf('t = %.4f s', t);
        end

        function zeichne_querschnitt(app, ax, t)
            E = app.Ergebnis;
            Z = asmbib.querschnitt_zustand(E.daten, E.par, t);
            asmbib.querschnitt(ax, Z, 1, E.par, app.Q.dopt);
        end

        function play(app)
            if ~isempty(app.Animation) && isvalid(app.Animation) && strcmp(app.Animation.Running, 'on')
                app.stoppe_animation();
                return;
            end
            if isempty(app.Ergebnis), return; end
            if app.Regler.Value >= app.Regler.Limits(2), app.Regler.Value = app.Regler.Limits(1); end
            app.Animation = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.04, 'BusyMode', 'drop', ...
                                  'TimerFcn', @(~, ~) app.animationsschritt(), 'UserData', tic);
            app.KnopfPlay.Text = '❚❚';
            start(app.Animation);
        end

        function animationsschritt(app)
            try
                dt = toc(app.Animation.UserData);  app.Animation.UserData = tic;
                t = app.Regler.Value + app.Zeitlupe.Value*dt;
                if t >= app.Regler.Limits(2)
                    t = app.Regler.Limits(2);
                    app.stoppe_animation();
                end
                app.Regler.Value = t;
                app.zeige_zeitpunkt(t);
                drawnow limitrate;
            catch
                app.stoppe_animation();
            end
        end

        function stoppe_animation(app)
            if ~isempty(app.Animation) && isvalid(app.Animation)
                stop(app.Animation);
                delete(app.Animation);
            end
            app.Animation = [];
            if ~isempty(app.KnopfPlay) && isvalid(app.KnopfPlay), app.KnopfPlay.Text = '▶'; end
        end

        function zeige_kennzahlen(app)
            E = app.Ergebnis;  K = E.kennzahlen;  P = E.P;
            z = @(x) sprintf('%.4g', x);
            if strcmp(E.betriebsart, 'labor')
                D = {
                    'Synchrondrehzahl', 'n_s', z(K.ns), '1/min', '60·f1/p'
                    'Drehzahl am Ende', 'n', z(K.n_end), '1/min', 'Simulation, Mittel der letzten 5 %'
                    'Schlupf am Ende', 's', z(K.s_end), '–', '(n_s − n)/n_s'
                    'Luftspaltmoment am Ende', 'M', z(K.M_end), 'N·m', 'Simulation, Mittel der letzten 5 %'
                    'Leiterstrom am Ende (eff.)', 'I', z(K.I_eff_end), 'A', 'Strommessung 3~'
                    'Anzugsmoment', 'M_A', z(K.M_A), 'N·m', 'T-ESB stationär, s = 1'
                    'Kippmoment', 'M_K', z(K.M_K), 'N·m', 'T-ESB stationär'
                    'Kippschlupf', 's_K', z(K.s_K), '–', 'T-ESB stationär'
                    'Kippdrehzahl', 'n_K', z(K.n_K), '1/min', 'n_s·(1 − s_K)'
                    'Anzugsmoment / Bemessungsmoment', 'M_A/M_N', z(K.M_A/P.M_N), '–', ...
                        sprintf('M_N = %g N·m (Beispielmotor)', P.M_N)
                    'größtes Luftspaltmoment (dynamisch)', '|M|max', z(K.M_max_dyn), 'N·m', ...
                        'Simulation, enthält Einschaltpendelmomente'
                    'Rechenzeit', '', z(E.dauer_s), 's', E.modell};
            else
                D = {
                    'Synchrondrehzahl (zweipolig)', 'n_s', z(K.ns), '1/min', '60·f1/p'
                    'Schlupf (Rotor steht)', 's', z(K.s), '–', 'Ideales Drehfeld'
                    'Amplitude der Luftspaltflussdichte', 'B̂', z(K.Bhat), 'T', 'p·|ψh|/(2·N1ξ1·l·r)'
                    'Scheitelwert Stabstrom', 'î_Stab', z(K.ihat_stab), 'A', 'Rotorstab-Formeln (SPEC 4.4)'
                    'Versatzwinkel', 'φ2', z(K.phi2_grad), '°', '∠ψh − ∠i2′ = 90° + φ_Z'
                    'Rotorimpedanzwinkel', 'φ_Z', z(K.phiZ_grad), '°', 'φ2 − 90°'
                    'mittleres Schleifenmoment', 'M̄_S', z(K.M_S_mittel), 'N·m', 'î·l·B̂·r·sin φ2, über eine Feldumdrehung'
                    'Rechenzeit', '', z(E.dauer_s), 's', E.modell};
            end
            app.Tabelle.Data = D;
        end
    end
end

%% ========================= lokale Funktionen =========================
function gl = raster(parent, zeilen, spalten)
gl = uigridlayout(parent, [zeilen numel(spalten)], 'ColumnWidth', spalten, ...
                  'RowHeight', repmat({22}, 1, zeilen), 'RowSpacing', 6, 'ColumnSpacing', 6, ...
                  'BackgroundColor', 'w');
end

function ax = symbolachse(gl, zeilen)
ax = uiaxes(gl);
ax.Layout.Row = [zeilen(1) zeilen(end)];  ax.Layout.Column = 1;
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
axis(ax, 'off');
end

function s = onoff(tf)
if tf, s = 'on'; else, s = 'off'; end
end

function t = bereich_text(g)
if g.min_offen, u = sprintf('> %g', g.min); else, u = sprintf('≥ %g', g.min); end
if isinf(g.min), u = ''; end
o = '';
if ~isinf(g.max), o = sprintf('≤ %g', g.max); end
t = strjoin([{'Bereich'}, {u}, {o}], ' ');
t = regexprep(strtrim(t), '\s+', ' ');
if strcmp(t, 'Bereich'), t = 'Bereich: reelle Zahl'; end
if g.ganz, t = [t ', ganzzahlig']; end
end

function v = leer_zu_text(c)
if isempty(c), v = {'Keine Hinweise.'}; else, v = c(:); end
end

function c = strichfarbe(aktiv)
if aktiv, c = [0.15 0.15 0.15]; else, c = [0.72 0.72 0.72]; end
end

function vorbereiten(ax)
cla(ax);  hold(ax, 'on');  axis(ax, 'equal', 'off');
xlim(ax, [-1.7 1.7]);  ylim(ax, [-1.5 1.5]);
end

function symbol_netz(ax, lab)
% Drehstromquelle: Kreis mit Sinus, Leiter L1, L2, L3, N
vorbereiten(ax);  c = strichfarbe(true);  ca = strichfarbe(lab);
w = linspace(0, 2*pi, 100);
plot(ax, 0.55*cos(w) - 0.6, 0.55*sin(w), '-', 'Color', c, 'LineWidth', 1.5);
x = linspace(-0.35, 0.35, 60);
plot(ax, x - 0.6, 0.18*sin(x/0.35*pi), '-', 'Color', c, 'LineWidth', 1.5);
y = [0.9 0.45 0 -0.45];  nam = {'L1', 'L2', 'L3', 'N'};
for k = 1:4
    if k == 4, ck = ca; else, ck = c; end
    plot(ax, [-0.05 1.2], [y(k) y(k)], '-', 'Color', ck, 'LineWidth', 1.2);
    text(ax, 1.28, y(k), nam{k}, 'FontSize', 9, 'Color', ck);
end
text(ax, -0.6, -0.85, '3~', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', c);
hold(ax, 'off');
end

function symbol_motor(ax, lab)
% Labor: Motor M 3~ mit Welle; Folien: Querschnitt mit Drehfeldpfeil (Rotor steht)
vorbereiten(ax);  c = strichfarbe(true);
w = linspace(0, 2*pi, 100);
if lab
    for y = [0.35 0 -0.35]
        plot(ax, [-1.6 -0.66], [y y], '-', 'Color', c, 'LineWidth', 1.2);
    end
    plot(ax, 0.7*cos(w), 0.7*sin(w), '-', 'Color', c, 'LineWidth', 1.8);
    text(ax, 0, 0.18, 'M', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold', 'Color', c);
    text(ax, 0, -0.25, '3~', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', c);
    plot(ax, [0.7 1.6], [0 0], '-', 'Color', c, 'LineWidth', 4);
else
    plot(ax, 0.95*cos(w), 0.95*sin(w), '-', 'Color', c, 'LineWidth', 1.5);
    plot(ax, 0.6*cos(w), 0.6*sin(w), '-', 'Color', c, 'LineWidth', 1.2);
    plot(ax, [0 0], [0.42 -0.42], 'o', 'MarkerSize', 6, 'MarkerFaceColor', [0.8 0.1 0.1], 'Color', c);
    a = linspace(pi/2 + 0.6, pi/2 - 0.9, 30);                % Feld im Uhrzeigersinn (wie Folien)
    plot(ax, 1.2*cos(a), 1.2*sin(a), '-', 'Color', [0.1 0.65 0.3], 'LineWidth', 2);
    plot(ax, 1.2*cos(a(end)), 1.2*sin(a(end)), '>', 'MarkerSize', 6, ...
         'MarkerFaceColor', [0.1 0.65 0.3], 'Color', [0.1 0.65 0.3]);
    text(ax, 0, 0, 's = 1', 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', c);
end
hold(ax, 'off');
end

function symbol_last(ax, lab)
% Welle, Schwungmasse J_L, Last M_L
vorbereiten(ax);  c = strichfarbe(lab);
plot(ax, [-1.7 -0.55], [0 0], '-', 'Color', c, 'LineWidth', 4);
patch(ax, [-0.55 -0.25 -0.25 -0.55], [-0.75 -0.75 0.75 0.75], [0.9 0.9 0.9], 'EdgeColor', c, 'LineWidth', 1.5);
text(ax, -0.4, 1.0, 'J_L', 'HorizontalAlignment', 'center', 'Color', c);
plot(ax, [-0.25 0.35], [0 0], '-', 'Color', c, 'LineWidth', 4);
patch(ax, [0.35 1.4 1.4 0.35], [-0.5 -0.5 0.5 0.5], [1 1 1], 'EdgeColor', c, 'LineWidth', 1.5);
text(ax, 0.875, 0, 'M_L', 'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', c);
for x = linspace(0.35, 1.4, 6)                               % Bezug (Fundament)
    plot(ax, [x x - 0.15], [-0.6 -0.8], '-', 'Color', c);
end
plot(ax, [0.35 1.4], [-0.6 -0.6], '-', 'Color', c, 'LineWidth', 1.2);
if ~lab
    text(ax, 0.4, -1.25, 'Rotor festgebremst', 'HorizontalAlignment', 'center', 'FontSize', 9, ...
         'Color', strichfarbe(true));
end
hold(ax, 'off');
end
