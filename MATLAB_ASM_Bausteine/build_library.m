function info = build_library()
%BUILD_LIBRARY Baut die ASM-Bausteinbibliothek vollständig per Skript.
%   info = build_library() erzeugt im Ordner lib/
%     asmlib_lib.slx        Simscape-Bibliothek aus den .ssc-Quellen in +asmlib (sscbuild)
%     asm_bausteine_lib.slx Hauptbibliothek mit den Untergruppen Quellen, Maschine, Mechanik,
%                           Messgeräte, Didaktik, Referenz (erscheint im Library Browser)
%   Beide Dateien sind generiert und werden nicht von Hand bearbeitet.
%
%   Grundlage ist der Bausteinkatalog asmbib.katalog (Ports, Masken, Wertebereiche,
%   Hilfetexte). Jeder Baustein ist ein maskiertes Subsystem (Simulink.Mask):
%     physikalisch  Simscape-Komponente aus +asmlib, physikalische Anschlüsse über
%                   Connection Ports, Ausgänge über PS-Simulink-Wandler
%     kompakt       zerlegter Motor (Klemmbrett, Stator, Luftspalt-Drehfeld, Käfigläufer)
%     fl            Block der Simscape Foundation Library
%     simulink      reines Simulink-Subsystem
%   Phase 1: Platzhalter mit korrekten Ports und Masken, noch ohne Physik.
%
%   Rückgabe info: Struktur mit Dateinamen, Anzahl Bausteine und Bauzeit.

t0 = tic;
wurzel = fileparts(mfilename('fullpath'));
libdir = fullfile(wurzel, 'lib');
if ~exist(libdir, 'dir'), mkdir(libdir); end
addpath(wurzel, libdir, fullfile(wurzel, 'parameter'));

haupt   = 'asm_bausteine_lib';
ssclib  = 'asmlib_lib';
datei   = fullfile(libdir, [haupt '.slx']);
sscdat  = fullfile(libdir, [ssclib '.slx']);

% offene Bibliotheken schließen, alte Dateien entfernen
for m = {haupt, ssclib}
    if bdIsLoaded(m{1}), close_system(m{1}, 0); end
end
for f = {datei, sscdat}
    if exist(f{1}, 'file'), delete(f{1}); end
end

%% 1 Simscape-Bibliothek aus +asmlib
alterOrdner = cd(wurzel);
aufraeumen  = onCleanup(@() cd(alterOrdner));
if exist('sscbuild', 'file')                         % ab R2024b
    sscbuild('asmlib', '-output', sscdat);
else                                                 % R2023b ... R2024a
    ssc_build('asmlib');
    movefile(fullfile(wurzel, [ssclib '.slx']), sscdat);
end
load_system(ssclib);
quelle = ssc_bloecke(ssclib);                         % Komponentenpfad -> Bibliotheksblock

%% 2 Hauptbibliothek
K = asmbib.katalog();
new_system(haupt, 'Library');
set_param(haupt, 'EnableLBRepository', 'on');        % im Library Browser anzeigen
set_param(haupt, 'Description', ['ASM-Bausteinbibliothek (Drehstrom-Asynchronmotor), ' ...
    'Seminararbeit DHBW Mannheim. Generiert mit build_library.m - nicht von Hand bearbeiten.']);

kategorien = fieldnames(asmbib.stil());
for i = 1:numel(kategorien)
    kat = kategorien{i};
    st  = asmbib.stil(kat);
    sub = [haupt '/' st.anzeige];
    add_block('built-in/Subsystem', sub, 'Position', [40 + 140*(i-1), 40, 140 + 140*(i-1), 110]);
    mo = Simulink.Mask.create(sub);                  % Untergruppe wie in fl_lib: maskiert, ohne Parameter
    mo.Display = sprintf('disp(''%s'');', st.anzeige);
    set_param(sub, 'ShowName', 'off', 'BackgroundColor', farbe(st.hintergrund), ...
                   'ForegroundColor', farbe(st.vordergrund));

    Kk = K(strcmp({K.kategorie}, kat));
    y  = 40;
    for j = 1:numel(Kk)
        h = baustein_hoehe(Kk(j));
        x = 60 + 260*mod(j-1, 3);
        if j > 1 && mod(j-1, 3) == 0, y = y + yzeile + 70; end
        if mod(j-1, 3) == 0, yzeile = 0; end
        yzeile = max(yzeile, h);
        baue_baustein([sub '/' Kk(j).name], Kk(j), [x, y, x + 130, y + h], quelle);
    end
