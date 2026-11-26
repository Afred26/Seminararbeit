function Z = cross_section_state(data, par, t)
%CROSS_SECTION_STATE State of the rotor cross-section at times t (for figures and animation).
%   Z = asmtools.cross_section_state(data, par, t)
%
%   data   struct with t (n x 1), psi_h (n x 2), i2b (n x 2), th_mech (n x 1) - e.g. the log of
%          the field display or of the measurement bus
%   par    p, N2, l, r, N1xi1, k1, k2, bar1_angle (see asmtools.rotor_bars)
%   t      time instants (vector)
%
%   Z (fields as rows per time instant): t, phi_el, theta2 (field angle relative to the rotor),
%   Bhat, th (mech. rotor angle), alpha (mech. position of the bars, N2 columns), i_slide, B, F
%   (per bar), B_perp, dB_perp (loop, dB_perp/dt from a central difference quotient), M_S,
%   M_sum, phi2

t = t(:);
ip = @(x) interp1(data.t, x, t, 'linear', 'extrap');
dt = max(1e-6, 1e-3*median(diff(data.t)));
R  = asmtools.rotor_bars(ip(data.psi_h), ip(data.i2b), ip(data.th_mech), par);
Rp = asmtools.rotor_bars(interp1(data.t, data.psi_h, t + dt, 'linear', 'extrap'), ...
                         interp1(data.t, data.i2b, t + dt, 'linear', 'extrap'), ...
                         interp1(data.t, data.th_mech, t + dt, 'linear', 'extrap'), par);
Rm = asmtools.rotor_bars(interp1(data.t, data.psi_h, t - dt, 'linear', 'extrap'), ...
                         interp1(data.t, data.i2b, t - dt, 'linear', 'extrap'), ...
                         interp1(data.t, data.th_mech, t - dt, 'linear', 'extrap'), par);
Z.t       = t;
Z.phi_el  = R.phi_el;
Z.th      = ip(data.th_mech);
Z.theta2  = angle(exp(1j*(R.phi_el - par.p*Z.th)));
Z.Bhat    = R.Bhat;
Z.alpha   = R.gamma/par.p;
Z.i_slide = R.i_slide;
Z.B       = R.B;
Z.F       = R.F;
Z.B_perp  = R.B_perp;
Z.dB_perp = (Rp.B_perp - Rm.B_perp)/(2*dt);
Z.M_S     = R.M_S;
Z.M_sum   = R.M_sum;
Z.phi2    = R.phi2;
end
