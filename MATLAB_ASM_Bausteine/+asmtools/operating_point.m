function op = operating_point(M_motor, M_load, ns, n_start, opt)
%OPERATING_POINT Stable operating point that is reachable from an initial speed.
%   op = asmtools.operating_point(M_motor, M_load, ns, n_start)
%   op = asmtools.operating_point(..., 'StandstillSpeed', 4.77)
%
%   M_motor  function handle M(n) of the motor torque [N*m], n in rpm (vectorised)
%   M_load   function handle M_L(n) of the total load torque [N*m] (vectorised); it must use the
%            same characteristic and smoothing as the load blocks (see run_asm/load_torque)
%   ns       synchronous speed [rpm] (upper end of the motor range)
%   n_start  initial speed [rpm], e.g. 0 for a run-up or the old operating point before a
%            load step
%
%   The acceleration J*dOm/dt = M_motor(n) - M_load(n) = d(n) decides the direction: starting
%   at n_start the speed moves towards larger n for d > 0 and towards smaller n for d < 0
%   until d changes sign (grid of 20001 points between n_start and ns or 0, then fzero). The
%   first sign change in that direction is the operating point the trajectory actually reaches;
%   there d decreases with n, so it is stable (checked numerically: field "stable"). Other
%   intersections (e.g. on the unstable branch beyond the breakdown slip) are not reachable from
%   n_start and are not returned. The inertia does not influence the result.
%
%   Standstill: the load blocks smooth the sign of the speed with tanh(Om/0.1 rad/s), so a load
%   that the motor cannot overcome at standstill still yields a formal intersection at a creeping
%   speed of about 1 rpm. Every intersection below StandstillSpeed (default 0.5 rad/s = 5 time
%   constants of the smoothing, about 4.77 rpm) is therefore marked standstill = true: the motor
%   does not start (n_start = 0) or stalls after a load step. reachable = found && ~standstill.
%
%   Returns op with n [rpm], M [N*m], s [-], found, stable, standstill, reachable, stalls (true if
%   the speed would fall to zero without any intersection), direction (+1/-1/0).

arguments
    M_motor
    M_load
    ns (1,1) double
    n_start (1,1) double
    opt.StandstillSpeed (1,1) double = 0.5*60/(2*pi)
end

d = @(n) M_motor(n) - M_load(n);
op = struct('n', NaN, 'M', NaN, 's', NaN, 'found', false, 'stable', false, 'standstill', false, ...
            'reachable', false, 'stalls', false, 'direction', 0);
d0 = d(n_start);
if d0 == 0
    op.n = n_start;  op.found = true;
else
    op.direction = sign(d0);
    if d0 > 0, ngrid = linspace(n_start, ns, 20001); else, ngrid = linspace(n_start, 0, 20001); end
    dg = d(ngrid);
    k = find(sign(dg(2:end)) ~= sign(d0), 1);
    if isempty(k)
        op.stalls = d0 < 0;                       % falls to standstill without intersection
        if op.stalls, op.n = 0; op.standstill = true; end
    else
        op.n = fzero(d, sort(ngrid([k, k + 1])));
        op.found = true;
    end
end
if op.found
    h = max(1e-6*ns, 1e-3);
    op.stable = d(op.n + h) < d(op.n - h);         % restoring: d decreases with n
    op.standstill = abs(op.n) < opt.StandstillSpeed;
    op.reachable = op.stable && ~op.standstill;
end
if isfinite(op.n)
    op.M = M_motor(op.n);
    op.s = (ns - op.n)/ns;
end
end
