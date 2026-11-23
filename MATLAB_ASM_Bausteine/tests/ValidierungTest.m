classdef ValidierungTest < matlab.unittest.TestCase
%VALIDIERUNGTEST Validierung des Motormodells "ASM Standard" (SPEC 4.6, V1 bis V6).
%   Ausführen im Projektordner:  startup_asm; runtests('tests')
%
%   V1  stationäre Kennlinienpunkte gegen das T-Ersatzschaltbild (ESB)        < 0,5 %
%   V2  Hochlauf + Laststoß gegen ee_lib Induction Machine Squirrel Cage      < 1 % (ns bzw. MK)
%   V3  Bemessungsbetrieb gegen Kloss und n_N                                  < 1 % von ns
%   V4  Rotorstab-Formeln: Σ M_k = M, Zwei-Stab-Schleife im Mittel 2/N2·M     < 0,1 % bzw. 1 %
%   V5  Leerlauf n -> ns, Kippmoment MK bei sK                                < 0,1 % bzw. 1 %
%   V6  Energiebilanz P_el = P_Cu1 + P_Cu2 + P_mech + dW_mag/dt               < 0,5 %
%   V7  Baustein "ASM Kloss" gegen direkte Integration der Bewegungsgleichung  < 0,1 % von ns
%   V8  Klemmbrett: Dreieck an U/√3 gleich Stern an U                          < 0,01 % von ns
%   Alle Prüfstände bestehen nur aus Bibliotheksbausteinen (asmbib.pruefstand), damit sind
%   Netz, Schwungmasse, Lasten, Laststoß, Messwelle und Drehzahlmesser mitgeprüft.
%   Laufzeit etwa 1 bis 2 Minuten.

    properties
        P        % Parametersatz
        HL_asm   % Hochlauf mit Laststoß, ASM Standard
        HL_ee    % dasselbe mit der ee_lib-Referenz
    end

    properties (Constant)
        t_stoss = 1
        dM_L    = 7.95       % 0,3·M_N
    end

    methods (TestClassSetup)
        function vorbereiten(tc)
            if ~exist('asm_bausteine_lib', 'file'), build_library(); end
            war = bdIsLoaded('asm_bausteine_lib');
            load_system('asm_bausteine_lib');
            if ~war, tc.addTeardown(@() close_system('asm_bausteine_lib', 0)); end
            tc.P = asm_standard();
            tc.HL_asm = asmbib.pruefstand('Motor', 'asm', 'dM_L', tc.dM_L, 't_stoss', tc.t_stoss, 't_end', 2);
            tc.HL_ee  = asmbib.pruefstand('Motor', 'ee',  'dM_L', tc.dM_L, 't_stoss', tc.t_stoss, 't_end', 2);
        end
    end

    methods (Test)
        function V1_stationaereKennlinieWieESB(tc)
            s = [0.02 0.05 0.1 0.2 0.4 0.7 1];
            ns = tc.P.ns;
            for k = 1:numel(s)
                % im Stillstand klingt der Gleichfluss langsam ab (τ ≈ (Lh + L2σ′)/R2′ ≈ 0,2 s)
                te = 1.5 + 1.5*(s(k) == 1);
                E = asmbib.pruefstand('n_fest', ns*(1 - s(k)), 'n0', ns*(1 - s(k)), 't_end', te, 'MaxStep', 2e-4);
                M_sim = mittel(E.mess.M, te - 0.2, te);
                M_esb = asmbib.esb_kennlinie(tc.P, s(k));
                tc.verifyEqual(M_sim, M_esb, 'RelTol', 5e-3, sprintf('V1: s = %.2f, M_sim = %.3f Nm, M_ESB = %.3f Nm', ...
                    s(k), M_sim, M_esb));
            end
        end

        function V2_hochlaufWieReferenz(tc)
            t  = linspace(0, 2, 8001)';
            nA = interp1(tc.HL_asm.n(:,1), tc.HL_asm.n(:,2), t);
            nE = interp1(tc.HL_ee.n(:,1),  tc.HL_ee.n(:,2),  t);
            % Wellenmoment an der Drehmomentmesswelle (bei beiden hinter J_M)
            MA = interp1(tc.HL_asm.M_W(:,1), tc.HL_asm.M_W(:,2), t);
            ME = interp1(tc.HL_ee.M_W(:,1), tc.HL_ee.M_W(:,2), t);
            MK = max(asmbib.esb_kennlinie(tc.P, linspace(1e-3, 1, 5000)));
            tc.verifyLessThan(max(abs(nA - nE))/tc.P.ns, 0.01, 'V2: Drehzahlabweichung > 1 % von ns');
            tc.verifyLessThan(max(abs(MA - ME))/MK, 0.01, 'V2: Momentabweichung > 1 % von MK');
        end

        function V3_bemessungsbetriebWieKloss(tc)
            E = asmbib.pruefstand('Last', 'konstant', 'M_L0', tc.P.M_N, 't_end', 1.5);
            n_sim = mittel(E.n, 1.3, 1.5);
            MK = 2.7*tc.P.M_N;  sK = 0.2;                                   % Kloss-Daten des Prototyps
            s_kloss = sK*(MK/tc.P.M_N - sqrt((MK/tc.P.M_N)^2 - 1));          % stabiler Ast
            n_kloss = tc.P.ns*(1 - s_kloss);
            tc.verifyLessThan(abs(n_sim - n_kloss)/tc.P.ns, 0.01, sprintf('V3: n_sim = %.1f, Kloss %.1f', n_sim, n_kloss));
            tc.verifyLessThan(abs(n_sim - tc.P.n_N)/tc.P.ns, 0.01, sprintf('V3: n_sim = %.1f, n_N = %.0f', n_sim, tc.P.n_N));
        end

        function V4_rotorstabSummeGleichMoment(tc)
            m = tc.HL_asm.mess;
            par = struct('p', tc.P.p, 'N2', tc.P.N2, 'l', tc.P.l, 'r', tc.P.r, ...
                         'N1xi1', tc.P.p*(tc.P.U_N/sqrt(3)*sqrt(2)/(2*pi*tc.P.f_N))/(2*tc.P.Bhat_N*tc.P.l*tc.P.r));
            % alle Signale auf das Zeitraster von M
            t  = m.M(:,1);
            ip = @(x) interp1(x(:,1), x(:,2:end), t);
            R  = asmbib.rotorstab(ip(m.psi_h), ip(m.i2b), ip(m.th_mech), par);
            MK = 2.7*tc.P.M_N;
            tc.verifyLessThan(max(abs(R.M_sum - m.M(:,2)))/MK, 1e-3, 'V4: Σ M_k weicht vom Luftspaltmoment ab');
            % Zwei-Stab-Schleife: Mittel über eine Rotorperiode vor dem Laststoß = 2/N2 · M
            s  = mittel(m.s, 0.8, 1);
            T2 = 1/(s*tc.P.f_N);
            tc.assertLessThan(T2, 0.7, 'Schlupf zu klein für die Mittelung');
            M_S = mittel([t R.M_S], 1 - T2, 1);
            M_m = mittel(m.M, 1 - T2, 1);
            tc.verifyEqual(M_S, 2/tc.P.N2*M_m, 'RelTol', 0.01, 'V4: Zwei-Stab-Mittelwert ≠ 2/N2·M');
            % Motorbetrieb: beide Stäbe im Mittel mit positivem Moment
            tc.verifyGreaterThan(mittel([t R.M_S2(:,1)], 1 - T2, 1), 0);
            tc.verifyGreaterThan(mittel([t R.M_S2(:,2)], 1 - T2, 1), 0);
        end

        function V5_leerlaufUndKippmoment(tc)
            E = asmbib.pruefstand('Last', 'keine', 't_end', 1.5);
            n_end = mittel(E.n, 1.3, 1.5);
            tc.verifyLessThan(abs(n_end - tc.P.ns)/tc.P.ns, 1e-3, sprintf('V5: Leerlauf n = %.2f', n_end));
            i2 = E.mess.i2b(E.mess.i2b(:,1) >= 1.3, 2:3);
            tc.verifyLessThan(max(hypot(i2(:,1), i2(:,2))), 0.5, 'V5: Rotorstrom im Leerlauf nicht ≈ 0');
            % Kippmoment des Modells bei sK (stationär, feste Drehzahl) = Kippmoment der ESB-Kennlinie
            sK = 0.2;
            E = asmbib.pruefstand('n_fest', tc.P.ns*(1 - sK), 'n0', tc.P.ns*(1 - sK), 't_end', 1.5, 'MaxStep', 2e-4);
            M_sK = mittel(E.mess.M, 1.3, 1.5);
            s_f  = linspace(1e-3, 1, 20000);
            [MK, iK] = max(asmbib.esb_kennlinie(tc.P, s_f));
            tc.verifyEqual(s_f(iK), sK, 'AbsTol', 5e-3, 'V5: Kippschlupf der ESB-Kennlinie ≠ sK');
            tc.verifyEqual(M_sK, MK, 'RelTol', 0.01, sprintf('V5: M(sK) = %.2f Nm, MK = %.2f Nm', M_sK, MK));
        end

        function V6_energiebilanz(tc)
            m = tc.HL_asm.mess;  P = tc.P;
            t = m.M(:,1);
            ip = @(x) interp1(x(:,1), x(:,2:end), t);
            u1 = ip(m.u1); i1 = ip(m.i1); i2 = ip(m.i2b); imu = ip(m.i_mu); Om = ip(m.Om);
            P_el  = 3/2*sum(u1.*i1, 2);                 % Stern ohne N: kein Nullsystem
            P_cu1 = 3/2*P.R1*sum(i1.^2, 2);
            P_cu2 = 3/2*P.R2b*sum(i2.^2, 2);
            P_me  = m.M(:,2).*Om;
            W_mag = 3/2*(P.L1s*sum(i1.^2, 2) + P.L2sb*sum(i2.^2, 2) + P.Lh*sum(imu.^2, 2))/2;
            E_el  = trapz(t, P_el);
            E_rest = trapz(t, P_cu1 + P_cu2 + P_me) + W_mag(end) - W_mag(1);
            tc.verifyEqual(E_rest, E_el, 'RelTol', 5e-3, sprintf('V6: E_el = %.1f J, Summe = %.1f J', E_el, E_rest));
        end

        function V8_dreieckWieStern(tc)
            % Klemmbrett: Dreieck an U/√3 ist für die Wicklung dasselbe wie Stern an U
            ES = asmbib.pruefstand('t_end', 0.8);
            ED = asmbib.pruefstand('t_end', 0.8, 'Schaltung', 'Dreieck', 'U', tc.P.U_N/sqrt(3));
            t = linspace(0, 0.8, 2001)';
            dn = max(abs(interp1(ES.n(:,1), ES.n(:,2), t) - interp1(ED.n(:,1), ED.n(:,2), t)));
            tc.verifyLessThan(dn/tc.P.ns, 1e-4, sprintf('V8: Stern/Dreieck weichen um %.3f 1/min ab', dn));
        end

        function V7_klossBausteinWieDGL(tc)
            % Baustein "ASM Kloss" am Prüfstand gegen direkte Integration J·dΩ/dt = M_Kloss − M_L
            P = tc.P;  ns = P.ns;  MK = 2.7*P.M_N;  sK = 0.2;
            E = asmbib.pruefstand('Motor', 'kloss', 'dM_L', tc.dM_L, 't_stoss', tc.t_stoss, 't_end', 2);
            kl = @(s) 2*MK*s*sK./(s.^2 + sK^2);
            ML = @(t, n) P.M_N*(n/P.n_N).*abs(n/P.n_N) + tc.dM_L*0.5*(1 + tanh((t - tc.t_stoss)/0.5e-3));
            J  = P.J_M + 0.01;
            [tK, wK] = ode45(@(t, w) (kl((ns - 60*w/(2*pi))/ns) - ML(t, 60*w/(2*pi)))/J, [0 2], 0, ...
                             odeset('RelTol', 1e-9, 'MaxStep', 1e-3));
            t = linspace(0, 2, 4001)';
            dn = max(abs(interp1(tK, 60*wK/(2*pi), t) - interp1(E.n(:,1), E.n(:,2), t)));
            tc.verifyLessThan(dn/ns, 1e-3, sprintf('V7: Kloss-Baustein weicht um %.3f 1/min ab', dn));
        end
    end
end

function m = mittel(x, t0, t1)
% zeitlicher Mittelwert der Spalte 2 von x = [t y] im Intervall [t0, t1]
tt = linspace(t0, t1, 4001);
m  = trapz(tt, interp1(x(:,1), x(:,2), tt))/(t1 - t0);
end
