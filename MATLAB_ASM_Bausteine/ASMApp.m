classdef ASMApp < handle
%ASMAPP Graphical user interface of the ASM block library (three-phase induction motor).
%   app = ASMApp                    opens the GUI
%   app = ASMApp('Visible', false)  invisible (tests)
%
%   Layout as in the laboratory from left to right: grid | motor (ASM) | shaft/load, below
%   outputs (time plots, torque-speed curve, cross-section, key figures) and simulation
%   parameters. Simulink stays the computational core: the GUI only collects the inputs,
%   calls run_asm (example models, parameters via Simulink.SimulationInput) and displays the
%   result. Results and parameters are passed explicitly (app.Result = run_asm(P)); the GUI
%   neither reads nor writes the base workspace. Drawing uses the functions of the library
%   (asmtools.draw_cross_section, asmtools.torque_speed_plot), export uses
%   asmexport.slide_figure. All texts shown in the window are German.
%
%   Modes
%     'lab'     laboratory set-up motor       examples/ex_startup_load_step.slx
%     'slides'  slides 16-30 (standstill)     examples/ex_slides16_30_rotor_bars.slx
%
%   Public methods (also for tests and scripts)
%     set_input(app, field, value)   set an input (field names as asm_params)
%     select_mode(app, mode)         'lab' | 'slides'
%     P = parameters(app)            inputs as parameter struct for run_asm
%     simulate(app)                  start the simulation, result in app.Result
%     export_figure(app, folder)     current figure via asmexport.slide_figure
%     close_app(app)
%
%   All default values are example values (parameter/asm_standard.m).

    properties (SetAccess = private)
        Figure                      % uifigure
        Result = []                 % return value of run_asm
        Mode = 'lab'                % 'lab' | 'slides'
    end

    properties (Access = private)
        G                           % value ranges (asmapp.limits)
        StandardMotor               % standard motor (asm_standard)
        Field = struct()            % numeric fields, field names as asm_params
        Choice = struct()           % drop-down fields
        Panel = struct()
        AxSymbol = struct()
        Radio = struct()
        ButtonSim
        ButtonExport
        Status
        Notes
        SolverText
        Tabs
        Tab = struct()
        AxTime
        AxCurve
        AxSection
        Slider
        ButtonPlay
        TimeText
        SlowMotion
        View
        AllBars
        Table
        Animation                   % timer
        Q = struct()                % display options of the cross-section
        Locked = false
    end

    %% ========================= public methods =========================
    methods
        function app = ASMApp(opt)
            arguments
                opt.Visible (1,1) logical = true
            end
            app.G = asmapp.limits();
            app.StandardMotor = asm_standard();
            app.build_gui();
            app.apply(asm_params('lab'));
            app.update_state();
            app.draw_symbols();
            app.clear_outputs();
            if opt.Visible, app.Figure.Visible = 'on'; end
        end

        function delete(app)
            app.stop_animation();
            if ~isempty(app.Animation) && isvalid(app.Animation), delete(app.Animation); end
            if ~isempty(app.Figure) && isvalid(app.Figure), delete(app.Figure); end
        end

        function close_app(app)
            delete(app);
        end

        function set_input(app, field, value)
            %SET_INPUT set an input as in the GUI (with value-range check)
            if isfield(app.Field, field)
                [ok, m] = asmapp.check_value(field, value, app.G);
                if ~ok, error('asm:value', '%s', m); end
                app.Field.(field).Value = value;
            elseif isfield(app.Choice, field)
                w = app.Choice.(field);
                if ~any(strcmp(w.ItemsData, value))
                    error('asm:value', 'Ungültige Auswahl für %s: "%s".', field, value);
                end
                w.Value = value;
                if strcmp(field, 'param_set'), app.param_set_changed(); end
            else
                error('asm:field', 'Unbekanntes Eingabefeld "%s".', field);
            end
            app.input_changed();
        end

        function select_mode(app, mode)
            mode = validatestring(mode, {'lab', 'slides'});
            app.Radio.(mode).Value = true;
            app.mode_changed(mode);
        end

        function P = parameters(app)
            %PARAMETERS inputs as parameter struct for run_asm
            P = asm_params(app.Mode);
            for f = fieldnames(app.Field)', P.(f{1}) = app.Field.(f{1}).Value; end
            for f = fieldnames(app.Choice)', P.(f{1}) = app.Choice.(f{1}).Value; end
        end

        function simulate(app)
            %SIMULATE start the simulation; the GUI is locked meanwhile
            app.stop_animation();
            P = app.parameters();
            model = struct('lab', 'ex_startup_load_step', 'slides', 'ex_slides16_30_rotor_bars');
            app.lock(true);
            app.report(sprintf('Simulation läuft … (%s, t_End = %g s)', model.(app.Mode), P.t_end), 'info');
            dlg = [];
            try
                dlg = uiprogressdlg(app.Figure, 'Title', 'Simulation', 'Indeterminate', 'on', ...
                    'Message', sprintf('Modell %s wird simuliert …', model.(app.Mode)));
            catch
            end
            drawnow;
            try
                R = run_asm(P);
                app.Result = R;
                app.SolverText.Text = sprintf('%s,  RelTol %g,  MaxStep %g s', R.solver.Solver, ...
                                              R.solver.RelTol, R.solver.MaxStep);
                app.Notes.Value = empty_to_text(R.notes);
                app.draw_outputs();
                app.report(sprintf('Simulation fertig (Rechenzeit %.1f s).', R.duration_s), 'ok');
            catch err
                app.Result = [];
                app.clear_outputs();
                app.Notes.Value = {err.message};
                app.report(['Fehler: ' err.message], 'error');
            end
            if ~isempty(dlg) && isvalid(dlg), close(dlg); end
            app.lock(false);
        end

        function files = export_figure(app, folder)
            %EXPORT_FIGURE current figure in the slide style (asmexport.slide_figure)
            if nargin < 2, folder = asmexport.output_folder(); end
            files = {};
            if isempty(app.Result), app.report('Erst simulieren, dann exportieren.', 'error'); return; end
            tab = app.active_tab();
            f = figure('Visible', 'off', 'Color', 'w');
            cleanup = onCleanup(@() close(f));
            switch tab
                case 'time'
                    tl = tiledlayout(f, 3, 1);
                    ax = gobjects(1, 3);
                    for k = 1:3, ax(k) = nexttile(tl); end
                    app.draw_time(ax);
                case 'curve'
                    app.draw_curve(axes(f));
                case 'section'
                    app.draw_section(axes(f), app.Slider.Value);
                otherwise
                    app.report('Für die Kennzahlen gibt es keine Abbildung.', 'error');
                    return;
            end
            name = sprintf('asmapp_%s_%s', app.Mode, tab);
            files = asmexport.slide_figure(f, name, 'Folder', folder);
            app.report(sprintf('Exportiert: %s', strjoin(files, ', ')), 'ok');
        end
    end

    %% ========================= layout =========================
    methods (Access = private)
        function build_gui(app)
            fig = uifigure('Name', 'ASM-Bausteine – Bedienoberfläche Drehstrom-Asynchronmotor', ...
                           'Position', [40 40 1440 940], 'Visible', 'off', 'Color', 'w');
            try, theme(fig, 'light'); catch, end              % from R2025a; older releases light
            fig.CloseRequestFcn = @(~, ~) app.close_app();
            app.Figure = fig;
            main = uigridlayout(fig, [3 3], 'RowHeight', {40, 290, '1x'}, ...
                                'ColumnWidth', {'0.95x', '1.6x', '1x'}, 'BackgroundColor', 'w');

            % mode
            bg = uibuttongroup(main, 'BorderType', 'none', 'BackgroundColor', 'w', ...
                               'SelectionChangedFcn', @(~, ev) app.mode_changed(ev.NewValue.Tag));
            bg.Layout.Row = 1;  bg.Layout.Column = [1 3];
            uilabel(bg, 'Text', 'Betriebsart:', 'FontWeight', 'bold', 'Position', [10 8 90 22]);
            app.Radio.lab = uiradiobutton(bg, 'Text', 'Laboraufbau Motor (Hochlauf, Laststoß)', ...
                'Tag', 'lab', 'Position', [100 8 290 22], 'Value', true);
            app.Radio.slides = uiradiobutton(bg, 'Text', 'Folien 16–30 (Stillstand, s = 1)', ...
                'Tag', 'slides', 'Position', [400 8 290 22]);

            app.build_grid_panel(main);
            app.build_motor_panel(main);
            app.build_load_panel(main);
            app.build_outputs(main);
            app.build_simulation_panel(main);
        end

        function build_grid_panel(app, main)
            p = uipanel(main, 'Title', 'Netz 3~', 'FontWeight', 'bold', 'BackgroundColor', 'w');
            p.Layout.Row = 2;  p.Layout.Column = 1;  app.Panel.grid = p;
            gl = grid_layout(p, 6, {160, 'fit', 85, 'fit'});
            app.AxSymbol.grid = symbol_axes(gl, 1:6);
            app.number_field(gl, 1, 2, 'U_L', 'U (Leiter, eff.)', 'V');
            app.number_field(gl, 2, 2, 'f1', 'f<sub>1</sub>', 'Hz');
            app.choice_field(gl, 3, 2, 'phase_seq', 'Phasenfolge', ...
                {'L1-L2-L3 (rechts)', 'L1-L3-L2 (links)'}, {'L1-L2-L3', 'L1-L3-L2'}, [3 4]);
            app.number_field(gl, 4, 2, 't_on', 't<sub>ein</sub>', 's');
        end

        function build_motor_panel(app, main)
            p = uipanel(main, 'Title', 'Motor (ASM)', 'FontWeight', 'bold', 'BackgroundColor', 'w');
            p.Layout.Row = 2;  p.Layout.Column = 2;  app.Panel.motor = p;
            gl = grid_layout(p, 8, {120, 'fit', 75, 'fit', 'fit', 75, 'fit'});
            app.AxSymbol.motor = symbol_axes(gl, 1:8);
            app.choice_field(gl, 1, 2, 'param_set', 'Parametersatz', {'Standard', 'Benutzerdefiniert'}, ...
                {'standard', 'custom'}, [3 4]);
            app.choice_field(gl, 1, 5, 'connection', 'Schaltung', {'Stern', 'Dreieck'}, {'star', 'delta'}, [6 7]);
            app.number_field(gl, 2, 2, 'R1',   'R<sub>1</sub>', 'Ω');
            app.number_field(gl, 2, 5, 'R2b',  'R<sub>2</sub>′', 'Ω');
            app.number_field(gl, 3, 2, 'L1s',  'L<sub>1σ</sub>', 'H');
            app.number_field(gl, 3, 5, 'L2sb', 'L<sub>2σ</sub>′', 'H');
            app.number_field(gl, 4, 2, 'Lh',   'L<sub>h</sub>', 'H');
            app.number_field(gl, 4, 5, 'p',    'p', '–');
            app.number_field(gl, 5, 2, 'J_M',  'J<sub>M</sub>', 'kg·m²');
            t = uilabel(gl, 'Text', 'Ideales Drehfeld (nur Folien 16–30): zweipolig, Rotor steht (s = 1)', ...
                        'FontAngle', 'italic');
            t.Layout.Row = 6;  t.Layout.Column = [2 7];
            app.number_field(gl, 7, 2, 'Bhat', 'B̂', 'T');
            app.choice_field(gl, 8, 2, 'phi2_mode', 'φ<sub>2</sub>', {'fest', 'aus Rotorimpedanz (90° + φZ)'}, ...
                {'fixed', 'impedance'}, [3 4]);
            app.number_field(gl, 8, 5, 'phi2_fix', 'φ<sub>2</sub> (fest)', '°');
            app.Choice.param_set.ValueChangedFcn = @(~, ~) app.param_set_changed();
        end

        function build_load_panel(app, main)
            p = uipanel(main, 'Title', 'Welle / Last', 'FontWeight', 'bold', 'BackgroundColor', 'w');
            p.Layout.Row = 2;  p.Layout.Column = 3;  app.Panel.load = p;
            gl = grid_layout(p, 6, {160, 'fit', 85, 'fit'});
            app.AxSymbol.load = symbol_axes(gl, 1:6);
            app.choice_field(gl, 1, 2, 'load_type', 'Lasttyp', {'konstant', 'Lüfter (M ~ n²)'}, ...
                {'constant', 'fan'}, [3 4]);
            app.number_field(gl, 2, 2, 'M_L', 'M<sub>L</sub>', 'N·m');
            app.number_field(gl, 3, 2, 'dM_L', 'ΔM<sub>L</sub> (Laststoß)', 'N·m');
            app.number_field(gl, 4, 2, 't_step', 't<sub>stoß</sub>', 's');
            app.number_field(gl, 5, 2, 'J_L', 'J<sub>L</sub> (Zusatz)', 'kg·m²');
            app.Field.M_L.Tooltip = ['Grundlast. Konstant: M_L0. Lüfter: Moment bei der Bezugsdrehzahl ' ...
                                     'n_B = 0,96·n_s (Beispielmotor 1440 1/min).'];
            app.Field.dM_L.Tooltip = 'Höhe des Laststoßes (0 = kein Laststoß, negativ = Entlastung).';
        end

        function build_outputs(app, main)
            p = uipanel(main, 'Title', 'Ausgaben', 'FontWeight', 'bold', 'BackgroundColor', 'w');
            p.Layout.Row = 3;  p.Layout.Column = [1 2];
            gl = uigridlayout(p, [2 2], 'RowHeight', {'1x', 30}, 'ColumnWidth', {'1x', 190}, ...
                              'BackgroundColor', 'w');
            app.Tabs = uitabgroup(gl, 'SelectionChangedFcn', @(~, ~) app.update_state());
            app.Tabs.Layout.Row = 1;  app.Tabs.Layout.Column = [1 2];

            app.Tab.time = uitab(app.Tabs, 'Title', 'Zeitverläufe', 'Tag', 'time');
            g = uigridlayout(app.Tab.time, [3 1], 'RowSpacing', 2, 'BackgroundColor', 'w');
            app.AxTime = gobjects(1, 3);
            for k = 1:3, app.AxTime(k) = uiaxes(g); end

            app.Tab.curve = uitab(app.Tabs, 'Title', 'Kennlinie M(n)', 'Tag', 'curve');
            g = uigridlayout(app.Tab.curve, [1 1], 'BackgroundColor', 'w');
            app.AxCurve = uiaxes(g);

            app.Tab.section = uitab(app.Tabs, 'Title', 'Querschnitt', 'Tag', 'section');
            g = uigridlayout(app.Tab.section, [2 1], 'RowHeight', {'1x', 30}, 'BackgroundColor', 'w');
            app.AxSection = uiaxes(g);
            app.AxSection.Toolbar.Visible = 'off';
            s = uigridlayout(g, [1 8], 'Padding', 0, 'BackgroundColor', 'w', ...
                             'ColumnWidth', {40, '1x', 110, 'fit', 70, 'fit', 'fit', 'fit'});
            app.ButtonPlay = uibutton(s, 'Text', '▶', 'Tooltip', 'Animation abspielen / anhalten', ...
                                      'ButtonPushedFcn', @(~, ~) app.play());
            app.Slider = uislider(s, 'Limits', [0 1], 'MajorTicks', [], 'MinorTicks', [], ...
                'ValueChangingFcn', @(~, ev) app.show_time(ev.Value), ...
                'ValueChangedFcn', @(src, ~) app.show_time(src.Value));
            app.TimeText = uilabel(s, 'Text', 't = – s');
            uilabel(s, 'Text', 'Zeitlupe [s/s]', 'Tooltip', 'Simulationszeit je Sekunde Abspielzeit');
            app.SlowMotion = uieditfield(s, 'numeric', 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', ...
                                         'Value', 0.02, 'ValueDisplayFormat', '%.4g');
            uilabel(s, 'Text', 'Ansicht');
            app.View = uidropdown(s, 'Items', {'rotorfest', 'statorfest'}, 'ItemsData', {'rotor', 'stator'}, ...
                                  'Value', 'stator', 'ValueChangedFcn', @(~, ~) app.section_options());
            app.AllBars = uicheckbox(s, 'Text', 'alle Stäbe', 'Value', true, ...
                                     'ValueChangedFcn', @(~, ~) app.section_options());

            app.Tab.metrics = uitab(app.Tabs, 'Title', 'Kennzahlen', 'Tag', 'metrics');
            g = uigridlayout(app.Tab.metrics, [1 1], 'BackgroundColor', 'w');
            app.Table = uitable(g, 'ColumnName', {'Größe', 'Zeichen', 'Wert', 'Einheit', 'Herkunft'}, ...
                                'ColumnWidth', {300, 80, 100, 70, 'auto'}, 'RowName', {});

            hint = uilabel(gl, 'Text', 'Export: 16:9, PNG 300 dpi und SVG nach export/ (asmexport.slide_figure)', ...
                           'FontColor', [0.4 0.4 0.4]);
            hint.Layout.Row = 2;  hint.Layout.Column = 1;
            app.ButtonExport = uibutton(gl, 'Text', 'Abbildung exportieren', ...
                                        'ButtonPushedFcn', @(~, ~) app.export_figure());
            app.ButtonExport.Layout.Row = 2;  app.ButtonExport.Layout.Column = 2;
        end

        function build_simulation_panel(app, main)
            p = uipanel(main, 'Title', 'Simulationsparameter', 'FontWeight', 'bold', 'BackgroundColor', 'w');
            p.Layout.Row = 3;  p.Layout.Column = 3;
            gl = uigridlayout(p, [7 3], 'RowHeight', {22, 22, 22, 44, 22, 22, '1x'}, ...
                              'ColumnWidth', {70, '1x', 'fit'}, 'BackgroundColor', 'w');
            app.number_field(gl, 1, 1, 't_end', 't<sub>End</sub>', 's');
            l = uilabel(gl, 'Text', 'Solver (wie Anleitung, Abschnitt 3):');
            l.Layout.Row = 2;  l.Layout.Column = [1 3];
            app.SolverText = uilabel(gl, 'Text', 'ode23t,  RelTol 1e-05,  MaxStep 0.0001 s', ...
                                     'FontColor', [0.3 0.3 0.3]);
            app.SolverText.Layout.Row = 3;  app.SolverText.Layout.Column = [1 3];
            app.ButtonSim = uibutton(gl, 'Text', 'Simulieren', 'FontSize', 16, 'FontWeight', 'bold', ...
                                     'ButtonPushedFcn', @(~, ~) app.simulate());
            app.ButtonSim.Layout.Row = 4;  app.ButtonSim.Layout.Column = [1 3];
            app.Status = uilabel(gl, 'Text', 'Bereit.', 'WordWrap', 'on');
            app.Status.Layout.Row = [5 6];  app.Status.Layout.Column = [1 3];
            app.Notes = uitextarea(gl, 'Editable', 'off', 'Value', {''}, ...
                                   'Tooltip', 'Hinweise zur Plausibilität der Eingaben und Ergebnisse');
            app.Notes.Layout.Row = 7;  app.Notes.Layout.Column = [1 3];
        end

        function number_field(app, gl, row, col, name, label, unit)
            % numeric field with symbol and unit; value range from the catalogue
            g = app.G.(name);
            l = uilabel(gl, 'Text', label, 'Interpreter', 'html', 'HorizontalAlignment', 'right');
            l.Layout.Row = row;  l.Layout.Column = col;
            f = uieditfield(gl, 'numeric', 'Limits', [g.min g.max], 'ValueDisplayFormat', '%.6g', ...
                            'Tooltip', sprintf('%s [%s], %s', g.prompt, g.unit, range_text(g)), ...
                            'ValueChangedFcn', @(src, ev) app.field_changed(name, src, ev));
            if g.min_open, f.LowerLimitInclusive = 'off'; end
            f.Layout.Row = row;  f.Layout.Column = col + 1;
            u = uilabel(gl, 'Text', unit);
            u.Layout.Row = row;  u.Layout.Column = col + 2;
            app.Field.(name) = f;
        end

        function choice_field(app, gl, row, col, name, label, items, data, cols)
            % drop-down with German items and English code values (ItemsData)
            l = uilabel(gl, 'Text', label, 'Interpreter', 'html', 'HorizontalAlignment', 'right');
            l.Layout.Row = row;  l.Layout.Column = col;
            d = uidropdown(gl, 'Items', items, 'ItemsData', data, ...
                           'ValueChangedFcn', @(~, ~) app.input_changed());
            d.Layout.Row = row;  d.Layout.Column = cols;
            app.Choice.(name) = d;
        end

        function apply(app, P)
            for f = fieldnames(app.Field)', app.Field.(f{1}).Value = P.(f{1}); end
            for f = fieldnames(app.Choice)', app.Choice.(f{1}).Value = P.(f{1}); end
        end
    end

    %% ========================= callbacks and state =========================
    methods (Access = private)
        function field_changed(app, name, src, ev)
            % second check (integer etc.), the limits are checked by the field itself
            [ok, m] = asmapp.check_value(name, src.Value, app.G);
            if ~ok
                src.Value = ev.PreviousValue;
                app.report(['Ungültige Eingabe – ' m], 'error');
                return;
            end
            app.input_changed();
        end

        function input_changed(app)
            app.update_state();
            if ~isempty(app.Result)
                app.report('Eingaben geändert – „Simulieren“ drücken, um die Ausgaben zu aktualisieren.', 'info');
            end
        end

        function param_set_changed(app)
            if strcmp(app.Choice.param_set.Value, 'standard')
                for f = {'R1', 'L1s', 'Lh', 'R2b', 'L2sb', 'p', 'J_M'}
                    app.Field.(f{1}).Value = app.StandardMotor.(f{1});
                end
            end
            app.input_changed();
        end

        function mode_changed(app, mode)
            if strcmp(mode, app.Mode), return; end
            app.stop_animation();
            app.Mode = mode;
            app.Field.t_end.Value = asm_params(mode).t_end;
            app.Result = [];
            app.Notes.Value = {''};
            app.clear_outputs();
            app.draw_symbols();
            app.update_state();
            app.report('Betriebsart gewechselt – Bereit.', 'info');
        end

        function update_state(app)
            % enable or grey out the fields depending on the mode
            if app.Locked, return; end
            lab = strcmp(app.Mode, 'lab');
            std = strcmp(app.Choice.param_set.Value, 'standard');
            fixed = strcmp(app.Choice.phi2_mode.Value, 'fixed');
            on = {'U_L', lab; 'f1', true; 'phase_seq', lab; 't_on', lab; ...
                  'param_set', lab; 'connection', lab; ...
                  'R1', lab && ~std; 'L1s', lab && ~std; 'Lh', lab && ~std; 'R2b', lab && ~std; ...
                  'L2sb', lab && ~std; 'p', lab && ~std; 'J_M', lab && ~std; ...
                  'Bhat', ~lab; 'phi2_mode', ~lab; 'phi2_fix', ~lab && fixed; ...
                  'load_type', lab; 'M_L', lab; 'dM_L', lab; 't_step', lab && app.Field.dM_L.Value ~= 0; ...
                  'J_L', lab; 't_end', true};
            for k = 1:size(on, 1)
                h = app.element(on{k, 1});
                h.Enable = onoff(on{k, 2});
            end
            if lab
                app.Panel.motor.Title = 'Motor (ASM)';
                app.Panel.load.Title = 'Welle / Last';
            else
                app.Panel.motor.Title = 'Motor (ASM) – Folienmodus: Ideales Drehfeld';
                app.Panel.load.Title = 'Welle / Last – Folienmodus: Rotor festgebremst';
            end
            has = ~isempty(app.Result);
            app.ButtonSim.Enable = 'on';
            app.Radio.lab.Enable = 'on';  app.Radio.slides.Enable = 'on';
            app.ButtonExport.Enable = onoff(has && ~strcmp(app.active_tab(), 'metrics'));
            controls = {app.ButtonPlay, app.Slider, app.SlowMotion, app.View, app.AllBars};
            for k = 1:numel(controls)
                controls{k}.Enable = onoff(has);
            end
        end

        function h = element(app, name)
            if isfield(app.Field, name), h = app.Field.(name); else, h = app.Choice.(name); end
        end

        function lock(app, yes)
            % lock the GUI during the simulation
            if yes
                app.Locked = true;
                all_controls = [struct2cell(app.Field); struct2cell(app.Choice); ...
                        {app.ButtonSim; app.ButtonExport; app.Radio.lab; app.Radio.slides; ...
                         app.ButtonPlay; app.Slider; app.SlowMotion; app.View; app.AllBars}];
                for k = 1:numel(all_controls), all_controls{k}.Enable = 'off'; end
                app.Figure.Pointer = 'watch';
            else
                app.Locked = false;
                app.Figure.Pointer = 'arrow';
                app.update_state();
            end
            drawnow;
        end

        function report(app, text, kind)
            colours = struct('ok', [0 0.45 0.15], 'info', [0.1 0.1 0.1], 'error', [0.8 0 0]);
            app.Status.Text = text;
            app.Status.FontColor = colours.(kind);
        end

        function t = active_tab(app)
            t = app.Tabs.SelectedTab.Tag;
        end
    end

    %% ========================= circuit symbols =========================
    methods (Access = private)
        function draw_symbols(app)
            lab = strcmp(app.Mode, 'lab');
            symbol_grid(app.AxSymbol.grid, lab);
            symbol_motor(app.AxSymbol.motor, lab);
            symbol_load(app.AxSymbol.load, lab);
        end
    end

    %% ========================= outputs =========================
    methods (Access = private)
        function clear_outputs(app)
            for ax = [app.AxTime, app.AxCurve, app.AxSection]
                cla(ax, 'reset');  axis(ax, 'off');
            end
            text(app.AxTime(2), 0.5, 0.5, 'Noch keine Ergebnisse – „Simulieren“ drücken.', ...
                 'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontSize', 14);
            app.Table.Data = cell(0, 5);
            app.TimeText.Text = 't = – s';
            app.update_state();
        end

        function draw_outputs(app)
            app.draw_time(app.AxTime);
            app.draw_curve(app.AxCurve);
            app.prepare_section();
            app.show_metrics();
        end

        function draw_time(app, ax)
            % time plots: lab M(t), n(t), i1(t); slides B_perp/i, F, M_S
            R = app.Result;  Z = R.time;  S = asmexport.style();
            for k = 1:3, cla(ax(k), 'reset'); hold(ax(k), 'on'); grid(ax(k), 'on'); end
            if strcmp(R.scenario, 'lab')
                plot(ax(1), Z.t, Z.M, '-', 'Color', S.colour.i, 'DisplayName', 'Luftspaltmoment M');
                plot(ax(1), Z.t, Z.M_W, '-', 'Color', [0.6 0.6 0.6], 'DisplayName', 'Wellenmoment M_W');
                plot(ax(1), Z.t, Z.M_L, '--', 'Color', S.colour.L2, 'DisplayName', 'Lastmoment M_L');
                ylabel(ax(1), 'M in N·m');
                plot(ax(2), Z.t, Z.n, '-', 'Color', S.colour.i, 'DisplayName', 'Drehzahl n');
                yline(ax(2), (1 - 2*strcmp(R.params.phase_seq, 'L1-L3-L2'))*R.params.ns, '--', ...
                      'Color', [0.4 0.4 0.4], 'DisplayName', 'Synchrondrehzahl n_s');
                ylabel(ax(2), 'n in 1/min');
                phase = {'U', 'V', 'W'};
                for j = 1:3
                    plot(ax(3), Z.t, Z.i_abc(:, j), '-', 'LineWidth', 0.8, ...
                         'Color', S.colour.(sprintf('L%d', j)), 'DisplayName', sprintf('i_%s (L%d)', phase{j}, j));
                end
                plot(ax(3), Z.t, Z.I_eff, 'k--', 'DisplayName', 'I_{eff} (Leiter)');
                ylabel(ax(3), 'i_1 in A');
                titles = {'Drehmoment', 'Drehzahl', 'Statorstrom (Strang, aus dem Raumzeiger i_1)'};
                places = {'north', 'southeast', 'northeast'};
            else
                yyaxis(ax(1), 'left');
                plot(ax(1), Z.t, Z.B_perp, '-', 'Color', S.colour.B, 'DisplayName', 'B_⊥ (Schleife)');
                ylabel(ax(1), 'B_⊥ in T');  ax(1).YColor = S.colour.B;
                yyaxis(ax(1), 'right');
                plot(ax(1), Z.t, Z.i_bar(:, 1), '-', 'Color', S.colour.i, 'DisplayName', 'i Stab 1');
                ylabel(ax(1), 'i in A');  ax(1).YColor = S.colour.i;
                plot(ax(2), Z.t, Z.F(:, 1), '-', 'Color', S.colour.bar1, 'DisplayName', 'F Stab 1');
                plot(ax(2), Z.t, Z.F(:, 2), '--', 'Color', S.colour.bar2, 'DisplayName', 'F Stab 2');
                ylabel(ax(2), 'F in N');
                plot(ax(3), Z.t, Z.M_S, '-', 'Color', S.colour.force, 'DisplayName', 'M_S (Schleife)');
                if isfinite(R.metrics.M_S_mean)               % no mean without a whole field revolution
                    yline(ax(3), R.metrics.M_S_mean, '--', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Mittelwert');
                end
                ylabel(ax(3), 'M_S in N·m');
                titles = {'Flussdichte senkrecht zur Schleife (rot) und Stabstrom (blau, positiv aus der Zeichenebene) – Folie 16', ...
                          'Kraft auf die Stäbe (positiv in Feldrichtung)', 'Moment der Leiterschleife'};
                places = {'eastoutside', 'eastoutside', 'eastoutside'};
            end
            for k = 1:3
                title(ax(k), titles{k}, 'FontWeight', 'normal');
                if contains(places{k}, 'outside'), ori = 'vertical'; else, ori = 'horizontal'; end
                legend(ax(k), 'Location', places{k}, 'Orientation', ori);
                xlim(ax(k), [Z.t(1) Z.t(end)]);
                hold(ax(k), 'off');
            end
            xlabel(ax(3), 't in s');
        end

        function draw_curve(app, ax)
            R = app.Result;
            if ~strcmp(R.scenario, 'lab')
                cla(ax, 'reset');  axis(ax, 'off');
                text(ax, 0.5, 0.5, {'Im Folienmodus steht der Rotor (s = 1):', ...
                     'keine Drehmoment-Drehzahl-Kennlinie.'}, 'Units', 'normalized', ...
                     'HorizontalAlignment', 'center', 'FontSize', 14);
                return;
            end
            P = R.params;  K = R.metrics;  d = R.torque_speed;
            vz = 1 - 2*strcmp(P.phase_seq, 'L1-L3-L2');       % negative sequence: show magnitudes
            d.n = vz*d.n;  d.M = vz*d.M;  d.M_L = vz*d.M_L;
            asmtools.torque_speed_plot(d, 'Axes', ax, 'Kloss', true, 'EC', true, 'MK', K.M_K, 'sK', K.s_K, ...
                'ns', P.ns, 'P', P, 'U', P.U_L, 'f', P.f1, 'Connection', P.connection);
            conn = struct('star', 'Stern', 'delta', 'Dreieck');
            t = sprintf('Drehmoment-Drehzahl-Kennlinie (%s, U = %g V, f_1 = %g Hz)', conn.(P.connection), P.U_L, P.f1);
            if vz < 0, t = [t ', Linksdrehfeld: Beträge']; end
            title(ax, t, 'FontWeight', 'normal');
        end

        function prepare_section(app)
            R = app.Result;
            t0 = R.field_data.t(1);  t1 = R.field_data.t(end);
            if strcmp(R.scenario, 'lab')
                app.View.Value = 'stator';  app.SlowMotion.Value = 0.02;  tz = t1;
            else
                app.View.Value = 'rotor';   app.SlowMotion.Value = 0.01;  tz = t0;
            end
            app.Slider.Limits = [t0 t1];
            app.Slider.Value = tz;
            app.section_options();
        end

        function section_options(app)
            % fixed scaling over the whole trajectory (as asmtools.field_animation)
            R = app.Result;
            if isempty(R), return; end
            par = R.field_par;
            tg = linspace(R.field_data.t(1), R.field_data.t(end), 4000);
            Zg = asmtools.cross_section_state(R.field_data, par, tg);
            app.Q.dopt = struct('orientation', 'slides', 'view', app.View.Value, ...
                'decomposition', true, 'change_vector', true, 'force', true, 'all_bars', app.AllBars.Value, ...
                'i_max', max(abs(Zg.i_slide(:))), 'F_max', max(max(abs(Zg.F(:, [par.k1 par.k2])))), ...
                'dB_max', max(abs(Zg.dB_perp)));
            app.show_time(app.Slider.Value);
        end

        function show_time(app, t)
            if isempty(app.Result), return; end
            app.draw_section(app.AxSection, t);
            app.TimeText.Text = sprintf('t = %.4f s', t);
        end

        function draw_section(app, ax, t)
            R = app.Result;
            Z = asmtools.cross_section_state(R.field_data, R.field_par, t);
            asmtools.draw_cross_section(ax, Z, 1, R.field_par, app.Q.dopt);
        end

        function play(app)
            if ~isempty(app.Animation) && isvalid(app.Animation) && strcmp(app.Animation.Running, 'on')
                app.stop_animation();
                return;
            end
            if isempty(app.Result), return; end
            if app.Slider.Value >= app.Slider.Limits(2), app.Slider.Value = app.Slider.Limits(1); end
            app.Animation = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.04, 'BusyMode', 'drop', ...
                                  'TimerFcn', @(~, ~) app.animation_step(), 'UserData', tic);
            app.ButtonPlay.Text = '❚❚';
            start(app.Animation);
        end

        function animation_step(app)
            try
                dt = toc(app.Animation.UserData);  app.Animation.UserData = tic;
                t = app.Slider.Value + app.SlowMotion.Value*dt;
                if t >= app.Slider.Limits(2)
                    t = app.Slider.Limits(2);
                    app.stop_animation();
                end
                app.Slider.Value = t;
                app.show_time(t);
                drawnow limitrate;
            catch
                app.stop_animation();
            end
        end

        function stop_animation(app)
            if ~isempty(app.Animation) && isvalid(app.Animation)
                stop(app.Animation);
                delete(app.Animation);
            end
            app.Animation = [];
            if ~isempty(app.ButtonPlay) && isvalid(app.ButtonPlay), app.ButtonPlay.Text = '▶'; end
        end

        function show_metrics(app)
            R = app.Result;  K = R.metrics;  P = R.params;
            z = @(x) value_text(x);
            if strcmp(R.scenario, 'lab')
                D = {
                    'Synchrondrehzahl', 'n_s', z(K.ns), '1/min', '60·f1/p'
                    'Drehzahl am Ende', 'n', z(K.n_end), '1/min', sprintf('Simulation, Mittel der letzten %g ms', 1e3*P.window)
                    'Schlupf am Ende', 's', z(K.s_end), '–', '(n_s − n)/n_s'
                    'Luftspaltmoment am Ende', 'M', z(K.M_end), 'N·m', sprintf('Simulation, Mittel der letzten %g ms', 1e3*P.window)
                    'Leiterstrom am Ende (eff.)', 'I', z(K.I_eff_end), 'A', 'Strommessung 3~'
                    sprintf('Hochlaufzeit bis %g %% von n_N (%.0f 1/min)', 100*P.n_target_rel, P.n_target), ...
                        't_H', reached_text(K.startup), 's', 'erstes Überschreiten vor dem Laststoß'
                    'erwarteter Arbeitspunkt (ESB ∩ Last)', 'n_1', operating_text(K.expected.before), '1/min', ...
                        'stabiler, aus n = 0 erreichbarer Schnittpunkt'};
                if ~isempty(K.load_step)
                    L = K.load_step;
                    if L.step_sign >= 0                       % load increase: minimum and dip
                        extreme = {'minimale Drehzahl nach dem Laststoß', 'n_min', z(L.n_min), '1/min', ...
                                   sprintf('bei t = %.4g s', L.t_min)
                                   'Drehzahleinbruch', 'Δn', z(L.dn_dip), '1/min', 'n_vor − n_min'
                                   'Unterschwingen', 'Δn_u', z(L.undershoot), '1/min', 'n_neu − n_min'};
                    else                                      % load decrease: maximum and overshoot
                        extreme = {'maximale Drehzahl nach der Entlastung', 'n_max', z(L.n_max), '1/min', ...
                                   sprintf('bei t = %.4g s', L.t_max)
                                   'Drehzahlanstieg', 'Δn', z(-L.dn_static), '1/min', 'n_neu − n_vor'
                                   'Überschwingen', 'Δn_ü', z(L.overshoot), '1/min', 'n_max − n_neu'};
                    end
                    D = [D; {
                        'Drehzahl vor dem Laststoß', 'n_vor', z(L.n_before), '1/min', ...
                            sprintf('Mittel %g ms, endet %g ms vor t_stoß', 1e3*P.window, 1e3*P.step_margin)}; extreme; {
                        'neuer stationärer Arbeitspunkt', 'n_neu', z(L.n_new), '1/min', ...
                            sprintf('Simulation; erwartet (ESB) %s 1/min', operating_text(K.expected.after))
                        sprintf('Einschwingzeit (±%.2g 1/min)', L.band), 't_s', settle_text(L), 's', ...
                            'Band bis zum Ende des Auswertefensters gehalten'}];
                end
                D = [D; {
                    'Anzugsmoment', 'M_A', z(K.M_A), 'N·m', 'T-ESB stationär, s = 1'
                    'Kippmoment', 'M_K', z(K.M_K), 'N·m', 'T-ESB stationär'
                    'Kippschlupf', 's_K', z(K.s_K), '–', 'T-ESB stationär'
                    'Kippdrehzahl', 'n_K', z(K.n_K), '1/min', 'n_s·(1 − s_K)'
                    'Anzugsmoment / Bemessungsmoment', 'M_A/M_N', z(K.M_A/P.M_N), '–', ...
                        sprintf('M_N = %g N·m (Beispielmotor)', P.M_N)
                    'größtes Luftspaltmoment (dynamisch)', '|M|max', z(K.M_max_dyn), 'N·m', ...
                        'Simulation, enthält Einschaltpendelmomente'
                    'Rechenzeit', '', z(R.duration_s), 's', R.model}];
            else
                D = {
                    'Synchrondrehzahl (zweipolig)', 'n_s', z(K.ns), '1/min', '60·f1/p'
                    'Schlupf (Rotor steht)', 's', z(K.s), '–', 'Ideales Drehfeld'
                    'Amplitude der Luftspaltflussdichte', 'B̂', z(K.Bhat), 'T', 'p·|ψh|/(2·N1ξ1·l·r)'
                    'Scheitelwert Stabstrom', 'î_Stab', z(K.ihat_bar), 'A', 'Rotorstab-Formeln (SPEC 4.4)'
                    'Versatzwinkel', 'φ2', z(K.phi2_deg), '°', '∠ψh − ∠i2′ = 90° + φ_Z'
                    'Rotorimpedanzwinkel', 'φ_Z', z(K.phiZ_deg), '°', 'φ2 − 90°'
                    'mittleres Schleifenmoment', 'M̄_S', z(K.M_S_mean), 'N·m', 'î·l·B̂·r·sin φ2, über eine Feldumdrehung'
                    'Rechenzeit', '', z(R.duration_s), 's', R.model};
            end
            app.Table.Data = D;
        end
    end
