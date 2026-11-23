function [M, I1, I2] = esb_kennlinie(P, s, opt)
%ESB_KENNLINIE Stationäre Kennlinie des T-Ersatzschaltbilds (je Strang, statorbezogen).
%   [M, I1, I2] = asmbib.esb_kennlinie(P, s)
%   [M, I1, I2] = asmbib.esb_kennlinie(P, s, 'U', 400, 'f', 50, 'Schaltung', 'Stern')
%
%   P   Parametersatz (asm_standard): R1, L1s, Lh, R2b, L2sb, p, U_N, f_N
%   s   Schlupf (Vektor erlaubt)
%   M   Luftspaltmoment [N·m],  I1, I2 Effektivwerte Strangstrom Stator / Rotor (bezogen) [A]
%
%   Gleichungen (Hagl, Elektrische Antriebstechnik, Hanser 2013):
%     Z2 = R2′/s + j·X2σ′,  Zh = j·Xh,  Z = R1 + j·X1σ + Zh·Z2/(Zh + Z2)
%     I1 = U1,Str / Z,  I2 = I1·Zh/(Zh + Z2),  M = 3·p/ω1 · I2²·R2′/s
%   Für s = 0 ist M = 0 und I2 = 0.

arguments
    P struct
    s double
    opt.U (1,1) double = P.U_N
    opt.f (1,1) double = P.f_N
    opt.Schaltung (1,:) char {mustBeMember(opt.Schaltung, {'Stern', 'Dreieck'})} = 'Stern'
end

w1 = 2*pi*opt.f;
if strcmp(opt.Schaltung, 'Stern'), U1 = opt.U/sqrt(3); else, U1 = opt.U; end
Zh = 1j*w1*P.Lh;
Z2 = P.R2b./s + 1j*w1*P.L2sb;
Z  = P.R1 + 1j*w1*P.L1s + Zh.*Z2./(Zh + Z2);
I1c = U1./Z;
I2c = I1c.*Zh./(Zh + Z2);
M  = 3*P.p/w1*abs(I2c).^2.*P.R2b./s;
null = (s == 0);
M(null) = 0;
I1c(null) = U1./(P.R1 + 1j*w1*(P.L1s + P.Lh));
I2c(null) = 0;
I1 = abs(I1c);
I2 = abs(I2c);
end