end

set_param(haupt, 'Lock', 'on');
save_system(haupt, datei);
close_system(haupt, 0);
close_system(ssclib, 0);

info = struct('bibliothek', datei, 'simscape_bibliothek', sscdat, ...
              'anzahl', numel(K), 'bauzeit_s', toc(t0));
fprintf('build_library: %d Bausteine in %.1f s -> %s\n', info.anzahl, info.bauzeit_s, datei);
end

%% ========================= Bausteine =========================
function baue_baustein(blk, b, pos, quelle)
% Maskiertes Subsystem mit Inhalt, Ports, Maske und Farbe anlegen
add_block('built-in/Subsystem', blk, 'Position', pos);
st = asmbib.stil(b.kategorie);

switch b.art
    case 'physikalisch'
        innen = [blk '/' b.id];
        add_block(quelle(b.ssc), innen, 'Position', [200 40 300 40 + baustein_hoehe(b)]);
        verbinde_ports(blk, b, innen);
        verbinde_ausgaenge(blk, b, innen);
        uebergebe_parameter(innen, {b.par.name});
    case 'fl'
        innen = [blk '/' b.id];
        add_block(b.ssc, innen, 'Position', [200 40 240 80]);
        verbinde_ports(blk, b, innen);
    case 'kompakt'
        baue_kompakt(blk, b, quelle);
    case 'ee'
        baue_ee_referenz(blk, b);
    case 'simulink'
        baue_simulink(blk, b);
end

% Maske
mo = Simulink.Mask.create(blk);
mo.Type        = ['ASM-Bibliothek: ' b.name];
mo.Description = maskentext(b, false);
mo.Help        = maskentext(b, true);
mo.IconUnits   = 'normalized';
mo.IconOpaque  = 'opaque';
mo.Display     = asmbib.icon(b);
for p = b.par
    neuer_parameter(mo, p);
end
if strcmp(b.art, 'simulink')                       % MATLAB-System-Eigenschaften sind nicht abstimmbar
    for q = mo.Parameters, q.Tunable = 'off'; end
end
init = {};
if any(strcmp({b.par.name}, 'parametersatz'))
    satz = mo.getParameter('parametersatz');
    satz.Callback = 'asmbib.parametersatz(gcb);';
    S = asm_standard();
    std = {};
    for p = b.par                                     % Standard: Felder gesperrt
        if strcmp(p.typ, 'edit') && isfield(S, p.name)
            q = mo.getParameter(p.name);
            q.Enabled = 'off';
            std{end+1} = sprintf('%s = S.%s;', p.name, p.name); %#ok<AGROW>
        end
    end
    % Bei "Standard" gelten immer die Werte aus asm_standard.m, auch wenn ein Feld
    % programmgesteuert verändert wurde.
    init = [init, {'% Parametersatz "Standard": Werte aus parameter/asm_standard.m', ...
                   'if parametersatz == 1', '    S = asm_standard();', ['    ' strjoin(std, ' ')], 'end'}];
end
if strcmp(b.art, 'kompakt')
    init = [init, {'% wirksame Windungszahl aus der Luftspaltflussdichte im Bemessungspunkt', ...
                   'N1xi1 = p*(U_N/sqrt(3)*sqrt(2)/(2*pi*f_N))/(2*Bhat_N*l*r);'}];