end

%% ========================= local functions =========================
function t = reached_text(S)
if S.reached, t = sprintf('%.4g', S.t_target); else, t = 'nicht erreicht'; end
end

function t = value_text(x)
if isnan(x), t = 'nicht bestimmbar'; else, t = sprintf('%.4g', x); end
end

function t = operating_text(op)
if op.reachable, t = sprintf('%.5g', op.n); else, t = 'kein Arbeitspunkt (Motor steht)'; end
end

function t = settle_text(L)
if L.settled
    t = sprintf('%.4g', L.t_settle);
elseif ~L.final_valid
    t = 'nicht bestimmbar (Endfenster zu kurz)';
else
    t = 'nicht eingeschwungen';
end
end

function gl = grid_layout(parent, rows, cols)
gl = uigridlayout(parent, [rows numel(cols)], 'ColumnWidth', cols, ...
                  'RowHeight', repmat({22}, 1, rows), 'RowSpacing', 6, 'ColumnSpacing', 6, ...
                  'BackgroundColor', 'w');
end

function ax = symbol_axes(gl, rows)
ax = uiaxes(gl);
ax.Layout.Row = [rows(1) rows(end)];  ax.Layout.Column = 1;
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
axis(ax, 'off');
end

function s = onoff(tf)
if tf, s = 'on'; else, s = 'off'; end
end

