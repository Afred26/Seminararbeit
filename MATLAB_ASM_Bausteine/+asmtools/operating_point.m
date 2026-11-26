function op = operating_point(M_motor, M_load, ns, n_start)
%OPERATING_POINT Stable operating point that is reachable from an initial speed.
%   op = asmtools.operating_point(M_motor, M_load, ns, n_start)
%
%   M_motor  function handle M(n) of the motor torque [N*m], n in rpm (vectorised)
%   M_load   function handle M_L(n) of the total load torque [N*m] (vectorised)
%   ns       synchronous speed [rpm] (upper end of the motor range)
%   n_start  initial speed [rpm], e.g. 0 for a run-up or the old operating point before a
%            load step
%
%   The acceleration J*dOm/dt = M_motor(n) - M_load(n) = d(n) decides the direction: starting
%   at n_start the speed moves towards larger n for d > 0 and towards smaller n for d < 0
%   until d changes sign. The first sign change in that direction is the operating point
%   that the run-up actually reaches; there d decreases with n, so the point is stable.
%   Other intersections (e.g. on the unstable branch beyond the breakdown slip) are not
%   reachable from n_start and are not returned.
%
%   Returns op with n [rpm], M [N*m], s [-], found (true if an intersection exists in the
%   direction of motion), stalls (true if the speed would fall to zero), direction (+1/-1/0).

d = @(n) M_motor(n) - M_load(n);
op = struct('n', NaN, 'M', NaN, 's', NaN, 'found', false, 'stalls', false, 'direction', 0);
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
        if op.stalls, op.n = 0; end
    else
        op.n = fzero(d, sort(ngrid([k, k + 1])));
        op.found = true;
    end
end
if isfinite(op.n)
    op.M = M_motor(op.n);
    op.s = (ns - op.n)/ns;
end
end
