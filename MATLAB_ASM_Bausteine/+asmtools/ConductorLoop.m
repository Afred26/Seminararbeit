classdef ConductorLoop < matlab.System
%CONDUCTORLOOP Conductor loop of two rotor bars in the rotor-fixed frame (prototype part A).
%   Computational kernel of the block "Leiterschleife (Prototyp Teil A)" (MATLAB System, interpreted).
%   Inputs:  slip s, theta2 = int(s*w1 dt) (integrator in the block)
%   Outputs: B_k (2) T, i_k (2) A, F_k (2) N, M_k (2) N*m, M_S N*m, B_perp T, phi2 rad, i2hat A
%
%   Equations (build_asm_prototyp.m, doku/SPEC.md 3.1):
%     x_k = gamma_k - theta2 (gamma_1 = 0, gamma_2 = pi),  B_k = Bhat*cos(x_k)
%     U20 = 2*Bhat*l*w1*r/p,  i2hat = s*U20/sqrt(R2^2 + (s*w1*L2sigma)^2),  phiZ = atan(s*w1*L2sigma/R2)
%     phi2 = 90 deg + conv*phiZ (mode 1) or phi2,fix (mode 2)
%     i_k = i2hat*sin(x_k + conv*phi2),  F_k = conv*i_k*l*B_k,  M_k = F_k*r,  M_S = M_1 + M_2
%     B_perp = Bhat*sin(gamma_1 - theta2)
%   Mean over a rotor period T2 = 1/(s*f1):  M_S,mean = i2hat*l*Bhat*r*sin(phi2)
%   (asmtools.loop_mean_torque). The slip is an input only; the loop torque does not act
%   back on any mechanics.

    properties (Nontunable)
        Bhat     = 0.8       % amplitude of the air-gap flux density [T]
        l        = 0.15      % bar length [m]
        r        = 0.06      % radius of the bar centre [m]
        f1       = 50        % stator frequency [Hz]
        p        = 2         % number of pole pairs
        R2_S     = 3.187e-4  % resistance of the conductor loop [Ohm]
        L2s_S    = 5.072e-6  % leakage inductance of the conductor loop [H]
        conv     = 1         % sign convention +1 or -1
        mode     = 1         % 1 = phi2 from rotor impedance, 2 = fixed
        phi2_fix = 90        % fixed displacement angle [deg]
    end

    methods
        function obj = ConductorLoop(varargin)
            setProperties(obj, nargin, varargin{:});
        end
    end

    methods (Access = protected)
        function [B_k, i_k, F_k, M_k, M_S, B_perp, phi2, i2hat] = stepImpl(obj, s, theta2)
            w1 = 2*pi*obj.f1;
            U20 = 2*obj.Bhat*obj.l*w1*obj.r/obj.p;
            X = s*w1*obj.L2s_S;
            i2hat = s*U20/sqrt(obj.R2_S^2 + X^2);
            if obj.mode == 1
                phi2 = pi/2 + obj.conv*atan2(X, obj.R2_S);
            else
                phi2 = obj.phi2_fix*pi/180;
            end
            x = [0; pi] - theta2;
            B_k = obj.Bhat*cos(x);
            i_k = i2hat*sin(x + obj.conv*phi2);
            F_k = obj.conv*i_k*obj.l.*B_k;
            M_k = F_k*obj.r;
            M_S = sum(M_k);
            B_perp = obj.Bhat*sin(-theta2);
        end

        function n = getNumInputsImpl(~),  n = 2; end
        function n = getNumOutputsImpl(~), n = 8; end
        function varargout = getOutputSizeImpl(~)
            varargout = {[2 1], [2 1], [2 1], [2 1], [1 1], [1 1], [1 1], [1 1]};
        end
        function varargout = getOutputDataTypeImpl(~), varargout = repmat({'double'}, 1, 8); end
        function varargout = isOutputComplexImpl(~),   varargout = repmat({false}, 1, 8); end
        function varargout = isOutputFixedSizeImpl(~), varargout = repmat({true}, 1, 8); end
    end
end
