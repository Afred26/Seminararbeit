classdef RotorBarProbe < matlab.System
%ROTORBARPROBE Rotor bar probe: flux density, current, force and torque at two rotor bars.
%   Computational kernel of the block "Rotorstab-Sonde" (MATLAB System, interpreted).
%   Inputs:  psi_h [psi_alpha; psi_beta] in Wb, i2b [i2_alpha; i2_beta] in A, th_mech in rad
%   Outputs: B_k (2) T, i_k (2) A, F_k (2) N, M_k (2) N*m, M_S N*m, B_perp T, sgn_i (2),
%            phi2 rad, M_sum N*m
%   Equations: asmtools.rotor_bars (doku/SPEC.md 4.4). With slide_convention = true the bar
%   current counts positive out of the drawing plane (slide view) and B_perp with the matching
%   normal (then B_perp = Bhat*cos(phi_el) for bar 1 on top, the current lags the flux by
%   90 deg + phiZ, slide 16); otherwise right-handed (conv_phi2 = +1).
%   Force and torque are positive in the direction of field rotation in both cases.

    properties (Nontunable)
        p     = 2      % number of pole pairs
        N2    = 28     % number of rotor bars
        l     = 0.15   % bar length [m]
        r     = 0.06   % radius of the bar centre [m]
        N1xi1 = 144    % effective number of turns
        k1    = 1      % bar 1 of the loop
        k2    = 8      % bar 2 of the loop
        bar1_angle = 0 % mechanical position of bar 1 [rad]
        slide_convention = true   % current direction as on the slides
    end

    methods
        function obj = RotorBarProbe(varargin)
            setProperties(obj, nargin, varargin{:});
        end
    end

    methods (Access = protected)
        function [B_k, i_k, F_k, M_k, M_S, B_perp, sgn_i, phi2, M_sum] = stepImpl(obj, psi_h, i2b, th)
            par = struct('p', obj.p, 'N2', obj.N2, 'l', obj.l, 'r', obj.r, 'N1xi1', obj.N1xi1, ...
                         'k1', obj.k1, 'k2', obj.k2, 'bar1_angle', obj.bar1_angle);
            R = asmtools.rotor_bars(psi_h(:).', i2b(:).', th, par);
            B_k = R.B_S(:);
            % slide convention: current positive out of the drawing plane; the loop normal
            % (right-hand screw to the counting direction of bar 1) flips as well, hence B_perp too
            if obj.slide_convention
                i_k = -R.i_S(:); B_perp = -R.B_perp;
            else
                i_k = R.i_S(:);  B_perp = R.B_perp;
            end
            F_k = R.F_S(:);
            M_k = R.M_S2(:);
            M_S = R.M_S;
            sgn_i = sign(i_k);
            phi2 = R.phi2;
            M_sum = R.M_sum;
        end

        function validatePropertiesImpl(obj)
            if obj.k1 < 1 || obj.k1 > obj.N2 || obj.k2 < 1 || obj.k2 > obj.N2
                error('asmtools:probe', 'Stabnummern k1, k2 müssen zwischen 1 und N2 liegen.');
            end
        end

        function n = getNumInputsImpl(~),  n = 3; end
        function n = getNumOutputsImpl(~), n = 9; end
        function varargout = getOutputSizeImpl(~)
            varargout = {[2 1], [2 1], [2 1], [2 1], [1 1], [1 1], [2 1], [1 1], [1 1]};
        end
        function varargout = getOutputDataTypeImpl(~), varargout = repmat({'double'}, 1, 9); end
        function varargout = isOutputComplexImpl(~),   varargout = repmat({false}, 1, 9); end
        function varargout = isOutputFixedSizeImpl(~), varargout = repmat({true}, 1, 9); end
        function flag = isInputSizeMutableImpl(~, ~), flag = false; end
    end
end
