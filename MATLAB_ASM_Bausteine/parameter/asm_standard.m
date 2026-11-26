function P = asm_standard()
%ASM_STANDARD Standard parameter set of the block "ASM Standard" and of the Kloss/loop models.
%   P = asm_standard() returns a struct with all parameters in SI units (speeds in rpm).
%   P.info holds unit and provenance for every field.
%
%   ALL NUMERICAL VALUES ARE EXAMPLE VALUES (fictitious 4 kW standard motor, 4 poles) OR
%   DERIVED FROM THEM. THEY ARE NEITHER DATASHEET VALUES NOR MEASUREMENTS.
%
%   Provenance: equivalent circuit (EC) from init_asm_referenz.m of the prototype (part C).
%   The EC values are chosen such that the stationary breakdown torque MK = 2.7*M_N is
%   reached at sK = 0.2 (see doku/SPEC.md, sections 3.3 and 4.5). The Kloss model (part B)
%   and the conductor loop (part A) use the same MK and sK.
%
%   Rated point (finding, see doku/VALIDIERUNG.md): n_N and M_N are information only. With
%   s_N = 0.04 the Kloss curve gives M(s_N) = 27.52 N*m instead of M_N = 26.5 N*m (+3.8 %),
%   because MK and sK are the fitted quantities, not (n_N, M_N). asmtools.rated_point
%   quantifies this and lists which Kloss parameter could be derived instead.
%
%   Notation as in the lecture slides: index 1 = stator, 2 = rotor; suffix s = leakage (sigma),
%   suffix b = stator-referred (prime). Source of the equations:
%   Hagl, R.: Elektrische Antriebstechnik. Hanser, Muenchen 2013.

% Table: field | value | unit | provenance
T = {
    'U_N',    400,        'V',          'example value, line voltage (star)'
    'f_N',    50,         'Hz',         'example value'
    'p',      2,          '-',          'example value'
    'P_N',    4e3,        'W',          'example value (information only)'
    'n_N',    1440,       '1/min',      'example value (information only, not an exact operating point)'
    'M_N',    26.5,       'N*m',        'example value (information only, P_N/(2*pi*n_N/60) = 26.53 N*m)'
    'MK',     71.55,      'N*m',        'assumption: breakdown torque MK = 2.7*M_N (Kloss, prototype)'
    'sK',     0.2,        '-',          'assumption: breakdown slip sK (Kloss, prototype)'
    'R1',     0.5,        'Ohm',        'assumption (prototype part C, Rs)'
    'L1s',    9.902e-3,   'H',          'derived (MK fit, prototype part C, Lls)'
    'Lh',     0.25,       'H',          'assumption (prototype part C, Lm)'
    'R2b',    1.225,      'Ohm',        'derived (sK fit, prototype part C, Rr)'
    'L2sb',   9.902e-3,   'H',          'derived (= L1s, prototype part C, Llr)'
    'J_M',    0.012,      'kg*m^2',     'example value'
    'k_R',    0,          'N*m*s/rad',  'assumption (no friction, as prototype)'
    'l',      0.15,       'm',          'example value (effective bar length)'
    'r',      0.06,       'm',          'example value (radius of the bar centre)'
    'N2',     28,         '-',          'assumption (number of rotor bars)'
    'Bhat_N', 0.8,        'T',          'example value (air-gap flux density at the rated point)'
    };

for k = 1:size(T, 1)
    P.(T{k,1}) = T{k,2};
    P.info.(T{k,1}) = struct('unit', T{k,3}, 'source', T{k,4});
end

% Derived quantities
P.ns    = 60*P.f_N/P.p;                           % synchronous speed          [rpm]
P.w1    = 2*pi*P.f_N;                             % stator angular frequency   [rad/s]
psi_h_N = P.U_N/sqrt(3)*sqrt(2)/P.w1;             % approximation |psi_h| ~ U1,phase*sqrt(2)/w1 [Vs]
P.N1xi1 = P.p*psi_h_N/(2*P.Bhat_N*P.l*P.r);       % effective number of turns  [-]
L = asmtools.loop_parameters(P);                  % conductor loop of part A (SPEC 3.1)
P.U20   = L.U20;                                  % standstill voltage amplitude of one loop [V]
P.R2_S  = L.R2_S;                                 % resistance of one loop     [Ohm]
P.L2s_S = L.L2s_S;                                % leakage inductance of one loop [H]
P.info.ns    = struct('unit', '1/min', 'source', 'derived: ns = 60*f_N/p');
P.info.w1    = struct('unit', 'rad/s', 'source', 'derived: w1 = 2*pi*f_N');
P.info.N1xi1 = struct('unit', '-', ...
    'source', 'derived: N1xi1 = p*|psi_h|/(2*Bhat_N*l*r), |psi_h| ~ U1,phase*sqrt(2)/w1');
P.info.U20   = struct('unit', 'V', 'source', 'derived: U20 = 2*Bhat_N*l*w1*r/p');
P.info.R2_S  = struct('unit', 'Ohm', 'source', 'derived: R2 = N_S*l*Bhat_N*r*sK*U20/(2*MK), N_S = N2/2');
P.info.L2s_S = struct('unit', 'H', 'source', 'derived: L2sigma = R2/(sK*w1)');
end
