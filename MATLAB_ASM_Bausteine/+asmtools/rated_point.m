function R = rated_point(P)
%RATED_POINT Check of the rated point against the Kloss and EC characteristics.
%   R = asmtools.rated_point(P)      P = asm_standard() (default)
%
%   Computes the rated slip s_N = (ns - n_N)/ns and the Kloss torque at s_N and compares it
%   with M_N. If n_N were meant as an exact operating point (M(s_N) = M_N), one Kloss
%   parameter could be derived from (n_N, M_N) instead of being assumed:
%     a) keep MK, derive sK:  sK = s_N*(k + sqrt(k^2 - 1)),  k = MK/M_N   (stable branch)
%     b) keep sK, derive MK:  MK = M_N*(s_N^2 + sK^2)/(2*s_N*sK)
%   Both alternatives change the rest of the curve (starting torque M_A, loop parameters,
%   EC fit); the fields alt_* quantify this. The function changes no parameter.
%
%   Returns R with s_N, M_kloss_sN, M_N, dev_rel (M_kloss_sN/M_N - 1), M_N_from_PN,
%   s_at_MN, n_at_MN (Kloss, stable branch), M_ec_sN, n_at_MN_ec (T equivalent circuit),
%   sK_squared_equals_sN, alt_sK (struct sK, M_A, M_at_0p1), alt_MK (struct MK, k, M_A, M_at_0p1),
%   base (struct MK, sK, M_A, M_at_0p1).

if nargin < 1, P = asm_standard(); end
ns = 60*P.f_N/P.p;
kl = @(s, MK, sK) asmtools.kloss_torque(s, MK, sK);
R.s_N = (ns - P.n_N)/ns;
R.M_N = P.M_N;
R.M_N_from_PN = P.P_N/(2*pi*P.n_N/60);
R.M_kloss_sN = kl(R.s_N, P.MK, P.sK);
R.dev_rel = R.M_kloss_sN/P.M_N - 1;
R.sK_squared_equals_sN = abs(R.s_N - P.sK^2) < 1e-12;   % then M(s_N) = M(1)
k = P.MK/P.M_N;
R.s_at_MN = P.sK*(k - sqrt(k^2 - 1));
R.n_at_MN = ns*(1 - R.s_at_MN);
R.M_ec_sN = asmtools.equivalent_circuit(P, R.s_N);
R.n_at_MN_ec = ns*(1 - fzero(@(s) asmtools.equivalent_circuit(P, s) - P.M_N, [1e-4, P.sK]));

R.base   = struct('MK', P.MK, 'sK', P.sK, 'M_A', kl(1, P.MK, P.sK), 'M_at_0p1', kl(0.1, P.MK, P.sK));
sK_a = R.s_N*(k + sqrt(k^2 - 1));
R.alt_sK = struct('sK', sK_a, 'M_A', kl(1, P.MK, sK_a), 'M_at_0p1', kl(0.1, P.MK, sK_a));
MK_b = P.M_N*(R.s_N^2 + P.sK^2)/(2*R.s_N*P.sK);
R.alt_MK = struct('MK', MK_b, 'k', MK_b/P.M_N, 'M_A', kl(1, MK_b, P.sK), 'M_at_0p1', kl(0.1, MK_b, P.sK));
end
