classdef QuellenMessgeraeteTest < matlab.unittest.TestCase
%QUELLENMESSGERAETETEST Netz 3~ und elektrische Messgeräte gegen die Wechselstromrechnung.
%   Prüfschaltung (pruefschaltung_rl): Netz 3~ -> Leistungsmesser -> Strommessung -> Amperemeter
%   -> RL-Last in Stern; Spannungsmessung 3~ und Voltmeter parallel.
%   Ausführen im Projektordner:  startup_asm; runtests('tests')

    properties (Constant)
        R = 10        % Lastwiderstand je Strang [Ohm]
        L = 0.02      % Lastinduktivität je Strang [H]
        U = 400       % Leiterspannung [V]
    end

    properties
        E             % Ergebnis der Standard-Prüfschaltung
    end

    methods (TestClassSetup)
        function vorbereiten(tc)
            if ~exist('asm_bausteine_lib', 'file'), build_library(); end
            tc.E = pruefschaltung_rl('R', tc.R, 'L', tc.L, 'U', tc.U);
        end
    end

    methods (Test)
        function effektivwerteUndLeistung(tc)
            Z = tc.R + 1j*2*pi*50*tc.L;
            I = tc.U/sqrt(3)/abs(Z);
            e = tc.E.ende;
            tc.verifyEqual(e.I_eff,   I, 'RelTol', 1e-3, 'Strommessung 3~: I_eff');
            tc.verifyEqual(e.I_eff_a, I, 'RelTol', 1e-3, 'Amperemeter: I_eff');
            tc.verifyEqual(e.U_eff,   tc.U, 'RelTol', 1e-3, 'Spannungsmessung 3~: U_eff');
            tc.verifyEqual(e.U_eff_ab, tc.U, 'RelTol', 1e-3, 'Voltmeter: U_ab');
            tc.verifyEqual(e.P, 3*I^2*real(Z), 'RelTol', 1e-3, 'Leistungsmesser: P');
            tc.verifyEqual(e.Q, 3*I^2*imag(Z), 'RelTol', 1e-3, 'Leistungsmesser: Q (induktiv > 0)');
            tc.verifyEqual(e.S, 3*I^2*abs(Z), 'RelTol', 1e-3, 'Leistungsmesser: S');
            tc.verifyEqual(e.cosphi, real(Z)/abs(Z), 'RelTol', 1e-3, 'Leistungsmesser: cos phi');
        end

        function augenblickswerte(tc)
            e = tc.E.ende;
            tc.verifyEqual(e.i, e.i_abc(1), 'AbsTol', 1e-9, 'Amperemeter und Strommessung Leiter a');
            tc.verifyEqual(sum(e.i_abc), 0, 'AbsTol', 1e-6, 'Summe der Leiterströme (Stern ohne N)');
            tc.verifyEqual(sum(e.u_str), 0, 'AbsTol', 1e-6, 'Summe der Strangspannungen');
            tc.verifyEqual(e.u, e.u_leiter(1), 'AbsTol', 1e-9, 'Voltmeter = u_ab');
            i1 = e.i1;  ia = e.i_abc;
            tc.verifyEqual(i1(1), 2/3*(ia(1) - ia(2)/2 - ia(3)/2), 'AbsTol', 1e-9, 'Raumzeiger i1 alpha');
            tc.verifyEqual(i1(2), (ia(2) - ia(3))/sqrt(3), 'AbsTol', 1e-9, 'Raumzeiger i1 beta');
        end

        function phasenfolge(tc)
            richtung = @(E) sign(mean(diff(unwrap(raumzeigerwinkel(E.u_str)))));
            tc.verifyEqual(richtung(tc.E), 1, 'L1-L2-L3: Spannungsraumzeiger dreht mathematisch positiv');
            E2 = pruefschaltung_rl('phasenfolge', 'L1-L3-L2 (Linksdrehfeld)', 't_end', 0.05);
            tc.verifyEqual(richtung(E2), -1, 'L1-L3-L2: Drehrichtung umgekehrt');
        end

        function nullphasenwinkelUndEinschalten(tc)
            Uh = sqrt(2)*tc.U/sqrt(3);
            E1 = pruefschaltung_rl('phi0', 90, 't_end', 0.01);
            tc.verifyEqual(E1.u_str(1, 2), Uh, 'RelTol', 1e-6, 'phi0 = 90°: u_a(0) = Scheitelwert');
            E2 = pruefschaltung_rl('t_ein', 0.05, 't_end', 0.1);
            t = E2.u_str(:, 1);  ua = E2.u_str(:, 2);
            tc.verifyLessThan(max(abs(ua(t < 0.048))), 1e-9, 'vor t_ein spannungslos (Anstieg geglättet)');
            tc.verifyGreaterThan(max(abs(ua(t > 0.06))), 0.99*Uh, 'nach t_ein volle Spannung');
        end

        function bezugDerStrangspannung(tc)
            % symmetrische Last: künstlicher Sternpunkt und Netzsternpunkt n liegen auf gleichem Potenzial
            E2 = pruefschaltung_rl('bezug', 'Anschluss n', 't_end', 0.05);
            E1 = pruefschaltung_rl('t_end', 0.05);
            tc.verifyEqual(E2.ende.u_str, E1.ende.u_str, 'AbsTol', 1e-6);
        end

        function innenimpedanz(tc)
            R_N = 1;  L_N = 2e-3;
            E2 = pruefschaltung_rl('R_N', R_N, 'L_N', L_N);
            Z = tc.R + R_N + 1j*2*pi*50*(tc.L + L_N);
            tc.verifyEqual(E2.ende.I_eff, tc.U/sqrt(3)/abs(Z), 'RelTol', 1e-3, 'Strom mit Netzimpedanz');
            tc.verifyLessThan(E2.ende.U_eff, tc.U, 'Spannungsfall an der Netzimpedanz');
        end
    end
end

function w = raumzeigerwinkel(u)
% Winkel des Raumzeigers aus [t ua ub uc]
x = 2/3*(u(:,2) - u(:,3)/2 - u(:,4)/2);
y = (u(:,3) - u(:,4))/sqrt(3);
w = atan2(y, x);
w = w(u(:,1) > 1e-3);
end
