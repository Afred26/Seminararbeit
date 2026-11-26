function info = build_library()
%BUILD_LIBRARY Builds the ASM block library completely by script.
%   info = build_library() creates in folder lib/
%     asmlib_lib.slx      Simscape library from the .ssc sources in +asmlib (sscbuild)
%     asm_blocks_lib.slx  main library with the sub-libraries Quellen, Maschine, Mechanik,
%                         Messgeräte, Didaktik, Referenz (shown in the Library Browser)
%   Both files are generated and must not be edited by hand.
%
%   Basis is the block catalogue asmtools.catalog (ports, masks, value ranges, help texts).
%   Every block is a masked subsystem (Simulink.Mask):
%     physical   Simscape component from +asmlib, physical connections via Connection Ports,
%                outputs via PS-Simulink converters
%     compact    decomposed motor (terminal box, stator, air-gap field, squirrel cage)
%     fl         block of the Simscape Foundation Library
%     simulink   plain Simulink subsystem
%   Block names, mask prompts and help texts are German (shown to the user).
%
%   Returns info: struct with file names, number of blocks and build time.

t0 = tic;
root = fileparts(mfilename('fullpath'));
libdir = fullfile(root, 'lib');
if ~exist(libdir, 'dir'), mkdir(libdir); end
addpath(root, libdir, fullfile(root, 'parameter'));

main    = 'asm_blocks_lib';
ssclib  = 'asmlib_lib';
file    = fullfile(libdir, [main '.slx']);
sscfile = fullfile(libdir, [ssclib '.slx']);

% close open libraries, remove old files
for m = {main, ssclib}
    if bdIsLoaded(m{1}), close_system(m{1}, 0); end
end
for f = {file, sscfile}
    if exist(f{1}, 'file'), delete(f{1}); end
end

%% 1 Simscape library from +asmlib
old_folder = cd(root);
restore    = onCleanup(@() cd(old_folder));
if exist('sscbuild', 'file')                         % from R2024b
    sscbuild('asmlib', '-output', sscfile);
else                                                 % R2023b ... R2024a
    ssc_build('asmlib');
    movefile(fullfile(root, [ssclib '.slx']), sscfile);
end
load_system(ssclib);
source = ssc_blocks(ssclib);                         % component path -> library block

%% 2 main library
K = asmtools.catalog();
new_system(main, 'Library');
set_param(main, 'EnableLBRepository', 'on');        % show in the Library Browser
set_param(main, 'Description', ['ASM-Bausteinbibliothek (Drehstrom-Asynchronmotor), ' ...
    'Seminararbeit DHBW Mannheim. Generiert mit build_library.m - nicht von Hand bearbeiten.']);

categories = fieldnames(asmtools.category_style());
for i = 1:numel(categories)
    cat_id = categories{i};
    st  = asmtools.category_style(cat_id);
    sub = [main '/' st.display];
    add_block('built-in/Subsystem', sub, 'Position', [40 + 140*(i-1), 40, 140 + 140*(i-1), 110]);
    mo = Simulink.Mask.create(sub);                  % sub-library as in fl_lib: masked, without parameters
    mo.Display = sprintf('disp(''%s'');', st.display);
    set_param(sub, 'ShowName', 'off', 'BackgroundColor', colour(st.background), ...
                   'ForegroundColor', colour(st.foreground));

    Kc = K(strcmp({K.category}, cat_id));
    y  = 40;
    for j = 1:numel(Kc)
        h = block_height(Kc(j));
        x = 60 + 260*mod(j-1, 3);
        if j > 1 && mod(j-1, 3) == 0, y = y + row_height + 70; end
        if mod(j-1, 3) == 0, row_height = 0; end
        row_height = max(row_height, h);
        build_block([sub '/' Kc(j).name], Kc(j), [x, y, x + 130, y + h], source);
    end
end

set_param(main, 'Lock', 'on');
save_system(main, file);
close_system(main, 0);
close_system(ssclib, 0);

info = struct('library', file, 'simscape_library', sscfile, ...
              'count', numel(K), 'build_time_s', toc(t0));
