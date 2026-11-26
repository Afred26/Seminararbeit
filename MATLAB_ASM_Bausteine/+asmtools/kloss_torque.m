function M = kloss_torque(s, MK, sK)
%KLOSS_TORQUE Motor torque according to the Kloss formula.
%   M = asmtools.kloss_torque(s, MK, sK)
%
%   M = 2*MK*s*sK / (s^2 + sK^2)   (singularity-free form; s may be a vector)
%   Assumptions: R1 = 0, constant air-gap flux, single cage without current displacement.
%   Source: Densborn, lecture notes "DS-Asynchron-Motor", slides 47-50; Hagl, Elektrische
%   Antriebstechnik, Hanser 2013.

M = 2*MK*s.*sK./(s.^2 + sK^2);
end