end
mo.Initialization = strjoin(init, newline);
% Knöpfe für die Auswertung nach der Simulation
knoepfe = struct('drehfeld_anzeige', {{'Animation zeigen', 'asmbib.drehfeld_animation(gcb);'}}, ...
                 'kennlinienschreiber', {{'Kennlinie zeichnen', 'asmbib.kennlinie_bild(gcb);'}});
if isfield(knoepfe, b.id)
    k = knoepfe.(b.id);
    mo.addDialogControl('Type', 'pushbutton', 'Name', 'knopf_auswertung', 'Prompt', k{1}, 'Callback', k{2});
end
set_param(blk, 'BackgroundColor', farbe(st.hintergrund), 'ForegroundColor', farbe(st.vordergrund), ...
               'Tag', ['asmlib:' b.id]);
end

function baue_kompakt(blk, b, quelle)
% ASM Standard: zerlegter Motor unter der Maske
kb = [blk '/Klemmbrett'];  stt = [blk '/Stator'];
ls = [blk '/Luftspalt-Drehfeld'];  kl = [blk '/Käfigläufer'];
add_block(quelle('asmlib.maschine.klemmbrett'),    kb,  'Position', [160  60 260 260]);
add_block(quelle('asmlib.maschine.stator'),        stt, 'Position', [360  60 460 260]);
add_block(quelle('asmlib.maschine.luftspaltfeld'), ls,  'Position', [560 300 660 400]);
add_block(quelle('asmlib.maschine.kaefiglaeufer'), kl,  'Position', [760  60 860 260]);
pk = get_param(kb, 'PortHandles'); ps = get_param(stt, 'PortHandles');
pl = get_param(ls, 'PortHandles'); pr = get_param(kl, 'PortHandles');
for k = 1:6
    add_line(blk, pk.RConn(k), ps.LConn(k), 'autorouting', 'on');   % U1 ... W2
end
add_line(blk, ps.RConn(1), pr.LConn(1), 'autorouting', 'on');       % Stator LS - Käfigläufer LS
add_line(blk, pl.LConn(1), pr.LConn(1), 'autorouting', 'on');       % Luftspalt LS
% äußere Anschlüsse: a, b, c an das Klemmbrett, R, C an den Käfigläufer
ziel = {pk.LConn(1), pk.LConn(2), pk.LConn(3), pr.RConn(1), pr.RConn(2)};
cp = connection_ports(blk, b);
for k = 1:numel(cp)
    add_line(blk, port_von(cp(k)), ziel{k}, 'autorouting', 'on');
end

% Parameter der Maske an die Teilbausteine (N1xi1 berechnet die Maskeninitialisierung)
namen = [{b.par.name}, {'N1xi1'}];
for innen = {kb, stt, ls, kl}
    uebergebe_parameter(innen{1}, namen);
end

% Messbus: Name | Teilbaustein | rechter Anschluss | Einheit  (Teilbaustein '' = in Simulink berechnet)
% Rechte Anschlüsse: Stator [LS i1 u1], Luftspalt [psi_h Bhat i_mu], Käfigläufer [R C i2b M Om th_mech s psi_h]
quellen = { 'i1',      stt, 2, 'A';      'u1',      stt, 3, 'V'
            'psi_h',   ls,  1, 'Wb';     'phi_el',  '',  0, ''
            'Bhat',    ls,  2, 'T';      'i_mu',    ls,  3, 'A'
            'i2b',     kl,  3, 'A';      'M',       kl,  4, 'N*m'
            'n',       kl,  5, 'rpm';    'Om',      kl,  5, 'rad/s'
            'th_mech', kl,  6, 'rad';    'theta2',  '',  0, ''
            's',       kl,  7, '1' };
nb = size(quellen, 1);
bc = [blk '/Messbus'];
add_block('simulink/Signal Routing/Bus Creator', bc, 'Inputs', num2str(nb), ...
          'Position', [1180 60 1185 60 + 30*nb]);