fprintf('build_library: %d Bausteine in %.1f s -> %s\n', info.count, info.build_time_s, file);
end

%% ========================= blocks =========================
function build_block(blk, b, pos, source)
% create masked subsystem with content, ports, mask and colour
add_block('built-in/Subsystem', blk, 'Position', pos);
st = asmtools.category_style(b.category);

switch b.kind
    case 'physical'
        inner = [blk '/' b.id];
        add_block(source(b.ssc), inner, 'Position', [200 40 300 40 + block_height(b)]);
        connect_ports(blk, b, inner);
        connect_outputs(blk, b, inner);
        pass_parameters(inner, {b.par.name});
    case 'fl'
        inner = [blk '/' b.id];
        add_block(b.ssc, inner, 'Position', [200 40 240 80]);
        connect_ports(blk, b, inner);
    case 'compact'
        build_compact(blk, b, source);
    case 'ee'
        build_ee_reference(blk, b);
    case 'simulink'
        build_simulink(blk, b);
end

% mask
mo = Simulink.Mask.create(blk);
mo.Type        = ['ASM-Bibliothek: ' b.name];
mo.Description = mask_text(b, false);
mo.Help        = mask_text(b, true);
mo.IconUnits   = 'normalized';
mo.IconOpaque  = 'opaque';
mo.Display     = asmtools.icon(b);
for p = b.par
    add_mask_parameter(mo, p);
end
if strcmp(b.kind, 'simulink')                       % MATLAB System properties are not tunable
    for q = mo.Parameters, q.Tunable = 'off'; end
end
init = {};
if any(strcmp({b.par.name}, 'param_set'))
    ps = mo.getParameter('param_set');
    ps.Callback = 'asmtools.param_set_callback(gcb);';
    S = asm_standard();
    std = {};
    for p = b.par                                     % standard: fields disabled
        if strcmp(p.type, 'edit') && isfield(S, p.name)
            q = mo.getParameter(p.name);
            q.Enabled = 'off';
            std{end+1} = sprintf('%s = S.%s;', p.name, p.name); %#ok<AGROW>
        end
    end
    % With "Standard" the values from asm_standard.m always apply, even if a field was
    % changed programmatically. run_asm therefore always passes "Benutzerdefiniert" together
    % with explicit values, so that a simulation never depends on this file implicitly.
    init = [init, {'% parameter set "Standard": values from parameter/asm_standard.m', ...
                   'if param_set == 1', '    S = asm_standard();', ['    ' strjoin(std, ' ')], 'end'}];
end
if strcmp(b.kind, 'compact')
    init = [init, {'% effective number of turns from the air-gap flux density at the rated point', ...
                   'N1xi1 = p*(U_N/sqrt(3)*sqrt(2)/(2*pi*f_N))/(2*Bhat_N*l*r);'}];
end
mo.Initialization = strjoin(init, newline);
% buttons for the evaluation after the simulation (German labels)
buttons = struct('field_display', {{'Animation zeigen', 'asmtools.field_animation(gcb);'}}, ...
                 'torque_speed_recorder', {{'Kennlinie zeichnen', 'asmtools.torque_speed_plot(gcb);'}});
if isfield(buttons, b.id)
    k = buttons.(b.id);
    mo.addDialogControl('Type', 'pushbutton', 'Name', 'evaluation_button', 'Prompt', k{1}, 'Callback', k{2});
end
set_param(blk, 'BackgroundColor', colour(st.background), 'ForegroundColor', colour(st.foreground), ...
               'Tag', ['asmlib:' b.id]);
end

