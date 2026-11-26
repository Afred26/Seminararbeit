classdef SpeedMetricsTest < matlab.unittest.TestCase
%SPEEDMETRICSTEST Independent unit tests of asmtools.speed_metrics with hand-computed expectations.
%   Run in the project folder:  startup_asm; runtests('tests')
%
%   Every expectation below is computed by hand from the given time-speed pairs (piecewise linear
%   trajectory between the samples, linear interpolation of crossings); neither speed_metrics nor
%   its helper functions are used to obtain expected values. No simulation is needed.
%   Conventions under test (documented in asmtools.speed_metrics):
%   - run-up target: first time with n >= target; a sample exactly on the target counts;
%   - steady values: time average over a window that must be completely covered by the data;
%   - band |n - n_new| <= band (boundary inside); settling time = last entry into the band,
%     reported only if the band holds over the whole final window.

    methods (Test)
        %% run-up target
        function targetCrossingLinearInterpolation(tc)
            K = asmtools.speed_metrics([0 1 2], [0 800 1200], cfg(1000));
            tc.verifyTrue(K.startup.reached);
            tc.verifyEqual(K.startup.t_target, 1.5, 'AbsTol', 1e-12, '800 -> 1200 zwischen 1 und 2 s: 1000 bei 1,5 s');
        end

        function targetHitExactlyOnSample(tc)
            K = asmtools.speed_metrics([0 1 2], [0 1000 1200], cfg(1000));
            tc.verifyEqual(K.startup.t_target, 1, 'AbsTol', 1e-12, 'Abtastwert genau auf dem Ziel zählt');
        end

        function onlyFirstCrossingCounts(tc)
            K = asmtools.speed_metrics([0 1 2 3], [0 1200 800 1200], cfg(1000));
            tc.verifyEqual(K.startup.t_target, 1000/1200, 'AbsTol', 1e-12, 'erster Übertritt bei 5/6 s');
        end

        function unevenTimeSteps(tc)
            K = asmtools.speed_metrics([0 0.5 2], [0 600 1200], cfg(900));
            tc.verifyEqual(K.startup.t_target, 0.5 + 1.5*(900 - 600)/600, 'AbsTol', 1e-12, '1,25 s');
        end

        function targetNotReached(tc)
            K = asmtools.speed_metrics([0 1 2], [0 500 800], cfg(1000));
            tc.verifyFalse(K.startup.reached);
            tc.verifyTrue(isnan(K.startup.t_target), '"nicht erreicht": kein Zeitwert');
        end

        function targetOnlyBeforeLoadStep(tc)
            % the speed exceeds the target only after the load step: not a run-up
            K = asmtools.speed_metrics([0 1 2 3], [0 500 500 1200], cfg(1000, 'step', 1.5, 'window', 0.2));
            tc.verifyFalse(K.startup.reached, 'Übertritt nach dem Laststoß zählt nicht');
        end

        %% steady values and windows
        function noLoadStep(tc)
            K = asmtools.speed_metrics([0 1 2], [0 1000 1000], cfg(900, 'window', 0.5));
            tc.verifyEmpty(K.step, 'ohne Laststoß keine Laststoß-Kennzahlen');
            tc.verifyTrue(K.final.valid);
            tc.verifyEqual(K.final.n, 1000, 'AbsTol', 1e-12);
            tc.verifyTrue(K.final.settled);
            tc.verifyEqual(K.startup.t_target, 0.9, 'AbsTol', 1e-12);
        end

        function bandBoundaryCountsAsInside(tc)
            % final window [1, 2] with a ramp 999 -> 1001: mean 1000, max deviation exactly 1 = band
            K = asmtools.speed_metrics([0 1 2], [999 999 1001], cfg(500, 'window', 1, 'band', 1));
            tc.verifyEqual(K.final.n, 1000, 'AbsTol', 1e-12);
            tc.verifyEqual(K.final.max_dev, 1, 'AbsTol', 1e-12);
            tc.verifyTrue(K.final.settled, 'Abweichung gleich Bandbreite gilt als innerhalb');
        end

        function endWindowTooShort(tc)
            % data cover only 30 ms, window 50 ms: no steady value
            K = asmtools.speed_metrics([0 0.01 0.03], [0 500 1000], cfg(900, 'window', 0.05));
            tc.verifyFalse(K.final.valid);
            tc.verifyTrue(isnan(K.final.n));
            tc.verifyFalse(K.final.settled);
            tc.verifySubstring(char(K.final.reason), 'zu kurz');
        end

        function loadStepShortlyBeforeEnd(tc)
            % step at 1.98 s, final window 50 ms would start at 1.95 s, i.e. before the step
            t = [0 1 1.98 1.99 2.0];  n = [1000 1000 1000 980 980];
            K = asmtools.speed_metrics(t, n, cfg(900, 'step', 1.98, 'window', 0.05));
            S = K.step;
            tc.verifyEqual(S.n_before, 1000, 'AbsTol', 1e-12, 'Fenster [1,93; 1,98] s vor dem Stoß');
            tc.verifyTrue(S.settled_before);
            tc.verifyFalse(S.final_valid);
            tc.verifyTrue(isnan(S.n_new) && isnan(S.dn_static) && isnan(S.undershoot), 'kein Mischwert');
            tc.verifyFalse(S.settled);
            tc.verifyTrue(isnan(S.t_settle));
            tc.verifySubstring(char(S.reason), 'überlappt');
        end

        function preStepWindowRespectsMargin(tc)
            % the speed starts to drop 15 ms before the nominal step (smoothed step); with a margin
            % of 20 ms the window [0.88, 0.98] s sees only the undisturbed 1000 rpm
            t = [0 0.985 1.0 1.5 2];  n = [1000 1000 990 990 990];
            K = asmtools.speed_metrics(t, n, cfg(900, 'step', 1, 'window', 0.1, 'margin', 0.02));
            tc.verifyEqual(K.step.n_before, 1000, 'AbsTol', 1e-12);
            tc.verifyEqual(K.before_step.t1, 0.98, 'AbsTol', 1e-12);
            tc.verifyEqual(K.startup.t_search_end, 0.98, 'AbsTol', 1e-12);
        end

        %% load step: extremes and settling
        function bandEntryExitAndPermanentReentry(tc)
            % 1000 -> enters the band at 979.5 (t = 1.1), leaves it at 978.5 (t = 1.2), re-enters
            % permanently on the way to 980.5 (t = 1.3); new operating point 980, band 1
            t = [0 1.0 1.1 1.2 1.3 1.6 2.0];  n = [1000 1000 979.5 978.5 980.5 980 980];
            K = asmtools.speed_metrics(t, n, cfg(900, 'step', 1, 'window', 0.2, 'band', 1));
            S = K.step;
            tc.verifyEqual(S.n_before, 1000, 'AbsTol', 1e-12);
            tc.verifyEqual(S.n_new, 980, 'AbsTol', 1e-12);
            tc.verifyEqual([S.n_min S.t_min], [978.5 1.2], 'AbsTol', 1e-12);
            tc.verifyEqual(S.dn_dip, 21.5, 'AbsTol', 1e-12, 'Einbruch n_vor - n_min');
            tc.verifyEqual(S.undershoot, 1.5, 'AbsTol', 1e-12, 'Unterschwingen n_neu - n_min');
            tc.verifyEqual(S.dn_static, 20, 'AbsTol', 1e-12);
            tc.verifyTrue(S.settled);
            % last entry: boundary 979 between (1.2, 978.5) and (1.3, 980.5) -> t = 1.225 s
            tc.verifyEqual(S.t_settle, 0.225, 'AbsTol', 1e-12, 'erster Eintritt bei 1,09 s zählt nicht');
        end

        function noPermanentSettling(tc)
            % after the step a sustained oscillation of +-3 rpm around 980 rpm, band 1 rpm
            t = (0:1e-3:2)';
            n = 1000*ones(size(t));
            k = t > 1;
            n(k) = 980 + 3*sin(2*pi*10*(t(k) - 1));
            K = asmtools.speed_metrics(t, n, cfg(900, 'step', 1, 'window', 0.2, 'band', 1));
            tc.verifyFalse(K.step.settled, 'Band im Endfenster nicht gehalten');
            tc.verifyTrue(isnan(K.step.t_settle), '"nicht eingeschwungen": keine Einschwingzeit');
            tc.verifyEqual(K.final.max_dev, 3, 'AbsTol', 1e-3);
            tc.verifyEqual(K.step.n_new, 980, 'AbsTol', 1e-6, 'Mittel über zwei ganze Perioden');
        end

        function loadDecrease(tc)
            % load decrease: speed rises 1000 -> 1020 with overshoot to 1023 rpm
            t = [0 1 1.1 1.3 2];  n = [1000 1000 1023 1020 1020];
            K = asmtools.speed_metrics(t, n, cfg(900, 'step', 1, 'window', 0.2, 'band', 1, 'sign', -1));
            S = K.step;
            tc.verifyEqual(S.step_sign, -1);
            tc.verifyEqual([S.n_max S.t_max], [1023 1.1], 'AbsTol', 1e-12);
            tc.verifyEqual(S.overshoot, 3, 'AbsTol', 1e-12, 'Überschwingen n_max - n_neu');
            tc.verifyEqual(S.dn_static, -20, 'AbsTol', 1e-12);
            % last exit: (1.1, 1023) outside, boundary 1021 reached at 1.1 + 0.2*2/3 s
            tc.verifyEqual(S.t_settle, 0.1 + 0.2*2/3, 'AbsTol', 1e-12);
        end

        function stepInsideBandSettlesImmediately(tc)
            % a step smaller than the band: the band is never left after the step
            t = [0 1 1.1 2];  n = [1000 1000 999.5 999.5];
            K = asmtools.speed_metrics(t, n, cfg(900, 'step', 1, 'window', 0.2, 'band', 1));
            tc.verifyTrue(K.step.settled);
            tc.verifyEqual(K.step.t_settle, 0, 'AbsTol', 1e-12);
        end

        %% invalid inputs
        function invalidInputs(tc)
            tc.verifyError(@() asmtools.speed_metrics([0 2 1], [0 1 2], cfg(1)), 'asmtools:metrics', ...
                'Zeit nicht monoton');
            tc.verifyError(@() asmtools.speed_metrics([0 1 1], [0 1 2], cfg(1)), 'asmtools:metrics', ...
                'doppelter Zeitpunkt');
            tc.verifyError(@() asmtools.speed_metrics([0 1 2], [0 NaN 2], cfg(1)), 'asmtools:metrics', 'NaN');
            tc.verifyError(@() asmtools.speed_metrics([0 1 2], [0 1], cfg(1)), 'asmtools:metrics', 'Längen');
            tc.verifyError(@() asmtools.speed_metrics(0, 0, cfg(1)), 'asmtools:metrics', 'nur ein Wert');
            c = cfg(1);  c.band = 0;
            tc.verifyError(@() asmtools.speed_metrics([0 1 2], [0 1 2], c), 'asmtools:metrics', 'Band 0');
        end

        %% operating point (no simulation)
        function operatingPointStandstill(tc)
            % constant load above the starting torque, smoothed as in the load block: the formal
            % intersection lies at a creeping speed and must be marked as standstill
            P = asm_standard();
            Mm = @(n) asmtools.kloss_torque((P.ns - n)/P.ns, P.MK, P.sK);
            ML = @(n) 30*tanh(n*2*pi/60/0.1);
            op = asmtools.operating_point(Mm, ML, P.ns, 0);
            tc.verifyTrue(op.found);
            tc.verifyLessThan(op.n, 2, 'Kriechdrehzahl in der Glättungszone');
            tc.verifyTrue(op.standstill);
            tc.verifyFalse(op.reachable, 'kein erreichbarer stabiler Arbeitspunkt im Motorbereich');
        end
    end
end

function c = cfg(n_target, varargin)
% metric configuration; defaults: no step, window 0.5 s, band 1 rpm, margin 0, load increase
p = inputParser;
p.addParameter('step', NaN);  p.addParameter('window', 0.5);  p.addParameter('band', 1);
p.addParameter('margin', 0);  p.addParameter('sign', 1);
p.parse(varargin{:});
c = struct('n_target', n_target, 't_step', p.Results.step, 'window', p.Results.window, ...
           'band', p.Results.band, 'margin', p.Results.margin, 'step_sign', p.Results.sign);
end
