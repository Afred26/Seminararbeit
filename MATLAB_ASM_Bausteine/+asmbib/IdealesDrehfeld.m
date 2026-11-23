classdef IdealesDrehfeld < matlab.System
%IDEALESDREHFELD Kinematische Quelle: ideales Drehfeld und Rotor mit festem Schlupf (Teil A).
%   Rechenkern des Bausteins "Ideales Drehfeld" (MATLAB System, interpretiert). Eingang: Zeit t.
%   Liefert dieselben Signale wie der Messbus des Motors (ψh, i2′, ϑ), damit Rotorstab-Sonde
%   und Drehfeld-Anzeige ohne Motor betrieben werden können (Folien 16-30: s = 1, φ2 = 90°).
%
%   Gleichungen (Prototyp Teil A; doku/SPEC.md 3.1 und 4.4):
%     φ_el = ω1·t,  ϑ = (1 − s)·ω1·t/p,  θ2 = φ_el − p·ϑ = s·ω1·t
%     |ψh| = 2·N1ξ1·B̂·l·r/p                        (ergibt genau die Amplitude B̂)
%     U20 = 2·B̂·l·ω1·r/p,  î2 = s·U20/√(R2² + (s·ω1·L2σ)²),  φZ = arctan(s·ω1·L2σ/R2)
%     φ2 = 90° + φZ (modus 1) oder φ2 = φ2,fix (modus 2)
%     |i2′| = î2·N2/(6·N1ξ1),  ∠i2′ = φ_el − φ2     (ergibt den Stabstrom î2 in der Sonde)

    properties (Nontunable)
        Bhat     = 0.8       % Amplitude der Luftspaltflussdichte [T]
        f1       = 50        % Statorfrequenz [Hz]
        p        = 2         % Polpaarzahl
        s        = 1         % Schlupf
        l        = 0.15      % Stablänge [m]
        r        = 0.06      % Radius der Stabmitte [m]
        N1xi1    = 144       % wirksame Windungszahl
        N2       = 28        % Anzahl Rotorstäbe
        R2_S     = 3.187e-4  % Widerstand einer Leiterschleife [Ohm]
        L2s_S    = 5.072e-6  % Streuinduktivität einer Leiterschleife [H]
        modus    = 1         % 1 = φ2 aus Rotorimpedanz, 2 = fest
        phi2_fix = 90        % fester Versatzwinkel [Grad]
    end

    methods
        function obj = IdealesDrehfeld(varargin)
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
            if obj.modus == 1
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