function build_compact(blk, b, source)
% ASM Standard: decomposed motor under the mask (inner block names German, shown with Ctrl+U)
tb = [blk '/Klemmbrett'];  stt = [blk '/Stator'];
ag = [blk '/Luftspalt-Drehfeld'];  sc = [blk '/Käfigläufer'];
add_block(source('asmlib.machine.terminal_box'),  tb,  'Position', [160  60 260 260]);
add_block(source('asmlib.machine.stator'),        stt, 'Position', [360  60 460 260]);
add_block(source('asmlib.machine.airgap_field'),  ag,  'Position', [560 300 660 400]);
add_block(source('asmlib.machine.squirrel_cage'), sc,  'Position', [760  60 860 260]);
pk = get_param(tb, 'PortHandles'); ps = get_param(stt, 'PortHandles');
pa = get_param(ag, 'PortHandles'); pr = get_param(sc, 'PortHandles');
for k = 1:6
    add_line(blk, pk.RConn(k), ps.LConn(k), 'autorouting', 'on');   % U1 ... W2
end
add_line(blk, ps.RConn(1), pr.LConn(1), 'autorouting', 'on');       % stator LS - squirrel cage LS
add_line(blk, pa.LConn(1), pr.LConn(1), 'autorouting', 'on');       % air gap LS
% outer connections: a, b, c to the terminal box, R, C to the squirrel cage
target = {pk.LConn(1), pk.LConn(2), pk.LConn(3), pr.RConn(1), pr.RConn(2)};
cp = connection_ports(blk, b);
for k = 1:numel(cp)
    add_line(blk, port_of(cp(k)), target{k}, 'autorouting', 'on');
end

% mask parameters to the sub-blocks (N1xi1 is computed by the mask initialization)
names = [{b.par.name}, {'N1xi1'}];
for inner = {tb, stt, ag, sc}
    pass_parameters(inner{1}, names);
end

% measurement bus: name | sub-block | right port | unit  (sub-block '' = computed in Simulink)
% right ports: stator [LS i1 u1], air gap [psi_h Bhat i_mu], squirrel cage [R C i2b M Om th_mech s psi_h]
sources = { 'i1',      stt, 2, 'A';      'u1',      stt, 3, 'V'
            'psi_h',   ag,  1, 'Wb';     'phi_el',  '',  0, ''
            'Bhat',    ag,  2, 'T';      'i_mu',    ag,  3, 'A'
            'i2b',     sc,  3, 'A';      'M',       sc,  4, 'N*m'
            'n',       sc,  5, 'rpm';    'Om',      sc,  5, 'rad/s'
            'th_mech', sc,  6, 'rad';    'theta2',  '',  0, ''
            's',       sc,  7, '1' };
nb = size(sources, 1);
bc = [blk '/MeasBus'];
add_block('simulink/Signal Routing/Bus Creator', bc, 'Inputs', num2str(nb), ...
          'Position', [1180 60 1185 60 + 30*nb]);
for k = 1:nb                                              % converters for the Simscape outputs
    if isempty(sources{k,2}), continue; end
    w = [blk '/PS_' sources{k,1}];
    add_block('nesl_utility/PS-Simulink Converter', w, 'Unit', sources{k,4}, ...
              'Position', [1040, 55 + 30*k, 1060, 75 + 30*k]);
    pq = get_param(sources{k,2}, 'PortHandles');
    pw = get_param(w, 'PortHandles');
    add_line(blk, pq.RConn(sources{k,3}), pw.LConn(1), 'autorouting', 'on');
end
% angles in Simulink (atan2 in Simscape would create solver events)
add_block('simulink/User-Defined Functions/Fcn', [blk '/PS_phi_el'], 'Expr', 'atan2(u(2),u(1))', ...
          'Position', [1100, 145, 1150, 165]);
add_line(blk, 'PS_psi_h/1', 'PS_phi_el/1', 'autorouting', 'on');
add_block('simulink/Signal Routing/Mux', [blk '/mux_theta2'], 'Inputs', '2', 'Position', [1080, 400, 1085, 440]);
add_block('simulink/User-Defined Functions/Fcn', [blk '/PS_theta2'], ...
          'Expr', 'atan2(sin(atan2(u(2),u(1)) - p*u(3)), cos(atan2(u(2),u(1)) - p*u(3)))', ...
          'Position', [1100, 410, 1150, 430]);
