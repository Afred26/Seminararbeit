classdef BenchmarkTest < matlab.unittest.TestCase
%BENCHMARKTEST Model benchmark of the motor model "ASM Standard" (SPEC 4.6, V1 to V8).
%   Run in the project folder:  startup_asm; runtests('tests')
%
%   These are model-to-model comparisons and consistency checks with the same example
%   parameters, NOT an experimental validation (no measurements of a real motor):
%   V1  stationary characteristic points against the T equivalent circuit (EC)     < 0.5 %
%   V2  run-up + load step against ee_lib Induction Machine Squirrel Cage           < 1 % (ns or MK)
%       (same grid, same inertia J_M + J_L, same load, both start currentless at n = 0,
%       compared over the whole window 0 ... 2 s)
%   V3  rated operation against Kloss and n_N                                        < 1 % of ns
%   V4  rotor bar formulas: sum M_k = M, two-bar loop on average 2/N2*M            < 0.1 % or 1 %
%   V5  no-load n -> ns, breakdown torque MK at sK                                  < 0.1 % or 1 %
%   V6  energy balance P_el = P_Cu1 + P_Cu2 + P_mech + dW_mag/dt                     < 0.5 %
%   V7  block "ASM Kloss" against direct integration of the equation of motion      < 0.1 % of ns
%   V8  terminal box: delta at U/sqrt(3) equals star at U                           < 0.01 % of ns
%   All test benches consist of library blocks only (asmtools.test_bench), so grid, inertia,
%   loads, load step, torque sensor and speed sensor are checked as well.
%   Run time about 1 to 2 minutes.

    properties
        P        % parameter set
        RU_asm   % run-up with load step, ASM Standard
        RU_ee    % the same with the ee_lib reference
    end

    properties (Constant)
        t_step = 1
        dM_L   = 7.95       % 0.3*M_N
    end

    methods (TestClassSetup)
        function prepare(tc)
            if ~exist('asm_blocks_lib', 'file'), build_library(); end
            was = bdIsLoaded('asm_blocks_lib');
            load_system('asm_blocks_lib');
            if ~was, tc.addTeardown(@() close_system('asm_blocks_lib', 0)); end
            tc.P = asm_standard();
            tc.RU_asm = asmtools.test_bench('Motor', 'asm', 'dM_L', tc.dM_L, 't_step', tc.t_step, 't_end', 2);
            tc.RU_ee  = asmtools.test_bench('Motor', 'ee',  'dM_L', tc.dM_L, 't_step', tc.t_step, 't_end', 2);
        end
    end

    methods (Test)
        function V1_stationaryCharacteristicLikeEC(tc)
            s = [0.02 0.05 0.1 0.2 0.4 0.7 1];
            ns = tc.P.ns;
            for k = 1:numel(s)
                % at standstill the DC flux decays slowly (tau ~ (Lh + L2sigma')/R2' ~ 0.2 s)
                te = 1.5 + 1.5*(s(k) == 1);
                E = asmtools.test_bench('n_fixed', ns*(1 - s(k)), 'n0', ns*(1 - s(k)), 't_end', te, 'MaxStep', 2e-4);
                M_sim = window_mean(E.meas.M, te - 0.2, te);
                M_ec = asmtools.equivalent_circuit(tc.P, s(k));
                tc.verifyEqual(M_sim, M_ec, 'RelTol', 5e-3, sprintf('V1: s = %.2f, M_sim = %.3f Nm, M_ESB = %.3f Nm', ...
                    s(k), M_sim, M_ec));
            end
        end

        function V2_runUpLikeReference(tc)
            t  = linspace(0, 2, 8001)';
            nA = interp1(tc.RU_asm.n(:,1), tc.RU_asm.n(:,2), t);
            nE = interp1(tc.RU_ee.n(:,1),  tc.RU_ee.n(:,2),  t);
            % shaft torque at the torque sensor (behind J_M for both)
            MA = interp1(tc.RU_asm.M_W(:,1), tc.RU_asm.M_W(:,2), t);
            ME = interp1(tc.RU_ee.M_W(:,1), tc.RU_ee.M_W(:,2), t);
            MK = max(asmtools.equivalent_circuit(tc.P, linspace(1e-3, 1, 5000)));
            tc.verifyLessThan(max(abs(nA - nE))/tc.P.ns, 0.01, 'V2: Drehzahlabweichung > 1 % von ns');
            tc.verifyLessThan(max(abs(MA - ME))/MK, 0.01, 'V2: Momentabweichung > 1 % von MK');
        end

        function V3_ratedOperationLikeKloss(tc)
            E = asmtools.test_bench('Load', 'constant', 'M_L0', tc.P.M_N, 't_end', 1.5);
            n_sim = window_mean(E.n, 1.3, 1.5);
            k = tc.P.MK/tc.P.M_N;
            s_kloss = tc.P.sK*(k - sqrt(k^2 - 1));                          % stable branch
            n_kloss = tc.P.ns*(1 - s_kloss);
            tc.verifyLessThan(abs(n_sim - n_kloss)/tc.P.ns, 0.01, sprintf('V3: n_sim = %.1f, Kloss %.1f', n_sim, n_kloss));
            tc.verifyLessThan(abs(n_sim - tc.P.n_N)/tc.P.ns, 0.01, sprintf('V3: n_sim = %.1f, n_N = %.0f', n_sim, tc.P.n_N));
        end

        function V4_rotorBarSumEqualsTorque(tc)
            m = tc.RU_asm.meas;
            par = struct('p', tc.P.p, 'N2', tc.P.N2, 'l', tc.P.l, 'r', tc.P.r, 'N1xi1', tc.P.N1xi1);
            % all signals on the time grid of M
            t  = m.M(:,1);
            ip = @(x) interp1(x(:,1), x(:,2:end), t);
            R  = asmtools.rotor_bars(ip(m.psi_h), ip(m.i2b), ip(m.th_mech), par);
            tc.verifyLessThan(max(abs(R.M_sum - m.M(:,2)))/tc.P.MK, 1e-3, 'V4: Σ M_k weicht vom Luftspaltmoment ab');
            % two-bar loop: mean over one rotor period before the load step = 2/N2 * M
            s  = window_mean(m.s, 0.8, 1);
            T2 = 1/(s*tc.P.f_N);
            tc.assertLessThan(T2, 0.7, 'Schlupf zu klein für die Mittelung');
            M_S = window_mean([t R.M_S], 1 - T2, 1);
            M_m = window_mean(m.M, 1 - T2, 1);
            tc.verifyEqual(M_S, 2/tc.P.N2*M_m, 'RelTol', 0.01, 'V4: Zwei-Stab-Mittelwert ≠ 2/N2·M');
            % motor operation: both bars with positive mean torque
            tc.verifyGreaterThan(window_mean([t R.M_S2(:,1)], 1 - T2, 1), 0);
            tc.verifyGreaterThan(window_mean([t R.M_S2(:,2)], 1 - T2, 1), 0);
        end

        function V5_noLoadAndBreakdownTorque(tc)
            E = asmtools.test_bench('Load', 'none', 't_end', 1.5);
            n_end = window_mean(E.n, 1.3, 1.5);
            tc.verifyLessThan(abs(n_end - tc.P.ns)/tc.P.ns, 1e-3, sprintf('V5: Leerlauf n = %.2f', n_end));
            i2 = E.meas.i2b(E.meas.i2b(:,1) >= 1.3, 2:3);
            tc.verifyLessThan(max(hypot(i2(:,1), i2(:,2))), 0.5, 'V5: Rotorstrom im Leerlauf nicht ≈ 0');
            % breakdown torque of the model at sK (stationary, fixed speed) = breakdown torque of the EC
            sK = tc.P.sK;
            E = asmtools.test_bench('n_fixed', tc.P.ns*(1 - sK), 'n0', tc.P.ns*(1 - sK), 't_end', 1.5, 'MaxStep', 2e-4);
            M_sK = window_mean(E.meas.M, 1.3, 1.5);
            s_f  = linspace(1e-3, 1, 20000);
            [MK, iK] = max(asmtools.equivalent_circuit(tc.P, s_f));
            tc.verifyEqual(s_f(iK), sK, 'AbsTol', 5e-3, 'V5: Kippschlupf der ESB-Kennlinie ≠ sK');
            tc.verifyEqual(M_sK, MK, 'RelTol', 0.01, sprintf('V5: M(sK) = %.2f Nm, MK = %.2f Nm', M_sK, MK));
        end

        function V6_energyBalance(tc)
            m = tc.RU_asm.meas;  P = tc.P;
            t = m.M(:,1);
            ip = @(x) interp1(x(:,1), x(:,2:end), t);
            u1 = ip(m.u1); i1 = ip(m.i1); i2 = ip(m.i2b); imu = ip(m.i_mu); Om = ip(m.Om);
            P_el  = 3/2*sum(u1.*i1, 2);                 % star without N: no zero sequence
            P_cu1 = 3/2*P.R1*sum(i1.^2, 2);
            P_cu2 = 3/2*P.R2b*sum(i2.^2, 2);
            P_me  = m.M(:,2).*Om;
            W_mag = 3/2*(P.L1s*sum(i1.^2, 2) + P.L2sb*sum(i2.^2, 2) + P.Lh*sum(imu.^2, 2))/2;
            E_el  = trapz(t, P_el);
            E_rest = trapz(t, P_cu1 + P_cu2 + P_me) + W_mag(end) - W_mag(1);
            tc.verifyEqual(E_rest, E_el, 'RelTol', 5e-3, sprintf('V6: E_el = %.1f J, Summe = %.1f J', E_el, E_rest));
        end

        function V8_deltaLikeStar(tc)
            % terminal box: delta at U/sqrt(3) is the same for the winding as star at U
            ES = asmtools.test_bench('t_end', 0.8);
            ED = asmtools.test_bench('t_end', 0.8, 'Connection', 'delta', 'U', tc.P.U_N/sqrt(3));
            t = linspace(0, 0.8, 2001)';
            dn = max(abs(interp1(ES.n(:,1), ES.n(:,2), t) - interp1(ED.n(:,1), ED.n(:,2), t)));
            tc.verifyLessThan(dn/tc.P.ns, 1e-4, sprintf('V8: Stern/Dreieck weichen um %.3f 1/min ab', dn));
        end

        function V7_klossBlockLikeODE(tc)
            % block "ASM Kloss" at the test bench against direct integration J*dOm/dt = M_Kloss - M_L
            P = tc.P;  ns = P.ns;
            E = asmtools.test_bench('Motor', 'kloss', 'dM_L', tc.dM_L, 't_step', tc.t_step, 't_end', 2);
            ML = @(t, n) P.M_N*(n/P.n_N).*abs(n/P.n_N) + tc.dM_L*0.5*(1 + tanh((t - tc.t_step)/0.5e-3));
            J  = P.J_M + 0.01;
            [tK, wK] = ode45(@(t, w) (asmtools.kloss_torque((ns - 60*w/(2*pi))/ns, P.MK, P.sK) ...
                                      - ML(t, 60*w/(2*pi)))/J, [0 2], 0, odeset('RelTol', 1e-9, 'MaxStep', 1e-3));
            t = linspace(0, 2, 4001)';
            dn = max(abs(interp1(tK, 60*wK/(2*pi), t) - interp1(E.n(:,1), E.n(:,2), t)));
            tc.verifyLessThan(dn/ns, 1e-3, sprintf('V7: Kloss-Baustein weicht um %.3f 1/min ab', dn));
        end
    end
end

function m = window_mean(x, t0, t1)
% time average of column 2 of x = [t y] over the interval [t0, t1]
tt = linspace(t0, t1, 4001);
m  = trapz(tt, interp1(x(:,1), x(:,2), tt))/(t1 - t0);
end