for k = 1:nb                                              % Wandler für die Simscape-Ausgänge
    if isempty(quellen{k,2}), continue; end
    w = [blk '/PS_' quellen{k,1}];
    add_block('nesl_utility/PS-Simulink Converter', w, 'Unit', quellen{k,4}, ...
              'Position', [1040, 55 + 30*k, 1060, 75 + 30*k]);
    pq = get_param(quellen{k,2}, 'PortHandles');
    pw = get_param(w, 'PortHandles');
    add_line(blk, pq.RConn(quellen{k,3}), pw.LConn(1), 'autorouting', 'on');
end
% Winkel in Simulink (atan2 in Simscape würde Solver-Ereignisse erzeugen)
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
    h = add_line(blk, ['PS_' quellen{k,1} '/1'], ['Messbus/' num2str(k)], 'autorouting', 'on');
    set_param(h, 'Name', quellen{k,1});
end
add_block('simulink/Sinks/Out1', [blk '/Mess'], 'Position', [1240 200 1270 214]);
add_line(blk, 'Messbus/1', 'Mess/1');
end

function uebergebe_parameter(innen, namen)
% Parameter der inneren Simscape-Komponente auf gleichnamige Maskenvariablen setzen
dp = fieldnames(get_param(innen, 'DialogParameters'));
for k = 1:numel(namen)
    if any(strcmp(dp, namen{k}))
        set_param(innen, namen{k}, namen{k});
    end
end
end

function baue_ee_referenz(blk, b)
% ASM Referenz: ee_lib Induction Machine Squirrel Cage mit denselben ESB-Werten (SI), Stern mit
% freiem Sternpunkt, J_M als Schwungmasse an der Welle. Parameter als Ausdrücke der Maskenvariablen.
nl = newline;
im = [blk '/Maschine'];
add_block(b.ssc, im, 'Position', [300 80 420 200], ...
    'SRated', 'sqrt(3)*U_N*10', 'VRated', 'U_N', 'FRated', 'f_N', 'nPolePairs', 'p', ...
    'param_unit', 'ee.enum.unit.si', 'squirrel_cage', 'ee.enum.squirrelcage.Single', ...
    'zero_sequence', 'ee.enum.park.zerosequence.include', ...
    'Rs', 'R1', 'Xls', '2*pi*f_N*L1s', 'Rrd', 'R2b', 'Xlrd', '2*pi*f_N*L2sb', 'Xm', '2*pi*f_N*Lh', ...
    'X0', '2*pi*f_N*L1s', 'saturation_option', 'ee.enum.saturation.exclude', ...
    'initialization_option', 'ee.enum.asm.initialization.fluxvariables');
for v = {'psids', 'psiqs', 'psidr', 'psiqr'}                 % Start stromlos
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
    add_line(blk, port_von(cp(k)), ps.RConn(k), 'autorouting', 'on');
end
add_line(blk, ps.LConn(1), pm.RConn(2), 'autorouting', 'on');   % Stator ~1
add_line(blk, pm.RConn(3), pn.LConn(1), 'autorouting', 'on');   % Wicklungsende ~2 -> Stern
add_line(blk, port_von(cp(4)), pm.LConn(1), 'autorouting', 'on');  % Welle R
add_line(blk, port_von(cp(5)), pm.LConn(2), 'autorouting', 'on');  % Gehäuse C
add_line(blk, pj.LConn(1), pm.LConn(1), 'autorouting', 'on');
end

function baue_simulink(blk, b)
% Didaktik-Bausteine und Leiterschleife: asmbib.baue_didaktik. Sonst Platzhalter
% (Eingänge -> Terminator, Ausgänge <- Konstante null); Schreiber: Eingang -> Scope
if asmbib.baue_didaktik(blk, b), return; end
for k = 1:numel(b.ein)
    e = b.ein(k);
    add_block('simulink/Sources/In1', [blk '/' e.name], 'Position', [40, 40 + 60*(k-1), 70, 54 + 60*(k-1)], ...
              'Port', num2str(k));
    if strcmp(b.id, 'schreiber')
        add_block('simulink/Sinks/Scope', [blk '/Scope'], 'Position', [140, 25 + 60*(k-1), 180, 69 + 60*(k-1)]);
        add_line(blk, [e.name '/1'], 'Scope/1');
    else
        add_block('simulink/Sinks/Terminator', [blk '/T_' e.name], 'Position', [140, 37 + 60*(k-1), 160, 57 + 60*(k-1)]);
        add_line(blk, [e.name '/1'], ['T_' e.name '/1']);
    end
