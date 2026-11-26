classdef MechanicsTest < matlab.unittest.TestCase
%MECHANICSTEST Mechanics blocks, torque sensor and speed sensor against analytic solutions.
%   Run-down tests of an inertia with different loads (without motor).
%   Run in the project folder:  startup_asm; runtests('tests')

    properties (Constant)
        J  = 0.01     % moment of inertia [kg*m^2]
        n0 = 1000     % initial speed [rpm]
    end

    methods (TestClassSetup)
        function prepare(~)
            if ~exist('asm_blocks_lib', 'file'), build_library(); end
            load_system('asm_blocks_lib');
        end
    end

    methods (Test)
        function viscousFriction(tc)
            k = 0.01;                                        % tau = J/k = 1 s
            E = run_down(tc, 'Mechanik/Reibung', {'k_R', num2str(k), 'M_C', '0'}, 1);
            tc.verifyEqual(value_at(E.n, 1), tc.n0*exp(-1), 'RelTol', 1e-3, 'n(1 s) = n0·e^(−t/τ)');
        end

        function coulombFrictionAndConstantLoad(tc)
            MC = 0.5;                                        % dn/dt = -M/J
            expected = tc.n0 - MC/tc.J*60/(2*pi)*1;
            E1 = run_down(tc, 'Mechanik/Reibung', {'k_R', '0', 'M_C', num2str(MC)}, 1);
            E2 = run_down(tc, 'Mechanik/Last konstant', {'M_L0', num2str(MC)}, 1);
            tc.verifyEqual(value_at(E1.n, 1), expected, 'RelTol', 1e-3, 'Coulomb-Reibung');
            tc.verifyEqual(value_at(E2.n, 1), expected, 'RelTol', 1e-3, 'Last konstant');
            % torque sensor: the torque flows from the inertia (R) to the load (C)
            tc.verifyEqual(value_at(E2.M, 0.5), MC, 'RelTol', 1e-3, 'Messwelle misst M_L0');
        end

        function fanLoad(tc)
            MB = 26.5;  nB = 1440;                           % J*dw/dt = -k*w^2, k = M_B/w_B^2
            E = run_down(tc, 'Mechanik/Last Lüfter', {'M_B', num2str(MB), 'n_B', num2str(nB)}, 0.1);
            w0 = tc.n0*2*pi/60;  k = MB/(nB*2*pi/60)^2;
            expected = w0/(1 + k*w0*0.1/tc.J)*60/(2*pi);
            tc.verifyEqual(value_at(E.n, 0.1), expected, 'RelTol', 1e-3);
        end

        function tableLoad(tc)
            % linear table M = 26.5 N*m*n/1500 -> exponential run-down
            E = run_down(tc, 'Mechanik/Last Kennlinie', {'n_tab', '[0 1500]', 'M_tab', '[0 26.5]'}, 0.1);
            tau = tc.J/(26.5/(1500*2*pi/60));
            tc.verifyEqual(value_at(E.n, 0.1), tc.n0*exp(-0.1/tau), 'RelTol', 2e-3);
        end

        function loadStep(tc)
            dM = 0.5;
            E = run_down(tc, 'Mechanik/Laststoß', {'t_step', '0.5', 'dM_L', num2str(dM)}, 1);
            tc.verifyEqual(value_at(E.n, 0.49), tc.n0, 'RelTol', 1e-6, 'vor dem Stoß keine Last');
            tc.verifyEqual(value_at(E.n, 1), tc.n0 - dM/tc.J*60/(2*pi)*0.5, 'RelTol', 1e-3, 'nach dem Stoß');
        end

        function speedSensor(tc)
            E = run_down(tc, 'Mechanik/Reibung', {'k_R', '0', 'M_C', '0'}, 0.2);
            tc.verifyEqual(value_at(E.n, 0.2), tc.n0, 'RelTol', 1e-9, 'ohne Last konstante Drehzahl');
            tc.verifyEqual(value_at(E.s, 0.1), (1500 - tc.n0)/1500, 'RelTol', 1e-9, 'Schlupf mit ns = 1500');
            tc.verifyEqual(value_at(E.th, 0.2), tc.n0*2*pi/60*0.2, 'RelTol', 1e-6, 'Drehwinkel');
            tc.verifyEqual(value_at(E.Om, 0.2), tc.n0*2*pi/60, 'RelTol', 1e-9, 'Winkelgeschwindigkeit');
        end

        function elasticShaft(tc)
            % two equal masses, initial speeds n0 and 0: speed of the centre of mass n0/2,
            % torsional oscillation with w_e = sqrt(c*(J1 + J2)/(J1*J2))
            c = 100;
            m = model(tc, 0.5);
            L = 'asm_blocks_lib/';
            add_block([L 'Mechanik/Schwungmasse'], [m '/J2'], 'J', num2str(tc.J), 'n0', '0');
            add_block([L 'Mechanik/Welle elastisch'], [m '/Welle'], 'c_W', num2str(c), 'd_W', '0');
            connect(m, 'J1', 'L', 1, 'Welle', 'L', 1);
            connect(m, 'Welle', 'R', 1, 'J2', 'L', 1);
            E = simulate(m);
            n = E.n(:,2);  t = E.n(:,1);
            tc.verifyEqual(mean(n(t > 0.1)), tc.n0/2, 'RelTol', 0.02, 'Schwerpunktdrehzahl');
            x = n - tc.n0/2;
            tn = t(find(x(1:end-1) > 0 & x(2:end) <= 0));    % falling zero crossings
            f = 1/mean(diff(tn));
            tc.verifyEqual(f, sqrt(c*2*tc.J/tc.J^2)/(2*pi), 'RelTol', 0.01, 'Torsionseigenfrequenz');
        end
    end

    methods (Access = private)
        function E = run_down(tc, load, par, t_end)
            % inertia (n0) -> torque sensor -> load (C at the reference), speed sensor at J
            m = model(tc, t_end);
            add_block(['asm_blocks_lib/' load], [m '/Last'], par{:});
            connect(m, 'Messwelle', 'R', 1, 'Last', 'L', 1);
            connect(m, 'Last', 'R', 1, 'Bezug', 'L', 1);
            E = simulate(m);
        end

        function m = model(tc, t_end)
            % basic model: inertia J1, torque sensor, speed sensor, reference, solver
            L = 'asm_blocks_lib/';
            m = sprintf('asm_mech_%d', randi(1e6));
            new_system(m);
            tc.addTeardown(@() close_system(m, 0));
            set_param(m, 'Solver', 'ode23t', 'StopTime', num2str(t_end), 'RelTol', '1e-7', 'MaxStep', '1e-3', ...
                'ReturnWorkspaceOutputs', 'on');
            add_block([L 'Mechanik/Schwungmasse'], [m '/J1'], 'J', num2str(tc.J), 'n0', num2str(tc.n0));
            add_block([L 'Messgeräte/Drehmomentmesswelle'], [m '/Messwelle']);
            add_block([L 'Messgeräte/Drehzahlmesser'], [m '/Tacho'], 'ns', '1500');
            add_block([L 'Mechanik/Mechanischer Bezug'], [m '/Bezug']);
            add_block('nesl_utility/Solver Configuration', [m '/Solver']);
            connect(m, 'J1', 'L', 1, 'Messwelle', 'L', 1);
            connect(m, 'J1', 'L', 1, 'Tacho', 'L', 1);
            connect(m, 'Tacho', 'R', 1, 'Bezug', 'L', 1);
            connect(m, 'Solver', 'R', 1, 'Bezug', 'L', 1);
            names = {'Tacho', {'n', 'Om', 'th', 's'}; 'Messwelle', {'M'}};
            for z = 1:2
                for k = 1:numel(names{z, 2})
                    add_block('simulink/Sinks/To Workspace', [m '/TW_' names{z,2}{k}], ...
                        'VariableName', names{z,2}{k}, 'SaveFormat', 'Timeseries', 'MaxDataPoints', 'inf');
                    add_line(m, sprintf('%s/%d', names{z,1}, k), ['TW_' names{z,2}{k} '/1']);
                end
            end
        end
    end
end

function E = simulate(m)
out = sim(m, 'TimeOut', 60);
for nm = {'n', 'Om', 'th', 's', 'M'}
    ts = out.get(nm{1});
    E.(nm{1}) = [ts.Time(:), squeeze(ts.Data)];
end
end

function connect(m, a, sa, na, b, sb, nb)
pa = get_param([m '/' a], 'PortHandles');  pb = get_param([m '/' b], 'PortHandles');
if sa == 'L', ha = pa.LConn(na); else, ha = pa.RConn(na); end
if sb == 'L', hb = pb.LConn(nb); else, hb = pb.RConn(nb); end
add_line(m, ha, hb, 'autorouting', 'on');
end

function y = value_at(x, t)
[tt, iu] = unique(x(:,1), 'last');
y = interp1(tt, x(iu,2), t);
end
