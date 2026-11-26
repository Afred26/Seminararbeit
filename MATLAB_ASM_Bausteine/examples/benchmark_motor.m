function V = benchmark_motor(opt)
%BENCHMARK_MOTOR Model benchmark of the block "ASM Standard" with key figures and slide figures.
%   V = benchmark_motor()                  computes V1 to V6, shows the table, exports figures
%   V = benchmark_motor('Export', false)   without figure export
%
%   Comparisons (doku/SPEC.md 4.6, results in doku/VALIDIERUNG.md). These are model-to-model
%   comparisons with the same example parameters (benchmark / consistency), not an experimental
%   validation against measurements:
%     V1  stationary operating points against the T equivalent circuit (EC)
%     V2  run-up + load step against ee_lib "Induction Machine Squirrel Cage" (same parameters,
%         same grid, inertia, load and initial state; window 0 ... 2 s)
%     V3  rated operation (M_L = M_N) against Kloss and n_N
%     V4  rotor bar formulas: sum M_k against M, two-bar loop against 2/N2*M
%     V5  no-load and breakdown torque
%     V6  energy balance
%   Figures (export/, German labels): validierung_hochlauf_n, validierung_hochlauf_M,
%   validierung_kennlinie, validierung_rotorstab. Run time about one minute.

arguments
    opt.Export (1,1) logical = true
end

load_system('asm_blocks_lib');
P  = asm_standard();
ns = P.ns;
kloss = @(s) asmtools.kloss_torque(s, P.MK, P.sK);
S = asmexport.style();

%% V2: run-up with load step (also used for V4 and V6)
HA = asmtools.test_bench('Motor', 'asm', 'dM_L', 0.3*P.M_N, 't_end', 2);
HE = asmtools.test_bench('Motor', 'ee',  'dM_L', 0.3*P.M_N, 't_end', 2);
HK = asmtools.test_bench('Motor', 'kloss', 'dM_L', 0.3*P.M_N, 't_end', 2);   % part B of the prototype
t  = linspace(0, 2, 8001)';
nA = interp1(HA.n(:,1), HA.n(:,2), t);       nE = interp1(HE.n(:,1), HE.n(:,2), t);
nK = interp1(HK.n(:,1), HK.n(:,2), t);
% shaft torque at the torque sensor (behind J_M for all three motors)
MA = interp1(HA.M_W(:,1), HA.M_W(:,2), t);   ME = interp1(HE.M_W(:,1), HE.M_W(:,2), t);
MKl = interp1(HK.M_W(:,1), HK.M_W(:,2), t);
V.V2 = struct('dn_max_rel_ns', max(abs(nA - nE))/ns, 'dM_max_rel_MK', max(abs(MA - ME))/P.MK, ...
              'n_end_asm', nA(end), 'n_end_ee', nE(end), 'M_max_asm', max(MA), 'M_max_ee', max(ME), ...
              'duration_asm_s', HA.duration_s, 'duration_ee_s', HE.duration_s);

%% V1: stationary operating points at fixed speed
s1 = [0.02 0.05 0.1 0.2 0.4 0.7 1];
M1 = zeros(size(s1));
for k = 1:numel(s1)
    te = 1.5 + 1.5*(s1(k) == 1);          % standstill: the DC flux decays slowly
    E = asmtools.test_bench('n_fixed', ns*(1 - s1(k)), 'n0', ns*(1 - s1(k)), 't_end', te, 'MaxStep', 2e-4);
    M1(k) = window_mean(E.meas.M, te - 0.2, te);
end
M1_ec = asmtools.equivalent_circuit(P, s1);
V.V1 = table(s1', M1', M1_ec', 100*(M1 - M1_ec)'./M1_ec', kloss(s1)', ...
             'VariableNames', {'s', 'M_sim_Nm', 'M_ESB_Nm', 'Abw_Prozent', 'M_Kloss_Nm'});

%% V3: rated operation
E3 = asmtools.test_bench('Load', 'constant', 'M_L0', P.M_N, 't_end', 1.5);
k = P.MK/P.M_N;
s_kl = P.sK*(k - sqrt(k^2 - 1));
V.V3 = struct('n_sim', window_mean(E3.n, 1.3, 1.5), 'n_kloss', ns*(1 - s_kl), 'n_N', P.n_N);