end
for k = 1:numel(b.aus)
    a = b.aus(k);
    add_block('simulink/Sources/Constant', [blk '/Null_' a.name], ...
              'Position', [240, 35 + 60*(k-1), 300, 65 + 60*(k-1)], 'Value', nullwert(a.breite));
    add_block('simulink/Sinks/Out1', [blk '/' a.name], 'Position', [380, 40 + 60*(k-1), 410, 54 + 60*(k-1)], ...
              'Port', num2str(k));
    add_line(blk, ['Null_' a.name '/1'], [a.name '/1']);
end
end

function verbinde_ports(blk, b, innen)
% Connection Ports des Subsystems mit den Knoten der inneren Komponente verbinden.
% Reihenfolge an der Komponente: links = LConn in Katalogreihenfolge, rechts = RConn.
ph = get_param(innen, 'PortHandles');
cp = connection_ports(blk, b);
nl = 0; nr = 0;
for k = 1:numel(b.ports)
    if strcmp(b.ports(k).seite, 'links') || isempty(ph.RConn)
        nl = nl + 1; ziel = alle_conn(ph, 'L', nl);
    else
        nr = nr + 1; ziel = alle_conn(ph, 'R', nr);
    end
    add_line(blk, port_von(cp(k)), ziel, 'autorouting', 'on');
end
end

function verbinde_ausgaenge(blk, b, innen)
% PS-Ausgänge (Rohsignale) der Komponente (rechts nach den Knoten) -> PS-Simulink-Wandler.
% Ausgänge des Bausteins: direkt ein Rohsignal oder ein Mittelwertausdruck (b.mittel) aus
% gleitenden Mittelwerten ⟨x⟩ = f_mess·(X(t) − X(t − 1/f_mess)), X = ∫ x dt.
ph = get_param(innen, 'PortHandles');
nrechts = sum(strcmp({b.ports.seite}, 'rechts'));
for k = 1:numel(b.roh)
    r = b.roh(k);
    y = 40 + 50*(k-1);
    add_block('nesl_utility/PS-Simulink Converter', [blk '/PS_' r.name], 'Position', [420, y, 440, y + 20], ...
              'Unit', r.einheit);
    pw = get_param([blk '/PS_' r.name], 'PortHandles');
    add_line(blk, ph.RConn(nrechts + k), pw.LConn(1), 'autorouting', 'on');
end
gemittelt = {};
for k = 1:numel(b.aus)
    a = b.aus(k);
    y = 40 + 50*(k-1);
    add_block('simulink/Sinks/Out1', [blk '/' a.name], 'Position', [1000, y + 3, 1030, y + 17], ...
              'Port', num2str(k));
    j = find(strcmp({b.mittel.name}, a.name));
    if isempty(j)
        add_line(blk, ['PS_' a.name '/1'], [a.name '/1']);
        continue;
    end
    m = b.mittel(j);
    if strcmp(m.art, 'mittel')
        for r = m.roh                                     % Mittelwertbildung je Rohsignal einmal
            if ~any(strcmp(gemittelt, r{1}))
                mittelwert(blk, r{1}, y);
                gemittelt{end+1} = r{1}; %#ok<AGROW>
            end
        end
        vor = 'M_';                                       % Eingänge: Mittelwerte
    else
        vor = 'PS_';                                      % Eingänge: Rohsignale direkt
    end
    fcn = [blk '/f_' a.name];
    add_block('simulink/User-Defined Functions/Fcn', fcn, 'Expr', m.expr, 'Position', [880, y, 950, y + 24]);
    if isscalar(m.roh)
        add_line(blk, [vor m.roh{1} '/1'], ['f_' a.name '/1'], 'autorouting', 'on');
    else
        mux = [blk '/mux_' a.name];
        add_block('simulink/Signal Routing/Mux', mux, 'Inputs', num2str(numel(m.roh)), ...
                  'Position', [840, y - 10, 845, y + 34]);
        for i = 1:numel(m.roh)
            add_line(blk, [vor m.roh{i} '/1'], sprintf('mux_%s/%d', a.name, i), 'autorouting', 'on');
        end
        add_line(blk, ['mux_' a.name '/1'], ['f_' a.name '/1']);
    end
    add_line(blk, ['f_' a.name '/1'], [a.name '/1']);
