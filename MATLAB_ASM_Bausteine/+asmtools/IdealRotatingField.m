classdef IdealRotatingField < matlab.System
%IDEALROTATINGFIELD Kinematic source: ideal rotating field and rotor with fixed slip (part A).
%   Computational kernel of the block "Ideales Drehfeld" (MATLAB System, interpreted). Input: time t.
%   Delivers the same signals as the measurement bus of the motor (psi_h, i2', th), so that the
%   rotor bar probe and the field display can be operated without a motor (slides 16-30: s = 1,
%   phi2 = 90 deg).
%
%   Equations (prototype part A; doku/SPEC.md 3.1 and 4.4):
%     phi_el = w1*t,  th = (1 - s)*w1*t/p,  theta2 = phi_el - p*th = s*w1*t
%     |psi_h| = 2*N1xi1*Bhat*l*r/p                    (gives exactly the amplitude Bhat)
%     U20 = 2*Bhat*l*w1*r/p,  i2hat = s*U20/sqrt(R2^2 + (s*w1*L2sigma)^2),  phiZ = atan(s*w1*L2sigma/R2)
%     phi2 = 90 deg + phiZ (mode 1) or phi2 = phi2,fix (mode 2)
%     |i2'| = i2hat*N2/(6*N1xi1),  angle(i2') = phi_el - phi2   (gives the bar current i2hat in the probe)

    properties (Nontunable)
        Bhat     = 0.8       % amplitude of the air-gap flux density [T]
        f1       = 50        % stator frequency [Hz]
        p        = 2         % number of pole pairs
        s        = 1         % slip
        l        = 0.15      % bar length [m]
        r        = 0.06      % radius of the bar centre [m]
        N1xi1    = 144       % effective number of turns
        N2       = 28        % number of rotor bars
        R2_S     = 3.187e-4  % resistance of one conductor loop [Ohm]
        L2s_S    = 5.072e-6  % leakage inductance of one conductor loop [H]
        mode     = 1         % 1 = phi2 from rotor impedance, 2 = fixed
        phi2_fix = 90        % fixed displacement angle [deg]
    end

    methods
        function obj = IdealRotatingField(varargin)
            setProperties(obj, nargin, varargin{:});
        end
    end

    methods (Access = protected)
        function [psi_h, i2b, th_mech, phi_el, phi2] = stepImpl(obj, t)
            w1 = 2*pi*obj.f1;
            phi_el = w1*t;
            th_mech = (1 - obj.s)*w1*t/obj.p;
            psi = 2*obj.N1xi1*obj.Bhat*obj.l*obj.r/obj.p;
            U20 = 2*obj.Bhat*obj.l*w1*obj.r/obj.p;
            X = obj.s*w1*obj.L2s_S;
            i2hat = obj.s*U20/sqrt(obj.R2_S^2 + X^2);
            if obj.mode == 1
                phi2 = pi/2 + atan2(X, obj.R2_S);
            else
                phi2 = obj.phi2_fix*pi/180;
            end
            i2 = i2hat*obj.N2/(6*obj.N1xi1);
            psi_h = psi*[cos(phi_el); sin(phi_el)];
            i2b = i2*[cos(phi_el - phi2); sin(phi_el - phi2)];
            phi_el = atan2(sin(phi_el), cos(phi_el));
        end

        function n = getNumInputsImpl(~),  n = 1; end
        function n = getNumOutputsImpl(~), n = 5; end
        function varargout = getOutputSizeImpl(~), varargout = {[2 1], [2 1], [1 1], [1 1], [1 1]}; end
        function varargout = getOutputDataTypeImpl(~), varargout = repmat({'double'}, 1, 5); end
        function varargout = isOutputComplexImpl(~),   varargout = repmat({false}, 1, 5); end
        function varargout = isOutputFixedSizeImpl(~), varargout = repmat({true}, 1, 5); end
    end
end
