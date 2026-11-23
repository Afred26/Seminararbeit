classdef AppTest < matlab.unittest.TestCase
%APPTEST Rechenkern asmapp.simuliere und Bedienoberfläche ASMApp.
%   Ausführen im Projektordner:  startup_asm; runtests('tests')
%
%   Laboraufbau: Standardwerte gegen das unveränderte Beispielmodell bsp_hochlauf_laststoss
%   (Toleranz wie ValidierungTest V2: 1 % von ns bzw. MK) und gegen BeispieleTest (n_end);
%   Parameterübergabe (Benutzerdefiniert, konstante Last) gegen asmbib.pruefstand.
%   Folien: Standardwerte gegen bsp_folien16_30_rotorstab und die Folienzustände (DidaktikTest).
%   Dazu Eingabeprüfung und ein Rauchtest der Oberfläche.

    properties
        P           % Parametersatz asm_standard
        E_labor     % asmapp.simuliere('labor') mit Standardwerten
        E_folien    % asmapp.simuliere('folien') mit Standardwerten
    end

    methods (TestClassSetup)
        function vorbereiten(tc)
            if ~exist('asm_bausteine_lib', 'file'), build_library(); end
            war = bdIsLoaded('asm_bausteine_lib');
            load_system('asm_bausteine_lib');
            if ~war, tc.addTeardown(@() close_system('asm_bausteine_lib', 0)); end
            tc.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                {'Simulink:Engine:MdlFileShadowedByFile', 'Simulink:Engine:MdlFileShadowing'}));
            for m = {'bsp_hochlauf_laststoss', 'bsp_folien16_30_rotorstab'}
                if ~bdIsLoaded(m{1}), tc.addTeardown(@() close_system(m{1}, 0)); end
            end
            tc.P = asm_standard();
            tc.E_labor  = asmapp.simuliere('labor', tc.P);
            tc.E_folien = asmapp.simuliere('folien');
        end
    end

    methods (Test)
        function laborWieBeispielmodell(tc)
            % Standardwerte = unverändertes Beispielmodell (nur Messbus protokolliert)
            m = 'bsp_hochlauf_laststoss';
            in = Simulink.SimulationInput(m).setModelParameter('TimeOut', 300);
            ls = Simulink.Simulation.LoggingSpecification;
            addSignalsToLog(ls, Simulink.SimulationData.BlockPath([m '/Motor']), 1);
            in.LoggingSpecification = ls;
            out = sim(in);
            mess = out.logsout{1}.Values;
            E = tc.E_labor.zeit;
            ns = tc.P.ns;  MK = max(asmbib.esb_kennlinie(tc.P, linspace(1e-3, 1, 5000)));
            t = linspace(0, 2, 8001)';
            dn = max(abs(ip(mess.n, t) - interp1(E.t, E.n, t)));
            dM = max(abs(ip(mess.M, t) - interp1(E.t, E.M, t)));
            tc.verifyLessThan(dn/ns, 0.01, sprintf('Drehzahl weicht um %.3g 1/min ab', dn));
            tc.verifyLessThan(dM/MK, 0.01, sprintf('Moment weicht um %.3g N·m ab', dM));
            tc.verifyEqual(E.n(end), 1427.4, 'AbsTol', 1, 'Enddrehzahl wie BeispieleTest');
            tc.verifyEqual(get_param(m, 'Dirty'), 'off', 'Modell darf nicht verändert werden');
        end

        function laborKennzahlen(tc)
            K = tc.E_labor.kennzahlen;
            tc.verifyEqual(K.ns, 1500);
            tc.verifyEqual(K.s_end, (1500 - K.n_end)/1500, 'AbsTol', 1e-12);
            tc.verifyEqual(K.M_K, 2.7*tc.P.M_N, 'RelTol', 1e-3, 'Kippmoment = MK des Beispielmotors');
            tc.verifyEqual(K.s_K, 0.2, 'AbsTol', 1e-3, 'Kippschlupf sK');
            tc.verifyEqual(K.M_A, asmbib.esb_kennlinie(tc.P, 1), 'RelTol', 1e-12, 'Anzugsmoment (ESB)');
            % Endzustand: Motormoment = Lastmoment (Lüfter + Laststoß), stationär
            ML = tc.P.M_N*(K.n_end/1440)^2 + 0.3*tc.P.M_N;
            tc.verifyEqual(K.M_end, ML, 'RelTol', 0.01, 'Gleichgewicht M = M_L am Ende');
            % Strangströme aus dem Raumzeiger: Summe null (Stern ohne N)
            tc.verifyLessThan(max(abs(sum(tc.E_labor.zeit.i_abc, 2))), 1e-9);
        end

        function laborBenutzerdefiniertWiePruefstand(tc)
            % Parameterübergabe: geänderter Motor und Netz gegen den unabhängig gebauten Prüfstand
            P = asmapp.standardwerte('labor');
            P.parametersatz = 'Benutzerdefiniert';
            P.R2b = 1.8;  P.J_M = 0.02;  P.t_end = 1.5;  P.U_L = 380;  P.J_L = 0.015;
            E = asmapp.simuliere('labor', P);
            Pm = tc.P;  Pm.R2b = 1.8;  Pm.J_M = 0.02;
            R = asmbib.pruefstand('P', Pm, 'U', 380, 'J_L', 0.015, 'dM_L', 0.3*tc.P.M_N, 't_stoss', 1, 't_end', 1.5);
            t = linspace(0, 1.5, 6001)';
            dn = max(abs(interp1(R.n(:,1), R.n(:,2), t) - interp1(E.zeit.t, E.zeit.n, t)));
            tc.verifyLessThan(dn/tc.P.ns, 0.01, sprintf('Benutzerdefiniert: Abweichung %.3g 1/min', dn));
            tc.verifyLessThan(E.kennzahlen.n_end, tc.E_labor.kennzahlen.n_end - 10, 'größeres R2′ -> mehr Schlupf');
        end

        function laborKonstanteLast(tc)
            % Lasttyp konstant (Baustein Last konstant) gegen Prüfstand; V3: Bemessungspunkt n_N
            P = asmapp.standardwerte('labor');
            P.last_typ = 'konstant';  P.M_L = tc.P.M_N;  P.dM_L = 0;  P.t_end = 1.5;
            E = asmapp.simuliere('labor', P);
            R = asmbib.pruefstand('Last', 'konstant', 'M_L0', tc.P.M_N, 't_end', 1.5);
            t = linspace(0, 1.5, 6001)';
            dn = max(abs(interp1(R.n(:,1), R.n(:,2), t) - interp1(E.zeit.t, E.zeit.n, t)));
            tc.verifyLessThan(dn/tc.P.ns, 0.01, sprintf('konstante Last: Abweichung %.3g 1/min', dn));
            tc.verifyLessThan(abs(E.kennzahlen.n_end - tc.P.n_N)/tc.P.ns, 0.01, 'Bemessungspunkt n_N');
        end

        function folienWieBeispielmodell(tc)
            % Daten der Drehfeld-Anzeige und Ausgänge der Rotorstab-Sonde (B⊥, Stabströme, M_S)
            m = 'bsp_folien16_30_rotorstab';
            in = Simulink.SimulationInput(m).setModelParameter('TimeOut', 120);
            ls = Simulink.Simulation.LoggingSpecification;
            for port = [2 5 6]                                   % i_k, M_S, B_perp
                addSignalsToLog(ls, Simulink.SimulationData.BlockPath([m '/Sonde']), port);
            end
            in.LoggingSpecification = ls;
            out = sim(in);
            D = asmbib.drehfeld_daten(out.get('drehfeld_anzeige'));
            E = tc.E_folien;
            L = out.logsout;  sonde = struct();
            for k = 1:L.numElements, sonde.(sprintf('p%d', L{k}.PortIndex)) = L{k}.Values; end
            t = E.zeit.t;
            tc.verifyEqual(E.zeit.B_perp, ip(sonde.p6, t), 'AbsTol', 1e-6*0.8, 'B⊥ wie Rotorstab-Sonde');
            tc.verifyEqual(E.zeit.i_stab, ip(sonde.p2, t), 'AbsTol', 1e-6*max(abs(E.zeit.i_stab(:))), ...
                'Stabströme wie Rotorstab-Sonde');
            tc.verifyEqual(E.zeit.M_S, ip(sonde.p5, t), 'AbsTol', 1e-6*max(abs(E.zeit.M_S)), 'M_S wie Sonde');
            tc.verifyEqual(E.zeit.B_perp(1), 0.8, 'RelTol', 1e-6, 'Folie 18: B⊥ maximal');
            tc.verifyEqual(E.daten.t, D.t, 'AbsTol', 1e-12);
            tc.verifyEqual(E.daten.psi_h, D.psi_h, 'AbsTol', 1e-9*max(abs(D.psi_h(:))));
            tc.verifyEqual(E.daten.i2b, D.i2b, 'AbsTol', 1e-9*max(abs(D.i2b(:))));
            tc.verifyEqual(max(hypot(E.daten.psi_h(:,1), E.daten.psi_h(:,2))), 2*144*0.8*0.15*0.06, ...
                'RelTol', 1e-9, '|ψh| aus B̂ = 0,8 T (p = 1)');
        end

        function folienZustaende(tc)
            % Folien 18/21/27 (wie DidaktikTest): Strom null, maximal aus der Ebene, umgekehrt
            Z = tc.E_folien.zeit;
            w = @(t) interp1(Z.t, Z.i_stab, t);
            ih = tc.E_folien.kennzahlen.ihat_stab;
            tc.verifyEqual(w(0), [0 0], 'AbsTol', 1e-6*ih, 'Folie 18: kein Strom');
            tc.verifyEqual(w(0.005), [ih -ih], 'RelTol', 1e-3, 'Folie 21: Stab 1 aus der Ebene maximal');
            tc.verifyEqual(w(0.015), [-ih ih], 'RelTol', 1e-3, 'Folie 27: Stromrichtung umgekehrt');
            tc.verifyGreaterThan(min(Z.F, [], 'all'), -1e-6*ih, 'Kraft stets in Feldrichtung');
            tc.verifyEqual(tc.E_folien.kennzahlen.M_S_mittel, ih*0.15*0.8*0.06, 'RelTol', 1e-3, ...
                'mittleres Schleifenmoment î·l·B̂·r·sin φ2');
        end

        function folienPhi2AusRotorimpedanz(tc)
            % φ2 = 90° + φZ mit tan φZ = s·ω1·L2σ/R2 (Schleifenwerte des Prototyps, s = 1)
            P = asmapp.standardwerte('folien');  P.modus_phi2 = 'Rotorimpedanz';
            E = asmapp.simuliere('folien', P);
            phiZ = atand(2*pi*50*5.072e-6/3.187e-4);
            tc.verifyEqual(E.kennzahlen.phiZ_grad, phiZ, 'AbsTol', 0.05);
        end

        function eingabepruefung(tc)
            G = asmapp.grenzen();
            tc.verifyFalse(asmapp.pruefe('R1', -1, G));
            tc.verifyFalse(asmapp.pruefe('R1', 0, G), 'R1 > 0 (Regel pos)');
            tc.verifyFalse(asmapp.pruefe('p', 2.5, G), 'p ganzzahlig');
            tc.verifyFalse(asmapp.pruefe('p', 13, G), 'p ≤ 12');
            tc.verifyFalse(asmapp.pruefe('J_L', 0, G), 'Zusatzträgheit > 0');
            tc.verifyFalse(asmapp.pruefe('U_L', NaN, G));
            tc.verifyTrue(asmapp.pruefe('U_L', 0, G), 'U = 0 erlaubt (min=0)');
            tc.verifyTrue(asmapp.pruefe('dM_L', -5, G), 'Entlastung erlaubt');
            P = asmapp.standardwerte();  P.parametersatz = 'Benutzerdefiniert';  P.R1 = -1;
            tc.verifyError(@() asmapp.simuliere('labor', P), 'asmapp:wert');
            P = asmapp.standardwerte();  P.last_typ = 'quadratisch';
            tc.verifyError(@() asmapp.simuliere('labor', P), 'asmapp:wert');
        end

        function appRauchtest(tc)
            % Oberfläche öffnen, Eingaben prüfen, simulieren, exportieren, schließen
            app = ASMApp('Sichtbar', false);
            tc.addTeardown(@() delete(app));
            tc.verifyTrue(isvalid(app.Figur));
            tc.verifyError(@() app.setze('p', 2.5), 'asmapp:wert', 'p muss ganzzahlig sein');
            tc.verifyError(@() app.setze('J_L', 0), 'asmapp:wert', 'Zusatzträgheit > 0');
            app.setze('parametersatz', 'Benutzerdefiniert');
            app.setze('R2b', 1.5);
            P = app.parameter();
            tc.verifyEqual(P.R2b, 1.5);
            app.setze('parametersatz', 'Standard');
            tc.verifyEqual(app.parameter().R2b, asm_standard().R2b, 'Standard setzt die Felder zurück');
            app.waehle_betriebsart('folien');
            tc.verifyEqual(app.parameter().t_end, 0.04);
            app.simulieren();
            tc.assertNotEmpty(app.Ergebnis, 'Simulation in der Oberfläche fehlgeschlagen');
            tc.verifyEqual(app.Ergebnis.kennzahlen.ihat_stab, tc.E_folien.kennzahlen.ihat_stab, 'RelTol', 1e-9);
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            d = app.exportieren(f.Folder);
            tc.verifyEqual(numel(d), 2, 'PNG und SVG');
            tc.verifyTrue(all(cellfun(@isfile, d)));
            fig = app.Figur;
            app.schliessen();
            tc.verifyFalse(isvalid(fig), 'Fenster geschlossen');
        end

        function standardIgnoriertMotorwerte(tc)
            % Parametersatz "Standard": Motorwerte aus asm_standard.m, mit Warnung
            P = asmapp.standardwerte();  P.R2b = 2.5;  P.t_end = 0.05;
            E = tc.verifyWarning(@() asmapp.simuliere('labor', P), 'asmapp:standard');
            tc.verifyEqual(E.P.R2b, tc.P.R2b);
        end
    end
end

function y = ip(ts, t)
d = squeeze(ts.Data);
if size(d, 1) ~= numel(ts.Time), d = d.'; end
[tt, iu] = unique(ts.Time(:), 'last');
y = interp1(tt, d(iu, :), t);
end