add_line(blk, 'PS_psi_h/1', 'mux_theta2/1', 'autorouting', 'on');
add_line(blk, 'PS_th_mech/1', 'mux_theta2/2', 'autorouting', 'on');
add_line(blk, 'mux_theta2/1', 'PS_theta2/1');
for k = 1:nb
    h = add_line(blk, ['PS_' sources{k,1} '/1'], ['MeasBus/' num2str(k)], 'autorouting', 'on');
    set_param(h, 'Name', sources{k,1});
end
add_block('simulink/Sinks/Out1', [blk '/Mess'], 'Position', [1240 200 1270 214]);
add_line(blk, 'MeasBus/1', 'Mess/1');
end

function pass_parameters(inner, names)
% set parameters of the inner Simscape component to the mask variables of the same name
dp = fieldnames(get_param(inner, 'DialogParameters'));
for k = 1:numel(names)
    if any(strcmp(dp, names{k}))
        set_param(inner, names{k}, names{k});
    end
end
end

function build_ee_reference(blk, b)
% ASM Referenz: ee_lib Induction Machine Squirrel Cage with the same EC values (SI), star with
% floating star point, J_M as inertia at the shaft. Parameters as expressions of the mask variables.
nl = newline;
im = [blk '/Maschine'];
add_block(b.ssc, im, 'Position', [300 80 420 200], ...
    'SRated', 'sqrt(3)*U_N*10', 'VRated', 'U_N', 'FRated', 'f_N', 'nPolePairs', 'p', ...
    'param_unit', 'ee.enum.unit.si', 'squirrel_cage', 'ee.enum.squirrelcage.Single', ...
    'zero_sequence', 'ee.enum.park.zerosequence.include', ...
    'Rs', 'R1', 'Xls', '2*pi*f_N*L1s', 'Rrd', 'R2b', 'Xlrd', '2*pi*f_N*L2sb', 'Xm', '2*pi*f_N*Lh', ...
    'X0', '2*pi*f_N*L1s', 'saturation_option', 'ee.enum.saturation.exclude', ...
    'initialization_option', 'ee.enum.asm.initialization.fluxvariables');
for v = {'psids', 'psiqs', 'psidr', 'psiqr'}                 % start currentless
    set_param(im, [v{1} '_specify'], 'on', [v{1} '_priority'], 'High', v{1}, '0');
end
add_block('ee_lib/Connectors & References/Phase Splitter', [blk '/Leiter'], 'Position', [160 100 200 180]);
add_block(['ee_lib/Connectors &' nl 'References/Floating Neutral' nl '(Three-Phase)'], [blk '/Sternpunkt'], ...
          'Position', [480 200 520 240]);
add_block('fl_lib/Mechanical/Rotational Elements/Inertia', [blk '/J_M'], 'Position', [480 40 540 80], ...
          'inertia', 'J_M');
ps = get_param([blk '/Leiter'], 'PortHandles');  pm = get_param(im, 'PortHandles');
pn = get_param([blk '/Sternpunkt'], 'PortHandles');  pj = get_param([blk '/J_M'], 'PortHandles');
cp = connection_ports(blk, b);                               % a, b, c, R, C
for k = 1:3
    add_line(blk, port_of(cp(k)), ps.RConn(k), 'autorouting', 'on');
end
add_line(blk, ps.LConn(1), pm.RConn(2), 'autorouting', 'on');   % stator ~1
add_line(blk, pm.RConn(3), pn.LConn(1), 'autorouting', 'on');   % winding end ~2 -> star
add_line(blk, port_of(cp(4)), pm.LConn(1), 'autorouting', 'on');  % shaft R
add_line(blk, port_of(cp(5)), pm.LConn(2), 'autorouting', 'on');  % housing C
add_line(blk, pj.LConn(1), pm.LConn(1), 'autorouting', 'on');
end

