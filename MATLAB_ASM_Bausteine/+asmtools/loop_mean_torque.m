function [M_mean, i2hat, phiZ, phi2] = loop_mean_torque(s, P)
%LOOP_MEAN_TORQUE Analytic mean torque of the conductor loop (part A) at fixed slip.
%   [M_mean, i2hat, phiZ, phi2] = asmtools.loop_mean_torque(s, P)
%
%   s   slip (vector allowed)
%   P   struct with Bhat, l, r, f1, p, R2_S, L2s_S, phi2_mode ('impedance' | 'fixed'), phi2_fix [deg]
%
%   Derivation (doku/SPEC.md 3.1): with x_k = gamma_k - theta2, theta2 = s*w1*t,
%     B_k = Bhat*cos(x_k),  i_k = i2hat*sin(x_k + conv*phi2),  F_k = conv*i_k*l*B_k,  M_k = F_k*r
%   the product averages over one rotor period T2 = 1/(s*f1) (x_k runs through 2*pi) to
%     mean(sin(x + a)*cos(x)) = sin(a)/2,   conv*sin(conv*phi2) = sin(phi2)   (conv = +-1)
%   so both bars together deliver
%     M_mean = i2hat*l*Bhat*r*sin(phi2),
%     i2hat  = s*U20/sqrt(R2^2 + (s*w1*L2sigma)^2),  U20 = 2*Bhat*l*w1*r/p,
%     phi2   = 90 deg + phiZ (impedance) with tan(phiZ) = s*w1*L2sigma/R2  ->  sin(phi2) = cos(phiZ)
%   For s = 0: i2hat = 0 and M_mean = 0 (no induced voltage without relative motion).
%   With R2_S, L2s_S from asmtools.loop_parameters, N_S*M_mean equals the Kloss torque; this is
%   a consistency check of the derivation, not an independent validation.

w1 = 2*pi*P.f1;
U20 = 2*P.Bhat*P.l*w1*P.r/P.p;
X = s*w1*P.L2s_S;
i2hat = s.*U20./sqrt(P.R2_S^2 + X.^2);
phiZ = atan2(X, P.R2_S);
if strcmp(P.phi2_mode, 'impedance')
    phi2 = pi/2 + phiZ;
else
    phi2 = deg2rad(P.phi2_fix)*ones(size(s));
end
M_mean = i2hat*P.l*P.Bhat*P.r.*sin(phi2);
end
