function V = validierung_motor(opt)
%VALIDIERUNG_MOTOR Validierung des Bausteins "ASM Standard" mit Kennzahlen und Folienbildern.
%   V = validierung_motor()                 rechnet V1 bis V6, zeigt Tabelle, exportiert Bilder
%   V = validierung_motor('Export', false)  ohne Bildexport
%
%   Vergleiche (doku/SPEC.md 4.6, Ergebnisse in doku/VALIDIERUNG.md):
%     V1  stationäre Arbeitspunkte gegen das T-Ersatzschaltbild (ESB)
%     V2  Hochlauf + Laststoß gegen ee_lib "Induction Machine Squirrel Cage" (gleiche Parameter)
%     V3  Bemessungsbetrieb (M_L = M_N) gegen Kloss und n_N
%     V4  Rotorstab-Formeln: Σ M_k gegen M, Zwei-Stab-Schleife gegen 2/N2·M
%     V5  Leerlauf und Kippmoment
%     V6  Energiebilanz
%   Bilder (export/): validierung_hochlauf_n, validierung_hochlauf_M, validierung_kennlinie,
%   validierung_rotorstab. Laufzeit etwa eine Minute.

arguments
    opt.Export (1,1) logical = true
end

load_system('asm_bausteine_lib');
P  = asm_standard();
ns = P.ns;
MK_kloss = 2.7*P.M_N;  sK = 0.2;
kloss = @(s) 2*MK_kloss*s*sK./(s.^2 + sK^2);
S = asmexport.stil();

%% V2: Hochlauf mit Laststoß (wird auch für V4 und V6 verwendet)
HA = asmbib.pruefstand('Motor', 'asm', 'dM_L', 0.3*P.M_N, 't_end', 2);
HE = asmbib.pruefstand('Motor', 'ee',  'dM_L', 0.3*P.M_N, 't_end', 2);
HK = asmbib.pruefstand('Motor', 'kloss', 'dM_L', 0.3*P.M_N, 't_end', 2);   % Teil B des Prototyps
t  = linspace(0, 2, 8001)';
nA = interp1(HA.n(:,1), HA.n(:,2), t);       nE = interp1(HE.n(:,1), HE.n(:,2), t);
nK = interp1(HK.n(:,1), HK.n(:,2), t);
% Wellenmoment an der Drehmomentmesswelle (bei allen drei Motoren hinter J_M)
MA = interp1(HA.M_W(:,1), HA.M_W(:,2), t);   ME = interp1(HE.M_W(:,1), HE.M_W(:,2), t);
MKl = interp1(HK.M_W(:,1), HK.M_W(:,2), t);
V.V2 = struct('dn_max_rel_ns', max(abs(nA - nE))/ns, 'dM_max_rel_MK', max(abs(MA - ME))/MK_kloss, ...
              'n_end_asm', nA(end), 'n_end_ee', nE(end), 'M_max_asm', max(MA), 'M_max_ee', max(ME), ...
              'dauer_asm_s', HA.dauer_s, 'dauer_ee_s', HE.dauer_s);

%% V1: stationäre Arbeitspunkte bei fester Drehzahl
s1 = [0.02 0.05 0.1 0.2 0.4 0.7 1];
M1 = zeros(size(s1));
for k = 1:numel(s1)
    te = 1.5 + 1.5*(s1(k) == 1);          % Stillstand: Gleichfluss klingt langsam ab
    E = asmbib.pruefstand('n_fest', ns*(1 - s1(k)), 'n0', ns*(1 - s1(k)), 't_end', te, 'MaxStep', 2e-4);
    M1(k) = mittel(E.mess.M, te - 0.2, te);
end
M1_esb = asmbib.esb_kennlinie(P, s1);
V.V1 = table(s1', M1', M1_esb', 100*(M1 - M1_esb)'./M1_esb', kloss(s1)', ...
             'VariableNames', {'s', 'M_sim_Nm', 'M_ESB_Nm', 'Abw_Prozent', 'M_Kloss_Nm'});

%% V3: Bemessungsbetrieb
E3 = asmbib.pruefstand('Last', 'konstant', 'M_L0', P.M_N, 't_end', 1.5);
s_kl = sK*(MK_kloss/P.M_N - sqrt((MK_kloss/P.M_N)^2 - 1));
V.V3 = struct('n_sim', mittel(E3.n, 1.3, 1.5), 'n_kloss', ns*(1 - s_kl), 'n_N', P.n_N);