function build_simulink(blk, b)
% didactic blocks and conductor loop: asmtools.build_didactic_blocks. Otherwise placeholder
% (inputs -> terminator, outputs <- constant zero); recorder: input -> scope
if asmtools.build_didactic_blocks(blk, b), return; end
for k = 1:numel(b.inputs)
    e = b.inputs(k);
    add_block('simulink/Sources/In1', [blk '/' e.name], 'Position', [40, 40 + 60*(k-1), 70, 54 + 60*(k-1)], ...
              'Port', num2str(k));
    if strcmp(b.id, 'recorder')
        add_block('simulink/Sinks/Scope', [blk '/Scope'], 'Position', [140, 25 + 60*(k-1), 180, 69 + 60*(k-1)]);
        add_line(blk, [e.name '/1'], 'Scope/1');
    else
        add_block('simulink/Sinks/Terminator', [blk '/T_' e.name], 'Position', [140, 37 + 60*(k-1), 160, 57 + 60*(k-1)]);
        add_line(blk, [e.name '/1'], ['T_' e.name '/1']);
    end
end
for k = 1:numel(b.outputs)
    a = b.outputs(k);
    add_block('simulink/Sources/Constant', [blk '/Zero_' a.name], ...
              'Position', [240, 35 + 60*(k-1), 300, 65 + 60*(k-1)], 'Value', zero_value(a.width));
    add_block('simulink/Sinks/Out1', [blk '/' a.name], 'Position', [380, 40 + 60*(k-1), 410, 54 + 60*(k-1)], ...
              'Port', num2str(k));
    add_line(blk, ['Zero_' a.name '/1'], [a.name '/1']);
end
end

function connect_ports(blk, b, inner)
% connect the Connection Ports of the subsystem with the nodes of the inner component.
% Order at the component: left = LConn in catalogue order, right = RConn.
ph = get_param(inner, 'PortHandles');
cp = connection_ports(blk, b);
nl = 0; nr = 0;
for k = 1:numel(b.ports)
    if strcmp(b.ports(k).side, 'left') || isempty(ph.RConn)
        nl = nl + 1; target = conn(ph, 'L', nl);
    else
        nr = nr + 1; target = conn(ph, 'R', nr);
    end
    add_line(blk, port_of(cp(k)), target, 'autorouting', 'on');
end
end

function connect_outputs(blk, b, inner)
% PS outputs (raw signals) of the component (right, after the nodes) -> PS-Simulink converters.
% Outputs of the block: either a raw signal directly or a derived expression (b.derived) of
% moving means <x> = f_meas*(X(t) - X(t - 1/f_meas)), X = int x dt.
ph = get_param(inner, 'PortHandles');
nright = sum(strcmp({b.ports.side}, 'right'));
for k = 1:numel(b.raw)
    r = b.raw(k);
    y = 40 + 50*(k-1);
    add_block('nesl_utility/PS-Simulink Converter', [blk '/PS_' r.name], 'Position', [420, y, 440, y + 20], ...
              'Unit', r.unit);
    pw = get_param([blk '/PS_' r.name], 'PortHandles');
    add_line(blk, ph.RConn(nright + k), pw.LConn(1), 'autorouting', 'on');
end
averaged = {};
for k = 1:numel(b.outputs)
    a = b.outputs(k);
    y = 40 + 50*(k-1);
    add_block('simulink/Sinks/Out1', [blk '/' a.name], 'Position', [1000, y + 3, 1030, y + 17], ...
              'Port', num2str(k));
    j = find(strcmp({b.derived.name}, a.name));
    if isempty(j)
        add_line(blk, ['PS_' a.name '/1'], [a.name '/1']);
        continue;
    end
    m = b.derived(j);
    if strcmp(m.kind, 'mean')
        for r = m.raw                                     % one moving mean per raw signal
            if ~any(strcmp(averaged, r{1}))
                moving_mean(blk, r{1}, y);
                averaged{end+1} = r{1}; %#ok<AGROW>
            end
        end
        prefix = 'M_';                                    % inputs: moving means
    else
        prefix = 'PS_';                                   % inputs: raw signals directly
    end
    fcn = [blk '/f_' a.name];
    add_block('simulink/User-Defined Functions/Fcn', fcn, 'Expr', m.expr, 'Position', [880, y, 950, y + 24]);
    if isscalar(m.raw)
        add_line(blk, [prefix m.raw{1} '/1'], ['f_' a.name '/1'], 'autorouting', 'on');
    else
        mux = [blk '/mux_' a.name];
        add_block('simulink/Signal Routing/Mux', mux, 'Inputs', num2str(numel(m.raw)), ...
                  'Position', [840, y - 10, 845, y + 34]);
        for i = 1:numel(m.raw)
            add_line(blk, [prefix m.raw{i} '/1'], sprintf('mux_%s/%d', a.name, i), 'autorouting', 'on');
        end
        add_line(blk, ['mux_' a.name '/1'], ['f_' a.name '/1']);
    end
    add_line(blk, ['f_' a.name '/1'], [a.name '/1']);
