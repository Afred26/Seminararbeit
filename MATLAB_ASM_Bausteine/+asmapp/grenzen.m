function G = grenzen()
%GRENZEN Wertebereiche der Eingabefelder, übernommen aus dem Bausteinkatalog (+asmbib/katalog.m).
%   G = asmapp.grenzen() liefert eine Struktur, ein Feld je Eingabegröße von asmapp.simuliere:
%     G.<feld>.min, .max     Grenzen (±Inf: keine)
%     G.<feld>.min_offen     true: Wert muss > min sein (Katalogregel "pos")
%     G.<feld>.ganz          true: ganze Zahl
%     G.<feld>.prompt, .einheit, .baustein, .parameter   Herkunft im Katalog
%
%   Einzige Quelle bleibt der Katalog; hier steht nur die Zuordnung Feld -> Baustein/Parameter.
%   Ausnahme: t_end (Simulationsdauer) ist kein Maskenparameter und hat die Regel "pos".

% Feld | Baustein-id | Maskenparameter
Z = {
    'U_L',      'netz3',            'U_L'
    'f1',       'netz3',            'f1'
    't_ein',    'netz3',            't_ein'
    'R1',       'asm_standard',     'R1'
    'L1s',      'asm_standard',     'L1s'
    'Lh',       'asm_standard',     'Lh'
    'R2b',      'asm_standard',     'R2b'
    'L2sb',     'asm_standard',     'L2sb'
    'p',        'asm_standard',     'p'
    'J_M',      'asm_standard',     'J_M'
    'M_L',      'last_konstant',    'M_L0'       % gleiche Regel wie Lüfter M_B (min=0)
    'dM_L',     'laststoss',        'dM_L'
    't_stoss',  'laststoss',        't_stoss'
    'J_L',      'schwungmasse',     'J'
    'Bhat',     'ideales_drehfeld', 'Bhat'
    'phi2_fix', 'ideales_drehfeld', 'phi2_fix'
    };

K = asmbib.katalog();
G = struct();
for k = 1:size(Z, 1)
    b = K(strcmp({K.id}, Z{k, 2}));
    q = b.par(strcmp({b.par.name}, Z{k, 3}));
    G.(Z{k, 1}) = regel(q.regel, q.prompt, q.einheit, b.name, q.name);
end
G.t_end = regel('pos', 'Simulationsdauer t_End', 's', '', 'StopTime');
end

function g = regel(r, prompt, einheit, baustein, parameter)
% Katalogregel (pos; ganz; min=x; max=x) -> Grenzen
g = struct('min', -Inf, 'max', Inf, 'min_offen', false, 'ganz', false, ...
           'prompt', prompt, 'einheit', einheit, 'baustein', baustein, 'parameter', parameter);
for t = strsplit(r, ';')
    t1 = strtrim(t{1});
    if strcmp(t1, 'pos')
        g.min = max(g.min, 0);  g.min_offen = true;
    elseif strcmp(t1, 'ganz')
        g.ganz = true;
    elseif startsWith(t1, 'min=')
        g.min = str2double(t1(5:end));  g.min_offen = false;
    elseif startsWith(t1, 'max=')
        g.max = str2double(t1(5:end));
    end
end
end