%% V4: rotor bar formulas
m   = HA.meas;
par = struct('p', P.p, 'N2', P.N2, 'l', P.l, 'r', P.r, 'N1xi1', P.N1xi1);
tm  = m.M(:,1);
ip  = @(x) interp1(x(:,1), x(:,2:end), tm);
R   = asmtools.rotor_bars(ip(m.psi_h), ip(m.i2b), ip(m.th_mech), par);
s_s = window_mean(m.s, 0.8, 1);  T2 = 1/(s_s*P.f_N);
V.V4 = struct('sum_error_max_rel_MK', max(abs(R.M_sum - m.M(:,2)))/P.MK, ...
              'M_S_mean', window_mean([tm R.M_S], 1 - T2, 1), 'M_mean_2_over_N2', 2/P.N2*window_mean(m.M, 1 - T2, 1), ...
              'T2_s', T2, 's', s_s, 'ihat_bar_A', window_mean([tm R.ihat], 1 - T2, 1), 'Bhat_T', window_mean([tm R.Bhat], 1 - T2, 1));

%% V5: no-load and breakdown torque
E5 = asmtools.test_bench('Load', 'none', 't_end', 1.5);
EK = asmtools.test_bench('n_fixed', ns*(1 - P.sK), 'n0', ns*(1 - P.sK), 't_end', 1.5, 'MaxStep', 2e-4);
s_f = linspace(1e-3, 1, 20000);
[MK_ec, iK] = max(asmtools.equivalent_circuit(P, s_f));
V.V5 = struct('n_no_load', window_mean(E5.n, 1.3, 1.5), 'ns', ns, 'M_sK_sim', window_mean(EK.meas.M, 1.3, 1.5), ...
              'MK_ESB', MK_ec, 'sK_ESB', s_f(iK));

%% V6: energy balance (run-up)
u1 = ip(m.u1); i1 = ip(m.i1); i2 = ip(m.i2b); imu = ip(m.i_mu); Om = ip(m.Om);
P_el = 3/2*sum(u1.*i1, 2);
P_v  = 3/2*P.R1*sum(i1.^2, 2) + 3/2*P.R2b*sum(i2.^2, 2);
W_m  = 3/4*(P.L1s*sum(i1.^2, 2) + P.L2sb*sum(i2.^2, 2) + P.Lh*sum(imu.^2, 2));
V.V6 = struct('E_el_J', trapz(tm, P_el), 'E_loss_J', trapz(tm, P_v), 'E_mech_J', trapz(tm, m.M(:,2).*Om), ...
              'dW_mag_J', W_m(end) - W_m(1));
V.V6.error_rel = (V.V6.E_loss_J + V.V6.E_mech_J + V.V6.dW_mag_J - V.V6.E_el_J)/V.V6.E_el_J;

%% output (German)
fprintf('\n=== Modellvergleich ASM Standard (Benchmark, keine Messung) ===\n');
disp(V.V1);
fprintf('V2  max |Δn|/ns = %.3f %%, max |ΔM|/MK = %.3f %%  (n_end %.2f / %.2f 1/min)\n', ...
        100*V.V2.dn_max_rel_ns, 100*V.V2.dM_max_rel_MK, V.V2.n_end_asm, V.V2.n_end_ee);
fprintf('V3  n_sim = %.1f, Kloss %.1f, n_N = %.0f 1/min\n', V.V3.n_sim, V.V3.n_kloss, V.V3.n_N);
fprintf('V4  max |ΣM_k − M|/MK = %.2e, Schleife %.4f Nm vs 2/N2·M = %.4f Nm, î_Stab = %.0f A, B̂ = %.3f T\n', ...
        V.V4.sum_error_max_rel_MK, V.V4.M_S_mean, V.V4.M_mean_2_over_N2, V.V4.ihat_bar_A, V.V4.Bhat_T);
fprintf('V5  Leerlauf n = %.3f 1/min (ns = %.0f), M(sK) = %.2f Nm, MK_ESB = %.2f Nm bei s = %.3f\n', ...
        V.V5.n_no_load, ns, V.V5.M_sK_sim, V.V5.MK_ESB, V.V5.sK_ESB);
