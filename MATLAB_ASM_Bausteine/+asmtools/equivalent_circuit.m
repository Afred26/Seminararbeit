function [M, I1, I2] = equivalent_circuit(P, s, opt)
%EQUIVALENT_CIRCUIT Stationary characteristic of the T equivalent circuit (per phase, stator-referred).
%   [M, I1, I2] = asmtools.equivalent_circuit(P, s)
%   [M, I1, I2] = asmtools.equivalent_circuit(P, s, 'U', 400, 'f', 50, 'Connection', 'star')
%
%   P   parameter set (asm_standard): R1, L1s, Lh, R2b, L2sb, p, U_N, f_N
%   s   slip (vector allowed)
%   M   air-gap torque [N*m],  I1, I2 RMS phase current stator / rotor (referred) [A]
%
%   Equations (Hagl, Elektrische Antriebstechnik, Hanser 2013):
%     Z2 = R2'/s + j*X2sigma',  Zh = j*Xh,  Z = R1 + j*X1sigma + Zh*Z2/(Zh + Z2)
%     I1 = U1,phase / Z,  I2 = I1*Zh/(Zh + Z2),  M = 3*p/w1 * I2^2*R2'/s
%   For s = 0, M = 0 and I2 = 0.

arguments
    P struct
    s double
    opt.U (1,1) double = P.U_N
    opt.f (1,1) double = P.f_N
    opt.Connection (1,:) char {mustBeMember(opt.Connection, {'star', 'delta'})} = 'star'
end

w1 = 2*pi*opt.f;
if strcmp(opt.Connection, 'star'), U1 = opt.U/sqrt(3); else, U1 = opt.U; end
Zh = 1j*w1*P.Lh;
Z2 = P.R2b./s + 1j*w1*P.L2sb;
Z  = P.R1 + 1j*w1*P.L1s + Zh.*Z2./(Zh + Z2);
I1c = U1./Z;
I2c = I1c.*Zh./(Zh + Z2);
M  = 3*P.p/w1*abs(I2c).^2.*P.R2b./s;
zero_slip = (s == 0);
M(zero_slip) = 0;
I1c(zero_slip) = U1./(P.R1 + 1j*w1*(P.L1s + P.Lh));
I2c(zero_slip) = 0;
I1 = abs(I1c);
I2 = abs(I2c);
end
