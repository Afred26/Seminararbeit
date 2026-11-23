classdef Leiterschleife < matlab.System
%LEITERSCHLEIFE Leiterschleife aus zwei Rotorstäben im rotorfesten System (Prototyp Teil A).
%   Rechenkern des Bausteins "Leiterschleife (Prototyp Teil A)" (MATLAB System, interpretiert).
%   Eingänge: Schlupf s, θ2 = ∫ s·ω1 dt (Integrator im Baustein)
%   Ausgänge: B_k (2) T, i_k (2) A, F_k (2) N, M_k (2) N·m, M_S N·m, B_perp T, phi2 rad, i2hat A
%
%   Gleichungen (build_asm_prototyp.m, doku/SPEC.md 3.1):
%     x_k = γ_k − θ2 (γ_1 = 0, γ_2 = π),  B_k = B̂·cos x_k
%     U20 = 2·B̂·l·ω1·r/p,  î2 = s·U20/√(R2² + (s·ω1·L2σ)²),  φZ = arctan(s·ω1·L2σ/R2)
%     φ2 = 90° + konv·φZ (modus 1) oder φ2,fix (modus 2)
%     i_k = î2·sin(x_k + konv·φ2),  F_k = konv·i_k·l·B_k,  M_k = F_k·r,  M_S = M_1 + M_2
%     B⊥ = B̂·sin(γ_1 − θ2)

    properties (Nontunable)
        Bhat     = 0.8       % Amplitude der Luftspaltflussdichte [T]
        l        = 0.15      % Stablänge [m]
        r        = 0.06      % Radius der Stabmitte [m]
        f1       = 50        % Statorfrequenz [Hz]
        p        = 2         % Polpaarzahl
        R2_S     = 3.187e-4  % Widerstand der Leiterschleife [Ohm]
        L2s_S    = 5.072e-6  % Streuinduktivität der Leiterschleife [H]
        konv     = 1         % Vorzeichenkonvention +1 oder −1
        modus    = 1         % 1 = φ2 aus Rotorimpedanz, 2 = fest
        phi2_fix = 90        % fester Versatzwinkel [Grad]
    end

    methods
        function obj = Leiterschleife(varargin)
            setProperties(obj, nargin, varargin{:});
        end
    end

    methods (Access = protected)
        function [B_k, i_k, F_k, M_k, M_S, B_perp, phi2, i2hat] = stepImpl(obj, s, theta2)
            w1 = 2*pi*obj.f1;
            U20 = 2*obj.Bhat*obj.l*w1*obj.r/obj.p;
            X = s*w1*obj.L2s_S;
            i2hat = s*U20/sqrt(obj.R2_S^2 + X^2);
            if obj.modus == 1
                phi2 = pi/2 + obj.konv*atan2(X, obj.R2_S);
            else
                phi2 = obj.phi2_fix*pi/180;
            end
            x = [0; pi] - theta2;
            B_k = obj.Bhat*cos(x);
            i_k = i2hat*sin(x + obj.konv*phi2);
            F_k = obj.konv*i_k*obj.l.*B_k;
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
