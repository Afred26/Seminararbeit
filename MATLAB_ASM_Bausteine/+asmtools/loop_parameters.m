function L = loop_parameters(P)
%LOOP_PARAMETERS Equivalent values of one conductor loop (part A) derived from the Kloss data.
%   L = asmtools.loop_parameters(P)
%
%   P  struct with Bhat_N, l, r, f_N, p, N2, MK, sK (asm_standard)
%   L  struct with fields
%        U20    amplitude of the standstill voltage of one loop  [V]
%        N_S    number of equal loops in the cage, N2/2          [-]
%        R2_S   resistance of one loop                           [Ohm]
%        L2s_S  leakage inductance of one loop                   [H]
%
%   Equations (doku/SPEC.md 3.1): two bars one pole pitch apart form a loop,
%     U20  = 2*Bhat*l*w1*r/p
%     R2_S = N_S*l*Bhat*r*sK*U20/(2*MK),   L2s_S = R2_S/(sK*w1)
%   so that N_S loops deliver on average exactly the Kloss torque
%     N_S*M_S,mean(s) = 2*MK*s*sK/(s^2 + sK^2).
%   R2_S and L2s_S are equivalent values of ONE loop, neither bar values nor EC values.
%   Because they are derived from MK and sK, comparing part A with part B is a consistency
%   check, not an independent validation.

w1 = 2*pi*P.f_N;
L.U20   = 2*P.Bhat_N*P.l*w1*P.r/P.p;
L.N_S   = P.N2/2;
L.R2_S  = L.N_S*P.l*P.Bhat_N*P.r*P.sK*L.U20/(2*P.MK);
L.L2s_S = L.R2_S/(P.sK*w1);
end