end
end

function mittelwert(blk, r, y)
% gleitender Mittelwert über eine Periode 1/f_mess: f_mess·(X(t) − X(t − T)), X = ∫ x dt
add_block('simulink/Continuous/Integrator', [blk '/I_' r], 'Position', [500, y, 530, y + 30]);
add_block('simulink/Continuous/Transport Delay', [blk '/T_' r], 'Position', [570, y + 40, 610, y + 70], ...
          'DelayTime', '1/f_mess', 'InitialOutput', '0', 'BufferSize', '16384');
add_block('simulink/Math Operations/Sum', [blk '/D_' r], 'Inputs', '+-', 'Position', [650, y, 670, y + 30]);
add_block('simulink/Math Operations/Gain', [blk '/M_' r], 'Gain', 'f_mess', 'Position', [710, y, 750, y + 30]);
add_line(blk, ['PS_' r '/1'], ['I_' r '/1']);
add_line(blk, ['I_' r '/1'], ['D_' r '/1']);
add_line(blk, ['I_' r '/1'], ['T_' r '/1'], 'autorouting', 'on');
add_line(blk, ['T_' r '/1'], ['D_' r '/2'], 'autorouting', 'on');
add_line(blk, ['D_' r '/1'], ['M_' r '/1']);
end

function cp = connection_ports(blk, b)
% Connection Ports anlegen: zuerst alle linken, dann alle rechten (Portnummern),
% Rückgabe in Katalogreihenfolge
links  = find(strcmp({b.ports.seite}, 'links'));
rechts = find(strcmp({b.ports.seite}, 'rechts'));
cp = zeros(1, numel(b.ports));
nr = 0;
for k = [links rechts]
    nr = nr + 1;
    p = b.ports(k);
    if strcmp(p.seite, 'links'), seite = 'Left'; x = 20; else, seite = 'Right'; x = 600; end
    cp(k) = add_block('nesl_utility/Connection Port', [blk '/' p.name], ...
        'Position', [x, 40 + 40*nr, x + 30, 56 + 40*nr], 'Side', seite, 'Port', num2str(nr));
end
end

function h = port_von(blockhandle)
ph = get_param(blockhandle, 'PortHandles');
h  = [ph.RConn ph.LConn];
h  = h(1);
end

function h = alle_conn(ph, seite, k)
if seite == 'L', h = ph.LConn(k); else, h = ph.RConn(k); end
end

%% ========================= Masken =========================
function neuer_parameter(mo, p)
% Maskenparameter mit Einheit im Prompt und Wertebereichsprüfung anlegen
if isempty(p.einheit), prompt = p.prompt; else, prompt = sprintf('%s [%s]', p.prompt, p.einheit); end
switch p.typ
    case 'edit'
        mo.addParameter('Name', p.name, 'Prompt', prompt, 'Type', 'edit', 'Value', p.wert, 'Evaluate', 'on');
        regel_anlegen(mo, p);
    case 'popup'
        mo.addParameter('Name', p.name, 'Prompt', prompt, 'Type', 'popup', 'TypeOptions', p.optionen, ...
                        'Value', p.wert, 'Evaluate', 'on');
    case 'checkbox'
        mo.addParameter('Name', p.name, 'Prompt', prompt, 'Type', 'checkbox', 'Value', p.wert, 'Evaluate', 'on');
    case 'text'
        mo.addParameter('Name', p.name, 'Prompt', prompt, 'Type', 'edit', 'Value', p.wert, 'Evaluate', 'off');
