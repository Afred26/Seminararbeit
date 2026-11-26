function R = rotor_bars(psi_h, i2b, th_mech, par)
%ROTOR_BARS Flux density, current, force and torque at the rotor bars from the model quantities.
%   R = asmtools.rotor_bars(psi_h, i2b, th_mech, par)
%
%   psi_h    main flux linkage [psi_alpha psi_beta] (n x 2) [Wb]
%   i2b      stator-referred rotor current [i2_alpha i2_beta] (n x 2) [A]
%   th_mech  mechanical rotor angle th (n x 1) [rad]
%   par      struct with p, N2, l, r, N1xi1, optionally k1, k2 (bars of the conductor loop) and
%            bar1_angle (mechanical position of bar 1 in rad, mathematically positive from the
%            axis of phase U; default 0; -pi/2 puts bar 1 on top in the slide view)
%
%   Equations (doku/SPEC.md, section 4.4; Hagl, Elektrische Antriebstechnik, Hanser 2013):
%     phi_el = angle(psi_h),  Bhat = p*|psi_h| / (2*N1xi1*l*r),  eps2 = angle(i2'),
%     ihat_bar = 6*N1xi1/N2*|i2'|
%     gamma_k = p*(th + bar1_angle) + (k-1)*2*pi*p/N2      (k = 1 ... N2, electrical, stator-fixed)
%     i_k  = ihat_bar*sin(gamma_k - eps2)                   (positive in +e_z, right-handed)
%     B_k  = Bhat*cos(gamma_k - phi_el),  F_k = i_k*l*B_k,  M_k = F_k*r
%     phi2 = angle(psi_h) - angle(i2'),   sum M_k = 3/2*p*|psi_h|*|i2'|*sin(phi2) = M   (for N2/p > 2)
%   Slide convention (current positive out of the drawing plane): i_slide = -i_k.
%
%   Returns R (rows = time instants, columns = bars)
%     gamma, B, i, F, M (n x N2), i_slide (n x N2)
%     M_sum, Bhat, phi_el, phi2, ihat (n x 1)
%     loop (bars k1, k2): B_S, i_S, F_S, M_S2 (n x 2), M_S (n x 1), B_perp (n x 1)

if ~isfield(par, 'k1'), par.k1 = 1; end
if ~isfield(par, 'k2'), par.k2 = 1 + par.N2/(2*par.p); end
if ~isfield(par, 'bar1_angle'), par.bar1_angle = 0; end
th_mech = th_mech(:) + par.bar1_angle;

R.phi_el = atan2(psi_h(:,2), psi_h(:,1));
R.Bhat   = par.p*hypot(psi_h(:,1), psi_h(:,2))/(2*par.N1xi1*par.l*par.r);
eps2     = atan2(i2b(:,2), i2b(:,1));
R.ihat   = 6*par.N1xi1/par.N2*hypot(i2b(:,1), i2b(:,2));
R.phi2   = angle(exp(1j*(R.phi_el - eps2)));

k = 0:par.N2-1;
R.gamma  = par.p*th_mech + k*2*pi*par.p/par.N2;
R.i      = R.ihat.*sin(R.gamma - eps2);
R.i_slide = -R.i;
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