end
end

function moving_mean(blk, r, y)
% moving mean over one period 1/f_meas: f_meas*(X(t) - X(t - T)), X = int x dt
add_block('simulink/Continuous/Integrator', [blk '/I_' r], 'Position', [500, y, 530, y + 30]);
add_block('simulink/Continuous/Transport Delay', [blk '/T_' r], 'Position', [570, y + 40, 610, y + 70], ...
          'DelayTime', '1/f_meas', 'InitialOutput', '0', 'BufferSize', '16384');
add_block('simulink/Math Operations/Sum', [blk '/D_' r], 'Inputs', '+-', 'Position', [650, y, 670, y + 30]);
add_block('simulink/Math Operations/Gain', [blk '/M_' r], 'Gain', 'f_meas', 'Position', [710, y, 750, y + 30]);
add_line(blk, ['PS_' r '/1'], ['I_' r '/1']);
add_line(blk, ['I_' r '/1'], ['D_' r '/1']);
add_line(blk, ['I_' r '/1'], ['T_' r '/1'], 'autorouting', 'on');
add_line(blk, ['T_' r '/1'], ['D_' r '/2'], 'autorouting', 'on');
add_line(blk, ['D_' r '/1'], ['M_' r '/1']);
end

function cp = connection_ports(blk, b)
% create Connection Ports: first all left, then all right ones (port numbers),
% return in catalogue order
left  = find(strcmp({b.ports.side}, 'left'));
right = find(strcmp({b.ports.side}, 'right'));
cp = zeros(1, numel(b.ports));
nr = 0;
for k = [left right]
    nr = nr + 1;
    p = b.ports(k);
    if strcmp(p.side, 'left'), side = 'Left'; x = 20; else, side = 'Right'; x = 600; end
    cp(k) = add_block('nesl_utility/Connection Port', [blk '/' p.name], ...
        'Position', [x, 40 + 40*nr, x + 30, 56 + 40*nr], 'Side', side, 'Port', num2str(nr));
end
end

function h = port_of(block_handle)
ph = get_param(block_handle, 'PortHandles');
h  = [ph.RConn ph.LConn];
h  = h(1);
end

function h = conn(ph, side, k)
if side == 'L', h = ph.LConn(k); else, h = ph.RConn(k); end
end

%% ========================= masks =========================
function add_mask_parameter(mo, p)
% create mask parameter with unit in the prompt and value-range check
if isempty(p.unit), prompt = p.prompt; else, prompt = sprintf('%s [%s]', p.prompt, p.unit); end
switch p.type
    case 'edit'
        mo.addParameter('Name', p.name, 'Prompt', prompt, 'Type', 'edit', 'Value', p.value, 'Evaluate', 'on');
        add_rule(mo, p);
    case 'popup'
        mo.addParameter('Name', p.name, 'Prompt', prompt, 'Type', 'popup', 'TypeOptions', p.options, ...
                        'Value', p.value, 'Evaluate', 'on');
    case 'checkbox'
        mo.addParameter('Name', p.name, 'Prompt', prompt, 'Type', 'checkbox', 'Value', p.value, 'Evaluate', 'on');
    case 'text'
        mo.addParameter('Name', p.name, 'Prompt', prompt, 'Type', 'edit', 'Value', p.value, 'Evaluate', 'off');
