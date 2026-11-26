function G = limits()
%LIMITS Value ranges of the input fields, taken from the block catalogue (+asmtools/catalog.m).
%   G = asmapp.limits() returns a struct with one field per input quantity of run_asm:
%     G.<field>.min, .max     limits (+-Inf: none)
%     G.<field>.min_open      true: value must be > min (catalogue rule "pos")
%     G.<field>.integer       true: integer
%     G.<field>.prompt, .unit, .block, .parameter   origin in the catalogue (prompt/unit German)
%
%   The catalogue stays the single source; here only the mapping field -> block/parameter is
%   defined. Exceptions without mask parameter: t_end (simulation time, rule "pos"), the solver
%   settings max_step and rel_tol (model parameters) and the slip of the conductor loop s_loop
%   (rule of the ideal field).

% field | block id | mask parameter
Z = {
    'U_L',      'grid3',          'U_L'
    'f1',       'grid3',          'f1'
    't_on',     'grid3',          't_on'
    'R1',       'asm_standard',   'R1'
    'L1s',      'asm_standard',   'L1s'
    'Lh',       'asm_standard',   'Lh'
    'R2b',      'asm_standard',   'R2b'
    'L2sb',     'asm_standard',   'L2sb'
    'p',        'asm_standard',   'p'
    'J_M',      'asm_standard',   'J_M'
    'MK',       'asm_kloss',      'MK'
    'sK',       'asm_kloss',      'sK'
    'M_L',      'load_constant',  'M_L0'       % same rule as fan M_B (min=0)
    'dM_L',     'load_step',      'dM_L'
    't_step',   'load_step',      't_step'
    'J_L',      'inertia',        'J'
    'Bhat',     'ideal_field',    'Bhat'
    'phi2_fix', 'ideal_field',    'phi2_fix'
    's_loop',   'ideal_field',    's'
    };

K = asmtools.catalog();
G = struct();
for k = 1:size(Z, 1)
    b = K(strcmp({K.id}, Z{k, 2}));
    q = b.par(strcmp({b.par.name}, Z{k, 3}));
    G.(Z{k, 1}) = rule(q.rule, q.prompt, q.unit, b.name, q.name);
end
G.t_end = rule('pos', 'Simulationsdauer t_End', 's', '', 'StopTime');
G.max_step = rule('pos;max=0.01', 'maximale Schrittweite', 's', '', 'MaxStep');
G.rel_tol = rule('pos;max=0.01', 'relative Toleranz', '-', '', 'RelTol');
end

function g = rule(r, prompt, unit, block, parameter)
% catalogue rule (pos; int; min=x; max=x) -> limits
g = struct('min', -Inf, 'max', Inf, 'min_open', false, 'integer', false, ...
           'prompt', prompt, 'unit', unit, 'block', block, 'parameter', parameter);
for t = strsplit(r, ';')
    t1 = strtrim(t{1});
    if strcmp(t1, 'pos')
        g.min = max(g.min, 0);  g.min_open = true;
    elseif strcmp(t1, 'int')
        g.integer = true;
    elseif startsWith(t1, 'min=')
        g.min = str2double(t1(5:end));  g.min_open = false;
    elseif startsWith(t1, 'max=')
        g.max = str2double(t1(5:end));
    end
end
end
