function d = icon(b)
%ICON Mask display (MaskDisplay) of a block from the catalogue.
%   d = asmtools.icon(b) returns the drawing commands: category symbol, short label and
%   port labels. Mask units: normalized (0 ... 1).

% line colour = ForegroundColor of the block (category colour, set in build_library)
z = {};

% category symbol
circle = @(r) sprintf('plot(0.5+%g*cos(0:0.05:6.3), 0.5+%g*sin(0:0.05:6.3));', r, r);
switch b.category
    case 'sources'
        z{end+1} = circle(0.3);
    case 'machine'
        z{end+1} = circle(0.36);
        z{end+1} = circle(0.26);
    case 'mechanics'
        z{end+1} = 'plot([0.05 0.95], [0.5 0.5]);';
    case 'sensors'
        z{end+1} = circle(0.3);
        z{end+1} = 'plot([0.5 0.68], [0.5 0.68]);';
    case 'didactics'
        z{end+1} = 'plot([0.1 0.9 0.9 0.1 0.1], [0.15 0.15 0.85 0.85 0.15]);';
    case 'reference'
        z{end+1} = 'plot([0.1 0.9], [0.1 0.1]); plot([0.1 0.9], [0.9 0.9]);';
end

% short label (TeX); the recorder shows its title (mask parameter "title_text")
if strcmp(b.id, 'recorder')
    z{end+1} = ['text(0.5, 0.6, ''Schreiber'', ''horizontalAlignment'', ''center'');' newline ...
                'text(0.5, 0.3, title_text, ''horizontalAlignment'', ''center'');'];
else
    z{end+1} = sprintf(['text(0.5, 0.5, ''%s'', ''horizontalAlignment'', ''center'', ' ...
                        '''verticalAlignment'', ''middle'', ''texmode'', ''on'');'], short_label(b.symbol));
end

% port labels
nl = 0; nr = 0;
for p = b.ports
    lbl = strrep(p.name, '_', '\_');
    if strcmp(p.side, 'left')
        nl = nl + 1; z{end+1} = sprintf('port_label(''LConn'', %d, ''%s'', ''texmode'', ''on'');', nl, lbl); %#ok<AGROW>
    else
        nr = nr + 1; z{end+1} = sprintf('port_label(''RConn'', %d, ''%s'', ''texmode'', ''on'');', nr, lbl); %#ok<AGROW>
    end
end
for k = 1:numel(b.inputs)
    z{end+1} = sprintf('port_label(''input'', %d, ''%s'', ''texmode'', ''on'');', k, tex(b.inputs(k).name)); %#ok<AGROW>
end
for k = 1:numel(b.outputs)
    z{end+1} = sprintf('port_label(''output'', %d, ''%s'', ''texmode'', ''on'');', k, tex(b.outputs(k).name)); %#ok<AGROW>
end
d = strjoin(z, newline);
end

function t = short_label(symbol)
% short label per symbol code (TeX notation; shown on the block, German)
tab = struct( ...
    'grid', '3~', 'ground', '\perp', 'motor', 'M 3~', 'stator', 'Stator', ...
    'airgap', 'B(\gamma,t)', 'rotor', 'Käfig', 'terminals', 'Y / \Delta', ...
    'mass', 'J', 'shaft', 'c, d', 'load', 'M_L', 'step', '\DeltaM_L', 'friction', 'k_R', ...
    'reference', 'Bezug', 'A', 'A', 'V', 'V', 'A3', 'A 3~', 'V3', 'V 3~', 'W', 'W', 'M', 'M', ...
    'n', 'n', 'B', 'B', 'scope', 'Schreiber', 'field', 'Drehfeld', 'bar', 'Stab', ...
    'display', 'Anzeige', 'coils', 'B_U B_V B_W', 'curve', 'M(n)', 'ref', 'Referenz', ...
    'kloss', 'Kloss', 'loop', 'Schleife');
t = tab.(symbol);
end

function t = tex(name)
% signal names for TeX: psi_h -> \psi_h, phi_el -> \phi_{el}, i_mu -> i_\mu, theta2 -> \theta_2
t = regexprep(name, '^(psi|phi|theta|th)(?=_|\d|$)', '\\$1');
t = regexprep(t, '_(mu|perp)$', '_\\$1');
t = regexprep(t, '_(\w{2,})', '_{$1}');
t = regexprep(t, '^\\th(?=_|$)', '\\vartheta');
t = regexprep(t, '\\theta(\d)', '\\theta_$1');
end