function t = range_text(g)
% value range as German tooltip text
if g.min_open, u = sprintf('> %g', g.min); else, u = sprintf('≥ %g', g.min); end
if isinf(g.min), u = ''; end
o = '';
if ~isinf(g.max), o = sprintf('≤ %g', g.max); end
t = strjoin([{'Bereich'}, {u}, {o}], ' ');
t = regexprep(strtrim(t), '\s+', ' ');
if strcmp(t, 'Bereich'), t = 'Bereich: reelle Zahl'; end
if g.integer, t = [t ', ganzzahlig']; end
end

function v = empty_to_text(c)
if isempty(c), v = {'Keine Hinweise.'}; else, v = c(:); end
end

function c = line_colour(active)
if active, c = [0.15 0.15 0.15]; else, c = [0.72 0.72 0.72]; end
end

function prepare(ax)
cla(ax);  hold(ax, 'on');  axis(ax, 'equal', 'off');
xlim(ax, [-1.7 1.7]);  ylim(ax, [-1.5 1.5]);
end

function symbol_grid(ax, lab)
% three-phase source: circle with sine, conductors L1, L2, L3, N
prepare(ax);  c = line_colour(true);  ca = line_colour(lab);
w = linspace(0, 2*pi, 100);
plot(ax, 0.55*cos(w) - 0.6, 0.55*sin(w), '-', 'Color', c, 'LineWidth', 1.5);
x = linspace(-0.35, 0.35, 60);
plot(ax, x - 0.6, 0.18*sin(x/0.35*pi), '-', 'Color', c, 'LineWidth', 1.5);
y = [0.9 0.45 0 -0.45];  names = {'L1', 'L2', 'L3', 'N'};
for k = 1:4
    if k == 4, ck = ca; else, ck = c; end
    plot(ax, [-0.05 1.2], [y(k) y(k)], '-', 'Color', ck, 'LineWidth', 1.2);
    text(ax, 1.28, y(k), names{k}, 'FontSize', 9, 'Color', ck);