%% V4: Rotorstab-Formeln
m   = HA.mess;
par = struct('p', P.p, 'N2', P.N2, 'l', P.l, 'r', P.r, ...
             'N1xi1', P.p*(P.U_N/sqrt(3)*sqrt(2)/(2*pi*P.f_N))/(2*P.Bhat_N*P.l*P.r));
tm  = m.M(:,1);
ip  = @(x) interp1(x(:,1), x(:,2:end), tm);
R   = asmbib.rotorstab(ip(m.psi_h), ip(m.i2b), ip(m.th_mech), par);
s_s = mittel(m.s, 0.8, 1);  T2 = 1/(s_s*P.f_N);
V.V4 = struct('sum_fehler_max_rel_MK', max(abs(R.M_sum - m.M(:,2)))/MK_kloss, ...
              'M_S_mittel', mittel([tm R.M_S], 1 - T2, 1), 'M_mittel_2_durch_N2', 2/P.N2*mittel(m.M, 1 - T2, 1), ...
              'T2_s', T2, 's', s_s, 'ihat_Stab_A', mittel([tm R.ihat], 1 - T2, 1), 'Bhat_T', mittel([tm R.Bhat], 1 - T2, 1));

%% V5: Leerlauf und Kippmoment
E5 = asmbib.pruefstand('Last', 'keine', 't_end', 1.5);
EK = asmbib.pruefstand('n_fest', ns*(1 - sK), 'n0', ns*(1 - sK), 't_end', 1.5, 'MaxStep', 2e-4);
s_f = linspace(1e-3, 1, 20000);
[MK_esb, iK] = max(asmbib.esb_kennlinie(P, s_f));
V.V5 = struct('n_leerlauf', mittel(E5.n, 1.3, 1.5), 'ns', ns, 'M_sK_sim', mittel(EK.mess.M, 1.3, 1.5), ...
              'MK_ESB', MK_esb, 'sK_ESB', s_f(iK));

%% V6: Energiebilanz (Hochlauf)
u1 = ip(m.u1); i1 = ip(m.i1); i2 = ip(m.i2b); imu = ip(m.i_mu); Om = ip(m.Om);
P_el = 3/2*sum(u1.*i1, 2);
P_v  = 3/2*P.R1*sum(i1.^2, 2) + 3/2*P.R2b*sum(i2.^2, 2);
W_m  = 3/4*(P.L1s*sum(i1.^2, 2) + P.L2sb*sum(i2.^2, 2) + P.Lh*sum(imu.^2, 2));
V.V6 = struct('E_el_J', trapz(tm, P_el), 'E_Verlust_J', trapz(tm, P_v), 'E_mech_J', trapz(tm, m.M(:,2).*Om), ...
              'dW_mag_J', W_m(end) - W_m(1));
V.V6.Fehler_rel = (V.V6.E_Verlust_J + V.V6.E_mech_J + V.V6.dW_mag_J - V.V6.E_el_J)/V.V6.E_el_J;

%% Ausgabe
fprintf('\n=== Validierung ASM Standard ===\n');
disp(V.V1);
fprintf('V2  max |Δn|/ns = %.3f %%, max |ΔM|/MK = %.3f %%  (n_end %.2f / %.2f 1/min)\n', ...
        100*V.V2.dn_max_rel_ns, 100*V.V2.dM_max_rel_MK, V.V2.n_end_asm, V.V2.n_end_ee);
fprintf('V3  n_sim = %.1f, Kloss %.1f, n_N = %.0f 1/min\n', V.V3.n_sim, V.V3.n_kloss, V.V3.n_N);
fprintf('V4  max |ΣM_k − M|/MK = %.2e, Schleife %.4f Nm vs 2/N2·M = %.4f Nm, î_Stab = %.0f A, B̂ = %.3f T\n', ...
        V.V4.sum_fehler_max_rel_MK, V.V4.M_S_mittel, V.V4.M_mittel_2_durch_N2, V.V4.ihat_Stab_A, V.V4.Bhat_T);
fprintf('V5  Leerlauf n = %.3f 1/min (ns = %.0f), M(sK) = %.2f Nm, MK_ESB = %.2f Nm bei s = %.3f\n', ...
        V.V5.n_leerlauf, ns, V.V5.M_sK_sim, V.V5.MK_ESB, V.V5.sK_ESB);
