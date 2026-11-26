function K = speed_metrics(t, n, cfg)
%SPEED_METRICS Run-up and load-step metrics of a speed trajectory with fixed definitions.
%   K = asmtools.speed_metrics(t, n, cfg)
%
%   t, n   time [s] and speed [rpm] (column vectors; speed counted positive in the direction
%          of the rotating field)
%   cfg    struct with
%            n_target  run-up target speed [rpm], e.g. 0.9*n_N (fixed, NOT relative to the
%                      last simulated value)
%            t_step    time of the load step [s] (NaN or Inf: no load step)
%            window    averaging window for steady-state values [s]
%            band      tolerance band for "settled" [rpm] (absolute, +-band)
%            margin    (optional, default 0) distance [s] of the pre-step window from t_step.
%                      The load-step block is smoothed (tanh with 0.5 ms) and already acts with
%                      50 % at t_step; run_asm uses 5 ms (= 10 time constants).
%
%   Definitions (t_b = t_step - margin)
%     run-up      t_target = first time with n >= n_target, searched before t_b
%                 (linear interpolation between samples). Not exceeded -> reached = false,
%                 t_target = NaN ("nicht erreicht").
%     steady      mean over a window: before the step [t_b - window, t_b], at the end
%                 [t_end - window, t_end]. "settled" means max|n - mean| <= band in that window.
%     load step   n_before (steady value before the step), n_min (minimum after t_b) and
%                 t_min, dn_dip = n_before - n_min, n_new (steady value at the end),
%                 dn_static = n_before - n_new.
%     settling    t_settle = time after the step from which |n - n_new| <= band holds up to
%                 t_end. It is only reported (settled = true) if the band is held at least over
%                 the whole final window, i.e. the trajectory is still inside the band at the end
%                 of the evaluation window; otherwise t_settle = NaN ("nicht eingeschwungen").
%
%   Returns K with fields startup, before_step (or final), step (empty without load step).

t = t(:);  n = n(:);
t_end = t(end);
if ~isfield(cfg, 'margin'), cfg.margin = 0; end
has_step = isfinite(cfg.t_step) && cfg.t_step > t(1) && cfg.t_step < t_end;
t_b = cfg.t_step - cfg.margin;                         % end of the undisturbed part before the step

% run-up (before the load step)
if has_step, t_search = t_b; else, t_search = t_end; end
K.startup = struct('n_target', cfg.n_target, 't_target', NaN, 'reached', false);
idx = find(n >= cfg.n_target & t <= t_search, 1);
if ~isempty(idx)
    K.startup.reached = true;
    if idx == 1
        K.startup.t_target = t(1);
    else
        K.startup.t_target = interp1(n(idx-1:idx), t(idx-1:idx), cfg.n_target);
    end
end

% steady state before the step (or at the end without step)
if has_step
    K.before_step = steady(t, n, t_b - cfg.window, t_b, cfg.band);
else
    K.before_step = steady(t, n, t_end - cfg.window, t_end, cfg.band);
end
K.final = steady(t, n, t_end - cfg.window, t_end, cfg.band);

% load step
K.step = [];
if has_step
    after = t > t_b;
    ta = t(after);  na = n(after);
    [n_min, i_min] = min(na);
    S.t_step    = cfg.t_step;
    S.n_before  = K.before_step.n;
    S.settled_before = K.before_step.settled;
    S.n_min     = n_min;
    S.t_min     = ta(i_min);
    S.dn_dip    = S.n_before - n_min;
    S.n_new     = K.final.n;
    S.dn_static = S.n_before - S.n_new;
    S.band      = cfg.band;
    outside = find(abs(na - S.n_new) > cfg.band, 1, 'last');
    if isempty(outside)
        t_exit = cfg.t_step;
    elseif outside == numel(na)
        t_exit = t_end;
    else
        t_exit = ta(outside + 1);
    end
    S.settled  = t_exit <= t_end - cfg.window;
    if S.settled, S.t_settle = t_exit - cfg.t_step; else, S.t_settle = NaN; end
    K.step = S;
end
end

function s = steady(t, n, t0, t1, band)
% time-weighted mean over [t0, t1] and check of the tolerance band
tt = linspace(max(t0, t(1)), t1, 2001)';
nn = interp1(t, n, tt);
s.t0 = tt(1);
s.t1 = t1;
s.n = trapz(tt, nn)/(tt(end) - tt(1));
s.max_dev = max(abs(nn - s.n));
s.settled = s.max_dev <= band;
end
