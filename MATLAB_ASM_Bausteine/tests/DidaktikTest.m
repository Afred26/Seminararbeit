classdef DidaktikTest < matlab.unittest.TestCase
%DIDAKTIKTEST Didaktik-Bausteine, Leiterschleife und Folienbilder (Phase 4).
%   Folienzustände 18-30 (Ideales Drehfeld + Rotorstab-Sonde), Summe der Stabmomente am Motor,
%   Leiterschleife gegen Prototyp/Kloss, Spulenfelder, Querschnittsbilder, Animation, Kennlinie.
%   Ausführen im Projektordner:  startup_asm; runtests('tests')

    properties
        Ordner
    end

    methods (TestClassSetup)
        function vorbereiten(tc)
            if ~exist('asm_bausteine_lib', 'file'), build_library(); end
            load_system('asm_bausteine_lib');
            tc.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                {'Simulink:Engine:MdlFileShadowedByFile', 'Simulink:Engine:MdlFileShadowing'}));
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Ordner = f.Folder;
        end
    end

    methods (Test)
        function folienzustaende(tc)
            % Folien 18/21/24/27: Strom null bei B⊥ maximal, maximal (aus der Ebene) bei 90°,
            % Umkehr bei 270°, Kraft stets in Feldrichtung (φ2 = 90°, Rotor steht)
            [m, L] = modell(tc, 0.04);
            geo = {'p', '1', 'N2', '2', 'N1xi1', '144', 'l', '0.15', 'r', '0.06'};
            add_block([L 'Didaktik/Ideales Drehfeld'], [m '/Feld'], geo{:}, 's', '1', 'modus_phi2', 'fest', 'phi2_fix', '90');
            add_block([L 'Didaktik/Rotorstab-Sonde'], [m '/Sonde'], geo{:}, 'k1', '1', 'k2', '2', 'lage1', '-90');
            for k = 1:3, add_line(m, sprintf('Feld/%d', k), sprintf('Sonde/%d', k)); end
            prot(m, {'Sonde/2', 'i_k'; 'Sonde/3', 'F_k'; 'Sonde/5', 'M_S'; 'Feld/4', 'phi_el'});
            E = simuliere(m);
            ih = max(abs(E.i_k(:,2)));
            tc.verifyEqual(wert(E.i_k, 0.0), [0 0], 'AbsTol', 1e-6*ih, 'Folie 18: kein Strom');
            tc.verifyEqual(wert(E.i_k, 0.005), [ih -ih], 'RelTol', 1e-3, 'Folie 21: Stab 1 aus der Ebene maximal');
            tc.verifyEqual(wert(E.i_k, 0.015), [-ih ih], 'RelTol', 1e-3, 'Folie 27: Stromrichtung umgekehrt');
            tc.verifyGreaterThan(min(E.F_k(:,2:3), [], 'all'), -1e-6*ih, 'Kraft stets in Feldrichtung');
            Fm = trapz(E.M_S(:,1), E.M_S(:,2))/0.04;
            tc.verifyEqual(Fm, ih*0.15*0.8*0.06, 'RelTol', 1e-3, 'mittleres Schleifenmoment î·l·B̂·r·sin φ2');
        end

        function sondeSummeGleichLuftspaltmoment(tc)
            % am Motor: Summe aller Stabmomente = Luftspaltmoment des Messbusses (SPEC 4.4)
            E0 = asmbib.pruefstand('t_end', 0.001, 'Behalten', true);
            m = E0.modell;  tc.addTeardown(@() close_system(m, 0));
            set_param(m, 'StopTime', '0.4');
            P = asm_standard();
            add_block('simulink/Signal Routing/Bus Selector', [m '/Sel'], 'OutputSignals', 'psi_h,i2b,th_mech,M');
            add_line(m, 'Motor/1', 'Sel/1');
            add_block('asm_bausteine_lib/Didaktik/Rotorstab-Sonde', [m '/Sonde'], 'p', num2str(P.p), ...
                'N2', num2str(P.N2), 'l', num2str(P.l), 'r', num2str(P.r), ...
                'N1xi1', num2str(P.p*(P.U_N/sqrt(3)*sqrt(2)/(2*pi*P.f_N))/(2*P.Bhat_N*P.l*P.r), 16));
            for k = 1:3, add_line(m, sprintf('Sel/%d', k), sprintf('Sonde/%d', k)); end
            prot(m, {'Sonde/10', 'M_sum'; 'Sel/4', 'M'});
            E = simuliere(m);
            t = E.M(:,1);
            d = max(abs(interp1(E.M_sum(:,1), E.M_sum(:,2), t) - E.M(:,2)));
            tc.verifyLessThan(d/(2.7*P.M_N), 1e-3, 'Σ M_k ≠ Luftspaltmoment');
        end

        function leiterschleifeWiePrototyp(tc)
            % Prototyp-Prüfung 8: N_S Schleifen liefern bei s = sK im Mittel das Kippmoment MK
            [m, L] = modell(tc, 0.1);                  % T2 = 1/(0,2·50 Hz) = 0,1 s
            add_block('simulink/Sources/Constant', [m '/s'], 'Value', '0.2');
            add_block([L 'Referenz/Leiterschleife (Prototyp Teil A)'], [m '/Schleife']);
            add_line(m, 's/1', 'Schleife/1');
            prot(m, {'Schleife/5', 'M_S'; 'Schleife/8', 'i2hat'});
            E = simuliere(m);
            MS = trapz(E.M_S(:,1), E.M_S(:,2))/0.1;
            tc.verifyEqual(14*MS, 2.7*26.5, 'RelTol', 2e-3, 'N_S·M_S(sK) = MK (Prototyp)');
            tc.verifyEqual(E.i2hat(end, 2), 0.2*2.262/sqrt(3.187e-4^2*2), 'RelTol', 2e-3, 'î2(sK)');
        end

        function spulenfelder(tc)
            % symmetrische Ströme: Drehfeldamplitude = 1,5 · Amplitude einer Spule, Lage = Stromwinkel
            [m, L] = modell(tc, 0.001);
            phi = 0.7;  I = 10;
            add_block('simulink/Sources/Constant', [m '/i'], 'Value', ...
                sprintf('%g*[cos(%g); cos(%g - 2*pi/3); cos(%g - 4*pi/3)]', I, phi, phi, phi));
            add_block([L 'Didaktik/Spulenfelder'], [m '/Spulen'], 'Lh', '0.25', 'N1xi1', '144', 'p', '2', ...
                'l', '0.15', 'r', '0.06');
            add_line(m, 'i/1', 'Spulen/1');
            prot(m, {'Spulen/1', 'BUVW'; 'Spulen/2', 'Bhat'; 'Spulen/3', 'phi'});
            E = simuliere(m);
            c = 2*0.25/(2*144*0.15*0.06);
            tc.verifyEqual(E.Bhat(end, 2), c*I, 'RelTol', 1e-9, 'B̂ = p·Lh·|i1|/(2·N1ξ1·l·r)');
            tc.verifyEqual(E.Bhat(end, 2), 1.5*(2/3)*c*I, 'RelTol', 1e-9, 'B̂_ges = 1,5·B̂_Spule');
            tc.verifyEqual(E.phi(end, 2), phi, 'AbsTol', 1e-9, 'Feldwinkel = Stromwinkel');
        end

        function querschnittSerieUndAnimation(tc)
            Q = asmbib.IdealesDrehfeld('p', 1, 's', 1, 'N2', 2, 'modus', 2, 'phi2_fix', 90);
            t = linspace(0, 0.04, 401)';
            D = struct('t', t, 'psi_h', zeros(401, 2), 'i2b', zeros(401, 2), 'th_mech', zeros(401, 1));
            for k = 1:401
                [ps, i2, th] = Q(t(k));  D.psi_h(k,:) = ps';  D.i2b(k,:) = i2';  D.th_mech(k) = th;
            end
            par = struct('p', 1, 'N2', 2, 'l', 0.15, 'r', 0.06, 'N1xi1', 144, 'k1', 1, 'k2', 2, 'lage1', -pi/2);
            d = asmexport.querschnitt_serie(D, par, 'Ordner', tc.Ordner, 'Formate', "png");
            tc.verifyEqual(numel(d), 13, '13 Bilder für die Folien 18-30');
            tc.verifyTrue(all(cellfun(@(f) exist(f, 'file') == 2, d)));
            tc.verifyTrue(endsWith(d{1}, 'folie18.png') && endsWith(d{end}, 'folie30.png'));
            fig = asmbib.drehfeld_animation(D, par, 'Abspielen', false);
            tc.addTeardown(@() close(fig));
            tc.verifyTrue(isgraphics(fig), 'Animation (erstes Bild) erzeugt');
        end

        function kennlinienbild(tc)
            n = linspace(0, 1440, 200)';
            D = struct('t', linspace(0, 1, 200)', 'n', n, 'M', 2*71.55*0.2*(1 - n/1500)./((1 - n/1500).^2 + 0.04), ...
                       'M_L', 26.5*(n/1440).^2);
            fig = asmbib.kennlinie_bild(D, 'ESB', true);
            tc.addTeardown(@() close(fig));
            tc.verifyEqual(numel(findobj(fig, 'Type', 'line')), 5, 'ESB, Kloss, Motor, Last, Arbeitspunkt');
            f2 = asmbib.spulenfelder_bild(30);
            tc.addTeardown(@() close(f2));
            tc.verifyEqual(numel(findobj(f2, 'Type', 'line')), 4, 'B_U, B_V, B_W und Summe');
        end
    end

    methods (Access = private)
        function [m, L] = modell(tc, t_end)
            L = 'asm_bausteine_lib/';
            m = sprintf('asm_didaktik_%d', randi(1e6));
            new_system(m);
            tc.addTeardown(@() close_system(m, 0));
            set_param(m, 'Solver', 'ode23t', 'StopTime', num2str(t_end), 'MaxStep', '1e-4', 'RelTol', '1e-6', ...
                'ReturnWorkspaceOutputs', 'on');
        end
    end
end

function prot(m, liste)
for k = 1:size(liste, 1)
    add_block('simulink/Sinks/To Workspace', [m '/TW_' liste{k, 2}], 'VariableName', liste{k, 2}, ...
        'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf');
    add_line(m, liste{k, 1}, ['TW_' liste{k, 2} '/1'], 'autorouting', 'on');
end
end

function E = simuliere(m)
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

function y = wert(x, t)
y = interp1(x(:,1), x(:,2:end), t);
end
