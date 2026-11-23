classdef SondeRotorstab < matlab.System
%SONDEROTORSTAB Rotorstab-Sonde: Flussdichte, Strom, Kraft und Moment an zwei Rotorstäben.
%   Rechenkern des Bausteins "Rotorstab-Sonde" (MATLAB System, interpretiert).
%   Eingänge: psi_h [ψα; ψβ] in Wb, i2b [i2α; i2β] in A, th_mech in rad
%   Ausgänge: B_k (2) T, i_k (2) A, F_k (2) N, M_k (2) N·m, M_S N·m, B_perp T, sgn_i (2),
%             phi2 rad, M_sum N·m
%   Gleichungen: asmbib.rotorstab (doku/SPEC.md 4.4). Mit folie = true zählt der Stabstrom
%   positiv aus der Zeichenebene (Folienansicht) und B⊥ mit der dazu passenden Normale
%   (dann B⊥ = B̂·cos φ_el bei Stab 1 oben, Strom eilt dem Fluss um 90° + φZ nach, Folie 16);
%   sonst rechtshändig (konv_phi2 = +1).
%   Kraft und Moment sind in beiden Fällen positiv in Drehrichtung des Feldes.

    properties (Nontunable)
        p     = 2      % Polpaarzahl
        N2    = 28     % Anzahl Rotorstäbe
        l     = 0.15   % Stablänge [m]
        r     = 0.06   % Radius der Stabmitte [m]
        N1xi1 = 144    % wirksame Windungszahl
        k1    = 1      % Stab 1 der Schleife
        k2    = 8      % Stab 2 der Schleife
        lage1 = 0      % mechanische Lage von Stab 1 [rad]
        folie = true   % Zählrichtung wie Folien
    end

    methods
        function obj = SondeRotorstab(varargin)
            setProperties(obj, nargin, varargin{:});
        end
    end

    methods (Access = protected)
        function [B_k, i_k, F_k, M_k, M_S, B_perp, sgn_i, phi2, M_sum] = stepImpl(obj, psi_h, i2b, th)
            par = struct('p', obj.p, 'N2', obj.N2, 'l', obj.l, 'r', obj.r, 'N1xi1', obj.N1xi1, ...
                         'k1', obj.k1, 'k2', obj.k2, 'lage1', obj.lage1);
            R = asmbib.rotorstab(psi_h(:).', i2b(:).', th, par);
            B_k = R.B_S(:);
            % Folienzählung: Strom positiv aus der Zeichenebene; die Schleifennormale (Rechtsschraube
            % zur Zählrichtung von Stab 1) dreht sich mit um, daher auch B⊥ mit umgekehrtem Vorzeichen
            if obj.folie, i_k = -R.i_S(:); B_perp = -R.B_perp; else, i_k = R.i_S(:); B_perp = R.B_perp; end
            F_k = R.F_S(:);
            M_k = R.M_S2(:);
            M_S = R.M_S;
            sgn_i = sign(i_k);
            phi2 = R.phi2;
            M_sum = R.M_sum;
        end

        function validatePropertiesImpl(obj)
            if obj.k1 < 1 || obj.k1 > obj.N2 || obj.k2 < 1 || obj.k2 > obj.N2
                error('asmbib:sonde', 'Stabnummern k1, k2 müssen zwischen 1 und N2 liegen.');
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
