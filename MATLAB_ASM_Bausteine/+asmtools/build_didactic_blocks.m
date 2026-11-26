function ok = build_didactic_blocks(blk, b)
%BUILD_DIDACTIC_BLOCKS Content of the didactic blocks and the conductor loop (called by build_library).
%   ok = asmtools.build_didactic_blocks(blk, b)  builds the content of subsystem blk for catalogue
%   entry b and returns true; false for other blocks (build_library then builds a placeholder).
%   Computational kernels: MATLAB System blocks (interpreted, no C compiler needed) with the
%   System objects asmtools.IdealRotatingField, asmtools.RotorBarProbe, asmtools.ConductorLoop.
%   Inputs and outputs are named as in the catalogue; parameters are the mask variables.

ok = true;
switch b.id
    case 'ideal_field'
        add_block('simulink/Sources/Clock', [blk '/Clock'], 'Position', [40 100 70 130]);
        sys = system_block(blk, 'Field', 'asmtools.IdealRotatingField', ...
            {'Bhat', 'f1', 'p', 's', 'l', 'r', 'N1xi1', 'N2', 'R2_S', 'L2s_S', 'phi2_fix'}, ...
            {'mode', 'phi2_mode'});
        add_line(blk, 'Clock/1', 'Field/1');
        connect_outputs(blk, b, sys, 1:5);

    case 'rotor_bar_probe'
        add_inports(blk, b);
        system_block(blk, 'Probe', 'asmtools.RotorBarProbe', {'p', 'N2', 'l', 'r', 'N1xi1', 'k1', 'k2'}, ...
            {'bar1_angle', 'bar1_angle*pi/180', 'slide_convention', 'convention == 1'});
        for k = 1:3, add_line(blk, sprintf('%s/1', b.inputs(k).name), sprintf('Probe/%d', k)); end
        % outputs: 6 direct, dB_perp via Derivative of B_perp, then sgn_i, phi2, M_sum
        add_block('simulink/Continuous/Derivative', [blk '/dBdt'], 'Position', [520 300 550 330]);
        add_line(blk, 'Probe/6', 'dBdt/1');
        src = {'Probe/1', 'Probe/2', 'Probe/3', 'Probe/4', 'Probe/5', 'Probe/6', 'dBdt/1', ...
               'Probe/7', 'Probe/8', 'Probe/9'};
        add_outports(blk, b, src);

    case 'field_display'
        add_inports(blk, b);
        add_block('simulink/Signal Routing/Mux', [blk '/Mux'], 'Inputs', '[2 2 1]', 'Position', [200 40 205 160]);
        for k = 1:3, add_line(blk, sprintf('%s/1', b.inputs(k).name), sprintf('Mux/%d', k)); end
        add_block('simulink/Sinks/To Workspace', [blk '/Log'], 'Position', [260 85 360 115], ...
            'VariableName', 'field_display_log', 'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf');
        add_line(blk, 'Mux/1', 'Log/1');

    case 'coil_fields'
        add_inports(blk, b);
        c = 'p*Lh/(2*N1xi1*l*r)';                            % Bhat per A of space-vector current
        add_block('simulink/Math Operations/Gain', [blk '/f_BUVW'], 'Position', [200 30 260 60], ...
            'Gain', [c '*2/3']);
        add_block('simulink/User-Defined Functions/Fcn', [blk '/f_Bhat'], 'Position', [200 90 300 120], ...
            'Expr', [c '*sqrt((2/3*(u(1)-u(2)/2-u(3)/2))^2 + ((u(2)-u(3))/sqrt(3))^2)']);
        add_block('simulink/User-Defined Functions/Fcn', [blk '/f_phi'], 'Position', [200 150 300 180], ...
            'Expr', 'atan2((u(2)-u(3))/sqrt(3), 2/3*(u(1)-u(2)/2-u(3)/2))');
        for z = {'f_BUVW', 'f_Bhat', 'f_phi'}, add_line(blk, 'i_abc/1', [z{1} '/1']); end
        add_outports(blk, b, {'f_BUVW/1', 'f_Bhat/1', 'f_phi/1'});

    case 'torque_speed_recorder'
        add_inports(blk, b);
        add_block('simulink/Signal Routing/Mux', [blk '/Mux'], 'Inputs', '3', 'Position', [200 40 205 160]);
        for k = 1:3, add_line(blk, sprintf('%s/1', b.inputs(k).name), sprintf('Mux/%d', k)); end
        add_block('simulink/Sinks/To Workspace', [blk '/Log'], 'Position', [260 85 360 115], ...
            'VariableName', 'torque_speed_log', 'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf');
        add_line(blk, 'Mux/1', 'Log/1');

    case 'conductor_loop'
        add_inports(blk, b);
        add_block('simulink/Math Operations/Gain', [blk '/w1'], 'Gain', '2*pi*f1', 'Position', [120 120 160 150]);
        add_block('simulink/Continuous/Integrator', [blk '/Int_theta2'], 'Position', [200 120 230 150]);
        add_line(blk, 's/1', 'w1/1');
        add_line(blk, 'w1/1', 'Int_theta2/1');
        system_block(blk, 'Loop', 'asmtools.ConductorLoop', ...
            {'Bhat', 'l', 'r', 'f1', 'p', 'R2_S', 'L2s_S', 'phi2_fix'}, ...
            {'conv', '3 - 2*conv_phi2', 'mode', 'phi2_mode'});
        add_line(blk, 's/1', 'Loop/1');
        add_line(blk, 'Int_theta2/1', 'Loop/2');
        add_outports(blk, b, [arrayfun(@(k) sprintf('Loop/%d', k), 1:8, 'UniformOutput', false), {'Int_theta2/1'}]);

    otherwise
        ok = false;
end
end

%% ========================= helper functions =========================
function add_inports(blk, b)
for k = 1:numel(b.inputs)
    add_block('simulink/Sources/In1', [blk '/' b.inputs(k).name], ...
        'Position', [40, 40 + 60*(k-1), 70, 54 + 60*(k-1)], 'Port', num2str(k));
end
end

function sys = system_block(blk, name, class_name, same_name, expressions)
% MATLAB System block (interpreted); properties = mask variables of the same name or expressions
sys = [blk '/' name];
add_block('simulink/User-Defined Functions/MATLAB System', sys, 'Position', [300 40 420 340], ...
    'System', class_name, 'SimulateUsing', 'Interpreted execution');
for k = 1:numel(same_name), set_param(sys, same_name{k}, same_name{k}); end
for k = 1:2:numel(expressions), set_param(sys, expressions{k}, expressions{k+1}); end
end

function connect_outputs(blk, b, sys, idx)
[~, name] = fileparts(sys);
add_outports(blk, b, arrayfun(@(k) sprintf('%s/%d', name, k), idx, 'UniformOutput', false));
end

function add_outports(blk, b, src)
for k = 1:numel(b.outputs)
    add_block('simulink/Sinks/Out1', [blk '/' b.outputs(k).name], ...
        'Position', [700, 40 + 50*(k-1), 730, 54 + 50*(k-1)], 'Port', num2str(k));
    add_line(blk, src{k}, [b.outputs(k).name '/1'], 'autorouting', 'on');
end
end
