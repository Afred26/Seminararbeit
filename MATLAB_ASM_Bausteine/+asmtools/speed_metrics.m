function K = speed_metrics(t, n, cfg)
%SPEED_METRICS Run-up and load-step metrics of a speed trajectory with fixed definitions.
%   K = asmtools.speed_metrics(t, n, cfg)
%
%   t, n   time [s] and speed [rpm], vectors of equal length (>= 2 samples), finite, t strictly
%          increasing (duplicate solver time stamps must be removed by the caller). The speed is
%          counted positive in the direction of the rotating field. Between samples the trajectory
%          is taken as piecewise linear (linear interpolation); all times below are interpolated.
%   cfg    struct with
%            n_target   run-up target speed [rpm], e.g. 0.9*n_N (fixed, NOT relative to the last
%                       simulated value)
%            t_step     nominal time of the load step [s] (NaN or Inf: no load step)
%            window     length of the averaging windows [s] (> 0)
%            band       tolerance band for "settled" [rpm] (> 0, absolute, +-band)
%            margin     (optional, default 0) distance [s] of the pre-step window from t_step and
%                       earliest start of the final window after t_step. The load-step block is
%                       smoothed (tanh with 0.5 ms) and acts with 50 % already at t_step; run_asm
%                       uses 5 ms (= 10 time constants).
%            step_sign  (optional, default +1) +1 load increase (speed falls), -1 load decrease
%                       (speed rises); only selects which extreme value is the relevant one.
%
%   Definitions (t_b = t_step - margin, t_a = t_step + margin)
%     run-up     t_target = first time with n >= n_target (a sample exactly on the target counts as
%                reached at that sample's time; between samples linear interpolation), searched
%                up to t_b (with load step) or t_end. Not reached -> reached = false,
%                t_target = NaN ("nicht erreicht").
%     windows    steady value = time average of the piecewise linear trajectory over a window;
%                before the step [t_b - window, t_b], at the end [t_end - window, t_end].
%                A window is valid only if the data cover it completely and (final window with
%                load step) it starts at or after t_a; otherwise valid = false, n = NaN and a
%                reason is given (e.g. "Endfenster zu kurz", "Endfenster überlappt den Laststoß").
%                settled = valid and max|n - mean| <= band inside the window. A single last sample
%                is never used as proof of a steady state.
%     load step  n_before = steady value before the step; n_min/t_min and n_max/t_max = extremes
%                after t_b; dn_dip = n_before - n_min (speed dip); undershoot = n_new - n_min
%                (depth below the new operating point); overshoot = n_max - n_new; n_new = steady
%                value of the final window; dn_static = n_before - n_new. For a load decrease
%                (step_sign = -1) n_max, overshoot and -dn_static are the relevant values.
%     settling   the band is |n - n_new| <= band (boundary counts as inside). t_cross = time of the
%                last entry into the band, evaluated on the piecewise linear trajectory from the
%                last sample at or before t_step (linear interpolation of the boundary crossing,
%                not earlier than t_step; t_cross = t_step if the band is never left). settled = true only if
%                the final window is valid, settled, and t_cross <= t_end - window, i.e. the band
%                holds from t_cross up to the end of the evaluation window; then
%                t_settle = t_cross - t_step (time reference: nominal t_step). Otherwise
%                settled = false, t_settle = NaN ("nicht eingeschwungen").
%
%   Returns K with fields startup, before_step, final and step (empty without load step).

validate(t, n, cfg);
t = t(:);  n = n(:);
t_end = t(end);
if ~isfield(cfg, 'margin'), cfg.margin = 0; end
if ~isfield(cfg, 'step_sign') || cfg.step_sign == 0, cfg.step_sign = 1; end
has_step = isfinite(cfg.t_step) && cfg.t_step > t(1) && cfg.t_step < t_end;
t_b = cfg.t_step - cfg.margin;                         % end of the undisturbed part before the step
t_a = cfg.t_step + cfg.margin;                         % step completed (smoothing decayed)

% run-up (before the load step)
if has_step, t_search = t_b; else, t_search = t_end; end
K.startup = struct('n_target', cfg.n_target, 't_target', NaN, 'reached', false, 't_search_end', t_search);
idx = find(n >= cfg.n_target & t <= t_search, 1);
if ~isempty(idx)
    K.startup.reached = true;
    if idx == 1
        K.startup.t_target = t(1);
    else                                               % n(idx-1) < n_target <= n(idx)
        K.startup.t_target = t(idx-1) + (cfg.n_target - n(idx-1))*(t(idx) - t(idx-1))/(n(idx) - n(idx-1));
    end
end

% steady values
if has_step
    K.before_step = steady(t, n, t_b - cfg.window, t_b, cfg.band, -Inf);
    K.final = steady(t, n, t_end - cfg.window, t_end, cfg.band, t_a);
else
    K.final = steady(t, n, t_end - cfg.window, t_end, cfg.band, -Inf);
    K.before_step = K.final;
end

% load step
K.step = [];
if ~has_step, return; end
after = t > t_b;
ta = t(after);  na = n(after);
[n_min, i_min] = min(na);
[n_max, i_max] = max(na);
S.t_step         = cfg.t_step;
S.step_sign      = sign(cfg.step_sign);
S.n_before       = K.before_step.n;
S.settled_before = K.before_step.settled;
S.n_min          = n_min;
S.t_min          = ta(i_min);
S.n_max          = n_max;
S.t_max          = ta(i_max);
S.dn_dip         = S.n_before - n_min;
S.n_new          = K.final.n;
S.undershoot     = S.n_new - n_min;
S.overshoot      = n_max - S.n_new;
S.dn_static      = S.n_before - S.n_new;
S.band           = cfg.band;
S.final_valid    = K.final.valid;
S.settled        = false;
S.t_settle       = NaN;
S.reason         = K.final.reason;
if K.final.valid
    % piecewise linear trajectory from the last sample at or before t_step onwards
    i0 = find(t <= cfg.t_step, 1, 'last');
    tp = t(i0:end);  np = n(i0:end);
    dev = np - S.n_new;
    k = find(abs(dev) > cfg.band, 1, 'last');
    if isempty(k)
        t_cross = cfg.t_step;                          % band never left after the step
    elseif k == numel(np)
        t_cross = Inf;                                 % still outside at the last sample
    else                                               % interpolate the boundary crossing
        nb = S.n_new + sign(dev(k))*cfg.band;
        t_cross = max(cfg.t_step, tp(k) + (nb - np(k))*(tp(k+1) - tp(k))/(np(k+1) - np(k)));
    end
    S.settled = K.final.settled && t_cross <= t_end - cfg.window;
    if S.settled
        S.t_settle = t_cross - cfg.t_step;
        S.reason = '';
    else
        S.reason = 'Toleranzband nicht bis zum Ende des Auswertefensters gehalten';
    end
end
K.step = S;
end

function s = steady(t, n, t0, t1, band, t_min_start)
% time average of the piecewise linear trajectory over [t0, t1] and check of the band
s = struct('t0', t0, 't1', t1, 'n', NaN, 'max_dev', NaN, 'settled', false, 'valid', false, 'reason', '');
if t0 < t(1) - 1e-12
    s.reason = 'Endfenster zu kurz: Daten decken das Auswertefenster nicht ab';
    return;
end
if t0 < t_min_start - 1e-12
    s.reason = 'Endfenster überlappt den Laststoß (Simulation endet zu kurz nach dem Stoß)';
    return;
end
tt = unique([t0; t(t > t0 & t < t1); t1]);
nn = interp1(t, n, tt);
s.n = trapz(tt, nn)/(t1 - t0);
s.max_dev = max(abs(nn - s.n));                        % extremes of a piecewise linear curve are at nodes
s.valid = true;
s.settled = s.max_dev <= band;
end

function validate(t, n, cfg)
if ~(isnumeric(t) && isnumeric(n) && isvector(t) && isvector(n) && numel(t) == numel(n) && numel(t) >= 2)
    error('asmtools:metrics', 'Zeit und Drehzahl müssen Vektoren gleicher Länge mit mindestens 2 Werten sein.');
end
if ~all(isfinite(t)) || ~all(isfinite(n))
    error('asmtools:metrics', 'Zeit und Drehzahl müssen endlich sein (keine NaN/Inf).');
end
if any(diff(t(:)) <= 0)
    error('asmtools:metrics', 'Die Zeit muss streng monoton steigen (doppelte Zeitpunkte vorher entfernen).');
end
if ~(isfield(cfg, 'window') && cfg.window > 0 && isfield(cfg, 'band') && cfg.band > 0 && isfield(cfg, 'n_target'))
    error('asmtools:metrics', 'cfg braucht n_target, window > 0 und band > 0.');
end
end