end
text(ax, -0.6, -0.85, '3~', 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', c);
hold(ax, 'off');
end

function symbol_motor(ax, lab)
% lab: motor M 3~ with shaft; slides: cross-section with field arrow (rotor at rest)
prepare(ax);  c = line_colour(true);
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
    a = linspace(pi/2 + 0.6, pi/2 - 0.9, 30);                % field clockwise (as on the slides)
    plot(ax, 1.2*cos(a), 1.2*sin(a), '-', 'Color', [0.1 0.65 0.3], 'LineWidth', 2);
    plot(ax, 1.2*cos(a(end)), 1.2*sin(a(end)), '>', 'MarkerSize', 6, ...
         'MarkerFaceColor', [0.1 0.65 0.3], 'Color', [0.1 0.65 0.3]);
    text(ax, 0, 0, 's = 1', 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', c);
end
hold(ax, 'off');
end

function symbol_load(ax, lab)
% shaft, inertia J_L, load M_L
prepare(ax);  c = line_colour(lab);
plot(ax, [-1.7 -0.55], [0 0], '-', 'Color', c, 'LineWidth', 4);
patch(ax, [-0.55 -0.25 -0.25 -0.55], [-0.75 -0.75 0.75 0.75], [0.9 0.9 0.9], 'EdgeColor', c, 'LineWidth', 1.5);
text(ax, -0.4, 1.0, 'J_L', 'HorizontalAlignment', 'center', 'Color', c);
plot(ax, [-0.25 0.35], [0 0], '-', 'Color', c, 'LineWidth', 4);
patch(ax, [0.35 1.4 1.4 0.35], [-0.5 -0.5 0.5 0.5], [1 1 1], 'EdgeColor', c, 'LineWidth', 1.5);
text(ax, 0.875, 0, 'M_L', 'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', c);
for x = linspace(0.35, 1.4, 6)                               % reference (foundation)
    plot(ax, [x x - 0.15], [-0.6 -0.8], '-', 'Color', c);
end
plot(ax, [0.35 1.4], [-0.6 -0.6], '-', 'Color', c, 'LineWidth', 1.2);
if ~lab
    text(ax, 0.4, -1.25, 'Rotor festgebremst', 'HorizontalAlignment', 'center', 'FontSize', 9, ...
         'Color', line_colour(true));
end
hold(ax, 'off');
end