fprintf('V6  E_el = %.1f J, Verluste %.1f J, mech. %.1f J, ΔW_mag %.2f J, Fehler %.3f %%\n', ...
        V.V6.E_el_J, V.V6.E_loss_J, V.V6.E_mech_J, V.V6.dW_mag_J, 100*V.V6.error_rel);

if ~opt.Export, return; end

%% slide figures (German labels)
f = figure('Visible', 'off');
plot(t, nK, ':', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Kloss (quasistationär, Teil B)'); hold on;
plot(t, nE, '-', 'Color', S.colour.L2, 'LineWidth', 3, 'DisplayName', 'Referenz ee\_lib Induction Machine');
plot(t, nA, '--', 'Color', S.colour.L1, 'DisplayName', 'ASM Standard (Raumzeigermodell)');
yline(ns, ':', 'n_s'); grid on; xlabel('t in s'); ylabel('n in 1/min');
legend('Location', 'southeast'); title('Hochlauf am starren Netz, Lüfterlast, Laststoß bei t = 1 s');
asmexport.slide_figure(f, 'validierung_hochlauf_n'); close(f);

f = figure('Visible', 'off');
plot(t, ME, '-', 'Color', S.colour.L2, 'LineWidth', 3, 'DisplayName', 'Referenz ee\_lib'); hold on;
plot(t, MA, '--', 'Color', S.colour.L1, 'DisplayName', 'ASM Standard');
plot(t, MKl, ':', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Kloss');
grid on; xlabel('t in s'); ylabel('M in N·m'); xlim([0 1.5]);
legend('Location', 'northeast'); title('Wellenmoment beim direkten Einschalten (Drehmomentmesswelle)');
asmexport.slide_figure(f, 'validierung_hochlauf_M'); close(f);

f = figure('Visible', 'off');
n_v = linspace(0, ns, 600); s_v = (ns - n_v)/ns;
plot(n_v, asmtools.equivalent_circuit(P, s_v), '-', 'Color', S.colour.L1, 'DisplayName', 'ESB stationär'); hold on;
plot(n_v, kloss(s_v), ':', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Kloss');
plot(ns*(1 - s1), M1, 'o', 'Color', S.colour.L2, 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Simulation (feste Drehzahl)');
plot(HA.n(:,2), HA.meas.M(:,2), '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.5, 'DisplayName', 'Hochlauf (dynamisch)');
grid on; xlabel('n in 1/min'); ylabel('M in N·m'); xlim([0 ns]);
legend('Location', 'northwest'); title('Drehmoment-Drehzahl-Kennlinie');
asmexport.slide_figure(f, 'validierung_kennlinie'); close(f);

f = figure('Visible', 'off');
iw = tm >= 1 - T2 & tm <= 1;
k2 = 1 + par.N2/(2*par.p);
tiledlayout(f, 2, 1);
nexttile; plot(tm(iw), R.i_slide(iw, 1), 'DisplayName', 'Strom Stab 1 (aus der Ebene positiv)'); hold on;
plot(tm(iw), R.i_slide(iw, k2), 'DisplayName', 'Strom Stab 2'); grid on; ylabel('i in A');
legend('Location', 'eastoutside'); title(sprintf('Leiterschleife im Bemessungsbetrieb, s = %.3f, T_2 = %.2f s', s_s, T2));
nexttile; plot(tm(iw), R.M_S(iw), 'DisplayName', 'M_S Schleife (Stab 1 + Stab 2)'); hold on;
plot(tm(iw), 2/P.N2*m.M(iw, 2), '--', 'DisplayName', '2/N_2 · M (Motor)'); grid on; xlabel('t in s'); ylabel('M in N·m');
legend('Location', 'eastoutside');
asmexport.slide_figure(f, 'validierung_rotorstab'); close(f);
fprintf('Folienbilder in %s\n', asmexport.output_folder());
end

function m = window_mean(x, t0, t1)
tt = linspace(t0, t1, 4001);
m  = trapz(tt, interp1(x(:,1), x(:,2), tt))/(t1 - t0);
end
