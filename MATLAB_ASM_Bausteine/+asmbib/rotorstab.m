function R = rotorstab(psi_h, i2b, th_mech, par)
%ROTORSTAB Flussdichte, Strom, Kraft und Moment an den Rotorstäben aus den Modellgrößen.
%   R = asmbib.rotorstab(psi_h, i2b, th_mech, par)
%
%   psi_h    Hauptflussverkettung [ψα ψβ] (n×2) [Wb]
%   i2b      Rotorstrom statorbezogen [i2α i2β] (n×2) [A]
%   th_mech  mechanischer Rotorwinkel ϑ (n×1) [rad]
%   par      Struktur mit p, N2, l, r, N1xi1, optional k1, k2 (Stäbe der Leiterschleife) und
%            lage1 (mechanische Lage von Stab 1 in rad, mathematisch positiv ab Achse Strang U;
%            Standard 0; −π/2 legt Stab 1 in der Folienansicht nach oben)
%
%   Gleichungen (doku/SPEC.md, Abschnitt 4.4; Hagl, Elektrische Antriebstechnik, Hanser 2013):
%     φ_el = ∠ψh,  B̂ = p·|ψh| / (2·N1ξ1·l·r),  ε2 = ∠i2′,  î_Stab = 6·N1ξ1/N2·|i2′|
%     γ_k  = p·(ϑ + lage1) + (k−1)·2π·p/N2             (k = 1 … N2, elektrisch, statorfest)
%     i_k  = î_Stab·sin(γ_k − ε2)                      (positiv in +e_z, rechtshändig)
%     B_k  = B̂·cos(γ_k − φ_el),  F_k = i_k·l·B_k,  M_k = F_k·r
%     φ2   = ∠ψh − ∠i2′,   Σ M_k = 3/2·p·|ψh|·|i2′|·sin φ2 = M   (für N2/p > 2)
%   Darstellung wie Folien (Strom positiv aus der Zeichenebene): i_Folie = −i_k.
%
%   Rückgabe R (Zeilen = Zeitpunkte, Spalten = Stäbe)
%     gamma, B, i, F, M (n×N2), i_folie (n×N2)
%     M_sum, Bhat, phi_el, phi2, ihat (n×1)
%     Schleife (Stäbe k1, k2): B_S, i_S, F_S, M_S2 (n×2), M_S (n×1), B_perp (n×1)

if ~isfield(par, 'k1'), par.k1 = 1; end
if ~isfield(par, 'k2'), par.k2 = 1 + par.N2/(2*par.p); end
if ~isfield(par, 'lage1'), par.lage1 = 0; end
th_mech = th_mech(:) + par.lage1;

R.phi_el = atan2(psi_h(:,2), psi_h(:,1));
R.Bhat   = par.p*hypot(psi_h(:,1), psi_h(:,2))/(2*par.N1xi1*par.l*par.r);
eps2     = atan2(i2b(:,2), i2b(:,1));
R.ihat   = 6*par.N1xi1/par.N2*hypot(i2b(:,1), i2b(:,2));
R.phi2   = angle(exp(1j*(R.phi_el - eps2)));

k = 0:par.N2-1;
R.gamma  = par.p*th_mech + k*2*pi*par.p/par.N2;
R.i      = R.ihat.*sin(R.gamma - eps2);
R.i_folie = -R.i;
R.B      = R.Bhat.*cos(R.gamma - R.phi_el);
R.F      = R.i*par.l.*R.B;
R.M      = R.F*par.r;
R.M_sum  = sum(R.M, 2);

ks = [par.k1, par.k2];
R.B_S    = R.B(:, ks);
R.i_S    = R.i(:, ks);
R.F_S    = R.F(:, ks);
R.M_S2   = R.M(:, ks);
R.M_S    = sum(R.M_S2, 2);
R.B_perp = R.Bhat.*sin(R.gamma(:, par.k1) - R.phi_el);
end