fprintf('V6  E_el = %.1f J, Verluste %.1f J, mech. %.1f J, ΔW_mag %.2f J, Fehler %.3f %%\n', ...
        V.V6.E_el_J, V.V6.E_Verlust_J, V.V6.E_mech_J, V.V6.dW_mag_J, 100*V.V6.Fehler_rel);

if ~opt.Export, return; end

%% Folienbilder
f = figure('Visible', 'off');
plot(t, nK, ':', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Kloss (quasistationär, Teil B)'); hold on;
plot(t, nE, '-', 'Color', S.farbe.L2, 'LineWidth', 3, 'DisplayName', 'Referenz ee\_lib Induction Machine');
plot(t, nA, '--', 'Color', S.farbe.L1, 'DisplayName', 'ASM Standard (Raumzeigermodell)');
yline(ns, ':', 'n_s'); grid on; xlabel('t in s'); ylabel('n in 1/min');
legend('Location', 'southeast'); title('Hochlauf am starren Netz, Lüfterlast, Laststoß bei t = 1 s');
asmexport.folienbild(f, 'validierung_hochlauf_n'); close(f);

f = figure('Visible', 'off');
plot(t, ME, '-', 'Color', S.farbe.L2, 'LineWidth', 3, 'DisplayName', 'Referenz ee\_lib'); hold on;
plot(t, MA, '--', 'Color', S.farbe.L1, 'DisplayName', 'ASM Standard');
plot(t, MKl, ':', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Kloss');
grid on; xlabel('t in s'); ylabel('M in N·m'); xlim([0 1.5]);
legend('Location', 'northeast'); title('Wellenmoment beim direkten Einschalten (Drehmomentmesswelle)');
asmexport.folienbild(f, 'validierung_hochlauf_M'); close(f);

f = figure('Visible', 'off');
n_v = linspace(0, ns, 600); s_v = (ns - n_v)/ns;
plot(n_v, asmbib.esb_kennlinie(P, s_v), '-', 'Color', S.farbe.L1, 'DisplayName', 'ESB stationär'); hold on;
plot(n_v, kloss(s_v), ':', 'Color', [0.4 0.4 0.4], 'DisplayName', 'Kloss');
plot(ns*(1 - s1), M1, 'o', 'Color', S.farbe.L2, 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Simulation (feste Drehzahl)');
plot(HA.n(:,2), HA.mess.M(:,2), '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.5, 'DisplayName', 'Hochlauf (dynamisch)');
grid on; xlabel('n in 1/min'); ylabel('M in N·m'); xlim([0 ns]);
legend('Location', 'northwest'); title('Drehmoment-Drehzahl-Kennlinie');
asmexport.folienbild(f, 'validierung_kennlinie'); close(f);

f = figure('Visible', 'off');
iw = tm >= 1 - T2 & tm <= 1;
tiledlayout(f, 2, 1);
nexttile; plot(tm(iw), R.i_folie(iw, par_k(par, 1)), 'DisplayName', 'Strom Stab 1 (aus der Ebene positiv)'); hold on;
plot(tm(iw), R.i_folie(iw, par_k(par, 2)), 'DisplayName', 'Strom Stab 2'); grid on; ylabel('i in A');
legend('Location', 'eastoutside'); title(sprintf('Leiterschleife im Bemessungsbetrieb, s = %.3f, T_2 = %.2f s', s_s, T2));
nexttile; plot(tm(iw), R.M_S(iw), 'DisplayName', 'M_S Schleife (Stab 1 + Stab 2)'); hold on;
plot(tm(iw), 2/P.N2*m.M(iw, 2), '--', 'DisplayName', '2/N_2 · M (Motor)'); grid on; xlabel('t in s'); ylabel('M in N·m');
legend('Location', 'eastoutside');
asmexport.folienbild(f, 'validierung_rotorstab'); close(f);
fprintf('Folienbilder in %s\n', asmexport.zielordner());
end

function k = par_k(par, j)
if j == 1, k = 1; else, k = 1 + par.N2/(2*par.p); end
end

function m = mittel(x, t0, t1)
tt = linspace(t0, t1, 4001);
m  = trapz(tt, interp1(x(:,1), x(:,2), tt))/(t1 - t0);
end
