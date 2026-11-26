function [ok, msg] = check_value(field, value, G)
%CHECK_VALUE Checks an input value against the value range from the catalogue.
%   [ok, msg] = asmapp.check_value(field, value)
%   [ok, msg] = asmapp.check_value(field, value, G)    G = asmapp.limits() (saves reloading)
%   asmapp.check_value(P)                              checks all fields of struct P, error
%                                                      'asm:value' at the first invalid value
%
%   Additionally always: real, finite, scalar (conventions, section 4). Messages are German.
%   Empty values are allowed only for t_end (automatic simulation time of the loop).

if nargin < 3, G = asmapp.limits(); end
if isstruct(field)                                      % whole parameter struct
    P = field;
    for f = fieldnames(G)'
        if isfield(P, f{1}) && ~(strcmp(f{1}, 't_end') && isempty(P.(f{1})))
            [ok1, m] = asmapp.check_value(f{1}, P.(f{1}), G);
            if ~ok1, error('asm:value', '%s', m); end
        end
    end
    ok = true;  msg = '';
    return;
end

g = G.(field);
name = sprintf('%s [%s]', g.prompt, g.unit);
ok = false;
if ~(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value))
    msg = sprintf('%s: endliche reelle Zahl erwartet.', name);
elseif g.integer && value ~= round(value)
    msg = sprintf('%s: ganze Zahl erwartet.', name);
elseif g.min_open && value <= g.min
    msg = sprintf('%s muss > %g sein.', name, g.min);
elseif ~g.min_open && value < g.min
    msg = sprintf('%s muss ≥ %g sein.', name, g.min);
elseif value > g.max
    msg = sprintf('%s muss ≤ %g sein.', name, g.max);
else
    ok = true;  msg = '';
end
end
