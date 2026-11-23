function Z = querschnitt_zustand(daten, par, t)
%QUERSCHNITT_ZUSTAND Zustand des Rotorquerschnitts zu den Zeitpunkten t (für Bilder und Animation).
%   Z = asmbib.querschnitt_zustand(daten, par, t)
%
%   daten  Struktur mit t (n×1), psi_h (n×2), i2b (n×2), th_mech (n×1) – z. B. Protokoll der
%          Drehfeld-Anzeige oder des Messbusses
%   par    p, N2, l, r, N1xi1, k1, k2, lage1 (siehe asmbib.rotorstab)
%   t      Zeitpunkte (Vektor)
%
%   Z (Felder als Zeilen je Zeitpunkt): t, phi_el, theta2 (Feldwinkel relativ zum Rotor), Bhat,
%   th (mech. Rotorwinkel), alpha (mech. Lage der Stäbe, N2 Spalten), i_folie, B, F (je Stab),
%   B_perp, dB_perp (Schleife, dB⊥/dt aus zentralem Differenzenquotienten), M_S, M_sum, phi2

t = t(:);
ip = @(x) interp1(daten.t, x, t, 'linear', 'extrap');
dt = max(1e-6, 1e-3*median(diff(daten.t)));
R  = asmbib.rotorstab(ip(daten.psi_h), ip(daten.i2b), ip(daten.th_mech), par);
Rp = asmbib.rotorstab(interp1(daten.t, daten.psi_h, t + dt, 'linear', 'extrap'), ...
                      interp1(daten.t, daten.i2b, t + dt, 'linear', 'extrap'), ...
                      interp1(daten.t, daten.th_mech, t + dt, 'linear', 'extrap'), par);
Rm = asmbib.rotorstab(interp1(daten.t, daten.psi_h, t - dt, 'linear', 'extrap'), ...
                      interp1(daten.t, daten.i2b, t - dt, 'linear', 'extrap'), ...
                      interp1(daten.t, daten.th_mech, t - dt, 'linear', 'extrap'), par);
if ~isfield(par, 'lage1'), par.lage1 = 0; end
Z.t       = t;
Z.phi_el  = R.phi_el;
Z.th      = ip(daten.th_mech);
Z.theta2  = angle(exp(1j*(R.phi_el - par.p*Z.th)));
Z.Bhat    = R.Bhat;
Z.alpha   = R.gamma/par.p;
Z.i_folie = R.i_folie;
Z.B       = R.B;
Z.F       = R.F;
Z.B_perp  = R.B_perp;
Z.dB_perp = (Rp.B_perp - Rm.B_perp)/(2*dt);
Z.M_S     = R.M_S;
Z.M_sum   = R.M_sum;
Z.phi2    = R.phi2;
end