end
end

function regel_anlegen(mo, p)
% Regel aus dem Katalog (pos; ganz; vektor; min=x; max=x) als Maskenconstraint
c = Simulink.Mask.Constraints;
c.Name = ['wb_' p.name];
r = c.addParameterConstraintRule();
r.Complexity = {'real'};
r.Finiteness = {'finite'};
r.Dimension  = {'scalar'};
for t = strsplit(p.regel, ';')
    tok = strtrim(t{1});
    if isempty(tok), continue; end
    if strcmp(tok, 'pos'),         r.Sign = {'positive'};
    elseif strcmp(tok, 'ganz'),    r.Fraction = {'integer'};
    elseif strcmp(tok, 'vektor'),  r.Dimension = {'scalar', 'row vector', 'column vector'};
    elseif startsWith(tok, 'min='), r.Minimum = extractAfter(tok, 'min=');
    elseif startsWith(tok, 'max='), r.Maximum = extractAfter(tok, 'max=');
    else, error('build_library:regel', 'Unbekannte Regel "%s" bei Parameter %s.', tok, p.name);
    end
end
mo.addParameterConstraint(c);
q = mo.getParameter(p.name);
q.ConstraintName = c.Name;
end

function t = maskentext(b, lang)
% Beschreibung (kurz) bzw. Hilfe (lang) mit Gleichungen und Quelle
t = sprintf('%s\n\nGleichungen:\n%s\n\nQuelle: %s', b.beschreibung, b.gleichungen, b.quelle);
if strcmp(b.stand, 'Platzhalter')
    t = sprintf('%s\n\nStand: Platzhalter mit Anschlüssen und Maske, noch ohne Physik.', t);
end
if lang
    pz = arrayfun(@(p) sprintf('  %-14s %s', p.name, regeltext(p)), b.par, 'UniformOutput', false);
    if isempty(pz), pz = {'  (keine)'}; end
    t = sprintf(['%s\n\nParameter und Wertebereiche:\n%s\n\nAlle Standardwerte sind Beispielwerte ' ...
                 '(parameter/asm_standard.m), keine Datenblattwerte.\nSpezifikation: doku/SPEC.md'], ...
                t, strjoin(pz, newline));
end
end

function t = regeltext(p)
switch p.typ
    case 'popup',    t = ['Auswahl: ' strjoin(p.optionen, ' | ')];
    case 'checkbox', t = 'ein/aus';
    case 'text',     t = 'Text';
    otherwise
        t = {};
        for tok = strsplit(p.regel, ';')
            switch strtrim(tok{1})
                case 'pos',    t{end+1} = '> 0'; %#ok<AGROW>
                case 'ganz',   t{end+1} = 'ganzzahlig'; %#ok<AGROW>
                case 'vektor', t{end+1} = 'Vektor'; %#ok<AGROW>
                case '',       % nichts
                otherwise,     t{end+1} = strrep(strrep(strtrim(tok{1}), 'min=', '≥ '), 'max=', '≤ '); %#ok<AGROW>
            end
        end
        if isempty(t), t = 'endlich'; else, t = strjoin(t, ', '); end
        if ~isempty(p.einheit), t = sprintf('%s  [%s]', t, p.einheit); end
end
end

%% ========================= Hilfsfunktionen =========================
function q = ssc_bloecke(ssclib)
% Map Komponentenpfad (SourceFile) -> Blockpfad in der Simscape-Bibliothek
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

function h = baustein_hoehe(b)
n = max([sum(strcmp({b.ports.seite}, 'links')), sum(strcmp({b.ports.seite}, 'rechts')) + numel(b.aus), ...
         numel(b.ein), numel(b.aus), 2]);
h = 25*n + 10;
end

function t = nullwert(n)
if n == 1, t = '0'; else, t = sprintf('zeros(%d,1)', n); end
end

function t = farbe(rgb)
t = sprintf('[%g %g %g]', rgb);
end
