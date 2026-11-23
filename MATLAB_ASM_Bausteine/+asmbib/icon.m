function d = icon(b)
%ICON Maskenanzeige (MaskDisplay) eines Bausteins aus dem Katalog.
%   d = asmbib.icon(b) liefert die Zeichenbefehle: Kategoriesymbol, Kurzzeichen und
%   Portbeschriftungen. Einheiten der Maske: normalized (0 ... 1).

% Linienfarbe = ForegroundColor des Blocks (Kategoriefarbe, gesetzt in build_library)
z = {};

% Kategoriesymbol
kreis = @(r) sprintf('plot(0.5+%g*cos(0:0.05:6.3), 0.5+%g*sin(0:0.05:6.3));', r, r);
switch b.kategorie
    case 'Quellen'
        z{end+1} = kreis(0.3);
    case 'Maschine'
        z{end+1} = kreis(0.36);
        z{end+1} = kreis(0.26);
    case 'Mechanik'
        z{end+1} = 'plot([0.05 0.95], [0.5 0.5]);';
    case 'Messgeraete'
        z{end+1} = kreis(0.3);
        z{end+1} = 'plot([0.5 0.68], [0.5 0.68]);';
    case 'Didaktik'
        z{end+1} = 'plot([0.1 0.9 0.9 0.1 0.1], [0.15 0.15 0.85 0.85 0.15]);';
    case 'Referenz'
        z{end+1} = 'plot([0.1 0.9], [0.1 0.1]); plot([0.1 0.9], [0.9 0.9]);';
end

% Kurzzeichen (TeX); der Schreiber zeigt seinen Titel (Maskenparameter "titel")
if strcmp(b.id, 'schreiber')
    z{end+1} = ['text(0.5, 0.6, ''Schreiber'', ''horizontalAlignment'', ''center'');' newline ...
                'text(0.5, 0.3, titel, ''horizontalAlignment'', ''center'');'];
else
    z{end+1} = sprintf(['text(0.5, 0.5, ''%s'', ''horizontalAlignment'', ''center'', ' ...
                        '''verticalAlignment'', ''middle'', ''texmode'', ''on'');'], kurzzeichen(b.symbol));
end

% Portbeschriftungen
nl = 0; nr = 0;
for p = b.ports
    lbl = strrep(p.name, '_', '\_');
    if strcmp(p.seite, 'links')
        nl = nl + 1; z{end+1} = sprintf('port_label(''LConn'', %d, ''%s'', ''texmode'', ''on'');', nl, lbl); %#ok<AGROW>
    else
        nr = nr + 1; z{end+1} = sprintf('port_label(''RConn'', %d, ''%s'', ''texmode'', ''on'');', nr, lbl); %#ok<AGROW>
    end
end
for k = 1:numel(b.ein)
    z{end+1} = sprintf('port_label(''input'', %d, ''%s'', ''texmode'', ''on'');', k, tex(b.ein(k).name)); %#ok<AGROW>
end
for k = 1:numel(b.aus)
    z{end+1} = sprintf('port_label(''output'', %d, ''%s'', ''texmode'', ''on'');', k, tex(b.aus(k).name)); %#ok<AGROW>
end
d = strjoin(z, newline);
end

function t = kurzzeichen(symbol)
% Kurzzeichen je Symbolcode (TeX-Schreibweise)
tab = struct( ...
    'netz', '3~', 'erde', '\perp', 'motor', 'M 3~', 'stator', 'Stator', ...
    'luftspalt', 'B(\gamma,t)', 'rotor', 'Käfig', 'klemmen', 'Y / \Delta', ...
    'masse', 'J', 'welle', 'c, d', 'last', 'M_L', 'stoss', '\DeltaM_L', 'reibung', 'k_R', ...
    'bezug', 'Bezug', 'A', 'A', 'V', 'V', 'A3', 'A 3~', 'V3', 'V 3~', 'W', 'W', 'M', 'M', ...
    'n', 'n', 'B', 'B', 'scope', 'Schreiber', 'feld', 'Drehfeld', 'stab', 'Stab', ...
    'anzeige', 'Anzeige', 'spulen', 'B_U B_V B_W', 'kennlinie', 'M(n)', 'ref', 'Referenz', ...
    'kloss', 'Kloss', 'schleife', 'Schleife');
t = tab.(symbol);
end

function t = tex(name)
% Signalnamen für TeX: psi_h -> \psi_h, phi_el -> \phi_{el}, i_mu -> i_\mu, theta2 -> \theta2
t = regexprep(name, '^(psi|phi|theta|th)(?=_|\d|$)', '\\$1');
t = regexprep(t, '_(mu|perp)$', '_\\$1');
t = regexprep(t, '_(\w{2,})', '_{$1}');
t = regexprep(t, '^\\th(?=_|$)', '\\vartheta');
t = regexprep(t, '\\theta(\d)', '\\theta_$1');
end