end
end

function add_rule(mo, p)
% rule from the catalogue (pos; int; vector; min=x; max=x) as mask constraint
c = Simulink.Mask.Constraints;
c.Name = ['vr_' p.name];
r = c.addParameterConstraintRule();
r.Complexity = {'real'};
r.Finiteness = {'finite'};
r.Dimension  = {'scalar'};
for t = strsplit(p.rule, ';')
    tok = strtrim(t{1});
    if isempty(tok), continue; end
    if strcmp(tok, 'pos'),          r.Sign = {'positive'};
    elseif strcmp(tok, 'int'),      r.Fraction = {'integer'};
    elseif strcmp(tok, 'vector'),   r.Dimension = {'scalar', 'row vector', 'column vector'};
    elseif startsWith(tok, 'min='), r.Minimum = extractAfter(tok, 'min=');
    elseif startsWith(tok, 'max='), r.Maximum = extractAfter(tok, 'max=');
    else, error('build_library:rule', 'Unbekannte Regel "%s" bei Parameter %s.', tok, p.name);
    end
end
mo.addParameterConstraint(c);
q = mo.getParameter(p.name);
q.ConstraintName = c.Name;
end

function t = mask_text(b, long)
% description (short) or help (long) with equations and source (German)
t = sprintf('%s\n\nGleichungen:\n%s\n\nQuelle: %s', b.description, b.equations, b.source);
if strcmp(b.status, 'placeholder')
    t = sprintf('%s\n\nStand: Platzhalter mit Anschlüssen und Maske, noch ohne Physik.', t);
end
if long
    pz = arrayfun(@(p) sprintf('  %-14s %s', p.name, rule_text(p)), b.par, 'UniformOutput', false);
    if isempty(pz), pz = {'  (keine)'}; end
    t = sprintf(['%s\n\nParameter und Wertebereiche:\n%s\n\nAlle Standardwerte sind Beispielwerte ' ...
                 '(parameter/asm_standard.m), keine Datenblattwerte.\nSpezifikation: doku/SPEC.md'], ...
                t, strjoin(pz, newline));
end
end

function t = rule_text(p)
% value range as German text for the mask help
switch p.type
    case 'popup',    t = ['Auswahl: ' strjoin(p.options, ' | ')];
    case 'checkbox', t = 'ein/aus';
    case 'text',     t = 'Text';
    otherwise
        t = {};
        for tok = strsplit(p.rule, ';')
            switch strtrim(tok{1})
                case 'pos',    t{end+1} = '> 0'; %#ok<AGROW>
                case 'int',    t{end+1} = 'ganzzahlig'; %#ok<AGROW>
                case 'vector', t{end+1} = 'Vektor'; %#ok<AGROW>
                case '',       % nothing
                otherwise,     t{end+1} = strrep(strrep(strtrim(tok{1}), 'min=', '≥ '), 'max=', '≤ '); %#ok<AGROW>
            end
        end
        if isempty(t), t = 'endlich'; else, t = strjoin(t, ', '); end
        if ~isempty(p.unit), t = sprintf('%s  [%s]', t, p.unit); end
end
end

%% ========================= helper functions =========================
function q = ssc_blocks(ssclib)
% map component path (SourceFile) -> block path in the Simscape library
q = containers.Map();
bl = find_system(ssclib, 'LookUnderMasks', 'all', 'Type', 'block');
for k = 1:numel(bl)
    try
        src = get_param(bl{k}, 'SourceFile');
    catch
        continue;
    end
    if ~isempty(src), q(src) = bl{k}; end
end
end

function h = block_height(b)
n = max([sum(strcmp({b.ports.side}, 'left')), sum(strcmp({b.ports.side}, 'right')) + numel(b.outputs), ...
         numel(b.inputs), numel(b.outputs), 2]);
h = 25*n + 10;
end

function t = zero_value(n)
if n == 1, t = '0'; else, t = sprintf('zeros(%d,1)', n); end
end

function t = colour(rgb)
t = sprintf('[%g %g %g]', rgb);
end
