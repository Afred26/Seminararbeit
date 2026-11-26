classdef DidacticsTest < matlab.unittest.TestCase
%DIDACTICSTEST Didactic blocks, conductor loop and slide figures (phase 4).
%   Slide states 18-30 (ideal rotating field + rotor bar probe), sum of the bar torques at the
%   motor, conductor loop against prototype/Kloss, coil fields, cross-section figures,
%   animation, torque-speed figure.
%   Run in the project folder:  startup_asm; runtests('tests')

    properties
        Folder
    end

    methods (TestClassSetup)
        function prepare(tc)
            if ~exist('asm_blocks_lib', 'file'), build_library(); end
            load_system('asm_blocks_lib');
            tc.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                {'Simulink:Engine:MdlFileShadowedByFile', 'Simulink:Engine:MdlFileShadowing'}));
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Folder = f.Folder;
        end
    end

    methods (Test)
        function slideStates(tc)
            % slides 18/21/24/27: no current at maximum B_perp, maximum (out of the plane) at
            % 90 deg, reversal at 270 deg, force always in field direction (phi2 = 90 deg, rotor at rest)
            [m, L] = model(tc, 0.04);
            geo = {'p', '1', 'N2', '2', 'N1xi1', '144', 'l', '0.15', 'r', '0.06'};
            add_block([L 'Didaktik/Ideales Drehfeld'], [m '/Feld'], geo{:}, 's', '1', 'phi2_mode', 'fest', 'phi2_fix', '90');
            add_block([L 'Didaktik/Rotorstab-Sonde'], [m '/Sonde'], geo{:}, 'k1', '1', 'k2', '2', 'bar1_angle', '-90');
            for k = 1:3, add_line(m, sprintf('Feld/%d', k), sprintf('Sonde/%d', k)); end
            log_to_ws(m, {'Sonde/2', 'i_k'; 'Sonde/3', 'F_k'; 'Sonde/5', 'M_S'; 'Feld/4', 'phi_el'});
            E = simulate(m);
            ih = max(abs(E.i_k(:,2)));
            tc.verifyEqual(value_at(E.i_k, 0.0), [0 0], 'AbsTol', 1e-6*ih, 'Folie 18: kein Strom');
            tc.verifyEqual(value_at(E.i_k, 0.005), [ih -ih], 'RelTol', 1e-3, 'Folie 21: Stab 1 aus der Ebene maximal');
            tc.verifyEqual(value_at(E.i_k, 0.015), [-ih ih], 'RelTol', 1e-3, 'Folie 27: Stromrichtung umgekehrt');
            tc.verifyGreaterThan(min(E.F_k(:,2:3), [], 'all'), -1e-6*ih, 'Kraft stets in Feldrichtung');
            Fm = trapz(E.M_S(:,1), E.M_S(:,2))/0.04;
            tc.verifyEqual(Fm, ih*0.15*0.8*0.06, 'RelTol', 1e-3, 'mittleres Schleifenmoment î·l·B̂·r·sin φ2');
        end

        function probeSumEqualsAirgapTorque(tc)
            % at the motor: sum of all bar torques = air-gap torque of the measurement bus (SPEC 4.4)
            E0 = asmtools.test_bench('t_end', 0.001, 'Keep', true);
            m = E0.model;  tc.addTeardown(@() close_system(m, 0));
            set_param(m, 'StopTime', '0.4');
            P = asm_standard();
            add_block('simulink/Signal Routing/Bus Selector', [m '/Sel'], 'OutputSignals', 'psi_h,i2b,th_mech,M');
            add_line(m, 'Motor/1', 'Sel/1');
            add_block('asm_blocks_lib/Didaktik/Rotorstab-Sonde', [m '/Sonde'], 'p', num2str(P.p), ...
                'N2', num2str(P.N2), 'l', num2str(P.l), 'r', num2str(P.r), ...
                'N1xi1', num2str(P.N1xi1, 16));
            for k = 1:3, add_line(m, sprintf('Sel/%d', k), sprintf('Sonde/%d', k)); end
            log_to_ws(m, {'Sonde/10', 'M_sum'; 'Sel/4', 'M'});
            E = simulate(m);
            t = E.M(:,1);
            d = max(abs(interp1(E.M_sum(:,1), E.M_sum(:,2), t) - E.M(:,2)));
            tc.verifyLessThan(d/P.MK, 1e-3, 'Σ M_k ≠ Luftspaltmoment');
        end

        function conductorLoopLikePrototype(tc)
            % prototype check 8: N_S loops deliver on average the breakdown torque MK at s = sK
            P = asm_standard();
            [m, L] = model(tc, 0.1);                   % T2 = 1/(0.2*50 Hz) = 0.1 s
            add_block('simulink/Sources/Constant', [m '/s'], 'Value', num2str(P.sK));
            add_block([L 'Referenz/Leiterschleife (Prototyp Teil A)'], [m '/Loop']);
            add_line(m, 's/1', 'Loop/1');
            log_to_ws(m, {'Loop/5', 'M_S'; 'Loop/8', 'i2hat'});
            E = simulate(m);
            MS = trapz(E.M_S(:,1), E.M_S(:,2))/0.1;
            tc.verifyEqual(P.N2/2*MS, P.MK, 'RelTol', 2e-3, 'N_S·M_S(sK) = MK (Prototyp)');
            tc.verifyEqual(E.i2hat(end, 2), P.sK*P.U20/sqrt(P.R2_S^2*2), 'RelTol', 2e-3, 'î2(sK)');
        end

        function coilFields(tc)
            % symmetrical currents: amplitude of the rotating field = 1.5 * amplitude of one coil,
            % field angle = current angle
            [m, L] = model(tc, 0.001);
            phi = 0.7;  I = 10;
            add_block('simulink/Sources/Constant', [m '/i'], 'Value', ...
                sprintf('%g*[cos(%g); cos(%g - 2*pi/3); cos(%g - 4*pi/3)]', I, phi, phi, phi));
            add_block([L 'Didaktik/Spulenfelder'], [m '/Coils'], 'Lh', '0.25', 'N1xi1', '144', 'p', '2', ...
                'l', '0.15', 'r', '0.06');
            add_line(m, 'i/1', 'Coils/1');
            log_to_ws(m, {'Coils/1', 'BUVW'; 'Coils/2', 'Bhat'; 'Coils/3', 'phi'});
            E = simulate(m);
            c = 2*0.25/(2*144*0.15*0.06);
            tc.verifyEqual(E.Bhat(end, 2), c*I, 'RelTol', 1e-9, 'B̂ = p·Lh·|i1|/(2·N1ξ1·l·r)');
            tc.verifyEqual(E.Bhat(end, 2), 1.5*(2/3)*c*I, 'RelTol', 1e-9, 'B̂_ges = 1,5·B̂_Spule');
            tc.verifyEqual(E.phi(end, 2), phi, 'AbsTol', 1e-9, 'Feldwinkel = Stromwinkel');
        end

        function crossSectionSeriesAndAnimation(tc)
            Q = asmtools.IdealRotatingField('p', 1, 's', 1, 'N2', 2, 'mode', 2, 'phi2_fix', 90);
            t = linspace(0, 0.04, 401)';
            D = struct('t', t, 'psi_h', zeros(401, 2), 'i2b', zeros(401, 2), 'th_mech', zeros(401, 1));
            for k = 1:401
                [ps, i2, th] = Q(t(k));  D.psi_h(k,:) = ps';  D.i2b(k,:) = i2';  D.th_mech(k) = th;
            end
            par = struct('p', 1, 'N2', 2, 'l', 0.15, 'r', 0.06, 'N1xi1', 144, 'k1', 1, 'k2', 2, 'bar1_angle', -pi/2);
            d = asmexport.cross_section_series(D, par, 'Folder', tc.Folder, 'Formats', "png");
            tc.verifyEqual(numel(d), 13, '13 Bilder für die Folien 18-30');
            tc.verifyTrue(all(cellfun(@(f) exist(f, 'file') == 2, d)));
            tc.verifyTrue(endsWith(d{1}, 'folie18.png') && endsWith(d{end}, 'folie30.png'));
            fig = asmtools.field_animation(D, par, 'Play', false);
            tc.addTeardown(@() close(fig));
            tc.verifyTrue(isgraphics(fig), 'Animation (erstes Bild) erzeugt');
        end

        function torqueSpeedFigure(tc)
            n = linspace(0, 1440, 200)';
            D = struct('t', linspace(0, 1, 200)', 'n', n, 'M', 2*71.55*0.2*(1 - n/1500)./((1 - n/1500).^2 + 0.04), ...
                       'M_L', 26.5*(n/1440).^2);
            fig = asmtools.torque_speed_plot(D, 'EC', true);
            tc.addTeardown(@() close(fig));
            tc.verifyEqual(numel(findobj(fig, 'Type', 'line')), 5, 'ESB, Kloss, Motor, Last, Arbeitspunkt');
            f2 = asmtools.coil_fields_plot(30);
            tc.addTeardown(@() close(f2));
            tc.verifyEqual(numel(findobj(f2, 'Type', 'line')), 4, 'B_U, B_V, B_W und Summe');
        end
    end

    methods (Access = private)
        function [m, L] = model(tc, t_end)
            L = 'asm_blocks_lib/';
            m = sprintf('asm_didactics_%d', randi(1e6));
            new_system(m);
            tc.addTeardown(@() close_system(m, 0));
            set_param(m, 'Solver', 'ode23t', 'StopTime', num2str(t_end), 'MaxStep', '1e-4', 'RelTol', '1e-6', ...
                'ReturnWorkspaceOutputs', 'on');
        end
    end
end

function log_to_ws(m, list)
for k = 1:size(list, 1)
    add_block('simulink/Sinks/To Workspace', [m '/TW_' list{k, 2}], 'VariableName', list{k, 2}, ...
        'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf');
    add_line(m, list{k, 1}, ['TW_' list{k, 2} '/1'], 'autorouting', 'on');
end
end

function E = simulate(m)
out = sim(m, 'TimeOut', 120);
for nm = out.who'
    ts = out.get(nm{1});
    if ~isa(ts, 'timeseries'), continue; end
    y = squeeze(ts.Data);
    if size(y, 1) ~= numel(ts.Time), y = y.'; end
    [t, iu] = unique(ts.Time(:), 'last');
    E.(nm{1}) = [t, y(iu, :)];
end
end

function y = value_at(x, t)
y = interp1(x(:,1), x(:,2:end), t);
end
